import { Island } from "./island";
import { Profile } from "./profile";
import type { Env } from "./env";

export { Island, Profile };

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);
    const match = url.pathname.match(/^\/island\/([A-Za-z0-9_-]{1,32})\/ws$/);
    if (!match) {
      return new Response("fujoma server", { status: 200 });
    }
    if (request.headers.get("Upgrade") !== "websocket") {
      return new Response("Expected WebSocket upgrade", { status: 426 });
    }
    // One Durable Object per island code.
    const id = env.ISLAND.idFromName(match[1]);
    return env.ISLAND.get(id).fetch(request);
  },
} satisfies ExportedHandler<Env>;
