import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { describe, expect, it } from "vitest";

describe("NUI shell coexistence", () => {
  it("keeps Field HUD passive, independent from Inspection, and suppressed by focused surfaces", () => {
    const source = readFileSync(resolve(process.cwd(), "..", "nui-shell", "index.html"), "utf8");
    expect(source).toContain('id="field-hud"');
    expect(source).toContain("pointer-events:none");
    expect(source).toContain("is-suppressed");
    expect(source).toContain("message.type.startsWith('fieldHud:')");
    expect(source).toContain('id="inspection"');
  });
});
