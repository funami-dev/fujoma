# fujoma

3D-Browserspiel im Stil von Animal Crossing mit Echtzeit-Multiplayer.

## Architektur
- `client/` – Godot 4 Projekt (Web-Export, WebAssembly)
- `server/` – Cloudflare Worker + Durable Objects (TypeScript), eine Insel pro Durable Object, Speicherstände in D1
- `web/` – statisch ausgelieferte Dateien auf Vercel (später der Godot-Web-Export)

## Entscheidungen
- Gastzugang zuerst, Konten später
- Platzhalter-Assets, später Asset-Packs oder eigene Modelle
- MVP: Echtzeit-Events (Ostern, Halloween), Sammeln und Crafting, Inselgestaltung, Wirtschaft und NPCs
