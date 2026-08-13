# Public Job Hub design QA

Date: 2026-08-13  
Branch: `codex/publicjob-v1`  
Scope: Today, Fields, Field Detail, Market and Sell after the complete Hub UX audit

## Sources of truth

- Read-only implementation reference: `D:\sonar_app\sonar_farm\web`
- User-supplied Supplies reference: `C:\Users\aboul\AppData\Local\Temp\codex-clipboard-f76aa251-430f-4c43-8dc8-1c2f4df573e8.png`
- Normalized original Supplies capture: `C:\Users\aboul\.codex\audits\sonar-farm-publicjob\2026-08-13\ui-rebuild\origin-supplies-1280x720.png`
- Rejected pre-rebuild Public Job capture: `C:\Users\aboul\AppData\Local\Temp\codex-clipboard-2b809581-1e35-485b-bea1-577ea3a0687f.png`
- Reused source assets: `tablet-frame.webp`, `office-frame.webp`, farm background, catalog item artwork, Barlow Condensed, Source Sans 3 and Phosphor Icons.

The original `sonar_farm` visual system remains authoritative. Public Job removes business capabilities and terminology without introducing another visual direction.

## Final comparison evidence

The original Supplies screen and current Public Job Market were captured at the same viewport and placed in one combined comparison image before review.

- CSS viewport: 1280×720
- Device pixel ratio: 1
- Source pixels: 1280×720
- Implementation pixels: 1280×720
- Density normalization: none required; both inputs are one CSS pixel per output pixel
- Logical product canvas: 1440×810 inside the original 1584×914 physical frame
- Measured implementation screen: x 129.54, y 72.87, width 1020.92, height 574.27
- State: physical Market, empty cart, complete catalog at initial scroll position
- Implementation: `docs/design-qa/market-1280x720-final.png`
- Combined comparison: `docs/design-qa/market-comparison-final.png`

The full-view comparison verifies composition, frame, header geometry, navigation rhythm, title block, toolbar, dense two-column catalog, right-hand purchase inspector and above-the-fold crop. Focused card/inspector regions were also reviewed because typography, real item artwork, tier badges, stock, prices and steppers are too small to judge reliably from composition alone.

## Required fidelity surfaces

- Fonts and typography: Barlow Condensed display hierarchy and Source Sans 3 body copy remain aligned with the original weights, capitalization, line height and density. No fallback-font flashes or broken wrapping were observed.
- Spacing and layout rhythm: source canvas proportions, margins, two-column cards, inspector width, separators and vertical crop remain consistent. No persistent control is clipped.
- Colors and tokens: charcoal surfaces, yellow accent, muted olive borders, semantic status colors and disabled opacity remain mapped to the source system.
- Image quality and assets: original catalog PNG artwork, frame WebPs and background are sharp, correctly contained and free of placeholder or CSS-drawn substitutes. Phosphor provides the UI icon family.
- Copy and content: Market/Sell copy is personal, immediate-delivery and personal-bank language. Company, Treasury, Warehouse, Work and Cargo terminology is absent.

## Route and interaction evidence

- Today: `docs/design-qa/today-1280x720-final.png`
- Fields: `docs/design-qa/fields-1280x720-final.png`
- Field Detail: `docs/design-qa/field-detail-1280x720-final.png`
- Market: `docs/design-qa/market-1280x720-final.png`
- Physical Sell: `docs/design-qa/sell-1280x720-final.png`

Integrated Browser checks passed for navigation, Market quantity selection, purchase review, dialog focus containment, Escape closing only the confirmation, owner-only extension, existing-participation blocking and physical Sell rendering. The Browser console contained no warnings or errors.

The final UX audit added and verified:

1. A global progression inspector with every unlock and the exact XP remaining.
2. Exact rental/grace deadlines, own-Field identification, private availability countdowns and direct routing.
3. Immediately visible topology slots, allowed-crop context, 24-hour-cap gating and exact post-extension expiry.
4. Personal bank before/after previews for rental, Market and Sell, with proactive insufficient-funds blocking.
5. Crop readiness/attention on Today, a bounded co-op invite selector and a complete no-reservation quick start.
6. Clear quality-unit pricing plus the personal Sell bonus, avoiding misleading rounded per-unit totals.

Audit captures before and after are retained in `docs/hub-ux-audit/`; final states are numbered `11` through `20`.

Accessibility checks now include dialog focus restoration/trapping, keyboard-operable FarmSelect, live-region notices, semantic dialog busy state, disabled pending controls and reduced-motion handling.

## Scale evidence

- 1280×720: screen 1020.92×574.27; no document overflow.
- 1920×1080: screen 1588.10×893.30; no document overflow.
- 2560×1080 ultrawide: screen 1588.10×893.30 and centered; no document overflow.

This validates Hub scaling only. FiveM world placement, crop culling and FPS remain separate manual release gates.

## Comparison history

1. Initial Public Job UI was a light, sparse dashboard. P1: composition, density, palette, frame, typography and catalog treatment diverged from the source.
2. Foundation and route rebuild restored the source visual system and all five public routes. The normalized source/implementation comparison cleared the earlier P1.
3. Release-readiness review found P2 interaction drift: Hub invalidations were ignored, guests could see extension affordances, modal/select keyboard behavior was incomplete and notices were not announced.
4. Current iteration reloads active data on invalidation, mirrors authoritative owner/participation gates, preserves cart/selection after rejection, traps modal focus, fixes Escape behavior, completes select keyboard navigation and adds live regions/reduced motion.
5. Post-fix source/implementation comparison and route captures found no remaining actionable P0/P1/P2 visual or interaction mismatch. No P3 follow-up is required for this release candidate.
6. Complete-route UX audit found P2 operational-context gaps: the player's own Field looked like any other reservation, expiry and balance consequences were hidden, topology started blank, rounded Sell unit copy could disagree with exact totals, and progression lacked a discoverable detail view.
7. The current iteration resolves those findings without adding a top-level route or weakening the original visual system. Tablet and physical surfaces retain their distinct frames and authority.

## Automated verification

- Lua: 51 authoritative domain tests passed; generated inventory/catalog artifacts are current.
- Web: typecheck, lint, 101 Vitest tests, production build and 4 Sites packaging tests passed.
- Inspection HUD: typecheck, lint, 8 tests, production build and production-contract verification passed.
- Minigames: typecheck, lint, 11 tests and production build passed while the feature remains disabled for v1.

## Residual release gates

Multi-client reservation/stock races, resource restarts, real ox_inventory/bank failures, licensed crop props, all six in-world topologies, NPC placement, ground snap, target reachability, resmon and FPS require a running FiveM staging server. They remain unchecked in `docs/RELEASE_CHECKLIST.md` and do not alter this browser design result.

final result: passed
