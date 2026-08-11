export type HubRoute = "today" | "fields" | "market" | "sell";
export type HubSurface = "tablet" | "market" | "sell";
export type ViewState = "ready" | "loading" | "empty" | "blocked" | "error" | "restricted" | "unavailable";

export interface Progression {
  xp: number; level: number; maxLevel: number; levelStartXp: number; nextLevelXp: number;
  rentDiscount: number; sellBonus: number;
  unlocks: { plus: boolean; pro: boolean; medium: boolean; large: boolean };
}
export interface ReservationMember { identifier: string; display_name: string; role: "owner" | "guest"; status: "active" | "departing" | "released" }
export interface Reservation { id: string; fieldId: string; status: "active" | "grace" | "released"; expiresAt: number; graceUntil?: number;
  isOwner: boolean; ownCrops: number; liveCrops: number; members: ReservationMember[] }
export interface RentPlan { hours: 6 | 12 | 24; basePrice: number; price: number; graceSurcharge: boolean }
export interface PublicField { id: string; name: string; location: string; region: string; sizeClass: "S" | "M" | "L";
  slotCount: number; available: boolean; expiresAt?: number; requiredLevel: number; rentPlans: RentPlan[] }
export interface MarketProduct { id: string; label: string; description?: string; category: string; tier: "basic" | "plus" | "pro";
  price: number; stock?: number; requiredLevel: number; unlocked: boolean; physicalOnly?: boolean; owned?: boolean }
export interface SellGroup { key: string; cropType: string; itemId: string; tier: string; quantity: number; unitPrice: number; basePrice?: number; multiplier?: number }

export interface TodayData { progression: Progression; reservation?: Reservation; ownCrops: number;
  marketStock: Record<string, number>; sellableGroups: SellGroup[]; nextUnlock?: { level: number; label: string } }
export interface FieldsData { fields: PublicField[]; reservation?: Reservation; progression: Progression }
export interface MarketData { products: MarketProduct[]; stock: Record<string, number>; progression: Progression }
export interface SellData { groups: SellGroup[]; sellBonus: number; progression: Progression }

export interface HubContextModel { actorId: string; actorName?: string; role: "farmer"; surface: HubSurface; presence: string;
  marketId?: string; nonce: string; serverTime: number; locale: "en"; routes: HubRoute[]; progression: Progression;
  capabilities: { reserveFields: boolean; manageCoop: boolean; purchase: boolean; confirmSell: boolean } }
export interface HubViewRequest { kind: string; route?: HubRoute; fieldId?: string; selections?: Record<string, number>; sellAll?: boolean }
export interface HubViewModel<T = unknown> { request: HubViewRequest; state: ViewState; data?: T; reason?: string }
export interface IntentResult { ok: boolean; reason?: string; message?: string; closeSurface?: boolean;
  route?: { x: number; y: number; z?: number }; [key: string]: unknown }
export interface HubAdapter { bootstrap(): Promise<HubContextModel>; load<T>(request: HubViewRequest): Promise<HubViewModel<T>>;
  dispatch(intent: Record<string, unknown>): Promise<IntentResult>; close(): Promise<void> }

export interface MarketCatalogProduct { id: string; label: string; category: string; cropRelation: string;
  description: string; effect: string; tier: "basic" | "plus" | "pro"; image: string; price: number;
  stock: number | "base"; restock: string; leadMinutes: number; applications: number }
