# Installation

## Requirements

- QB-Core
- ox_lib
- ox_inventory
- ox_target
- oxmysql

## QB job

Add the job to `qb-core/shared/jobs.lua` (merge with your server's existing structure):

```lua
farmer = {
    label = 'Farmer',
    defaultDuty = false,
    offDutyPay = false,
    grades = {
        ['0'] = { name = 'Field Hand', payment = 0 },
        ['1'] = { name = 'Experienced Farmer', payment = 0 },
    },
},
```

Players must be `farmer` and on duty. Duty locations are server-specific and intentionally not created by this resource.

## ox_inventory items

Merge every definition from `data/ox_inventory_items.lua` into `ox_inventory/data/items.lua`. Do not rename the items without also updating the canonical catalog and crop configuration.

Copy the runtime item images from `inventory_images/` into `ox_inventory/web/images/` (keep the filenames unchanged). The `inventory_images/previews/` folder and `PROMPTS.md` are production-source references and do not need to be copied.

`farm_tablet` must remain `stack = false`, explicitly set `consume = 0`, and use the `sonar_farm_publicjob.openTablet` client export. The resource prevents Market duplicates and rejects transfers to a player who already carries one.

Regenerate after catalog changes:

```powershell
lua scripts/generate_items.lua
lua scripts/generate_items.lua --check
```

## Crop prop pack

The configured growth stages use the licensed `bzzz_plants_*` models for carrot, potato, lettuce and tomato. Install and start the compatible Bzzz plant prop resource before `sonar_farm_publicjob`; those third-party assets are not redistributed here. At startup the client validates every configured model and logs the missing names.

If the pack is absent, crops fall back to the built-in `prop_plant_01a`, so gameplay remains visible but loses crop/stage fidelity. For a commercial release, treat any missing-model warning as a failed installation rather than relying on the fallback.

## Database

Choose one method:

- Recommended: leave `Config.Database.AutoCreateSchema = true`. The resource creates/migrates every `sfpj_*` table at startup.
- Manual: import `database/publicjob.sql`, then set AutoCreateSchema according to your operational policy.

No `sonar_farm` table is referenced.

## ACE

```cfg
add_ace group.admin sonar_farm_publicjob.admin allow
add_ace group.admin sonar_farm_publicjob.fields_admin allow
```

Diagnostic commands are registered only while `Config.Debug = true` and still require `sonar_farm_publicjob.admin`:

- `/sfpj_reservation <reservation-id|field-id>`
- `/sfpj_release <reservation-id|field-id>`
- `/sfpj_setxp <citizenid> <xp>`
- `/sfpj_reconcile`
- `/sfpj_activate_field <field-id> <revision-id>`

## Start order and smoke test

After first start, confirm the console reports `Sonar Farm Public Job ready`, schema validation reports no missing table/column, the `sfpj_schema_migrations` row exists, and all six public Fields appear in the Hub and map. Test Market and Sell with a real on-duty farmer before opening access to players.
