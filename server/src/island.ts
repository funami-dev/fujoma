import { DurableObject } from "cloudflare:workers";
import type { Env } from "./env";
import {
  EMOTES,
  FISH_COOLDOWN_MS,
  INTERACT_RANGE,
  ISLAND_RADIUS,
  MAX_CHAT_LENGTH,
  MAX_PLAYERS,
  RECIPES,
  ROCK_COOLDOWN_MS,
  SHORE_DISTANCE,
  TREE_FRUIT_COOLDOWN_MS,
  TREE_WOOD_COOLDOWN_MS,
  type ClientMessage,
  type Inventory,
  type Player,
  type ServerMessage,
  type WorldNode,
} from "./protocol";
import { generateNodes, type NodeLayout } from "./world";

/** Per-node cooldown timestamps (ms since epoch): [fruit/stone ready at, wood ready at]. */
type Cooldowns = Record<string, [number, number]>;

/** One Durable Object per island. Player state lives in each socket's attachment. */
export class Island extends DurableObject<Env> {
  private layout: NodeLayout[] = generateNodes();
  private cooldowns: Cooldowns = {};
  private lastFish = new Map<string, number>();

  constructor(ctx: DurableObjectState, env: Env) {
    super(ctx, env);
    ctx.blockConcurrencyWhile(async () => {
      this.cooldowns = (await ctx.storage.get<Cooldowns>("cooldowns")) ?? {};
    });
  }

  async fetch(_request: Request): Promise<Response> {
    if (this.ctx.getWebSockets().length >= MAX_PLAYERS) {
      return new Response("Island is full", { status: 503 });
    }
    const pair = new WebSocketPair();
    const [client, server] = Object.values(pair);
    this.ctx.acceptWebSocket(server);
    return new Response(null, { status: 101, webSocket: client });
  }

  async webSocketMessage(ws: WebSocket, raw: string | ArrayBuffer): Promise<void> {
    if (typeof raw !== "string" || raw.length > 1024) return;
    let msg: ClientMessage;
    try {
      msg = JSON.parse(raw);
    } catch {
      return;
    }
    const player = ws.deserializeAttachment() as Player | null;

    if (msg.t === "join") {
      if (!player) await this.join(ws, msg);
      return;
    }
    if (!player) return; // must join first

    switch (msg.t) {
      case "pos": {
        if (![msg.x, msg.z, msg.ry].every(Number.isFinite)) return;
        const len = Math.hypot(msg.x, msg.z);
        const k = len > ISLAND_RADIUS ? ISLAND_RADIUS / len : 1;
        player.x = msg.x * k;
        player.z = msg.z * k;
        player.ry = msg.ry;
        ws.serializeAttachment(player);
        this.broadcast({ t: "pos", id: player.id, x: player.x, z: player.z, ry: player.ry }, ws);
        break;
      }
      case "chat": {
        const text = String(msg.text ?? "").trim().slice(0, MAX_CHAT_LENGTH);
        if (text) this.broadcast({ t: "chat", id: player.id, name: player.name, text });
        break;
      }
      case "emote": {
        if ((EMOTES as readonly string[]).includes(msg.e)) {
          this.broadcast({ t: "emote", id: player.id, e: msg.e });
        }
        break;
      }
      case "interact":
        await this.interact(ws, player, String(msg.id));
        break;
      case "fish":
        await this.fish(ws, player);
        break;
      case "craft":
        await this.craft(ws, player, String(msg.recipe));
        break;
    }
  }

  webSocketClose(ws: WebSocket, code: number): void {
    const player = ws.deserializeAttachment() as Player | null;
    try {
      ws.close(code === 1005 ? 1000 : code);
    } catch {
      /* already closed */
    }
    if (player) {
      this.lastFish.delete(player.id);
      this.broadcast({ t: "left", id: player.id }, ws);
    }
  }

  webSocketError(ws: WebSocket): void {
    this.webSocketClose(ws, 1011);
  }

  // ------------------------------------------------------------ actions

  private async join(ws: WebSocket, msg: Extract<ClientMessage, { t: "join" }>): Promise<void> {
    const secret = String(msg.secret ?? "");
    if (!/^[A-Za-z0-9]{16,64}$/.test(secret)) {
      ws.close(4001, "bad secret");
      return;
    }
    const p: Player = {
      id: cleanId(msg.id),
      name: cleanName(msg.name),
      color: /^#[0-9a-fA-F]{6}$/.test(msg.color) ? msg.color : "#ffffff",
      x: 0,
      z: 0,
      ry: 0,
    };
    const profile = this.env.PROFILE.get(this.env.PROFILE.idFromName(p.id));
    if (!(await profile.auth(await sha256(secret)))) {
      ws.close(4003, "guest id taken");
      return;
    }
    if (ws.deserializeAttachment()) return; // joined while we were awaiting

    // A reconnecting guest replaces their stale socket.
    for (const other of this.ctx.getWebSockets()) {
      const o = other.deserializeAttachment() as Player | null;
      if (o && o.id === p.id) other.close(4000, "replaced");
    }
    ws.serializeAttachment(p);
    const players = this.players().filter((q) => q.id !== p.id);
    this.send(ws, {
      t: "welcome",
      you: p.id,
      players,
      nodes: this.nodes(),
      inv: await profile.inventory(),
    });
    this.broadcast({ t: "joined", p }, ws);
  }

  private async interact(ws: WebSocket, player: Player, id: string): Promise<void> {
    const node = this.layout.find((n) => n.id === id);
    if (!node) return;
    if (Math.hypot(node.x - player.x, node.z - player.z) > INTERACT_RANGE) {
      this.toast(ws, "Too far away");
      return;
    }
    const now = Date.now();
    const cd = this.cooldowns[id] ?? [0, 0];
    let item: string | null = null;
    let qty = 1;
    let text = "";

    if (node.k === "tree") {
      if (cd[0] <= now) {
        item = "apple";
        cd[0] = now + TREE_FRUIT_COOLDOWN_MS;
        text = "You picked an apple";
      } else if (cd[1] <= now) {
        item = "wood";
        cd[1] = now + TREE_WOOD_COOLDOWN_MS;
        text = "You gathered some wood";
      }
    } else if (cd[0] <= now) {
      item = "stone";
      qty = Math.random() < 0.25 ? 2 : 1;
      cd[0] = now + ROCK_COOLDOWN_MS;
      text = qty === 2 ? "You found 2 stones" : "You found a stone";
    }

    if (!item) {
      this.toast(ws, "Nothing to collect right now");
      return;
    }
    this.cooldowns[id] = cd;
    await this.ctx.storage.put("cooldowns", this.cooldowns);
    const inv = await this.profile(player).add(item, qty);
    this.send(ws, { t: "inv", inv });
    this.toast(ws, text);
    this.broadcast({ t: "node", id, ready_in: Math.max(0, cd[0] - now) });
  }

  private async fish(ws: WebSocket, player: Player): Promise<void> {
    if (Math.hypot(player.x, player.z) < SHORE_DISTANCE) {
      this.toast(ws, "Go to the shore to fish");
      return;
    }
    const now = Date.now();
    if ((this.lastFish.get(player.id) ?? 0) + FISH_COOLDOWN_MS > now) return;
    const profile = this.profile(player);
    if (((await profile.inventory()).fishing_rod ?? 0) < 1) {
      this.toast(ws, "You need a fishing rod (craft one from 3 wood)");
      return;
    }
    this.lastFish.set(player.id, now);
    if (Math.random() < 0.7) {
      this.send(ws, { t: "inv", inv: await profile.add("fish", 1) });
      this.toast(ws, "You caught a fish!");
    } else {
      this.toast(ws, "Nothing is biting...");
    }
  }

  private async craft(ws: WebSocket, player: Player, recipe: string): Promise<void> {
    const cost = RECIPES[recipe];
    if (!cost) return;
    const inv = await this.profile(player).craft(recipe, cost);
    if (!inv) {
      this.toast(ws, "Missing materials");
      return;
    }
    this.send(ws, { t: "inv", inv });
    this.toast(ws, `Crafted: ${recipe.replace("_", " ")}`);
  }

  // ------------------------------------------------------------ helpers

  private profile(player: Player) {
    return this.env.PROFILE.get(this.env.PROFILE.idFromName(player.id));
  }

  private nodes(): WorldNode[] {
    const now = Date.now();
    return this.layout.map((n) => ({
      ...n,
      ready_in: Math.max(0, (this.cooldowns[n.id]?.[0] ?? 0) - now),
    }));
  }

  private players(): Player[] {
    return this.ctx
      .getWebSockets()
      .map((w) => w.deserializeAttachment() as Player | null)
      .filter((p): p is Player => p !== null);
  }

  private toast(ws: WebSocket, text: string): void {
    this.send(ws, { t: "toast", text });
  }

  private send(ws: WebSocket, msg: ServerMessage): void {
    try {
      ws.send(JSON.stringify(msg));
    } catch {
      /* socket already gone */
    }
  }

  private broadcast(msg: ServerMessage, except?: WebSocket): void {
    for (const ws of this.ctx.getWebSockets()) {
      if (ws !== except && ws.deserializeAttachment()) this.send(ws, msg);
    }
  }
}

async function sha256(text: string): Promise<string> {
  const buf = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(text));
  return [...new Uint8Array(buf)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

function cleanId(id: unknown): string {
  const s = String(id ?? "").replace(/[^A-Za-z0-9_-]/g, "").slice(0, 36);
  return s || crypto.randomUUID();
}

function cleanName(name: unknown): string {
  const s = String(name ?? "").replace(/[\u0000-\u001f<>]/g, "").trim().slice(0, 16);
  return s || "Guest";
}

export type { Inventory };
