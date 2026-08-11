-- Authoritative personal item selection, progression gates and tool wear.

Items = Items or {}
local REJECT = Sonar.Constants.REJECT

local function effectFor(item) return item.tool or item.consumable end
local function actionFor(item) local effect = effectFor(item); return effect and effect.action end
local function tierAllowed(source, tier)
    if not Progression or not Progression.CanUseTier then return true end
    return Progression.CanUseTier(Bridge.GetIdentifier(source), tier or 'basic')
end
local function durabilityOf(slot)
    return Sonar.Utils.Clamp(slot and slot.metadata and tonumber(slot.metadata.durability) or 100, 0, 100)
end
local function usableSlots(source, item)
    local result = {}
    for _, slot in pairs(Bridge.Inventory.GetSlotsWithItem(source, item.id) or {}) do
        if not item.tool or durabilityOf(slot) > 0 then result[#result + 1] = slot end
    end
    table.sort(result, function(a, b)
        local left, right = durabilityOf(a), durabilityOf(b)
        return left == right and (tonumber(a.slot) or 0) < (tonumber(b.slot) or 0) or left < right
    end)
    return result
end

function Items.Get(itemId) return type(itemId) == 'string' and Sonar.ItemCatalog.byId[itemId] or nil end

function Items.Resolve(source, action, itemId)
    local item = Items.Get(itemId)
    if not item or actionFor(item) ~= action then return nil, REJECT.MISSING_TOOL end
    local allowed = tierAllowed(source, item.tier)
    if not allowed then return nil, REJECT.LEVEL_REQUIRED end
    local slots = usableSlots(source, item)
    if #slots == 0 then return nil, REJECT.MISSING_TOOL end
    local slot = slots[1]
    return { definition = item, effect = effectFor(item), slot = tonumber(slot.slot),
        count = tonumber(slot.count) or 1, metadata = slot.metadata or {}, durability = durabilityOf(slot) }
end

function Items.ListForAction(source, action, record)
    local options, identifier = {}, Bridge.GetIdentifier(source)
    for _, item in ipairs(Sonar.ItemCatalog.items) do
        local effect = effectFor(item)
        local allowed = effect and effect.action == action and tierAllowed(source, item.tier)
        if allowed then
            local slots = usableSlots(source, item)
            if #slots > 0 then
                local count, uses = 0, 0
                for _, slot in ipairs(slots) do
                    count = count + (tonumber(slot.count) or 1)
                    uses = uses + (item.tool and math.ceil(durabilityOf(slot) / 100 * item.tool.uses - 0.0001)
                        or (tonumber(slot.count) or 1))
                end
                options[#options + 1] = { id = item.id, label = item.label, tier = item.tier,
                    count = count, usesRemaining = uses, effect = effect,
                    protectionSeconds = record and Sonar.CropClock.ProtectionSeconds(record, effect) or 0,
                    protectionCycleRatio = record and Sonar.CropClock.IsV2(record)
                        and (tonumber(effect.protectionCycleRatio) or 0) or 0,
                    description = item.description }
            end
        end
    end
    table.sort(options, function(a, b) return (Sonar.ItemCatalog.tiers[a.tier] or 0) < (Sonar.ItemCatalog.tiers[b.tier] or 0) end)
    return options
end

function Items.Consume(source, resolved)
    local item = resolved and resolved.definition
    if not item or not resolved.slot then return false, false end
    if item.consumable then
        return Bridge.Inventory.RemoveFromSlot(source, item.id, 1, resolved.slot, resolved.metadata), false
    end
    local remaining = math.max(0, resolved.durability - (100 / item.tool.uses))
    if remaining <= 0.0001 then
        local removed = Bridge.Inventory.RemoveFromSlot(source, item.id, 1, resolved.slot, resolved.metadata)
        return removed, removed
    end
    return Bridge.Inventory.SetDurability(source, resolved.slot, remaining), false
end

function Items.RecordUse() return true end
