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
  | { t: "join"; id: string; name: string; color: string }
  | { t: "pos"; x: number; z: number; ry: number }
  | { t: "chat"; text: string }
  | { t: "emote"; e: string };

// server -> client
export type ServerMessage =
  | { t: "welcome"; you: string; players: Player[] }
  | { t: "joined"; p: Player }
  | { t: "left"; id: string }
  | { t: "pos"; id: string; x: number; z: number; ry: number }
  | { t: "chat"; id: string; name: string; text: string }
  | { t: "emote"; id: string; e: string };

export const ISLAND_RADIUS = 40;
export const MAX_PLAYERS = 12;
export const MAX_CHAT_LENGTH = 120;
export const EMOTES = ["wave", "happy", "sad", "dance"] as const;
