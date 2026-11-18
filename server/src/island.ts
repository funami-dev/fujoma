import { DurableObject } from "cloudflare:workers";

/** Phase 0: echo + broadcast to all sockets on the island. */
export class Island extends DurableObject {
  async fetch(_request: Request): Promise<Response> {
    const pair = new WebSocketPair();
    const [client, server] = Object.values(pair);
    this.ctx.acceptWebSocket(server);
    server.send(JSON.stringify({ type: "hello", players: this.ctx.getWebSockets().length }));
    return new Response(null, { status: 101, webSocket: client });
  }

  webSocketMessage(sender: WebSocket, message: string | ArrayBuffer): void {
    if (typeof message !== "string") return;
    for (const ws of this.ctx.getWebSockets()) {
      if (ws !== sender) ws.send(message);
    }
    sender.send(JSON.stringify({ type: "ack" }));
  }

  webSocketClose(ws: WebSocket, code: number): void {
    ws.close(code);
  }
}
