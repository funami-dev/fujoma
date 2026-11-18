import { ISLAND_RADIUS, type WorldNode } from "./protocol";

/** Deterministic PRNG so every island has the same layout. */
function mulberry32(seed: number): () => number {
  return () => {
    seed = (seed + 0x6d2b79f5) | 0;
    let t = Math.imul(seed ^ (seed >>> 15), 1 | seed);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

export type NodeLayout = Omit<WorldNode, "ready_in">;

export function generateNodes(): NodeLayout[] {
  const rng = mulberry32(1234);
  const nodes: NodeLayout[] = [];
  const place = (k: "tree" | "rock", count: number, prefix: string): void => {
    let n = 0;
    while (n < count) {
      const angle = rng() * Math.PI * 2;
      const dist = Math.sqrt(rng()) * (ISLAND_RADIUS - 6);
      if (dist < 5) continue;
      const x = Math.cos(angle) * dist;
      const z = Math.sin(angle) * dist;
      if (nodes.some((o) => Math.hypot(o.x - x, o.z - z) < 3)) continue;
      nodes.push({ id: `${prefix}${n}`, k, x, z });
      n++;
    }
  };
  place("tree", 28, "t");
  place("rock", 10, "r");
  return nodes;
}
