import { CANONICAL_MARKET_PRODUCTS } from "../data/itemCatalog.generated";
import type { FieldDetailData, FieldsData, HubAdapter, HubContextModel, HubSurface, HubViewModel, HubViewRequest, MarketData, PublicField, PublicFieldDetail, Reservation, SellData, TodayData, ViewState } from "../types";
import { NuiHubAdapter, isNuiRuntime } from "./NuiHubAdapter";

const progression = {
  xp: 4380, level: 5, maxLevel: 20, levelStartXp: 3520, nextLevelXp: 5500,
  rentDiscount: 0.05, sellBonus: 0.03,
  unlocks: { plus: true, pro: false, medium: true, large: false },
};

const plan = (hours: 6 | 12 | 24, basePrice: number) => ({ hours, basePrice, price: Math.round(basePrice * 0.95), graceSurcharge: false });
const plans = {
  S: [plan(6, 1500), plan(12, 2700), plan(24, 4800)],
  M: [plan(6, 2400), plan(12, 4300), plan(24, 7600)],
  L: [plan(6, 3600), plan(12, 6500), plan(24, 11500)],
};

const fieldSeed: PublicField[] = [
  { id: "grapeseed_south", name: "South Fields", location: "South farm road", region: "Grapeseed", sizeClass: "S", slotCount: 24, available: false, requiredLevel: 1, rentPlans: plans.S },
  { id: "grapeseed_east", name: "East Fields", location: "East service track", region: "Grapeseed", sizeClass: "M", slotCount: 40, available: false, expiresAt: Math.floor(Date.now() / 1000) + 6400, requiredLevel: 5, rentPlans: plans.M },
  { id: "grapeseed_north", name: "North Acre", location: "North irrigation road", region: "Grapeseed", sizeClass: "L", slotCount: 64, available: true, requiredLevel: 10, rentPlans: plans.L },
  { id: "paleto_creek", name: "Creek Plot", location: "Creek approach", region: "Paleto", sizeClass: "S", slotCount: 24, available: true, requiredLevel: 1, rentPlans: plans.S },
  { id: "paleto_orchard", name: "Orchard Rows", location: "Old orchard road", region: "Paleto", sizeClass: "M", slotCount: 40, available: true, requiredLevel: 5, rentPlans: plans.M },
  { id: "paleto_highland", name: "Highland Farm", location: "Highland service lane", region: "Paleto", sizeClass: "L", slotCount: 64, available: true, requiredLevel: 10, rentPlans: plans.L },
];

const reservation: Reservation = {
  id: "reservation-preview", fieldId: "grapeseed_south", status: "active",
  expiresAt: Math.floor(Date.now() / 1000) + 18_900, isOwner: true, ownCrops: 12, liveCrops: 19,
  members: [
    { identifier: "preview", display_name: "Alex Farmer", role: "owner", status: "active" },
    { identifier: "coop-1", display_name: "Maya Fields", role: "guest", status: "active" },
  ],
};

function detailedField(field: PublicField): PublicFieldDetail {
  const rowCount = field.sizeClass === "S" ? 4 : field.sizeClass === "M" ? 5 : 8;
  const perRow = field.slotCount / rowCount;
  const rows = Array.from({ length: rowCount }, (_, rowIndex) => ({
    id: `${field.id}:row:${rowIndex + 1}`,
    label: `Row ${rowIndex + 1}`,
    order: rowIndex + 1,
    slotIds: Array.from({ length: perRow }, (_, slotIndex) => `${field.id}:slot:${rowIndex * perRow + slotIndex + 1}`),
  }));
  const slots = rows.flatMap((row, rowIndex) => row.slotIds.map((id, slotIndex) => ({
    id, rowId: row.id, order: slotIndex + 1, index: rowIndex * perRow + slotIndex + 1,
    heading: 0, position: { x: slotIndex / (perRow - 1), y: rowIndex / (rowCount - 1) },
  })));
  return { ...field, rows, slots, allowedCrops: ["carrot", "potato", "lettuce", "tomato"], access: { x: 2440.2, y: 4975.4, z: 46.8 } };
}

const fields: FieldsData = { progression, reservation, fields: fieldSeed };
const market: MarketData = {
  progression, stock: { plus: 16, pro: 7 },
  products: [
    ...CANONICAL_MARKET_PRODUCTS.map((item) => ({ id: item.id, label: item.label, description: item.description, category: item.category, tier: item.tier, price: item.price, stock: item.tier === "basic" ? undefined : item.tier === "plus" ? 16 : 7, requiredLevel: item.tier === "basic" ? 1 : item.tier === "plus" ? 4 : 8, unlocked: item.tier !== "pro" })),
    { id: "farm_tablet", label: "Farmer Tablet", description: "Opens the complete public farming Hub remotely.", category: "Access", tier: "basic", price: 1500, requiredLevel: 1, unlocked: true, physicalOnly: true, owned: false },
  ],
};
const sell: SellData = {
  progression, sellBonus: 0.03,
  groups: [
    { key: "carrot:poor", cropType: "carrot", itemId: "carrot", tier: "poor", quantity: 8, unitPrice: 6, basePrice: 12, multiplier: 0.5 },
    { key: "potato:standard", cropType: "potato", itemId: "potato", tier: "standard", quantity: 14, unitPrice: 10, basePrice: 10, multiplier: 1 },
    { key: "lettuce:fine", cropType: "lettuce", itemId: "lettuce", tier: "fine", quantity: 9, unitPrice: 21, basePrice: 14, multiplier: 1.5 },
    { key: "tomato:premium", cropType: "tomato", itemId: "tomato", tier: "premium", quantity: 5, unitPrice: 32, basePrice: 16, multiplier: 2 },
  ],
};
const today: TodayData = {
  progression, reservation, ownCrops: reservation.ownCrops, marketStock: market.stock, sellableGroups: sell.groups,
  nextUnlock: { level: 8, label: "Pro products" },
};

function previewState(): ViewState {
  const candidate = new URLSearchParams(window.location.search).get("state") as ViewState | null;
  return candidate && ["ready", "loading", "empty", "blocked", "error", "restricted", "unavailable"].includes(candidate) ? candidate : "ready";
}

function previewSurface(): HubSurface {
  const candidate = new URLSearchParams(window.location.search).get("surface");
  return candidate === "market" || candidate === "sell" ? candidate : "tablet";
}

function detailReservation(selected: PublicField): Reservation | undefined {
  const mode = new URLSearchParams(window.location.search).get("participation");
  if (mode === "none") return undefined;
  if (mode === "guest" && selected.id === reservation.fieldId) return { ...reservation, isOwner: false };
  return reservation;
}

class FixtureAdapter implements HubAdapter {
  async bootstrap(): Promise<HubContextModel> {
    const surface = previewSurface();
    return {
      actorId: "preview", actorName: "Alex Farmer", role: "farmer", surface,
      presence: surface === "tablet" ? "remote" : surface, marketId: surface === "market" ? "grapeseed" : undefined,
      nonce: "preview", serverTime: Math.floor(Date.now() / 1000), locale: "en",
      routes: ["today", "fields", "market", "sell"], progression,
      capabilities: { reserveFields: true, manageCoop: true, purchase: true, confirmSell: surface === "sell" },
    };
  }
  async load<T>({ kind, route, fieldId }: HubViewRequest): Promise<HubViewModel<T>> {
    const state = previewState();
    if (state !== "ready") return { request: { kind, route, fieldId }, state };
    const selected = fieldSeed.find((field) => field.id === fieldId) ?? fieldSeed[0];
    const detail: FieldDetailData = { field: detailedField(selected), reservation: detailReservation(selected), progression, rentPlans: selected.rentPlans };
    const data = kind === "inviteCandidates" ? [{ source: 21, name: "Jamie Crops" }, { source: 36, name: "Robin Acre" }]
      : kind === "fieldDetail" ? detail
      : route === "today" ? today
      : route === "fields" || kind === "fieldsOverview" ? fields
      : route === "market" ? market
      : sell;
    return { request: { kind, route, fieldId }, state: "ready", data: data as T };
  }
  async dispatch(): Promise<{ ok: true; message: string }> { return { ok: true, message: "Preview operation completed." }; }
  async close() { return; }
}

export const runtimeIsNui = isNuiRuntime();
export const hubAdapter: HubAdapter = runtimeIsNui ? new NuiHubAdapter() : new FixtureAdapter();
