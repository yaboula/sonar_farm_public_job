# Sonar Farm Public Job

Personal public-field farming for FiveM. Players work as an on-duty `farmer`, reserve a complete Field, optionally invite up to three nearby farmers, grow crops in authoritative slots, buy personal supplies and sell only their own harvest.

This is an independent sibling of `sonar_farm`. It does not read, migrate or modify `sonar_farm` tables.

## v0.1.0 scope

- QB-Core, ox_lib, ox_inventory, ox_target and oxmysql.
- Hub routes: Today, Fields, Market and Sell.
- Six public Fields: Grapeseed S24/M40/L64 and Paleto S24/M40/L64. The QA Field is hidden unless `Config.Debug` is enabled.
- Persistent 6/12/24-hour reservations, 15-minute grace, grace surcharge, purge and same-Field cooldown.
- Co-op invitations with atomic one-reservation membership and `departing` ownership protection.
- Personal 20-level progression with an idempotent XP ledger.
- Personal Market, global Plus/Pro stock, one non-stackable tablet and immediate inventory delivery.
- Quality-priced central Sell NPC with producer/resource metadata enforcement.
- Durable economy operation IDs, receipts, compensation outbox and reconciliation.
- Advanced crop care and Inspection HUD retained. Minigames ship as disabled future code.

Company, treasury, warehouse, P2P marketplace, staff, contracts, cargo, seasons, freshness and translations are outside v1.

## Installation

1. Copy the resource as `sonar_farm_publicjob` and start dependencies first:

   ```cfg
   ensure oxmysql
   ensure ox_lib
   ensure qb-core
   ensure ox_inventory
   ensure ox_target
   ensure sonar_farm_publicjob
   ```

2. Follow [Installation](docs/INSTALLATION.md) for the QB job, ox_inventory items, ACE and SQL.
3. Review [Economy](docs/ECONOMY.md), especially rental and Market prices.
4. Run the [administration runbook](docs/RUNBOOK.md).
5. Complete the [release checklist](docs/RELEASE_CHECKLIST.md) before tagging.

Schema auto-creation is enabled by default. `database/install.sql` bootstraps persistent crops and the resource applies the versioned `sfpj_*` domain schema. `database/publicjob.sql` is provided for manual provisioning.

## Configuration

The main settings are in `config/config.lua`. Every Hub open, mutation and crop interaction is revalidated on the server for job, duty, reservation membership, level, inventory/tablet and physical presence where required.

Public API:

- Events: `sonar_farm_publicjob:cropPlanted`, `cropWatered`, `cropHarvested`, `cropFertilized`, `cropWeeded`, `cropTreated`.
- Client exports: `exports.sonar_farm_publicjob:useSeed(...)` and `exports.sonar_farm_publicjob:openTablet()`.
- ACE: `sonar_farm_publicjob.admin` and `sonar_farm_publicjob.fields_admin`.

See [API](docs/API.md) for payload and security notes.

## Development and verification

```powershell
lua tests/run.lua
lua scripts/generate_items.lua --check

cd web
npm run typecheck
npm run lint
npm test
npm run build
```

Run the same typecheck/lint/test/build sequence in `inspection-ui` and `minigames-ui`. The initial release remains `0.1.0`; create `v0.1.0` only after the multi-client FiveM E2E and all world placements are signed off.

## Provenance

The reusable baseline came from local `sonar_farm` commit `8064bab`, including relevant working-tree versions, without modifying the source tree. Details are recorded in [ORIGIN_BASELINE.md](docs/ORIGIN_BASELINE.md).
