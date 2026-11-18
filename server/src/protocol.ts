/** Wire protocol shared by client (Godot, mirrored in GDScript) and server. */

export interface Player {
  id: string;
  name: string;
  color: string; // hex like "#ff8844"
  x: number;
  z: number;
  ry: number;
}

// client -> server
export type ClientMessage =
  | { t: "join"; id: string; secret: string; name: string; color: string }
  | { t: "pos"; x: number; z: number; ry: number }
  | { t: "chat"; text: string }
  | { t: "emote"; e: string }
  | { t: "interact"; id: string }
  | { t: "fish" }
  | { t: "craft"; recipe: string };

// server -> client
export type ServerMessage =
  | { t: "welcome"; you: string; players: Player[]; nodes: WorldNode[]; inv: Inventory }
  | { t: "inv"; inv: Inventory }
  | { t: "node"; id: string; ready_in: number }
  | { t: "toast"; text: string }
  | { t: "joined"; p: Player }
  | { t: "left"; id: string }
  | { t: "pos"; id: string; x: number; z: number; ry: number }
  | { t: "chat"; id: string; name: string; text: string }
  | { t: "emote"; id: string; e: string };

export const ISLAND_RADIUS = 40;
export const MAX_PLAYERS = 12;
export const MAX_CHAT_LENGTH = 120;
export const EMOTES = ["wave", "happy", "sad", "dance"] as const;

export type Inventory = Record<string, number>;

/** A harvestable object on the island. ready_in is milliseconds until it can be used again (0 = ready). */
export interface WorldNode {
  id: string;
  k: "tree" | "rock";
  x: number;
  z: number;
  ready_in: number;
}

export const ITEMS = ["apple", "wood", "stone", "fish", "fishing_rod", "fruit_basket", "campfire"] as const;

/** recipe name -> cost. Each recipe produces exactly one item with the same name. */
export const RECIPES: Record<string, Inventory> = {
  fishing_rod: { wood: 3 },
  fruit_basket: { apple: 3, wood: 1 },
  campfire: { wood: 2, stone: 3 },
};

export const INTERACT_RANGE = 4;
export const SHORE_DISTANCE = ISLAND_RADIUS - 3;
export const TREE_FRUIT_COOLDOWN_MS = 90_000;
export const TREE_WOOD_COOLDOWN_MS = 20_000;
export const ROCK_COOLDOWN_MS = 120_000;
export const FISH_COOLDOWN_MS = 3_000;
