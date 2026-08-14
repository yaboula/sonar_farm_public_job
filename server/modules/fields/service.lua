-- Public Field topology and farming authority.

Fields = Fields or {}

local active, byLegacyZone, byCell, subscribers = {}, {}, {}, {}

local function encode(value) return json.encode(value or {}) end
local function decode(value)
    if type(value) == 'table' then return value end
    local ok, result = pcall(json.decode, value or '')
    return ok and type(result) == 'table' and result or {}
end
local function has(list, wanted)
    if not list or #list == 0 then return true end
    for _, value in ipairs(list) do if value == wanted then return true end end
    return false
end
local function fieldCell(x, y)
    return ('%d:%d'):format(math.floor(x / Sonar.Constants.SPATIAL_CELL_SIZE),
        math.floor(y / Sonar.Constants.SPATIAL_CELL_SIZE))
end

function Fields.IsEnabled() return Config.Features.Fields == true end
function Fields.IsAuthorityEnabled() return Fields.IsEnabled() end

local function revisionQueries(field, revisionId, revisionNumber, status)
    local queries = {{ query = [[INSERT INTO sfpj_field_revisions
        (id,field_id,revision_number,checksum,status,orientation,bounds_width,bounds_height,created_by,activated_at)
        VALUES (?,?,?,?,?,?,?,?,'seed',IF(?='active',CURRENT_TIMESTAMP,NULL))]],
        values = { revisionId, field.id, revisionNumber, field.checksum, status, field.orientation,
            field.bounds.width, field.bounds.height, status } }}
    for _, row in ipairs(field.rows) do
        queries[#queries + 1] = { query = [[INSERT INTO sfpj_field_rows
            (revision_id,field_id,id,label,row_order) VALUES (?,?,?,?,?)]],
            values = { revisionId, field.id, row.id, row.label, row.order } }
    end
    for _, slot in ipairs(field.slots) do
        queries[#queries + 1] = { query = [[INSERT INTO sfpj_field_slots
            (revision_id,field_id,row_id,id,slot_order,legacy_index,pos_x,pos_y,pos_z,heading,normalized_x,normalized_y,cell_key)
            VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)]], values = { revisionId, field.id, slot.rowId, slot.id,
            slot.order, slot.legacyIndex, slot.x, slot.y, slot.z, slot.heading,
            slot.position.x, slot.position.y, fieldCell(slot.x, slot.y) } }
    end
    return queries
end

function Fields.ImportSeeds()
    local compiled, errors = Sonar.Fields.CompileSeeds()
    if #errors > 0 then
        for _, message in ipairs(errors) do Logger.Warn(message, 'fields') end
        return false
    end
    for _, field in ipairs(compiled) do
        local current = MySQL.single.await([[SELECT f.active_revision_id,r.checksum FROM sfpj_fields f
            LEFT JOIN sfpj_field_revisions r ON r.id=f.active_revision_id WHERE f.id=?]], { field.id })
        if not current then
            local revisionId = Sonar.Utils.Uuid()
            local queries = {{ query = [[INSERT INTO sfpj_fields
                (id,legacy_zone,name,location,region,size_class,catalog_visible,active_revision_id,
                 access_x,access_y,access_z,allowed_crops,blip) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)]],
                values = { field.id, field.legacyZone, field.name, field.location, field.region, field.sizeClass,
                    field.catalogVisible and 1 or 0, revisionId, field.access.x, field.access.y, field.access.z,
                    encode(field.allowedCrops), encode(field.blip) } }}
            for _, query in ipairs(revisionQueries(field, revisionId, 1, 'active')) do queries[#queries + 1] = query end
            if not MySQL.transaction.await(queries) then return false end
        else
            MySQL.update.await([[UPDATE sfpj_fields SET legacy_zone=?,name=?,location=?,region=?,size_class=?,
                catalog_visible=?,access_x=?,access_y=?,access_z=?,allowed_crops=?,blip=? WHERE id=?]],
                { field.legacyZone, field.name, field.location, field.region, field.sizeClass,
                  field.catalogVisible and 1 or 0, field.access.x, field.access.y, field.access.z,
                  encode(field.allowedCrops), encode(field.blip), field.id })
            if tostring(current.checksum or '') ~= field.checksum then
                local existingDraft = MySQL.scalar.await([[SELECT COUNT(*) FROM sfpj_field_revisions
                    WHERE field_id=? AND checksum=?]], { field.id, field.checksum })
                if tonumber(existingDraft) == 0 then
                    local revisionId = Sonar.Utils.Uuid()
                    local revisionNumber = (tonumber(MySQL.scalar.await([[SELECT MAX(revision_number)
                        FROM sfpj_field_revisions WHERE field_id=?]], { field.id })) or 0) + 1
                    if not MySQL.transaction.await(revisionQueries(field, revisionId, revisionNumber, 'draft')) then
                        return false
                    end
                end
                Logger.Warn(('Topology seed %s differs from active revision; a draft is ready for in-game QA and activation.'):format(field.id), 'fields')
            end
        end
    end
    return true
end

function Fields.Reload()
    active, byLegacyZone, byCell = {}, {}, {}
    local rows = MySQL.query.await([[SELECT f.*,r.revision_number,r.checksum,r.orientation,r.bounds_width,r.bounds_height
        FROM sfpj_fields f JOIN sfpj_field_revisions r ON r.id=f.active_revision_id WHERE r.status='active']]) or {}
    for _, db in ipairs(rows) do
        local field = {
            id = db.id, legacyZone = db.legacy_zone, name = db.name, location = db.location,
            region = db.region, sizeClass = db.size_class,
            catalogVisible = (db.catalog_visible == 1 or db.catalog_visible == true or tonumber(db.catalog_visible) == 1),
            revisionId = db.active_revision_id,
            topologyRevision = tostring(db.revision_number) .. ':' .. tostring(db.checksum),
            orientation = tonumber(db.orientation) or 0,
            bounds = { width = tonumber(db.bounds_width), height = tonumber(db.bounds_height) },
            access = { x = tonumber(db.access_x), y = tonumber(db.access_y), z = tonumber(db.access_z) },
            allowedCrops = decode(db.allowed_crops), blip = decode(db.blip),
            rows = {}, slots = {}, rowMap = {}, slotMap = {}, legacySlots = {},
        }
        for _, row in ipairs(MySQL.query.await([[SELECT id,label,row_order FROM sfpj_field_rows
            WHERE revision_id=? ORDER BY row_order]], { field.revisionId }) or {}) do
            local value = { id = row.id, label = row.label, order = tonumber(row.row_order), slotIds = {} }
            field.rows[#field.rows + 1], field.rowMap[value.id] = value, value
        end
        for _, slot in ipairs(MySQL.query.await([[SELECT * FROM sfpj_field_slots
            WHERE revision_id=? ORDER BY legacy_index]], { field.revisionId }) or {}) do
            local value = { id = slot.id, rowId = slot.row_id, order = tonumber(slot.slot_order),
                legacyIndex = tonumber(slot.legacy_index), index = tonumber(slot.legacy_index),
                zone = field.legacyZone or field.id, fieldId = field.id, revisionId = field.revisionId,
                x = tonumber(slot.pos_x), y = tonumber(slot.pos_y), z = tonumber(slot.pos_z),
                heading = tonumber(slot.heading) or 0, cell = slot.cell_key,
                position = { x = tonumber(slot.normalized_x), y = tonumber(slot.normalized_y) } }
            field.slots[#field.slots + 1] = value
            field.slotMap[value.id], field.legacySlots[value.legacyIndex] = value, value
            if field.rowMap[value.rowId] then field.rowMap[value.rowId].slotIds[#field.rowMap[value.rowId].slotIds + 1] = value.id end
            byCell[value.cell] = byCell[value.cell] or {}
            byCell[value.cell][field.id] = field
        end
        active[field.id] = field
        byLegacyZone[field.legacyZone or field.id] = field
    end
    local keys = {}
    for k in pairs(active) do keys[#keys + 1] = k end
    Logger.Info(('Fields.Reload completed: %d active fields [%s]'):format(#rows, table.concat(keys, ', ')), 'fields')
    return true
end

function Fields.Init()
    return Fields.ImportSeeds() and Fields.Reload()
end

local function overlapsActive(field)
    local minimum = Config.Fields and tonumber(Config.Fields.MinimumSlotSpacing) or 0.75
    for otherId, other in pairs(active) do
        if otherId ~= field.id then
            for _, left in ipairs(field.slots) do
                for _, right in ipairs(other.slots) do
                    local dx, dy, dz = left.x - right.x, left.y - right.y, left.z - right.z
                    if math.sqrt(dx * dx + dy * dy + dz * dz) < minimum then return otherId end
                end
            end
        end
    end
end

function Fields.SaveDraft(definition, createdBy)
    local field, errors = Sonar.Fields.Compile(definition)
    if not field then return nil, table.concat(errors or {}, '; ') end
    local expectedSlots = { S = 24, M = 40, L = 64 }
    if #field.slots ~= expectedSlots[field.sizeClass] then
        return nil, ('size_%s_requires_%d_slots'):format(field.sizeClass, expectedSlots[field.sizeClass])
    end
    local overlap = overlapsActive(field)
    if overlap then return nil, 'overlaps_' .. overlap end
    local existing = MySQL.single.await([[SELECT f.id,f.active_revision_id,r.id revision_id
        FROM sfpj_fields f LEFT JOIN sfpj_field_revisions r ON r.field_id=f.id AND r.checksum=?
        WHERE f.id=?]], { field.checksum, field.id })
    if existing and existing.revision_id then return existing.revision_id end
    local revisionId = Sonar.Utils.Uuid()
    local revisionNumber = (tonumber(MySQL.scalar.await([[SELECT MAX(revision_number)
        FROM sfpj_field_revisions WHERE field_id=?]], { field.id })) or 0) + 1
    local queries = {}
    if existing then
        queries[#queries + 1] = { query = [[UPDATE sfpj_fields SET legacy_zone=?,name=?,location=?,region=?,
            size_class=?,catalog_visible=?,access_x=?,access_y=?,access_z=?,allowed_crops=?,blip=? WHERE id=?]],
            values = { field.legacyZone, field.name, field.location, field.region, field.sizeClass,
                field.catalogVisible and 1 or 0, field.access.x, field.access.y, field.access.z,
                encode(field.allowedCrops), encode(field.blip), field.id } }
    else
        queries[#queries + 1] = { query = [[INSERT INTO sfpj_fields
            (id,legacy_zone,name,location,region,size_class,catalog_visible,active_revision_id,
             access_x,access_y,access_z,allowed_crops,blip) VALUES (?,?,?,?,?,?,?,NULL,?,?,?,?,?)]],
            values = { field.id, field.legacyZone, field.name, field.location, field.region, field.sizeClass,
                field.catalogVisible and 1 or 0, field.access.x, field.access.y, field.access.z,
                encode(field.allowedCrops), encode(field.blip) } }
    end
    for _, query in ipairs(revisionQueries(field, revisionId, revisionNumber, 'draft')) do queries[#queries + 1] = query end
    if not MySQL.transaction.await(queries) then return nil, 'database_error' end
    MySQL.update.await('UPDATE sfpj_field_revisions SET created_by=? WHERE id=?',
        { tostring(createdBy or 'builder'), revisionId })
    return revisionId
end

function Fields.ActivateRevision(fieldId, revisionId)
    if Reservations and Reservations.GetByField(fieldId) then return false, 'field_reserved' end
    for _, crop in pairs(State and State.crops or {}) do
        if crop.data and crop.data.fieldId == fieldId then return false, 'field_has_crops' end
    end
    local revision = MySQL.single.await([[SELECT id FROM sfpj_field_revisions
        WHERE id=? AND field_id=? AND status='draft']], { revisionId, fieldId })
    if not revision then return false, 'draft_not_found' end
    local committed = MySQL.transaction.await({
        { query = [[UPDATE sfpj_field_revisions r JOIN sfpj_fields f ON f.active_revision_id=r.id
            SET r.status='archived' WHERE f.id=?]], values = { fieldId } },
        { query = [[UPDATE sfpj_field_revisions SET status='active',activated_at=CURRENT_TIMESTAMP
            WHERE id=? AND field_id=? AND status='draft']], values = { revisionId, fieldId } },
        { query = 'UPDATE sfpj_fields SET active_revision_id=? WHERE id=?', values = { revisionId, fieldId } },
    })
    if not committed then return false, 'database_error' end
    Fields.Reload()
    Fields.BroadcastInvalidate(fieldId, 'topology_activated')
    return true
end

lib.callback.register(Sonar.Constants.CALLBACKS.FIELD_DRAFT_SAVE, function(source, definition)
    if not Admin.IsAuthorized(source) or not Admin.IsFieldAuthorized(source) then
        return { ok = false, reason = 'forbidden' }
    end
    local revisionId, reason = Fields.SaveDraft(definition, Bridge.GetIdentifier(source) or 'console')
    return revisionId and { ok = true, revisionId = revisionId } or { ok = false, reason = reason }
end)

function Fields.Get(fieldId)
    local found = active[fieldId]
    if not found then
        local keys = {}
        for k in pairs(active) do keys[#keys + 1] = k end
        Logger.Warn(('Fields.Get(%s) failed! Active keys in memory: [%s]'):format(tostring(fieldId), table.concat(keys, ', ')), 'fields')
    end
    return found
end
function Fields.ByLegacyZone(zone) return byLegacyZone[zone] end
function Fields.CatalogBlips()
    local catalog = {}
    for _, field in pairs(active) do
        if field.catalogVisible or Config.Debug then
            catalog[#catalog + 1] = { id = field.id, name = field.name, access = field.access, blip = field.blip }
        end
    end
    table.sort(catalog, function(left, right) return left.name < right.name end)
    return catalog
end
lib.callback.register(Sonar.Constants.CALLBACKS.FIELD_CATALOG, function() return Fields.CatalogBlips() end)
function Fields.ResolveLegacySlot(zone, index)
    local field = byLegacyZone[zone]
    return field and field.legacySlots[tonumber(index)] or nil
end

function Fields.TopologiesForCells(cellKeys, identifier)
    local output, seen = {}, {}
    local link = Reservations and Reservations.GetLink(identifier) or nil
    for _, cell in ipairs(cellKeys or {}) do
        for id, field in pairs(byCell[cell] or {}) do
            local participates = link and link.field_id == id
                and (link.reservation_status == 'active' or link.reservation_status == 'grace')
                and (link.status == 'active' or link.status == 'departing')
            if not seen[id] and participates and (field.catalogVisible or Config.Debug) then
                seen[id] = true
                local slots = {}
                for _, slot in ipairs(field.slots) do
                    slots[#slots + 1] = { id = slot.id, rowId = slot.rowId, index = slot.index,
                        zone = slot.zone, fieldId = id, revisionId = field.revisionId,
                        x = slot.x, y = slot.y, z = slot.z, heading = slot.heading }
                end
                output[#output + 1] = { id = id, name = field.name, access = field.access,
                    revisionId = field.revisionId, topologyRevision = field.topologyRevision,
                    slots = slots, blip = field.blip, memberStatus = link.status,
                    reservationStatus = link.reservation_status }
            end
        end
    end
    return output
end

function Fields.ActorContext(source)
    local actor, reason = PublicJob.Guard(source)
    if not actor then return nil, reason end
    local link = Reservations and Reservations.GetLink(actor.identifier) or nil
    actor.reservation = link
    return actor
end

function Fields.ResolvePlantAccess(source, cropType, zone, index)
    local slot = Fields.ResolveLegacySlot(zone, index)
    if not slot then return { ok = false, reason = 'invalid_slot' } end
    local field = active[slot.fieldId]
    if not has(field.allowedCrops, cropType) then return { ok = false, reason = 'crop_not_allowed' } end
    local access, reason = Reservations.ResolveAccess(source, field.id, 'plant')
    if not access then return { ok = false, reason = reason } end
    access.ok, access.legacy, access.field, access.slot = true, false, field, slot
    return access
end

function Fields.ResolveCropAccess(source, record, action)
    local data = record and record.data or {}
    local fieldId = data.fieldId
    if not fieldId then return { ok = false, reason = 'reservation_required' } end
    local access, reason = Reservations.ResolveAccess(source, fieldId, action, record)
    if not access then return { ok = false, reason = reason } end
    access.ok, access.legacy, access.field = true, false, active[fieldId]
    access.slot = access.field and access.field.slotMap[data.slotId] or nil
    return access
end

function Fields.RecordOperation(source, record, action, access, payload)
    if not access or not access.reservationId then return false end
    local identifier = Bridge.GetIdentifier(source)
    if not identifier then return false end
    local operationId = payload and payload.operationId or Sonar.Utils.Uuid()
    local affected = MySQL.update.await([[INSERT IGNORE INTO sfpj_field_events
        (id,field_id,reservation_id,actor_identifier,event_type,crop_id,row_id,slot_id,payload)
        VALUES (?,?,?,?,?,?,?,?,?)]], { operationId, access.field.id, access.reservationId, identifier,
        action, record and record.id, record and record.data and record.data.rowId,
        record and record.data and record.data.slotId, encode(payload) })
    if tonumber(affected) ~= 1 then return false end
    local xp = 0
    if action == Sonar.Constants.ACTIONS.PLANT then xp = Config.Progression.PlantXp
    elseif action == Sonar.Constants.ACTIONS.HARVEST and not (payload and payload.deadCropCleared) then
        xp = Progression.HarvestXp(record.crop_type, payload and payload.tier or 'standard')
    elseif payload and payload.changed == true then xp = Config.Progression.EffectiveCareXp end
    if xp > 0 then Progression.Award(identifier, operationId .. ':xp', action, record.id, xp, payload) end
    if action == Sonar.Constants.ACTIONS.HARVEST then Reservations.OnCropRemoved(access.reservationId) end
    return true
end

function Fields.PrepareHarvestProduct(source, record, units, metadata, access)
    local identifier = Bridge.GetIdentifier(source)
    metadata = metadata or {}
    metadata.producer = identifier
    metadata.reservationId = access.reservationId
    metadata.fieldId = access.field.id
    metadata.operationId = metadata.operationId or Sonar.Utils.Uuid()
    metadata.resource = Sonar.Constants.RESOURCE
    return { metadata = metadata, units = units, operationId = metadata.operationId }
end
function Fields.CancelHarvestProduct() return true end
function Fields.FinalizeHarvestProduct() return true end

function Fields.LoadOverview(source)
    local actor, reason = PublicJob.Guard(source)
    if not actor then return nil, reason end
    local progression = Progression.Get(actor.identifier)
    local reservation = Reservations.GetForPlayer(actor.identifier)
    local rows = {}
    for _, field in pairs(active) do
        if field.catalogVisible or Config.Debug then
            local claim = Reservations.GetByField(field.id)
            rows[#rows + 1] = { id = field.id, name = field.name, location = field.location,
                region = field.region, sizeClass = field.sizeClass, slotCount = #field.slots,
                available = claim == nil, expiresAt = claim and tonumber(claim.expires_at) or nil,
                requiredLevel = Config.Progression.FieldSizeLevels[field.sizeClass] or 1,
                rentPlans = Reservations.PricePlans(field.sizeClass, progression.level) }
        end
    end
    table.sort(rows, function(a, b) return a.region == b.region and a.sizeClass < b.sizeClass or a.region < b.region end)
    return { fields = rows, reservation = reservation, progression = progression,
        bankBalance = tonumber(Bridge.GetMoney(source, 'bank')) or 0 }
end

function Fields.LoadDetail(source, fieldId)
    local overview, reason = Fields.LoadOverview(source)
    if not overview then return nil, reason end
    local field = Fields.Get(fieldId)
    if not field or (not field.catalogVisible and not Config.Debug) then return nil, 'field_not_found' end
    local claim = Reservations.GetByField(field.id)
    local ownReservation = overview.reservation and claim and overview.reservation.id == claim.id
        and overview.reservation or nil
    local rentPlans = Reservations.PricePlans(field.sizeClass, overview.progression.level,
        ownReservation and ownReservation.status == 'grace')
    local timestamp = Sonar.Time.Now()
    local extensionBase = ownReservation and math.max(timestamp, tonumber(ownReservation.expiresAt) or timestamp)
        or timestamp
    for _, plan in ipairs(rentPlans) do
        local allowed, resultingExpiry = Sonar.Rentals.CanExtend(extensionBase, timestamp, plan.hours)
        plan.resultingExpiresAt = resultingExpiry
        plan.available = not ownReservation or allowed
    end
    return { field = { id = field.id, name = field.name, location = field.location, region = field.region,
        sizeClass = field.sizeClass, access = field.access, rows = field.rows, slots = field.slots,
        slotCount = #field.slots, requiredLevel = Config.Progression.FieldSizeLevels[field.sizeClass] or 1,
        allowedCrops = field.allowedCrops, available = claim == nil,
        expiresAt = claim and tonumber(claim.expires_at) or nil }, reservation = overview.reservation,
        progression = overview.progression, rentPlans = rentPlans, bankBalance = overview.bankBalance }
end

function Fields.BroadcastInvalidate(fieldId, reason)
    if HubRuntime and HubRuntime.BroadcastInvalidate then
        HubRuntime.BroadcastInvalidate({ scope = 'field', fieldId = fieldId, reason = reason })
    else
        for source, subscription in pairs(subscribers) do
            if subscription.fieldId == fieldId then
                TriggerClientEvent('sonar_farm_publicjob:hubInvalidate', source,
                    { scope = 'field', fieldId = fieldId, reason = reason })
            end
        end
    end
end
function Fields.Subscribe(source, fieldId, afterSequence)
    if not active[fieldId] then return false end
    subscribers[source] = { fieldId = fieldId, afterSequence = tonumber(afterSequence) or 0 }
    return true
end
function Fields.Unsubscribe(source) subscribers[source] = nil end
AddEventHandler('playerDropped', function() Fields.Unsubscribe(source) end)
