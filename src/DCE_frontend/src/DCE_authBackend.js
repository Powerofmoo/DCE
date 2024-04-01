import { createActor } from "declarations/DCE_backend";

export const authActor = (canisterId, options = {}) => {
  DCE_authBackend = createActor(canisterId, options);
};

export var DCE_authBackend = undefined;
