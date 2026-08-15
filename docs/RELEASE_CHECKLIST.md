# v0.1.0 release checklist

## Automated

- [x] 46+ Lua tests pass (65 current).
- [x] Deterministic V3 S24 simulation passes homogeneous and mixed crops at 0/30/60/90/120-second latency.
- [x] 104 web tests pass; web typecheck, lint, Sites contract and production build pass.
- [x] 11 minigame tests pass; typecheck, lint and build pass while the feature remains disabled.
- [x] 8 Inspection tests pass; typecheck, lint, production contract and build pass.
- [x] Field Operations HUD typecheck, lint, 7 component/contract tests, production contract and build pass.
- [x] Generated ox_inventory catalog is current.
- [x] No legacy `sf_*` business table or `sonar_farm` runtime dependency remains.

## Multi-client FiveM

- [ ] Simultaneous reservation of one Field produces one winner and compensates the loser.
- [ ] One player cannot own/join two reservations; concurrent invite acceptance remains atomic.
- [ ] Guest limit, 15 m presence and 60-second expiry are enforced.
- [ ] Departing members cannot plant and can care/harvest only their own crops.
- [ ] Grace blocks planting, permits care/own harvest/extension, charges 25%, and purges after 15 minutes.
- [ ] Last crop harvested during grace releases immediately; 30-minute same-Field cooldown applies to every participant.
- [ ] Concurrent Plus/Pro purchases cannot oversell global stock.
- [ ] Full inventory and insufficient bank balance do not lose money or stock.
- [ ] Duplicate Sell operation IDs cannot pay twice; foreign/transferred produce is rejected.
- [ ] Resource restart recovers active/grace reservations, crops and pending operations.
- [ ] New reservations expose only 1/3/6/8-hour plans and never accumulate beyond eight hours.
- [ ] A legacy reservation with more than eight hours remaining is not shortened and cannot extend.

## World and performance

- [ ] Grapeseed S24/M40/L64 and Paleto S24/M40/L64 ground snap, headings, spacing and targets are approved in-game.
- [ ] Grapeseed and Paleto Market NPCs and the central Grapeseed Sell NPC are approved.
- [ ] Licensed `bzzz_plants_*` prop resource is installed; startup reports no missing crop models.
- [ ] Every `inventory_images/*.png` runtime item image is present in `ox_inventory/web/images/`.
- [ ] No topology overlap; L64 culling, prop pool and target counts remain stable.
- [ ] Hub and crop rendering are checked at 720p, 1080p and ultrawide.
- [ ] Client/server resmon and FPS are acceptable with a full L64 Field.
- [ ] Field HUD shows all 64 exact slot indicators, averages at most 0.25 ms, survives duty/job changes and clears after release/purge.
- [ ] All six action clips and synchronized durations are approved on freemode male/female without sliding or abrupt truncation.
- [ ] Cancel, death, distance, vehicle, duty loss and resource stop clear the active animation and release the action lock.
- [ ] A second farming action and Hub open are rejected until the first action and its server response finish.

## Release

- [x] English copy and install docs reviewed.
- [x] `sonar_farm` source working tree proven unchanged.
- [ ] Reviewed branch merged; changelog finalized.
- [ ] Tag `v0.1.0` created and release package smoke-tested on a clean server.
