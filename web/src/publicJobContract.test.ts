import { describe, expect, it } from "vitest";
import { FORBIDDEN_BUSINESS_ROUTES, levelThreshold, PRODUCE_PRICES, PUBLIC_FIELDS,
  PUBLIC_ROUTES, QUALITY_MULTIPLIERS, RENT_PRICES, UNLOCKS, VIEW_STATES } from "./publicJobContract";

describe("public-job v1 contract", () => {
  it.each(PUBLIC_ROUTES)("exposes route %s", route => expect(["today", "fields", "market", "sell"]).toContain(route));
  it.each(FORBIDDEN_BUSINESS_ROUTES)("excludes business route %s", route => expect(PUBLIC_ROUTES).not.toContain(route));
  it.each(VIEW_STATES)("supports %s view state", state => expect(typeof state).toBe("string"));
  it.each(Array.from({ length: 20 }, (_, index) => index + 1))("uses the quadratic XP threshold at level %i", level => {
    expect(levelThreshold(level)).toBe(Math.round(220 * (level - 1) ** 2));
  });
  it.each(Array.from({ length: 19 }, (_, index) => index + 1))("keeps XP thresholds monotonic from level %i", level => {
    expect(levelThreshold(level + 1)).toBeGreaterThan(levelThreshold(level));
  });
  it.each((["S", "M", "L"] as const).flatMap(size => ([6, 12, 24] as const).map(hours => [size, hours] as const)))(
    "defines a positive %s/%ih rental", (size, hours) => expect(RENT_PRICES[size][hours]).toBeGreaterThan(0));
  it.each(Object.entries(PRODUCE_PRICES))("defines the %s Standard sale price", (_crop, price) => expect(price).toBeGreaterThan(0));
  it.each(Object.entries(QUALITY_MULTIPLIERS))("defines the %s quality multiplier", (_tier, multiplier) => expect(multiplier).toBeGreaterThan(0));
  it.each(PUBLIC_FIELDS)("publishes field %s", field => expect(field).toMatch(/^(grapeseed|paleto)_/));
  it.each(UNLOCKS)("defines the level $level $id unlock", unlock => expect(unlock.level).toBeGreaterThan(1));
});
