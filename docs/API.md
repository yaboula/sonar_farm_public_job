# Public API

All gameplay mutations are server authoritative. Public events are notifications after a committed action, not alternate mutation entrypoints.

## Client exports

```lua
exports.sonar_farm_publicjob:openTablet()
exports.sonar_farm_publicjob:useSeed(itemData)
```

`openTablet` still requires the farmer job, on-duty state and a tablet in inventory. `useSeed` routes through authoritative slot, reservation, inventory and level validation.

## Server events

- `sonar_farm_publicjob:cropPlanted`
- `sonar_farm_publicjob:cropWatered`
- `sonar_farm_publicjob:cropHarvested`
- `sonar_farm_publicjob:cropFertilized`
- `sonar_farm_publicjob:cropWeeded`
- `sonar_farm_publicjob:cropTreated`

Payloads contain the crop ID/type, action source and personal owner identifier where relevant. Treat the payload as audit/integration data; consumers must not assume it authorizes later actions.

## Produce metadata

Harvested items include:

- `producer`: planter/harvester citizen ID.
- `reservationId` and `fieldId`.
- `tier` and quality metadata from the crop engine.
- `operationId`.
- `resource`: the current resource name.

The Sell service requires the resource and producer fields to match. Inventory transfers do not transfer sale eligibility.

## Rejection codes

Common codes include `job_required`, `duty_required`, `tablet_required`, `presence_required`, `reservation_required`, `reservation_grace`, `member_departing`, `crop_owner_required`, `level_required`, `stock_unavailable`, `inventory_full`, `insufficient_funds`, `maximum_expiry` and `operation_in_progress`.

Callers should display human-readable English copy and may retry only with the same operation ID when recovering an uncertain response.
