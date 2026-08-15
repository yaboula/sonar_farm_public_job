# Field Operations HUD design QA

## Sources

- Player-provided Field marker reference: `qa/reference-slot-markers.png` (720×360).
- Existing Sonar Farm visual system: Hub carbon/yellow tokens, Barlow Condensed, Source Sans 3 and Phosphor Icons.
- Existing Public Job Inspection rail: `../inspection-ui/qa-reference-comparison-v3.png` and its production CSS tokens.
- Implementation: `src/App.tsx`, `src/styles.css` and the Phosphor Grains runtime derivative in `../world/slot-marker.png`.

## Browser and viewports

Validated in the Codex integrated browser against the Vite development fixture on 15 August 2026.

| Viewport | Result |
|---|---|
| 1280×720 | Expanded HUD 360×488 at x=26/y=102; no clipping |
| 1440×810 | Expanded and compact modes; `C` changes mode without hiding |
| 2560×1080 | Expanded HUD 382×527 at x=51/y=276; proportional safe inset |

Console errors and warnings: none.

## Interaction and state checks

- Compact preserves Field identity, status, countdown, next priority and the `C` hint.
- Expanded adds visible slots, condition counts, co-op, own crops, interaction status, work cycle, contextual tip and complete legend.
- `left-center` and `top-left` both render without clipping.
- Active, grace, restricted and stale states use explicit semantic copy and never invent fresh timestamps.
- The HUD iframe remains pointer-free and separate from Inspection; Hub/minigame suppression preserves its prior mode.
- Official Phosphor components are used in NUI. The world glyph is the official Grains fill path rasterized to a single transparent 2.3 KB PNG and tinted at runtime.

## Iterations

1. Restored the Sonar carbon/yellow foundation and operational density.
2. Reduced the compact state to the three facts needed while moving through a Field.
3. Added exact role, crop, priority-slot and sync language; verified `C` after correcting the development fixture event path.
4. Replaced direct Phosphor barrel imports with icon-level imports to keep build/test transforms fast.
5. Compared the supplied source and the final semantic marker asset in one 1440×810 artifact: `qa/marker-comparison-1440x810.png`.

## Severity review

- P0 blockers: 0.
- P1 functional/legibility defects: 0.
- P2 visual inconsistencies: 0 after final compact spacing and marker comparison pass.
- Remaining external acceptance: FiveM world alignment and L64 resmon require the game runtime and are tracked in `docs/RELEASE_CHECKLIST.md`.

**final result: passed**
