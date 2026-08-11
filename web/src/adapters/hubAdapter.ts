import type { FieldsData, HubAdapter, HubContextModel, HubViewModel, HubViewRequest, MarketData, SellData, TodayData } from "../types";
import { NuiHubAdapter, isNuiRuntime } from "./NuiHubAdapter";

const progression = { xp: 4380, level: 5, maxLevel: 20, levelStartXp: 3520, nextLevelXp: 5500,
  rentDiscount: .05, sellBonus: .03, unlocks: { plus: true, pro: false, medium: true, large: false } };
const fields: FieldsData = { progression, fields: [
  { id: "grapeseed_south", name: "South Fields", location: "Grapeseed · South farm road", region: "Grapeseed", sizeClass: "S", slotCount: 24, available: true, requiredLevel: 1,
    rentPlans: [{ hours: 6, basePrice: 1500, price: 1425, graceSurcharge: false }, { hours: 12, basePrice: 2700, price: 2565, graceSurcharge: false }, { hours: 24, basePrice: 4800, price: 4560, graceSurcharge: false }] },
  { id: "grapeseed_east", name: "East Fields", location: "Grapeseed · East service track", region: "Grapeseed", sizeClass: "M", slotCount: 40, available: false, requiredLevel: 5,
    rentPlans: [{ hours: 6, basePrice: 2400, price: 2280, graceSurcharge: false }, { hours: 12, basePrice: 4300, price: 4085, graceSurcharge: false }, { hours: 24, basePrice: 7600, price: 7220, graceSurcharge: false }] },
  { id: "grapeseed_north", name: "North Acre", location: "Grapeseed · North irrigation road", region: "Grapeseed", sizeClass: "L", slotCount: 64, available: true, requiredLevel: 10,
    rentPlans: [{ hours: 6, basePrice: 3600, price: 3420, graceSurcharge: false }, { hours: 12, basePrice: 6500, price: 6175, graceSurcharge: false }, { hours: 24, basePrice: 11500, price: 10925, graceSurcharge: false }] },
  { id: "paleto_creek", name: "Creek Plot", location: "Paleto · Creek approach", region: "Paleto", sizeClass: "S", slotCount: 24, available: true, requiredLevel: 1,
    rentPlans: [{ hours: 6, basePrice: 1500, price: 1425, graceSurcharge: false }, { hours: 12, basePrice: 2700, price: 2565, graceSurcharge: false }, { hours: 24, basePrice: 4800, price: 4560, graceSurcharge: false }] },
  { id: "paleto_orchard", name: "Orchard Rows", location: "Paleto · Old orchard road", region: "Paleto", sizeClass: "M", slotCount: 40, available: true, requiredLevel: 5,
    rentPlans: [{ hours: 6, basePrice: 2400, price: 2280, graceSurcharge: false }, { hours: 12, basePrice: 4300, price: 4085, graceSurcharge: false }, { hours: 24, basePrice: 7600, price: 7220, graceSurcharge: false }] },
  { id: "paleto_highland", name: "Highland Farm", location: "Paleto · Highland service lane", region: "Paleto", sizeClass: "L", slotCount: 64, available: true, requiredLevel: 10,
    rentPlans: [{ hours: 6, basePrice: 3600, price: 3420, graceSurcharge: false }, { hours: 12, basePrice: 6500, price: 6175, graceSurcharge: false }, { hours: 24, basePrice: 11500, price: 10925, graceSurcharge: false }] },
] };
const market: MarketData = { progression, stock: { plus: 16, pro: 7 }, products: [
  { id: "carrot_seed", label: "Carrot Seeds", description: "Reliable field seed.", category: "Seeds", tier: "basic", price: 24, requiredLevel: 1, unlocked: true },
  { id: "watering_can_reinforced", label: "Reinforced Watering Can", description: "50 uses with water retention.", category: "Watering", tier: "plus", price: 380, stock: 16, requiredLevel: 4, unlocked: true },
  { id: "watering_can_professional", label: "Professional Watering Can", description: "100 uses and strong retention.", category: "Watering", tier: "pro", price: 650, stock: 7, requiredLevel: 8, unlocked: false },
] };
const sell: SellData = { progression, sellBonus: .03, groups: [
  { key: "carrot:standard", cropType: "carrot", itemId: "carrot", tier: "standard", quantity: 18, unitPrice: 12, basePrice: 12, multiplier: 1 },
  { key: "tomato:fine", cropType: "tomato", itemId: "tomato", tier: "fine", quantity: 7, unitPrice: 25, basePrice: 16, multiplier: 1.5 },
] };
const today: TodayData = { progression, ownCrops: 12, marketStock: market.stock, sellableGroups: sell.groups,
  nextUnlock: { level: 8, label: "Pro products" } };

class FixtureAdapter implements HubAdapter {
  async bootstrap(): Promise<HubContextModel> { return { actorId: "preview", actorName: "Alex Farmer", role: "farmer", surface: "tablet",
    presence: "remote", nonce: "preview", serverTime: Math.floor(Date.now() / 1000), locale: "en",
    routes: ["today", "fields", "market", "sell"], progression,
    capabilities: { reserveFields: true, manageCoop: true, purchase: true, confirmSell: false } }; }
  async load<T>({ kind, route, fieldId }: HubViewRequest): Promise<HubViewModel<T>> {
    const selectedField = fields.fields.find(field => field.id === fieldId) ?? fields.fields[0];
    const data = kind === "inviteCandidates" ? []
      : kind === "fieldDetail" ? { field: { ...selectedField, allowedCrops: [] }, progression, rentPlans: selectedField.rentPlans }
      : route === "today" ? today
      : route === "fields" || kind === "fieldsOverview" ? fields
      : route === "market" ? market
      : sell;
    return { request: { kind, route, fieldId }, state: "ready", data: data as T };
  }
  async dispatch(): Promise<{ ok: true }> { return { ok: true }; }
  async close() { return; }
}

export const runtimeIsNui = isNuiRuntime();
export const hubAdapter: HubAdapter = runtimeIsNui ? new NuiHubAdapter() : new FixtureAdapter();
