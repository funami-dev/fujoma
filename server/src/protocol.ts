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
  | { t: "pos"; x: number; z: number; ry: number; s?: boolean }
  | { t: "chat"; text: string }
  | { t: "emote"; e: string }
  | { t: "interact"; id: string }
  | { t: "fish" }
  | { t: "craft"; recipe: string }
  | { t: "place"; item: string; gx: number; gz: number; rot: number }
  | { t: "pickup"; id: string }
  | { t: "rotate"; id: string };

// server -> client
export type ServerMessage =
  | { t: "welcome"; you: string; players: Player[]; nodes: WorldNode[]; inv: Inventory; houses: House[]; decor: Decor[] }
  | { t: "inv"; inv: Inventory }
  | { t: "node"; id: string; ready_in: number }
  | { t: "toast"; text: string }
  | { t: "house"; h: House }
  | { t: "decor_add"; d: Decor }
  | { t: "decor_remove"; id: string }
  | { t: "decor_rot"; id: string; rot: number }
  | { t: "joined"; p: Player }
  | { t: "left"; id: string }
  | { t: "pos"; id: string; x: number; z: number; ry: number; s?: boolean }
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

export const ITEMS = [
  "apple", "wood", "stone", "fish", "fishing_rod",
  "fruit_basket", "campfire", "chair", "table", "lamp", "bed", "flower_pot",
] as const;

/** Items that can be placed in the world. */
export const PLACEABLE: readonly string[] = ["fruit_basket", "campfire", "chair", "table", "lamp", "bed", "flower_pot"];

/** recipe name -> cost. Each recipe produces exactly one item with the same name. */
export const RECIPES: Record<string, Inventory> = {
  fishing_rod: { wood: 3 },
  fruit_basket: { apple: 3, wood: 1 },
  campfire: { wood: 2, stone: 3 },
  chair: { wood: 2 },
  table: { wood: 4 },
  lamp: { wood: 1, stone: 1 },
  bed: { wood: 6 },
  flower_pot: { stone: 2 },
};

export const INTERACT_RANGE = 4;
export const SHORE_DISTANCE = ISLAND_RADIUS - 3;
export const TREE_FRUIT_COOLDOWN_MS = 90_000;
export const TREE_WOOD_COOLDOWN_MS = 20_000;
export const ROCK_COOLDOWN_MS = 120_000;
export const FISH_COOLDOWN_MS = 3_000;

// ---------------------------------------------------------------- houses and decoration

/** A placed decoration. gx/gz are integer grid coordinates (world meters); rot is 0..3 quarter turns. */
export interface Decor {
  id: string;
  item: string;
  gx: number;
  gz: number;
  rot: number;
  owner: string;
}

/** A guest's house. The exterior stands on the island ring, the interior room far away in the same world. */
export interface House {
  owner: string;
  name: string;
  slot: number;
}

export const MAX_HOUSES = 12;
export const HOUSE_RING_RADIUS = 28;
export const ROOM_BASE_X = 500;
export const ROOM_SPACING = 40;
export const ROOM_HALF = 6; // players are kept inside this half-size
export const ROOM_PLACE_HALF = 5; // furniture must be inside this half-size
export const ROOM_REGION_X = ROOM_BASE_X - 20; // any x beyond this is "inside a room"
export const PLACE_RANGE = 6;
export const MAX_DECOR_PER_ISLAND = 200;
export const MAX_DECOR_PER_PLAYER = 40;

const slotAngle = (slot: number): number => (slot * Math.PI * 2) / MAX_HOUSES;

export function houseCenter(slot: number): { x: number; z: number } {
  const a = slotAngle(slot);
  return { x: Math.cos(a) * HOUSE_RING_RADIUS, z: Math.sin(a) * HOUSE_RING_RADIUS };
}

/** Spot in front of the door, toward the island center. */
export function doorOutside(slot: number): { x: number; z: number } {
  const a = slotAngle(slot);
  return { x: Math.cos(a) * (HOUSE_RING_RADIUS - 3.5), z: Math.sin(a) * (HOUSE_RING_RADIUS - 3.5) };
}

export function roomCenter(slot: number): { x: number; z: number } {
  return { x: ROOM_BASE_X + slot * ROOM_SPACING, z: 0 };
}

export function roomSlotAt(x: number): number {
  return Math.round((x - ROOM_BASE_X) / ROOM_SPACING);
}
