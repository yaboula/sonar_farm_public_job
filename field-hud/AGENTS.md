# Field Operations HUD contributor notes

- This bundle is a passive, pointer-free NUI overlay. It must never request focus or authorize gameplay.
- Keep the runtime contract at `FieldHudPayloadV1` and the messages `fieldHud:show`, `fieldHud:update`, `fieldHud:mode` and `fieldHud:hide`.
- `C` is owned by the FiveM key mapping. Browser-only key handling exists solely inside the `import.meta.env.DEV` fixture.
- Preserve the Sonar Farm visual system: Barlow Condensed headings, Source Sans 3 body copy, Phosphor icons, carbon surfaces, yellow focus and semantic green/amber/orange-red states.
- Import Phosphor icons individually. Barrel imports make the Windows test/build transform unnecessarily expensive.
- Do not send slot coordinates to this React bundle. World projection belongs to `client/modules/field_hud/controller.lua`.
- Never ship fixture identities or browser QA state. `npm run build` runs the production-contract verifier.
- Before committing, run `npm run typecheck`, `npm run lint`, `npm test` and `npm run build`.
