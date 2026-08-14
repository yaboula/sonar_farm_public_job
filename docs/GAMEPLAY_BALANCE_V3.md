# Gameplay actions and V3 care balance

New crops use `simulationVersion = 3`. Existing V1/V2 crops keep their original rates, initialization and material retention until they leave the world; no migration rewrites their data.

## Manual S24 baseline

V3 derives rates from real seconds and then converts them to the crop's stored `growth_time` ratio so client prediction and server settlement use the same shared evaluator.

| Factor | First-round delay | Green delta | Time to green boundary |
|---|---:|---:|---:|
| Water | 0 s | -40 | 570 s |
| Nutrients | 120 s | -25 | 570 s |
| Weeds | 240 s | +20 | 570 s |
| Pests | 360 s | +20 | 570 s |

After the first effective care of a factor, its initial delay is permanently disabled by the persisted factor-specific `*CareAt` timestamp. V3 Basic care has no residual protection: water restores 40, fertilizer restores 25, and weed/pest care returns pressure below the green boundary. Nutrients initialize at `optimalMin + 25`, capped by `optimalMax`.

Weed competition starts only above 20. A 90-second late round therefore accumulates at most 90 seconds in Watch and never enters Critical; 120 seconds produces a clear Watch condition without sudden death. Abandoned crops may mature at low quality/yield.

Run `lua scripts/simulate_s24.lua` to exercise 24 carrots, potatoes, lettuce and tomatoes independently plus a mixed six-of-each S24 at 0/30/60/90/120-second delay. The simulator fails on unexpected Critical, sudden death, excessive Watch exposure or an ideal result below Fine.

## Action feedback

`Config.Gameplay.ActionFeedback` defines the duration, animation, prop, sound timing and one local particle system for Plant, Water, Fertilize, Weed, Treat pests and Harvest. `client/modules/interaction/feedback.lua` owns the `prepare -> perform -> finish/cancel` lifecycle and guarantees cleanup on cancellation, death, excess distance, vehicle entry, job/duty loss and resource stop.

The five bundled sounds are original procedural mono 48 kHz OGG assets, normalized approximately to -16 LUFS and totaling less than 500 KB. Their source and reproduction command are documented in `nui-shell/audio/README.md`. Use `/sfpj_action_preview <action>` only with `Config.Debug` and the configured admin ACE to approve freemode male/female clips and prop offsets in-game.
