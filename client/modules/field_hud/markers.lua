-- Cached full-Field slot classification and lightweight projected sprite draw.

FieldMarkers = FieldMarkers or {}

local authority, markerCache, prioritySlot = nil, {}, nil
local textureDictionary, textureName = 'sfpj_field_hud', Config.FieldHud.MarkerTexture or 'slot_marker'
local COLORS = {
    empty = { 232, 226, 204 }, healthy = { 121, 168, 77 }, care = { 239, 183, 44 },
    critical = { 228, 91, 49 }, ready = { 255, 205, 42 }, blocked = { 116, 119, 112 },
}

function FieldMarkers.SetState(state) authority = state end
function FieldMarkers.Clear() authority, markerCache, prioritySlot = nil, {}, nil end

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
    if not field then return end
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
        local entry = {
            id = slot.id, rowId = slot.rowId, index = slot.index, zone = slot.zone,
            x = slot.x, y = slot.y, z = slot.z,
            distance = #(coords - vec3(slot.x, slot.y, slot.z)), kind = classification.kind,
            action = classification.action, priority = classification.priority,
            isMine = crop and crop.isMine or false,
        }
        markerCache[#markerCache + 1], entries[#entries + 1] = entry, entry
    end
    prioritySlot = Sonar.FieldHud.Prioritize(entries)
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
            for _, marker in ipairs(markerCache) do
                local distance = #(coords - vec3(marker.x, marker.y, marker.z))
                if distance <= Config.FieldHud.MarkerMaxDistance then
                    local visible, sx, sy = GetScreenCoordFromWorldCoord(marker.x, marker.y,
                        marker.z + Config.FieldHud.MarkerHeight)
                    if visible then
                        local ratio = math.max(0, math.min(1, distance / Config.FieldHud.MarkerMaxDistance))
                        local scale = Config.FieldHud.MarkerMaxScale
                            - (Config.FieldHud.MarkerMaxScale - Config.FieldHud.MarkerMinScale) * ratio
                        if prioritySlot and prioritySlot.id == marker.id then scale = math.min(scale * 1.32, 0.045) end
                        local alpha = math.floor(Config.FieldHud.MarkerMaxAlpha
                            - (Config.FieldHud.MarkerMaxAlpha - Config.FieldHud.MarkerMinAlpha) * ratio)
                        local color = COLORS[marker.kind] or COLORS.blocked
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
