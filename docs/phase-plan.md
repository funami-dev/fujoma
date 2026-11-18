# Phase Plan

Each phase ends with something playable in the browser. The riskiest part (Godot on the web plus real-time networking) is tackled first.

## Phase 0: Foundation (~1 week)
- Godot 4 project with a web export served from Vercel (`web/`).
- Cloudflare Worker with one Durable Object and a WebSocket connection.
- CI: export, then deploy on push.
- **Done when:** a cube loads in the browser and talks to the server over WebSocket.

## Phase 1: Shared island (2–3 weeks)
- Placeholder island, player character with desktop and touch controls, camera.
- Guest access (device ID, name, color); island rooms joined by code.
- See other players live (position sync with interpolation); simple chat and emotes.
- **Done when:** two browsers on the same island see each other walking.

## Phase 2: Gathering, crafting, inventory (2–3 weeks)
- Inventory, trees, fruit, rocks, fishing as a simple mini-flow.
- Recipes and crafting; the server is authoritative for items to prevent cheating.
- Save data in D1, keyed by guest ID.
- **Done when:** progress survives a reload.

## Phase 3: Island decoration (2–3 weeks)
- Place, rotate and pick up objects on a grid, synced to all players.
- Furniture and an enterable house as a simple interior scene.
- **Done when:** two players furnish an island together.

## Phase 4: Economy and NPCs (~3 weeks)
- Currency, shop, selling gathered goods, server-side prices.
- 2–3 villagers with dialogue and daily routines; time of day follows the real clock.
- **Done when:** the full loop works: gather, sell, buy, decorate.

## Phase 5: Real-time events and polish (2–3 weeks)
- Date-driven event system (Easter, Halloween) that unlocks decorations, items and NPC dialogue.
- Seasons and weather, sound.
- Real assets instead of placeholders; optimize load time and mobile performance.
- **Done when:** an event starts on the right date without a redeploy.

## Afterwards
Accounts with login (carry over guest progress), moderation and chat filtering, island visits.

## Risks to check early
- **Godot web build size:** measure in Phase 0. Target under ~30 MB; keep the art low-poly.
- **Mobile:** if phones matter, test from Phase 1 on, not at the end.
- **Asset effort:** Phases 3 and 5 depend most on where assets come from.
- **Guest identity:** a device ID is lost when browser data is cleared; tell players early.

Estimates are rough, for one part-time person, and depend heavily on Godot experience.
