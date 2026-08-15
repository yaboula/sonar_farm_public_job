-- Public Job Hub lifecycle, physical NPCs and tablet entrypoint.

Hub = Hub or {}
local CALLBACKS, active = Sonar.Constants.CALLBACKS, nil
local entities = {}
local function reply(callback, value) if callback then callback(value or { ok = true }) end end

function Hub.Close()
    if active then lib.callback.await(CALLBACKS.HUB_CLOSE, false, { nonce = active.nonce }) end
    active = nil; SendNUIMessage({ type = 'hub:close' }); SetNuiFocus(false, false); SetNuiFocusKeepInput(false)
end

function Hub.Open(surface, presence, marketId)
    local feedbackActive = type(GameplayFeedback) == 'table'
        and type(GameplayFeedback.IsActive) == 'function'
        and GameplayFeedback.IsActive()
    if active or Minigame.IsActive() or feedbackActive then return end
    if Inspection and Inspection.IsActive() then Inspection.Close('hub_open') end
    local response = lib.callback.await(CALLBACKS.HUB_OPEN, false,
        { surface = surface, presence = presence, marketId = marketId })
    if not response or not response.ok then return Bridge.Notify(response and response.reason or 'hub_unavailable', 'error') end
    active = response.data; SetNuiFocus(true, true); SetNuiFocusKeepInput(false)
    SendNUIMessage({ type = 'hub:open', payload = active })
end
function Hub.IsActive() return active ~= nil end

RegisterNUICallback('hub:bootstrap', function(_, cb) reply(cb, active and { ok = true, data = active } or { ok = false, reason = 'invalid_session' }) end)
RegisterNUICallback('hub:load', function(data, cb)
    if not active then return reply(cb, { ok = false, reason = 'invalid_session' }) end
    reply(cb, lib.callback.await(CALLBACKS.HUB_LOAD, false, { nonce = active.nonce, request = data and data.request }))
end)
RegisterNUICallback('hub:dispatch', function(data, cb)
    if not active then return reply(cb, { ok = false, reason = 'invalid_session' }) end
    local intent = data and data.intent or {}
    local response = lib.callback.await(CALLBACKS.HUB_DISPATCH, false, { nonce = active.nonce, intent = intent })
    if response and response.route then SetNewWaypoint(response.route.x + 0.0, response.route.y + 0.0) end
    if response and response.ok and (intent.type == 'field.reserve' or intent.type == 'field.extend'
        or intent.type == 'field.release' or intent.type == 'coop.accept' or intent.type == 'coop.leave'
        or intent.type == 'coop.revoke') then Sync.RefreshNow() end
    reply(cb, response); if response and response.closeSurface then Hub.Close() end
end)
RegisterNUICallback('hub:subscribeField', function(data, cb)
    reply(cb, active and lib.callback.await(CALLBACKS.HUB_SUBSCRIBE_FIELD, false,
        { nonce = active.nonce, fieldId = data and data.fieldId, afterSequence = data and data.afterSequence })
        or { ok = false, reason = 'invalid_session' })
end)
RegisterNUICallback('hub:unsubscribeField', function(_, cb) reply(cb, { ok = true }) end)
RegisterNUICallback('hub:close', function(_, cb) reply(cb); Hub.Close() end)

RegisterNetEvent('sonar_farm_publicjob:hubInvalidate', function(payload)
    if active then SendNUIMessage({ type = 'hub:invalidate', payload = payload }) end
    if payload and (payload.scope == 'field' or payload.scope == 'reservation' or payload.scope == 'coop') then
        Sync.RefreshNow()
    end
end)
RegisterNetEvent('sonar_farm_publicjob:reservationInvite', function(invite)
    local result = lib.alertDialog({ header = 'Field co-op invitation',
        content = ('%s invited you to collaborate on a public Field.'):format(invite.inviter),
        centered = true, cancel = true, labels = { confirm = 'Accept', cancel = 'Decline' } })
    if result == 'confirm' then
        local response = lib.callback.await('sonar_farm_publicjob:reservation:accept', false, invite.id)
        if response and response.ok then Sync.RefreshNow() end
        Bridge.Notify(response and response.ok and 'Field invitation accepted.' or response and response.reason or 'Invitation failed.',
            response and response.ok and 'success' or 'error')
    end
end)

local function spawnNpc(definition, option)
    local model = joaat(definition.ped); lib.requestModel(model)
    local ped = CreatePed(0, model, definition.coords.x, definition.coords.y, definition.coords.z - 1.0,
        definition.heading or 0.0, false, false)
    SetEntityInvincible(ped, true); FreezeEntityPosition(ped, true); SetBlockingOfNonTemporaryEvents(ped, true)
    Bridge.Target.AddLocalEntity(ped, { option }); entities[#entities + 1] = ped; SetModelAsNoLongerNeeded(model)
end

CreateThread(function()
    for _, market in ipairs(Config.Market.Markets or {}) do
        spawnNpc(market, { name = 'sonar_farm_publicjob:market:' .. market.id, label = 'Open ' .. market.label,
            icon = 'fa-solid fa-basket-shopping', distance = Config.Market.InteractionDistance,
            onSelect = function() Hub.Open('market', 'market', market.id) end })
    end
    spawnNpc(Config.Sell.Buyer, { name = 'sonar_farm_publicjob:sell', label = 'Sell produce',
        icon = 'fa-solid fa-scale-balanced', distance = Config.Sell.InteractionDistance,
        onSelect = function() Hub.Open('sell', 'sell') end })
end)

exports('openTablet', function() Hub.Open('tablet', 'remote') end)
RegisterCommand(Config.Market.TabletCommand, function() Hub.Open('tablet', 'remote') end, false)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for _, ped in ipairs(entities) do Bridge.Target.RemoveLocalEntity(ped); DeleteEntity(ped) end
    if active then Hub.Close() end
end)
