# fujoma

A 3D browser game in the style of Animal Crossing with real-time multiplayer.

## Architecture
- `client/` – Godot 4 project (web export, WebAssembly)
- `server/` – Cloudflare Worker + Durable Objects (TypeScript); one island per Durable Object, save data in D1
- `web/` – static files served by Vercel (later the Godot web export)

## Decisions
- Guest access first, accounts later
- Placeholder assets for now, later asset packs or custom models
- Houses: every guest gets a house (up to 12 per island). Interiors are rooms far away in the same world; anyone can visit, only the owner decorates inside. Outdoors, anyone can place and pick up furniture.
- Island time follows Europe/Berlin for everyone (day/night, shop hours 8:00-22:00, villager routines). The server reports the current UTC offset, so daylight saving time is handled. `?hour=21.5` overrides the clock on the client only (for testing lighting and routines).
- Economy: coins live in the guest profile (100 starting coins). Mara's shop buys gathered and crafted items and sells furniture; prices and opening hours are enforced by the server.
- Villagers (Mara, Ole, Pia) follow routines computed from island time on each client; their dialogue is client-side.
- MVP: real-time events (Easter, Halloween), gathering and crafting, island decoration, economy and NPCs

See [docs/phase-plan.md](docs/phase-plan.md) for the roadmap.

## Deployment
- The web client is exported from Godot and deployed to Vercel by `.github/workflows/deploy-web.yml` on pushes to `main`.
- Vercel's own Git deployments are disabled in `vercel.json`, because the Godot export is not committed.
- Required GitHub repository secret: `VERCEL_TOKEN`.

## Credits
- Character model, animations and skins: "Animated Characters Survivors" by [Kenney](https://www.kenney.nl), CC0 (see `client/assets/characters/License.txt`).
- A player's skin is picked from their guest id (4 skins).
