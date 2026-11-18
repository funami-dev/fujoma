import type { Island } from "./island";
import type { Profile } from "./profile";

export interface Env {
  ISLAND: DurableObjectNamespace<Island>;
  PROFILE: DurableObjectNamespace<Profile>;
}
