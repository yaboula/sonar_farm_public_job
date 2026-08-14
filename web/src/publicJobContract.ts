import type { HubRoute, ViewState } from "./types";
export const PUBLIC_ROUTES = ["today", "fields", "market", "sell"] as const satisfies readonly HubRoute[];
export const FORBIDDEN_BUSINESS_ROUTES = ["company", "work", "treasury", "warehouse", "staff", "cargo", "supplies"] as const;
export const VIEW_STATES = ["ready", "loading", "empty", "blocked", "error", "restricted", "unavailable"] as const satisfies readonly ViewState[];
export const levelThreshold = (level: number) => Math.round(220 * (level - 1) ** 2);
export const RENT_PRICES = {
  S: { 1: 300, 3: 800, 6: 1500, 8: 1900 },
  M: { 1: 480, 3: 1300, 6: 2400, 8: 3000 },
  L: { 1: 720, 3: 1950, 6: 3600, 8: 4500 },
} as const;
export const PRODUCE_PRICES = { carrot: 12, potato: 10, lettuce: 14, tomato: 16 } as const;
export const QUALITY_MULTIPLIERS = { poor: .5, standard: 1, fine: 1.5, premium: 2 } as const;
export const PUBLIC_FIELDS = ["grapeseed_south", "grapeseed_east", "grapeseed_north", "paleto_creek", "paleto_orchard", "paleto_highland"] as const;
export const UNLOCKS = [{ level: 4, id: "plus" }, { level: 5, id: "medium" }, { level: 8, id: "pro" }, { level: 10, id: "large" }] as const;
