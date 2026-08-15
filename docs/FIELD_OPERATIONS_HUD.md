# Field Operations HUD

The Field Operations HUD appears automatically while the local character has an active or grace reservation membership. It remains visible when the farmer goes off duty or changes job because real-time rental and grace deadlines continue; the HUD changes to **Restricted** and client targets are hidden until server requirements are satisfied again.

## Player control

- `C` changes only between compact and expanded mode.
- The HUD cannot be manually hidden while a reservation continues.
- The key is remappable through FiveM key bindings. Administrators can change `Config.FieldHud.ToggleKey` and `ToggleCommand` before first use.
- Hub and minigame surfaces temporarily suppress the HUD. Closing them restores the previous compact/expanded mode. Crop Inspection remains a separate passive overlay.

Compact mode shows the Field, size, reservation state, authoritative countdown and the highest-priority next action. Expanded mode adds occupancy, own crops, co-op summary, the nearest priority slot, the four-step work cycle, a contextual guide and the marker legend.

Priority order is restriction/grace, own ready crop, critical condition, Watch care, empty slot and stable review. The timer is derived from the last server timestamp; `Syncing`, `Sync stale` and `Sync unavailable` explicitly communicate transport state without fabricating current data.

## Slot indicators

Every streamed slot in the reserved Field receives the same optimized agricultural glyph:

| Color | Meaning |
|---|---|
| Ivory | Empty and plantable |
| Green | Occupied and stable |
| Amber | Watch; care is required |
| Orange-red | Critical, withered or dead |
| Bright yellow | Own crop ready to harvest |
| Gray | Blocked by job, duty, grace or departing membership |

The highest-priority nearby actionable slot is statically larger. There is no pulse, sound, particle or physical prop. FiveM projects and tints one 128×128 transparent texture at exact server-loaded slot coordinates; the NUI never receives 24/40/64 coordinates per frame.

The same streamed slots are mirrored as small native GTA blips on the minimap and pause map. Blips inherit the semantic state color, keep the priority slot slightly larger and are removed immediately when the topology changes, leaves streaming range or the reservation ends. They are presentation only and never bypass `ox_target` or server validation.

Ground Z is resolved once when topology is streamed. Classification is cached at `Config.FieldHud.ClassificationMs`; only screen projection and `DrawSprite` remain in the frame loop. Indicators are skipped in interiors and outside `MarkerMaxDistance`.

## Runtime authority

`sonar_farm_publicjob:fieldHud:state` uses the normal runtime/bucket/player lifecycle gate but deliberately does not require farmer duty. Its `FieldHudPayloadV1` exposes only Field metadata, reservation role/status, aggregate co-op and crop counts, deadline and job/duty state. Other members' identifiers and display names are never included.

MySQL active Field revisions remain the source of topology. `data/fields.lua` is not a runtime catalogue. No SQL changes are required for this HUD.

Invalidation occurs after reserve, extend, release, grace transition, co-op accept/leave/revoke and server restart. Job/duty framework events trigger an immediate refresh; a ten-second refresh is the fallback.

## Administrator configuration

`Config.FieldHud.Position` supports `left-center` (default) and `top-left`. Visual distance, scale, alpha, refresh, stale and classification settings are grouped under `Config.FieldHud` in `config/config.lua`. `MapBlipsEnabled` controls the minimap/pause-map layer; `MapBlipShortRange = false` keeps every currently streamed slot visible on both map surfaces. Keep `MarkerMinScale <= MarkerMaxScale` and `MapBlipScale <= MapBlipPriorityScale`; startup validation fails closed on invalid values.

## In-game acceptance

Before release, validate with the real MySQL Fields:

1. Owner, active guest and departing guest in active and grace reservations.
2. Duty loss, job change, resource restart, release and expiry purge.
3. Exactly 24, 40 and 64 projected indicators and matching minimap/pause-map blips when each topology is streamed.
4. Marker alignment, ground snap, map colors, priority scale and ox_target options from different camera angles.
5. Hub/minigame suppression and simultaneous Crop Inspection.
6. 1280×720, 1920×1080 and 2560×1080 with chat and minimap enabled.
7. L64 resmon average target at or below 0.25 ms and no persistent texture/marker state after reservation end.
