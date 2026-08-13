# Public Job Hub design QA

Date: 2026-08-13  
Branch: `codex/publicjob-v1`  
Scope: Today, Fields, Field Detail, Market and Sell

## Sources of truth

- Read-only implementation reference: `D:\sonar_app\sonar_farm\web`
- User-supplied Supplies reference: `C:\Users\aboul\AppData\Local\Temp\codex-clipboard-f76aa251-430f-4c43-8dc8-1c2f4df573e8.png`
- Rejected pre-rebuild Public Job capture: `C:\Users\aboul\AppData\Local\Temp\codex-clipboard-2b809581-1e35-485b-bea1-577ea3a0687f.png`
- Reused source assets: `tablet-frame.webp`, `office-frame.webp`, farm background, catalog item artwork, Barlow Condensed, Source Sans 3 and Phosphor Icons.

The original `sonar_farm` visual system is authoritative. Public Job removes business capabilities and terminology, but does not introduce a new visual direction.

## Comparison method

The original Supplies screen and rebuilt Public Job Market were opened with the Codex integrated Browser, captured at the same browser viewport and placed in one combined comparison input.

- Browser viewport: 1280×720
- Device pixel ratio: 1.25
- Logical product canvas: 1440×810
- Measured screen in both captures: x 129.54, y 72.87, width 1020.919, height 574.267
- Original capture: `C:\Users\aboul\.codex\audits\sonar-farm-publicjob\2026-08-13\ui-rebuild\origin-supplies-1280x720.png`
- Implementation capture: `C:\Users\aboul\.codex\audits\sonar-farm-publicjob\2026-08-13\ui-rebuild\publicjob-market-1280x720.png`
- Combined comparison: `C:\Users\aboul\.codex\audits\sonar-farm-publicjob\2026-08-13\ui-rebuild\market-comparison-normalized.png`

The comparison covered the header geometry, navigation rhythm, title block, toolbar, dense two-column product cards, real item artwork, tiers, stock and quantity controls, right-hand inspector, charcoal/yellow tokens, borders, shadows and typography. The source-only preview toolbar is development tooling and is intentionally absent from the target resource.

## Iterations and findings

1. Initial Public Job UI: light, sparse conventional dashboard. Classified P1 because composition, density, palette, frame, typography and catalog treatment did not match the source.
2. Foundation rebuild: restored `SurfaceStage`, fixed canvas scaling, physical frames, source typography/tokens, header, scaffold, selectors, state panels, dialogs, deep-view shell and FieldMap patterns.
3. Route rebuild: rebuilt all five views together and restored the Market/Sell catalog-inspector workflows with public-job data and terminology.
4. Normalized side-by-side review: no remaining P0, P1 or P2 visual mismatch. No cropped controls, incorrect spacing, broken image sizing or unintended responsive reflow was observed.

## Route and interaction evidence

- Today: `C:\Users\aboul\.codex\audits\sonar-farm-publicjob\2026-08-13\ui-rebuild\today-pass-1.png`
- Fields: `C:\Users\aboul\.codex\audits\sonar-farm-publicjob\2026-08-13\ui-rebuild\fields-pass-1.png`
- Field Detail: `C:\Users\aboul\.codex\audits\sonar-farm-publicjob\2026-08-13\ui-rebuild\field-detail-pass-1.png`
- Extension confirmation: `C:\Users\aboul\.codex\audits\sonar-farm-publicjob\2026-08-13\ui-rebuild\field-extend-dialog.png`
- Market confirmation: `C:\Users\aboul\.codex\audits\sonar-farm-publicjob\2026-08-13\ui-rebuild\market-purchase-dialog.png`
- Physical Market: `C:\Users\aboul\.codex\audits\sonar-farm-publicjob\2026-08-13\ui-rebuild\market-physical-pass-1.png`
- Remote Sell: `C:\Users\aboul\.codex\audits\sonar-farm-publicjob\2026-08-13\ui-rebuild\sell-remote-pass-1.png`
- Physical Sell confirmation: `C:\Users\aboul\.codex\audits\sonar-farm-publicjob\2026-08-13\ui-rebuild\sell-physical-dialog.png`

Verified interactions include route navigation, search, category filters, quantity steppers, ten-line cart limit, level and stock gates, physical-only tablet purchase, exact purchase review, field topology, reservation extension, privacy, remote Sell route-only behavior, physical Sell review and exact bank preview. Loading, empty, blocked, error, restricted and unavailable states use the shared dark `StatePanel` treatment. Server rejection preserves the active cart or selection; successful confirmation clears it.

The integrated Browser console reported no warnings or errors during the full flow.

## Scale coverage

- 1280×720: proportional fit, no overflow or clipping.
- 1920×1080: proportional fit, no overflow or clipping.
- 2560×1080 ultrawide: proportional fit centered within the world stage, no overflow or clipping.

## Automated verification

- Web: typecheck, lint, 93 Vitest tests, production build and 4 Sites packaging tests passed.
- Lua: 50 authoritative domain tests passed.
- Inspection HUD: typecheck, lint, 8 tests, production build and production-contract verification passed.
- Minigames: typecheck, lint, 11 tests and production build passed while remaining disabled for v1.
- Generated ox_inventory and web catalog artifacts are current.

## Result

No P0, P1 or P2 design issues remain in the normalized comparison or route review.

final result: passed
