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
  | { t: "rotate"; id: string }
  | { t: "buy"; item: string }
  | { t: "sell"; item: string; qty: number }
  | { t: "ground"; gx: number; gz: number; kind: string }
  | { t: "sow"; gx: number; gz: number; seed: string }
  | { t: "water"; gx: number; gz: number }
  | { t: "harvest"; gx: number; gz: number };

// server -> client
export type ServerMessage =
  | { t: "welcome"; you: string; players: Player[]; nodes: WorldNode[]; inv: Inventory; houses: House[]; decor: Decor[]; tz_offset: number;
      ground: [number, number, GroundKind][]; plants: PlantState[] }
  | { t: "inv"; inv: Inventory }
  | { t: "node"; id: string; ready_in: number }
  | { t: "toast"; text: string }
  | { t: "house"; h: House }
  | { t: "decor_add"; d: Decor }
  | { t: "decor_remove"; id: string }
  | { t: "decor_rot"; id: string; rot: number }
  | { t: "ground_set"; gx: number; gz: number; kind: GroundKind | null }
  | { t: "plant_set"; gx: number; gz: number; p: PlantState | null }
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
  "shovel", "watering_can", "fence", "potted_tulip", "potted_sunflower",
  "carrot_seeds", "tomato_seeds", "pumpkin_seeds", "tulip_seeds", "sunflower_seeds",
  "carrot", "tomato", "pumpkin", "tulip", "sunflower",
] as const;

/** German display names, used in server messages. Mirrored in client/defs.gd. */
export const ITEM_LABELS: Record<string, string> = {
  apple: "Apfel",
  wood: "Holz",
  stone: "Stein",
  fish: "Fisch",
  fishing_rod: "Angel",
  fruit_basket: "Obstkorb",
  campfire: "Lagerfeuer",
  chair: "Stuhl",
  table: "Tisch",
  lamp: "Lampe",
  bed: "Bett",
  flower_pot: "Blumentopf",
  shovel: "Schaufel",
  watering_can: "Gießkanne",
  fence: "Zaun",
  potted_tulip: "Tulpe im Topf",
  potted_sunflower: "Sonnenblume im Topf",
  carrot_seeds: "Karottensamen",
  tomato_seeds: "Tomatensamen",
  pumpkin_seeds: "Kürbissamen",
  tulip_seeds: "Tulpenzwiebeln",
  sunflower_seeds: "Sonnenblumenkerne",
  carrot: "Karotte",
  tomato: "Tomate",
  pumpkin: "Kürbis",
  tulip: "Tulpe",
  sunflower: "Sonnenblume",
};

export const label = (item: string): string => ITEM_LABELS[item] ?? item;

/** Items that can be placed in the world. */
export const PLACEABLE: readonly string[] = [
  "fruit_basket", "campfire", "chair", "table", "lamp", "bed", "flower_pot",
  "fence", "potted_tulip", "potted_sunflower",
];

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
  shovel: { wood: 2, stone: 1 },
  watering_can: { stone: 3, wood: 1 },
  fence: { wood: 1 },
  potted_tulip: { flower_pot: 1, tulip: 1 },
  potted_sunflower: { flower_pot: 1, sunflower: 1 },
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

// ---------------------------------------------------------------- economy and island time

/** All islands run on this clock (day/night, shop hours, villager routines). */
export const ISLAND_TIMEZONE = "Europe/Berlin";

export const COINS = "coins";
export const STARTING_COINS = 100;

export const SHOP_X = 0;
export const SHOP_Z = -5;
export const SHOP_RANGE = 5;
export const SHOP_CLEARANCE = 3; // no furniture this close to the stall
export const SHOP_OPEN_HOUR = 8;
export const SHOP_CLOSE_HOUR = 22;

/** What the shop pays per item. */
export const SELL_PRICES: Inventory = {
  apple: 10,
  wood: 5,
  stone: 8,
  fish: 40,
  fishing_rod: 20,
  fruit_basket: 50,
  campfire: 30,
  chair: 15,
  table: 30,
  lamp: 25,
  bed: 45,
  flower_pot: 25,
  shovel: 15,
  watering_can: 20,
  fence: 5,
  potted_tulip: 45,
  potted_sunflower: 50,
  carrot_seeds: 5,
  tomato_seeds: 8,
  pumpkin_seeds: 10,
  tulip_seeds: 4,
  sunflower_seeds: 5,
  carrot: 25,
  tomato: 20,
  pumpkin: 90,
  tulip: 15,
  sunflower: 20,
};

/** What the shop sells, and for how much. */
export const SHOP_CATALOG: Inventory = {
  fishing_rod: 60,
  chair: 60,
  flower_pot: 80,
  lamp: 120,
  table: 140,
  bed: 250,
  shovel: 50,
  watering_can: 80,
  carrot_seeds: 20,
  tomato_seeds: 30,
  pumpkin_seeds: 40,
  tulip_seeds: 15,
  sunflower_seeds: 20,
};

/** Minutes to add to UTC to get island time, for the given instant (handles daylight saving time). */
export function islandOffsetMinutes(now: Date = new Date()): number {
  const parts = new Intl.DateTimeFormat("en-US", {
    timeZone: ISLAND_TIMEZONE,
    hourCycle: "h23",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
  }).formatToParts(now);
  const get = (t: string): number => Number(parts.find((p) => p.type === t)?.value);
  const asUtc = Date.UTC(get("year"), get("month") - 1, get("day"), get("hour"), get("minute"));
  return Math.round((asUtc - Math.floor(now.getTime() / 60000) * 60000) / 60000);
}

export function islandHour(now: Date = new Date()): number {
  const minutes = Math.floor(now.getTime() / 60000) + islandOffsetMinutes(now);
  return (((minutes % 1440) + 1440) % 1440) / 60;
}

export function shopIsOpen(now: Date = new Date()): boolean {
  const h = islandHour(now);
  return h >= SHOP_OPEN_HOUR && h < SHOP_CLOSE_HOUR;
}

// ---------------------------------------------------------------- props

/** Quirky decorations on the meadow. r is their footprint: no furniture inside it. Mirrored in client/defs.gd. */
export const PROPS: { kind: string; x: number; z: number; r: number }[] = [
  { kind: "bathtub", x: 9.2, z: -15, r: 2.2 },
  { kind: "signpost", x: 11.3, z: -2.6, r: 1.2 },
  { kind: "scarecrow", x: -12.5, z: -15, r: 1.6 },
  { kind: "laundry", x: -18.8, z: -0.9, r: 2.6 },
  { kind: "boot_house", x: -7.9, z: 32.3, r: 2.4 },
  { kind: "windmill", x: 19.7, z: 3.9, r: 1.2 },
  { kind: "ladder", x: 32.9, z: 7.9, r: 1.2 },
  { kind: "stump_house", x: 9.8, z: 16.4, r: 1.8 },
  { kind: "birdhouse", x: 1.3, z: 8.6, r: 1.0 },
  { kind: "crates", x: -2.9, z: 14.2, r: 2.0 },
  { kind: "mushroom_house", x: -16.9, z: 17.2, r: 2.2 },
  { kind: "wheelbarrow", x: 22, z: -4.5, r: 1.8 },
];

// ---------------------------------------------------------------- landscaping and gardening

/** Ground cells painted by players (1 m grid, island only). "grass" in a request clears a cell. */
export type GroundKind = "path" | "gravel" | "soil" | "pond";
export const GROUND_KINDS: readonly string[] = ["path", "gravel", "soil", "pond"];
/** Items consumed per cell. */
export const GROUND_COST: Record<string, Inventory> = { path: { stone: 1 } };
/** Ground kinds (and clearing) that need a shovel. */
export const GROUND_NEEDS_SHOVEL: readonly string[] = ["soil", "pond", "grass"];
export const MAX_GROUND_CELLS = 2500;
export const MAX_PLANTS = 400;

/**
 * A plant on a soil cell. It grows one stage for each island day it was watered:
 * at the next day change after watering. Ripe when stage === PLANTS[kind].stages.
 */
export interface PlantState {
  gx: number;
  gz: number;
  kind: string;
  stage: number;
  stage_day: number; // island day the current stage began
  watered_day: number; // island day it was last watered (-1 = never)
}

/** stages: watered days until ripe. regrow: stage after harvest, or null to remove the plant. */
export const PLANTS: Record<string, { seed: string; stages: number; yield: [string, number]; regrow: number | null }> = {
  carrot: { seed: "carrot_seeds", stages: 3, yield: ["carrot", 2], regrow: null },
  tomato: { seed: "tomato_seeds", stages: 3, yield: ["tomato", 3], regrow: 2 },
  pumpkin: { seed: "pumpkin_seeds", stages: 4, yield: ["pumpkin", 1], regrow: null },
  tulip: { seed: "tulip_seeds", stages: 2, yield: ["tulip", 1], regrow: 1 },
  sunflower: { seed: "sunflower_seeds", stages: 3, yield: ["sunflower", 1], regrow: 2 },
};

export const plantForSeed = (seed: string): string | undefined =>
  Object.keys(PLANTS).find((k) => PLANTS[k].seed === seed);

/** Days since the epoch, counted in island time. */
export function islandDay(now: Date = new Date()): number {
  return Math.floor((Math.floor(now.getTime() / 60000) + islandOffsetMinutes(now)) / 1440);
}

/** UTC timestamp (ms) of the next island midnight. */
export function nextIslandMidnight(now: Date = new Date()): number {
  return ((islandDay(now) + 1) * 1440 - islandOffsetMinutes(now)) * 60000;
}

/** Applies growth up to `today`. Returns true if the plant changed. */
export function growPlant(p: PlantState, today: number): boolean {
  const def = PLANTS[p.kind];
  if (!def || p.stage >= def.stages) return false;
  if (p.watered_day >= p.stage_day && p.watered_day < today) {
    p.stage += 1;
    p.stage_day = p.watered_day + 1;
    return true;
  }
  return false;
}
