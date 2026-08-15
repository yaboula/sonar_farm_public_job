-- Field Operations HUD presentation rules (shared and pure).
-- These classifications never authorize gameplay; server callbacks remain final.

Sonar = Sonar or {}

local FieldHud = {}

FieldHud.KIND = {
    EMPTY = 'empty', HEALTHY = 'healthy', CARE = 'care', CRITICAL = 'critical',
    READY = 'ready', BLOCKED = 'blocked',
}

local rank = { ready = 1, critical = 2, care = 3, empty = 4, healthy = 5, blocked = 6 }

local function number(value, fallback)
    value = tonumber(value)
    return value ~= nil and value or fallback
end

function FieldHud.Classify(input)
    input = input or {}
    local occupied = input.occupied == true
    local access = input.accessAllowed == true
        and (input.memberStatus == 'active' or input.memberStatus == 'departing')
        and (input.reservationStatus == 'active' or input.reservationStatus == 'grace')

    if not access then
        return { kind = FieldHud.KIND.BLOCKED, action = 'Unavailable', priority = rank.blocked }
    end
    if not occupied then
        if input.memberStatus ~= 'active' or input.reservationStatus ~= 'active' then
            return { kind = FieldHud.KIND.BLOCKED, action = 'Planting blocked', priority = rank.blocked }
        end
        return { kind = FieldHud.KIND.EMPTY, action = 'Plant', priority = rank.empty }
    end

    local state = tostring(input.state or '')
    local progress = number(input.progress, 0)
    if state == 'dead' or state == 'withered' then
        return { kind = FieldHud.KIND.CRITICAL, action = input.isMine and 'Clear crop' or 'Urgent', priority = rank.critical }
    end
    if input.isMine == true and (progress >= 1 or state == 'mature') then
        return { kind = FieldHud.KIND.READY, action = 'Harvest', priority = rank.ready }
    end

    local health = number(input.health, 100)
    local water = number(input.water, 100)
    local nutrients = input.nutrients ~= nil and number(input.nutrients, 100) or nil
    local weeds = input.weeds ~= nil and number(input.weeds, 0) or nil
    local pests = input.pests ~= nil and number(input.pests, 0) or nil
    local optimalMin = number(input.optimalMin, 40)
    local optimalMax = number(input.optimalMax, 80)
    local critical = health < 60 or water < 35
        or nutrients ~= nil and (nutrients < optimalMin - 20 or nutrients > optimalMax + 20)
        or weeds ~= nil and weeds > 50 or pests ~= nil and pests > 50
    if critical then
        return { kind = FieldHud.KIND.CRITICAL, action = 'Care now', priority = rank.critical }
    end

    local care = water < 60 or nutrients ~= nil and (nutrients < optimalMin or nutrients > optimalMax)
        or weeds ~= nil and weeds > 20 or pests ~= nil and pests > 20
    if care then
        local action = water < 60 and 'Water'
            or nutrients ~= nil and nutrients < optimalMin and 'Fertilize'
            or weeds ~= nil and weeds > 20 and 'Remove weeds'
            or pests ~= nil and pests > 20 and 'Treat pests' or 'Inspect'
        return { kind = FieldHud.KIND.CARE, action = action, priority = rank.care }
    end

    return { kind = FieldHud.KIND.HEALTHY, action = 'Maintain', priority = rank.healthy }
end

function FieldHud.Prioritize(entries)
    local best
    for _, entry in ipairs(entries or {}) do
        if not best or number(entry.priority, 99) < number(best.priority, 99)
            or number(entry.priority, 99) == number(best.priority, 99)
                and number(entry.distance, math.huge) < number(best.distance, math.huge) then
            best = entry
        end
    end
    return best
end

function FieldHud.BuildPayload(field, link, snapshot, access)
    local memberCount = 0
    for _, member in ipairs(snapshot.members or {}) do
        if member.status == 'active' or member.status == 'departing' then memberCount = memberCount + 1 end
    end
    return {
        version = 1,
        access = access,
        field = {
            id = field.id, name = field.name, location = field.location, region = field.region,
            sizeClass = field.sizeClass, slotCount = #(field.slots or {}), access = field.access,
        },
        reservation = {
            id = snapshot.id, fieldId = field.id, role = link.role,
            memberStatus = link.status, status = snapshot.status,
            expiresAt = snapshot.expiresAt, graceUntil = snapshot.graceUntil,
            isOwner = snapshot.isOwner, memberCount = memberCount,
            liveCrops = snapshot.liveCrops, ownCrops = snapshot.ownCrops,
        },
    }
end

Sonar.FieldHud = FieldHud
