import { DurableObject } from "cloudflare:workers";
import type { Env } from "./env";
import { COINS, STARTING_COINS, type Inventory } from "./protocol";

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

  /** Grants the one-time starting coins. Safe to call on every join. */
  claimStartingCoins(): void {
    const row = this.ctx.storage.sql.exec("SELECT v FROM meta WHERE k = 'starting_coins'").toArray()[0];
    if (row) return;
    this.ctx.storage.sql.exec("INSERT INTO meta (k, v) VALUES ('starting_coins', '1')");
    this.add(COINS, STARTING_COINS);
  }

  /** Pays `price` coins for one `item`. Returns null if the player cannot afford it. */
  buy(item: string, price: number): Inventory | null {
    if ((this.inventory()[COINS] ?? 0) < price) return null;
    this.ctx.storage.sql.exec("UPDATE inv SET qty = qty - ? WHERE item = ?", price, COINS);
    return this.add(item, 1);
  }

  /** Sells `qty` of `item` for `unitPrice` coins each. Returns null if the player has too few. */
  sell(item: string, qty: number, unitPrice: number): Inventory | null {
    if ((this.inventory()[item] ?? 0) < qty) return null;
    this.ctx.storage.sql.exec("UPDATE inv SET qty = qty - ? WHERE item = ?", qty, item);
    return this.add(COINS, qty * unitPrice);
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

  /** Removes one item. Returns the new inventory, or null if the player has none. */
  take(item: string): Inventory | null {
    const inv = this.inventory();
    if ((inv[item] ?? 0) < 1) return null;
    this.ctx.storage.sql.exec("UPDATE inv SET qty = qty - 1 WHERE item = ?", item);
    return this.inventory();
  }

  /** Pays `cost` without granting anything. Returns null if the inventory is short. */
  pay(cost: Inventory): Inventory | null {
    const inv = this.inventory();
    for (const [item, qty] of Object.entries(cost)) {
      if ((inv[item] ?? 0) < qty) return null;
    }
    for (const [item, qty] of Object.entries(cost)) {
      this.ctx.storage.sql.exec("UPDATE inv SET qty = qty - ? WHERE item = ?", qty, item);
    }
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
