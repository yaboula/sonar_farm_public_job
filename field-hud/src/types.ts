export type HudPosition = "left-center" | "top-left";
export type SyncState = "loading" | "ready" | "stale" | "unavailable";
export interface FieldHudAuthority {
  version: 1;
  access: { job?: string; onDuty: boolean; allowed: boolean; reason?: string };
  field: { id: string; name: string; location?: string; region?: string; sizeClass: "S" | "M" | "L"; slotCount: number };
  reservation: { id: string; fieldId: string; role: "owner" | "guest"; memberStatus: "active" | "departing"; status: "active" | "grace"; expiresAt: number; graceUntil?: number; isOwner: boolean; memberCount: number; liveCrops: number; ownCrops: number };
}
export interface HudCounts { empty: number; healthy: number; care: number; critical: number; ready: number; blocked: number; own: number }
export interface NextAction { label: string; slotId?: string; rowId?: string; distance?: number; kind?: string; urgent?: boolean }
export interface FieldHudView { state: FieldHudAuthority; expanded: boolean; position: HudPosition; serverNow?: number; remainingSeconds?: number; counts?: HudCounts; nextAction?: NextAction; streamedSlots?: number; sync?: SyncState; stale?: boolean }
export interface FieldHudMessage { type: "fieldHud:show" | "fieldHud:update" | "fieldHud:mode" | "fieldHud:hide"; payload?: Partial<FieldHudView> & { state?: FieldHudAuthority } }
