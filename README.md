# fujoma

A 3D browser game in the style of Animal Crossing with real-time multiplayer.

## Architecture
- `client/` – Godot 4 project (web export, WebAssembly)
- `server/` – Cloudflare Worker + Durable Objects (TypeScript); one island per Durable Object, save data in D1
- `web/` – static files served by Vercel (later the Godot web export)

## Decisions
- Guest access first, accounts later
- Placeholder assets for now, later asset packs or custom models
- MVP: real-time events (Easter, Halloween), gathering and crafting, island decoration, economy and NPCs

See [docs/phase-plan.md](docs/phase-plan.md) for the roadmap.
