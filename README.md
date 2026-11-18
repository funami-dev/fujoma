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
- MVP: real-time events (Easter, Halloween), gathering and crafting, island decoration, economy and NPCs

See [docs/phase-plan.md](docs/phase-plan.md) for the roadmap.

## Deployment
- The web client is exported from Godot and deployed to Vercel by `.github/workflows/deploy-web.yml` on pushes to `main`.
- Vercel's own Git deployments are disabled in `vercel.json`, because the Godot export is not committed.
- Required GitHub repository secret: `VERCEL_TOKEN`.
