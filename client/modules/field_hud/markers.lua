-- Cached full-Field slot classification and lightweight projected sprite draw.

FieldMarkers = FieldMarkers or {}

local authority, markerCache, prioritySlot = nil, {}, nil
local mapBlips = {}
local textureDictionary, textureName = 'sfpj_field_hud', Config.FieldHud.MarkerTexture or 'slot_marker'
local COLORS = {
    empty = { 232, 226, 204 }, healthy = { 121, 168, 77 }, care = { 239, 183, 44 },
    critical = { 228, 91, 49 }, ready = { 255, 205, 42 }, blocked = { 116, 119, 112 },
}
local BLIP_COLORS = { empty = 0, healthy = 2, care = 5, critical = 1, ready = 46, blocked = 40 }

local function clearMapBlips()
    for key, entry in pairs(mapBlips) do
        if entry.handle and DoesBlipExist(entry.handle) then RemoveBlip(entry.handle) end
        mapBlips[key] = nil
    end
end

local function mapLabel(marker)
    local row = marker.rowId and tostring(marker.rowId) or 'Row'
    return ('Reserved Field - %s / Slot %s - %s'):format(row, tostring(marker.index or marker.id), marker.action)
end

local function syncMapBlips()
    if not Config.FieldHud.MapBlipsEnabled then
        clearMapBlips()
        return
    end

    local wanted = {}
    for _, marker in ipairs(markerCache) do
        local key = tostring(marker.id or ('%s:%s'):format(marker.zone, marker.index))
        wanted[key] = true
        local selected = prioritySlot and prioritySlot.id == marker.id
        local entry = mapBlips[key]
        if not entry or not DoesBlipExist(entry.handle) then
            local handle = AddBlipForCoord(marker.x + 0.0, marker.y + 0.0, marker.z + 0.0)
            SetBlipSprite(handle, Config.FieldHud.MapBlipSprite or 1)
            SetBlipDisplay(handle, 2)
            SetBlipAsShortRange(handle, Config.FieldHud.MapBlipShortRange == true)
            SetBlipAlpha(handle, Config.FieldHud.MapBlipAlpha or 190)
            entry = { handle = handle }
            mapBlips[key] = entry
        end

        if entry.kind ~= marker.kind then
            SetBlipColour(entry.handle, BLIP_COLORS[marker.kind] or BLIP_COLORS.blocked)
            entry.kind = marker.kind
        end
        if entry.action ~= marker.action then
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName(mapLabel(marker))
            EndTextCommandSetBlipName(entry.handle)
            entry.action = marker.action
        end
        if entry.selected ~= selected then
            SetBlipScale(entry.handle, selected
                and (Config.FieldHud.MapBlipPriorityScale or 0.32)
                or (Config.FieldHud.MapBlipScale or 0.26))
            entry.selected = selected
        end
    end

    for key, entry in pairs(mapBlips) do
        if not wanted[key] then
            if entry.handle and DoesBlipExist(entry.handle) then RemoveBlip(entry.handle) end
            mapBlips[key] = nil
        end
    end
end

function FieldMarkers.SetState(state)
    local previousField = authority and authority.field and authority.field.id
    local nextField = state and state.field and state.field.id
    if previousField and previousField ~= nextField then
        markerCache, prioritySlot = {}, nil
        clearMapBlips()
    end
    authority = state
end
function FieldMarkers.Clear()
    authority, markerCache, prioritySlot = nil, {}, nil
    clearMapBlips()
end

function FieldMarkers.Snapshot()
    local counts = { empty = 0, healthy = 0, care = 0, critical = 0, ready = 0, blocked = 0, own = 0 }
    for _, marker in ipairs(markerCache) do
        counts[marker.kind] = (counts[marker.kind] or 0) + 1
        if marker.isMine then counts.own = counts.own + 1 end
    end
    return { counts = counts, priority = prioritySlot, streamedSlots = #markerCache }
end

local function rebuild()
    markerCache, prioritySlot = {}, nil
    if not authority or not authority.field then return end
    local field = Slots.HudSnapshot()[authority.field.id]
    if not field then
        syncMapBlips()
        return
    end
    local coords = GetEntityCoords(PlayerPedId())
    local allowed = authority.access and authority.access.allowed == true
    local entries = {}
    for _, slot in ipairs(field.slots or {}) do
        local crop = Crops.HudState(slot.zone, slot.index)
        local memberAccess = allowed and (field.memberStatus == 'active'
            or field.memberStatus == 'departing' and crop and crop.isMine)
        local classification = Sonar.FieldHud.Classify({
            occupied = crop ~= nil, accessAllowed = memberAccess,
            memberStatus = field.memberStatus, reservationStatus = field.reservationStatus,
            state = crop and crop.state, isMine = crop and crop.isMine, progress = crop and crop.progress,
            health = crop and crop.health, water = crop and crop.water, nutrients = crop and crop.nutrients,
            weeds = crop and crop.weeds, pests = crop and crop.pests,
            optimalMin = crop and crop.optimalMin, optimalMax = crop and crop.optimalMax,
        })
        local dx, dy, dz = coords.x - slot.x, coords.y - slot.y, coords.z - slot.z
        local entry = {
            id = slot.id, rowId = slot.rowId, index = slot.index, zone = slot.zone,
            x = slot.x, y = slot.y, z = slot.z,
            drawZ = slot.z + Config.FieldHud.MarkerHeight,
            distance = math.sqrt(dx * dx + dy * dy + dz * dz), kind = classification.kind,
            action = classification.action, priority = classification.priority,
            isMine = crop and crop.isMine or false,
        }
        markerCache[#markerCache + 1], entries[#entries + 1] = entry, entry
    end
    prioritySlot = Sonar.FieldHud.Prioritize(entries)
    syncMapBlips()
end

CreateThread(function()
    while true do
        if authority then rebuild() end
        Wait(Config.FieldHud.ClassificationMs)
    end
end)

CreateThread(function()
    local txd = CreateRuntimeTxd(textureDictionary)
    CreateRuntimeTextureFromImage(txd, textureName, 'world/slot-marker.png')
    while true do
        if authority and #markerCache > 0 and GetInteriorFromEntity(PlayerPedId()) == 0 then
            local coords = GetEntityCoords(PlayerPedId())
            local maxDistance = Config.FieldHud.MarkerMaxDistance
            local maxDistanceSquared = maxDistance * maxDistance
            local priorityId = prioritySlot and prioritySlot.id
            for _, marker in ipairs(markerCache) do
                local dx, dy, dz = coords.x - marker.x, coords.y - marker.y, coords.z - marker.z
                local distanceSquared = dx * dx + dy * dy + dz * dz
                if distanceSquared <= maxDistanceSquared then
                    local visible, sx, sy = GetScreenCoordFromWorldCoord(marker.x, marker.y, marker.drawZ)
                    if visible then
                        local distance = math.sqrt(distanceSquared)
                        local ratio = math.max(0, math.min(1, distance / maxDistance))
                        local scale = Config.FieldHud.MarkerMaxScale
                            - (Config.FieldHud.MarkerMaxScale - Config.FieldHud.MarkerMinScale) * ratio
                        local selected = priorityId == marker.id
                        if selected then
                            scale = math.min(scale * (Config.FieldHud.MarkerPriorityScale or 1.22), 0.036)
                        end
                        local alpha = math.floor(Config.FieldHud.MarkerMaxAlpha
                            - (Config.FieldHud.MarkerMaxAlpha - Config.FieldHud.MarkerMinAlpha) * ratio)
                        local color = COLORS[marker.kind] or COLORS.blocked
                        if selected or not Config.FieldHud.MarkerGroundOnlyPriority then
                            local groundScale = Config.FieldHud.MarkerGroundScale or 0.58
                            DrawMarker(27, marker.x, marker.y, marker.z + 0.05, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                                groundScale, groundScale, groundScale, color[1], color[2], color[3],
                                math.min(180, alpha), false, false, 2, nil, nil, false)
                        end
                        DrawSprite(textureDictionary, textureName, sx, sy, scale, scale * 1.7778,
                            0.0, color[1], color[2], color[3], alpha)
                    end
                end
            end
            Wait(0)
        else Wait(400) end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then FieldMarkers.Clear() end
end)
