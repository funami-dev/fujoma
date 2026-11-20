import { DurableObject } from "cloudflare:workers";
import type { Env } from "./env";
import {
  COINS,
  EMOTES,
  PROPS,
  SELL_PRICES,
  SHOP_CATALOG,
  SHOP_CLEARANCE,
  SHOP_RANGE,
  SHOP_X,
  SHOP_Z,
  islandOffsetMinutes,
  shopIsOpen,
  MAX_DECOR_PER_ISLAND,
  MAX_DECOR_PER_PLAYER,
  MAX_HOUSES,
  PLACEABLE,
  PLACE_RANGE,
  ROOM_HALF,
  ROOM_PLACE_HALF,
  ROOM_REGION_X,
  doorOutside,
  houseCenter,
  roomCenter,
  roomSlotAt,
  type Decor,
  type House,
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
  private decor: Decor[] = [];
  private houses: House[] = [];
  private nextDecorId = 1;

  constructor(ctx: DurableObjectState, env: Env) {
    super(ctx, env);
    ctx.blockConcurrencyWhile(async () => {
      this.cooldowns = (await ctx.storage.get<Cooldowns>("cooldowns")) ?? {};
      this.decor = (await ctx.storage.get<Decor[]>("decor")) ?? [];
      this.houses = (await ctx.storage.get<House[]>("houses")) ?? [];
      this.nextDecorId = (await ctx.storage.get<number>("nextDecorId")) ?? 1;
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
        const c = this.constrain(msg.x, msg.z);
        if (!c) return;
        player.x = c.x;
        player.z = c.z;
        player.ry = msg.ry;
        ws.serializeAttachment(player);
        this.broadcast({ t: "pos", id: player.id, x: player.x, z: player.z, ry: player.ry, s: msg.s === true }, ws);
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
      case "place":
        await this.place(ws, player, msg);
        break;
      case "pickup":
        await this.pickup(ws, player, String(msg.id));
        break;
      case "rotate":
        this.rotate(ws, player, String(msg.id));
        break;
      case "buy":
        await this.buy(ws, player, String(msg.item));
        break;
      case "sell":
        await this.sell(ws, player, String(msg.item), Number(msg.qty));
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
    const newHouse = await this.assignHouse(p);
    await profile.claimStartingCoins();
    const players = this.players().filter((q) => q.id !== p.id);
    this.send(ws, {
      t: "welcome",
      you: p.id,
      players,
      nodes: this.nodes(),
      inv: await profile.inventory(),
      houses: this.houses,
      decor: this.decor,
      tz_offset: islandOffsetMinutes(),
    });
    this.broadcast({ t: "joined", p }, ws);
    if (newHouse) this.broadcast({ t: "house", h: newHouse }, ws);
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

  // ------------------------------------------------------------ houses and decoration

  /** Gives a guest the first free house slot. Returns the house if it is new or its name changed. */
  private async assignHouse(p: Player): Promise<House | null> {
    const existing = this.houses.find((h) => h.owner === p.id);
    if (existing) {
      if (existing.name === p.name) return null;
      existing.name = p.name;
      await this.ctx.storage.put("houses", this.houses);
      return existing;
    }
    const used = new Set(this.houses.map((h) => h.slot));
    for (let slot = 0; slot < MAX_HOUSES; slot++) {
      if (!used.has(slot)) {
        const house: House = { owner: p.id, name: p.name, slot };
        this.houses.push(house);
        await this.ctx.storage.put("houses", this.houses);
        return house;
      }
    }
    return null; // island is full of houses; the guest can still visit others
  }

  private houseBySlot(slot: number): House | undefined {
    return this.houses.find((h) => h.slot === slot);
  }

  /** Clamps a position to the island or to an existing room. Returns null for invalid positions. */
  private constrain(x: number, z: number): { x: number; z: number } | null {
    if (x < ROOM_REGION_X) {
      const len = Math.hypot(x, z);
      const k = len > ISLAND_RADIUS ? ISLAND_RADIUS / len : 1;
      return { x: x * k, z: z * k };
    }
    const slot = roomSlotAt(x);
    if (slot < 0 || slot >= MAX_HOUSES || !this.houseBySlot(slot)) return null;
    const c = roomCenter(slot);
    return {
      x: Math.min(c.x + ROOM_HALF, Math.max(c.x - ROOM_HALF, x)),
      z: Math.min(ROOM_HALF, Math.max(-ROOM_HALF, z)),
    };
  }

  /** Why (gx, gz) is not a valid place for `player` to decorate, or null if it is fine. */
  private placementProblem(player: Player, gx: number, gz: number): string | null {
    if (Math.hypot(gx - player.x, gz - player.z) > PLACE_RANGE) return "Too far away";
    if (this.decor.some((d) => d.gx === gx && d.gz === gz)) return "Something is already there";

    if (gx >= ROOM_REGION_X) {
      const slot = roomSlotAt(gx);
      const house = this.houseBySlot(slot);
      if (!house || roomSlotAt(player.x) !== slot || player.x < ROOM_REGION_X) return "Not inside this room";
      if (house.owner !== player.id) return "Only the owner can decorate this room";
      const c = roomCenter(slot);
      if (Math.abs(gx - c.x) > ROOM_PLACE_HALF || Math.abs(gz) > ROOM_PLACE_HALF) return "Outside the room";
      return null;
    }
    if (player.x >= ROOM_REGION_X) return "Not on the island";
    if (Math.hypot(gx, gz) > ISLAND_RADIUS - 1.5) return "Too close to the water";
    if (this.layout.some((n) => Math.hypot(n.x - gx, n.z - gz) < 1.8)) return "Something is in the way";
    if (Math.hypot(SHOP_X - gx, SHOP_Z - gz) < SHOP_CLEARANCE) return "Too close to the shop";
    if (PROPS.some((p) => Math.hypot(p.x - gx, p.z - gz) < p.r + 0.8)) return "Something is in the way";
    for (let slot = 0; slot < MAX_HOUSES; slot++) {
      const h = houseCenter(slot);
      const d = doorOutside(slot);
      if (Math.hypot(h.x - gx, h.z - gz) < 4.5 || Math.hypot(d.x - gx, d.z - gz) < 2.5) {
        return "Too close to a house";
      }
    }
    return null;
  }

  private async place(ws: WebSocket, player: Player, msg: Extract<ClientMessage, { t: "place" }>): Promise<void> {
    const item = String(msg.item);
    const gx = Math.round(Number(msg.gx));
    const gz = Math.round(Number(msg.gz));
    const rot = ((Math.round(Number(msg.rot)) % 4) + 4) % 4;
    if (!PLACEABLE.includes(item) || !Number.isFinite(gx) || !Number.isFinite(gz)) return;

    const problem = this.placementProblem(player, gx, gz);
    if (problem) {
      this.toast(ws, problem);
      return;
    }
    if (this.decor.length >= MAX_DECOR_PER_ISLAND) {
      this.toast(ws, "This island has too much decoration");
      return;
    }
    if (this.decor.filter((d) => d.owner === player.id).length >= MAX_DECOR_PER_PLAYER) {
      this.toast(ws, "You have placed too many objects");
      return;
    }
    const inv = await this.profile(player).take(item);
    if (!inv) {
      this.toast(ws, "You do not have that item");
      return;
    }
    const d: Decor = { id: `d${this.nextDecorId++}`, item, gx, gz, rot, owner: player.id };
    this.decor.push(d);
    await this.saveDecor();
    this.send(ws, { t: "inv", inv });
    this.broadcast({ t: "decor_add", d });
  }

  /** Decoration the player may change: anyone outside, only the owner inside a room. */
  private editableDecor(ws: WebSocket, player: Player, id: string): Decor | null {
    const d = this.decor.find((x) => x.id === id);
    if (!d) return null;
    if (Math.hypot(d.gx - player.x, d.gz - player.z) > PLACE_RANGE) {
      this.toast(ws, "Too far away");
      return null;
    }
    if (d.gx >= ROOM_REGION_X && this.houseBySlot(roomSlotAt(d.gx))?.owner !== player.id) {
      this.toast(ws, "Only the owner can change this room");
      return null;
    }
    return d;
  }

  private async pickup(ws: WebSocket, player: Player, id: string): Promise<void> {
    const d = this.editableDecor(ws, player, id);
    if (!d) return;
    this.decor = this.decor.filter((x) => x.id !== id);
    await this.saveDecor();
    this.send(ws, { t: "inv", inv: await this.profile(player).add(d.item, 1) });
    this.broadcast({ t: "decor_remove", id });
  }

  private rotate(ws: WebSocket, player: Player, id: string): void {
    const d = this.editableDecor(ws, player, id);
    if (!d) return;
    d.rot = (d.rot + 1) % 4;
    void this.saveDecor();
    this.broadcast({ t: "decor_rot", id, rot: d.rot });
  }

  private async saveDecor(): Promise<void> {
    await this.ctx.storage.put({ decor: this.decor, nextDecorId: this.nextDecorId });
  }

  // ------------------------------------------------------------ shop

  /** Why the player cannot use the shop right now, or null. */
  private shopProblem(player: Player): string | null {
    if (Math.hypot(SHOP_X - player.x, SHOP_Z - player.z) > SHOP_RANGE) return "Walk up to the shop counter";
    if (!shopIsOpen()) return "The shop is closed (open 8:00-22:00)";
    return null;
  }

  private async buy(ws: WebSocket, player: Player, item: string): Promise<void> {
    const price = SHOP_CATALOG[item];
    if (!price) return;
    const problem = this.shopProblem(player);
    if (problem) {
      this.toast(ws, problem);
      return;
    }
    const inv = await this.profile(player).buy(item, price);
    if (!inv) {
      this.toast(ws, "Not enough coins");
      return;
    }
    this.send(ws, { t: "inv", inv });
    this.toast(ws, `Bought: ${item.replace("_", " ")} (-${price} coins)`);
  }

  private async sell(ws: WebSocket, player: Player, item: string, qty: number): Promise<void> {
    const price = SELL_PRICES[item];
    const n = Math.floor(qty);
    if (!price || item === COINS || !Number.isFinite(n) || n < 1 || n > 999) return;
    const problem = this.shopProblem(player);
    if (problem) {
      this.toast(ws, problem);
      return;
    }
    const inv = await this.profile(player).sell(item, n, price);
    if (!inv) {
      this.toast(ws, "You do not have that many");
      return;
    }
    this.send(ws, { t: "inv", inv });
    this.toast(ws, `Sold ${n} ${item.replace("_", " ")} (+${n * price} coins)`);
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
