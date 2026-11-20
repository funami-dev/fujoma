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
- A player's skin is picked from their guest id (the two human skins), lightly tinted with the player's color.
- Font: "Patrick Hand" by Patrick Wagesreiter, SIL Open Font License 1.1 (see `client/assets/fonts/PatrickHand-OFL.txt`).

## Landscaping and gardening
- Outdoors anyone can paint ground cells (1 m grid): stone path (costs 1 stone), gravel path (free), garden bed and pond (need a shovel); "Gras" clears a cell. Inside a house only its owner decorates.
- Seeds come from Mara's shop and are sown on garden beds. A plant grows one stage for every island day it was watered (watering can), at the next island midnight; the worker uses a Durable Object alarm so growth also happens while nobody is online. Anyone may harvest ripe plants. Tomatoes and flowers regrow after harvesting.
- Crafting: shovel, watering can, fence (placeable like furniture), potted tulip and potted sunflower.

## Language and controls
- The game is in German (villagers, UI, item names, server messages); code and comments stay English.
- The 2D UI scales with the window (`content_scale_mode = canvas_items`), with a smaller base size on touch devices so buttons stay finger-sized.
- Controls: a big context button (bottom right, label changes: Reden, Ernten, Angeln, Hinein, Platzieren ...) and a menu button that opens a radial action wheel (Bauen, Basteln, Chat, emotes, Aufheben/Drehen near furniture). Desktop: WASD, Q/E camera, F act, B build, C craft, H garden, P/R/G place/rotate/pick up, Tab wheel, 1-4 emotes, Enter chat.

## Look
A warm, hand-drawn storybook style: painterly toon shading with violet shadows and paper grain (`client/shaders/toon.gdshader`), ink outlines with a constant pixel width (`client/shaders/outline.gdshader`), a muted earthy palette and paper-like UI. Materials, labels and the UI theme come from `client/style.gd`.
