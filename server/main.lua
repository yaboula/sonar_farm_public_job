-- Sonar Farm Public Job bootstrap.

local REQUIRED = { 'qb-core', 'ox_lib', 'ox_inventory', 'ox_target', 'oxmysql' }
local engineReady = false

local function dependenciesReady()
    local missing = {}
    for _, resource in ipairs(REQUIRED) do if GetResourceState(resource) ~= 'started' then missing[#missing + 1] = resource end end
    if #missing > 0 then Logger.Warn('Missing required resources: ' .. table.concat(missing, ', '), 'boot'); return false end
    return true
end

CreateThread(function()
    Runtime.SetStatus(Runtime.STATUS.BOOTING)
    local valid, errors, warnings = pcall(Sonar.ConfigValidation.Validate)
    if not valid then Runtime.SetStatus(Runtime.STATUS.FAILED, 'invalid_config'); Logger.Warn(tostring(errors), 'boot'); return end
    for _, warning in ipairs(warnings or {}) do Logger.Warn(warning, 'config') end
    if #errors > 0 then
        for _, error in ipairs(errors) do Logger.Warn(error, 'config') end
        Runtime.SetStatus(Runtime.STATUS.FAILED, 'invalid_config'); return
    end
    Sonar.Utils.SeedRandom(os.time(), GetGameTimer())
    if not dependenciesReady() or not Bridge.Init() then Runtime.SetStatus(Runtime.STATUS.FAILED, 'dependencies'); return end
    if not Database.Init() or not PublicJobDatabase.Init() then Runtime.SetStatus(Runtime.STATUS.FAILED, 'database'); return end
    if not Fields.Init() then Runtime.SetStatus(Runtime.STATUS.FAILED, 'fields'); return end
    local loadedOk, loaded = State.LoadAll()
    if not loadedOk then Runtime.SetStatus(Runtime.STATUS.FAILED, 'state_load'); Logger.Warn(tostring(loaded), 'boot'); return end
    if not Reservations.Init() or not Market.Init() then Runtime.SetStatus(Runtime.STATUS.FAILED, 'services'); return end
    exports.ox_inventory:registerHook('swapItems', function(payload)
        local item = payload.fromSlot and payload.fromSlot.name
        if item ~= Config.Market.TabletItem or payload.fromInventory == payload.toInventory then return true end
        local target = tonumber(payload.toInventory)
        if target and Bridge.Inventory.HasItem(target, Config.Market.TabletItem, 1) then return false end
        return true
    end, { itemFilter = { [Config.Market.TabletItem] = true } })
    engineReady = true
    Runtime.SetStatus(Runtime.STATUS.READY)
    TriggerClientEvent(Sonar.Constants.EVENTS.BRIDGE_READY, -1, Bridge.Framework)
    TriggerClientEvent(Sonar.Constants.EVENTS.RUNTIME_READY, -1)
    Logger.Info(('Sonar Farm Public Job ready (%d crops loaded).'):format(tonumber(loaded) or 0), 'boot')

    CreateThread(function()
        while true do Wait((Config.SaveInterval or 60) * 1000); State.Flush() end
    end)
    CreateThread(function()
        while true do
            Wait(math.max(5, Config.Reservations.WorkerSeconds) * 1000)
            Reservations.Tick(); Market.Restock(); Sell.Reconcile()
        end
    end)
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= Sonar.Constants.RESOURCE then return end
    Runtime.SetStatus(Runtime.STATUS.STOPPING)
    if engineReady then State.FlushSync() end
end)

RegisterNetEvent(Sonar.Constants.EVENTS.BRIDGE_READY, function()
    if Bridge.Ready then TriggerClientEvent(Sonar.Constants.EVENTS.BRIDGE_READY, source, Bridge.Framework) end
end)
