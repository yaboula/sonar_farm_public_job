import type { FieldHudView } from "./types";
export function fieldHudFixture(): FieldHudView {
  const now = Math.floor(Date.now() / 1000);
  return {
    state: { version: 1, access: { job: "farmer", onDuty: true, allowed: true }, field: { id: "fixture-field", name: "Grapeseed South", location: "O'Neil Way", region: "Grapeseed", sizeClass: "S", slotCount: 24 }, reservation: { id: "fixture-reservation", fieldId: "fixture-field", role: "owner", memberStatus: "active", status: "active", expiresAt: now + 4872, isOwner: true, memberCount: 3, liveCrops: 18, ownCrops: 11 } },
    expanded: true, position: "left-center", serverNow: now, remainingSeconds: 4872,
    counts: { empty: 6, healthy: 11, care: 3, critical: 1, ready: 3, blocked: 0, own: 11 },
    nextAction: { label: "Harvest", slotId: "S-18", rowId: "Row 4", distance: 2.4, kind: "ready" },
    streamedSlots: 24, sync: "ready",
  };
}
