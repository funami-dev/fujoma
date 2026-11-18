import { DurableObject } from "cloudflare:workers";
import {
  EMOTES,
  ISLAND_RADIUS,
  MAX_CHAT_LENGTH,
  MAX_PLAYERS,
  type ClientMessage,
  type Player,
  type ServerMessage,
} from "./protocol";

/** One Durable Object per island. Player state lives in each socket's attachment. */
export class Island extends DurableObject {
  async fetch(_request: Request): Promise<Response> {
    if (this.ctx.getWebSockets().length >= MAX_PLAYERS) {
      return new Response("Island is full", { status: 503 });
    }
    const pair = new WebSocketPair();
    const [client, server] = Object.values(pair);
    this.ctx.acceptWebSocket(server);
    return new Response(null, { status: 101, webSocket: client });
  }

  webSocketMessage(ws: WebSocket, raw: string | ArrayBuffer): void {
    if (typeof raw !== "string" || raw.length > 1024) return;
    let msg: ClientMessage;
    try {
      msg = JSON.parse(raw);
    } catch {
      return;
    }
    const player = ws.deserializeAttachment() as Player | null;

    if (msg.t === "join") {
      if (player) return; // already joined
      const p: Player = {
        id: cleanId(msg.id),
        name: cleanName(msg.name),
        color: /^#[0-9a-fA-F]{6}$/.test(msg.color) ? msg.color : "#ffffff",
        x: 0,
        z: 0,
        ry: 0,
      };
      // A reconnecting guest replaces their stale socket.
      for (const other of this.ctx.getWebSockets()) {
        const o = other.deserializeAttachment() as Player | null;
        if (o && o.id === p.id) other.close(4000, "replaced");
      }
      ws.serializeAttachment(p);
      const players = this.players().filter((q) => q.id !== p.id);
      this.send(ws, { t: "welcome", you: p.id, players });
      this.broadcast({ t: "joined", p }, ws);
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
    }
  }

  webSocketClose(ws: WebSocket, code: number): void {
    const player = ws.deserializeAttachment() as Player | null;
    ws.close(code === 1005 ? 1000 : code);
    if (player) this.broadcast({ t: "left", id: player.id }, ws);
  }

  webSocketError(ws: WebSocket): void {
    this.webSocketClose(ws, 1011);
  }

  private players(): Player[] {
    return this.ctx
      .getWebSockets()
      .map((w) => w.deserializeAttachment() as Player | null)
      .filter((p): p is Player => p !== null);
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

function cleanId(id: unknown): string {
  const s = String(id ?? "").replace(/[^A-Za-z0-9_-]/g, "").slice(0, 36);
  return s || crypto.randomUUID();
}

function cleanName(name: unknown): string {
  const s = String(name ?? "").replace(/[\u0000-\u001f<>]/g, "").trim().slice(0, 16);
  return s || "Guest";
}
