import { DurableObject } from "cloudflare:workers";
import type { Env } from "./env";
import type { Inventory } from "./protocol";

/** One Durable Object per guest: secret hash (guest auth) and inventory, persisted in SQLite. */
export class Profile extends DurableObject<Env> {
  constructor(ctx: DurableObjectState, env: Env) {
    super(ctx, env);
    ctx.storage.sql.exec("CREATE TABLE IF NOT EXISTS meta (k TEXT PRIMARY KEY, v TEXT NOT NULL)");
    ctx.storage.sql.exec("CREATE TABLE IF NOT EXISTS inv (item TEXT PRIMARY KEY, qty INTEGER NOT NULL)");
  }

  /** First caller claims the guest id; later callers must present the same secret hash. */
  auth(secretHash: string): boolean {
    const row = this.ctx.storage.sql.exec("SELECT v FROM meta WHERE k = 'secret'").toArray()[0];
    if (!row) {
      this.ctx.storage.sql.exec("INSERT INTO meta (k, v) VALUES ('secret', ?)", secretHash);
      return true;
    }
    return row.v === secretHash;
  }

  inventory(): Inventory {
    const inv: Inventory = {};
    for (const r of this.ctx.storage.sql.exec("SELECT item, qty FROM inv WHERE qty > 0")) {
      inv[r.item as string] = r.qty as number;
    }
    return inv;
  }

  add(item: string, qty: number): Inventory {
    this.ctx.storage.sql.exec(
      "INSERT INTO inv (item, qty) VALUES (?, ?) ON CONFLICT(item) DO UPDATE SET qty = qty + excluded.qty",
      item,
      qty,
    );
    return this.inventory();
  }

  /** Atomically pays `cost` and grants one `output`. Returns null if the inventory is short. */
  craft(output: string, cost: Inventory): Inventory | null {
    const inv = this.inventory();
    for (const [item, qty] of Object.entries(cost)) {
      if ((inv[item] ?? 0) < qty) return null;
    }
    for (const [item, qty] of Object.entries(cost)) {
      this.ctx.storage.sql.exec("UPDATE inv SET qty = qty - ? WHERE item = ?", qty, item);
    }
    return this.add(output, 1);
  }
}
