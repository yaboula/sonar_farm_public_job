-- Secure NUI boundary for Today, Fields, Market and Sell.

HubRuntime = HubRuntime or {}
local sessions, CALLBACKS = {}, Sonar.Constants.CALLBACKS

local function within(source, point, radius)
    local ped = GetPlayerPed(source)
    if not ped or ped <= 0 then return false end
    return Sonar.Utils.IsWithin(GetEntityCoords(ped), point, radius)
end

local function findMarket(id)
    for _, market in ipairs(Config.Market.Markets or {}) do if market.id == id then return market end end
end

local function authorizeSurface(source, session)
    if session.surface == 'tablet' then
        return Bridge.Inventory.HasItem(source, Config.Market.TabletItem, 1) or false, 'tablet_required'
    elseif session.surface == 'market' then
        local market = findMarket(session.marketId)
        return market and within(source, market.coords, Config.Market.InteractionDistance + (market.radius or 0)), 'presence_required'
    elseif session.surface == 'sell' then
        return within(source, Config.Sell.Buyer.coords, Config.Sell.InteractionDistance + (Config.Sell.Buyer.radius or 0)), 'presence_required'
    end
    return false, 'invalid_surface'
end

local function context(session, actor)
    local progress = Progression.Get(actor.identifier)
    return { actorId = actor.identifier, actorName = actor.name, role = 'farmer', surface = session.surface,
        presence = session.presence, marketId = session.marketId, nonce = session.nonce,
        serverTime = Sonar.Time.Now(), locale = 'en', routes = { 'today', 'fields', 'market', 'sell' },
        progression = progress, capabilities = { reserveFields = true, manageCoop = true,
            purchase = true, confirmSell = session.surface == 'sell' } }
end

function HubRuntime.Validate(source, nonce)
    local session = sessions[source]
    if not session or session.nonce ~= nonce then return nil, 'invalid_session' end
    if session.expiresAt <= Sonar.Time.Now() then sessions[source] = nil; Fields.Unsubscribe(source); return nil, 'session_expired' end
    local actor, reason = PublicJob.Guard(source)
    if not actor then return nil, reason end
    local allowed, surfaceReason = authorizeSurface(source, session)
    if not allowed then return nil, surfaceReason end
    session.expiresAt = Sonar.Time.Now() + Config.Market.SessionTtlSeconds
    return session, nil, actor
end

function HubRuntime.Invalidate(source, payload)
    if sessions[source] then
        TriggerClientEvent('sonar_farm_publicjob:hubInvalidate', source, payload or { scope = 'hub' })
    end
end

function HubRuntime.BroadcastInvalidate(payload)
    for source in pairs(sessions) do HubRuntime.Invalidate(source, payload) end
end

local function today(source, actor)
    local progress, reservation = Progression.Get(actor.identifier), Reservations.GetForPlayer(actor.identifier)
    local ownCrops = 0
    for _, crop in pairs(State.crops or {}) do if crop.owner == actor.identifier then ownCrops = ownCrops + 1 end end
    local market, sell = Market.Load(source), Sell.Load(source)
    return { progression = progress, reservation = reservation, ownCrops = ownCrops,
        marketStock = market and market.stock or {}, sellableGroups = sell and sell.groups or {},
        nextUnlock = progress.level < 4 and { level = 4, label = 'Plus products' }
            or progress.level < 5 and { level = 5, label = 'Medium Fields' }
            or progress.level < 8 and { level = 8, label = 'Pro products' }
            or progress.level < 10 and { level = 10, label = 'Large Fields' }
            or progress.level < 15 and { level = 15, label = '18% rent discount and 11% Sell bonus' }
            or progress.level < 20 and { level = 20, label = '25% rent discount and 15% Sell bonus' } or nil }
end

lib.callback.register(CALLBACKS.HUB_OPEN, function(source, payload)
    local runtime = Runtime.GuardPlayer(source)
    if not runtime.ok then return runtime end
    local actor, reason = PublicJob.Guard(source)
    if not actor then return { ok = false, reason = reason } end
    payload = payload or {}
    local surface = tostring(payload.surface or 'tablet')
    if surface ~= 'tablet' and surface ~= 'market' and surface ~= 'sell' then return { ok = false, reason = 'invalid_surface' } end
    local session = { nonce = Sonar.Utils.Uuid(), surface = surface,
        presence = surface == 'tablet' and 'remote' or surface, marketId = payload.marketId,
        expiresAt = Sonar.Time.Now() + Config.Market.SessionTtlSeconds }
    local allowed, surfaceReason = authorizeSurface(source, session)
    if not allowed then return { ok = false, reason = surfaceReason } end
    sessions[source] = session
    return { ok = true, data = context(session, actor) }
end)

lib.callback.register(CALLBACKS.HUB_LOAD, function(source, payload)
    payload = payload or {}
    local session, reason, actor = HubRuntime.Validate(source, payload.nonce)
    if not session then return { ok = false, reason = reason } end
    local request, data, dataReason = payload.request or {}
    if request.kind == 'hub' and request.route == 'today' then data = today(source, actor)
    elseif request.kind == 'hub' and request.route == 'fields' or request.kind == 'fieldsOverview' then data, dataReason = Fields.LoadOverview(source)
    elseif request.kind == 'fieldDetail' then data, dataReason = Fields.LoadDetail(source, request.fieldId)
    elseif request.kind == 'hub' and request.route == 'market' then data, dataReason = Market.Load(source)
    elseif request.kind == 'hub' and request.route == 'sell' then data, dataReason = Sell.Load(source)
    elseif request.kind == 'sellPreview' then data, dataReason = Sell.Preview(source, request.selections, request.sellAll)
    elseif request.kind == 'inviteCandidates' then data, dataReason = Reservations.InviteCandidates(source)
    else return { ok = true, data = { request = request, state = 'unavailable' } } end
    if not data then return { ok = true, data = { request = request,
        state = (dataReason == 'job_required' or dataReason == 'duty_required') and 'restricted' or 'unavailable', reason = dataReason } } end
    return { ok = true, data = { request = request, state = 'ready', data = data } }
end)

lib.callback.register(CALLBACKS.HUB_DISPATCH, function(source, payload)
    payload = payload or {}
    local session, reason = HubRuntime.Validate(source, payload.nonce)
    if not session then return { ok = false, reason = reason } end
    local intent = payload.intent or {}
    if intent.type == 'field.reserve' then return Reservations.Reserve(source, intent.fieldId, intent.hours, intent.operationId)
    elseif intent.type == 'field.extend' then return Reservations.Extend(source, intent.hours, intent.operationId)
    elseif intent.type == 'field.release' then return Reservations.Release(source, intent.confirmed)
    elseif intent.type == 'coop.invite' then return Reservations.Invite(source, intent.targetSource)
    elseif intent.type == 'coop.accept' then return Reservations.Accept(source, intent.inviteId)
    elseif intent.type == 'coop.leave' then return Reservations.Leave(source)
    elseif intent.type == 'coop.revoke' then return Reservations.Revoke(source, intent.identifier)
    elseif intent.type == 'market.purchase' then
        intent.input = intent.input or {}
        intent.input.physical = session.surface == 'market'
        intent.input.marketId = session.marketId
        return Market.Purchase(source, intent.input)
    elseif intent.type == 'sell.confirm' then
        if session.surface ~= 'sell' then return { ok = false, reason = 'presence_required' } end
        return Sell.Confirm(source, intent.input)
    elseif intent.type == 'field.setRoute' then
        local field = Fields.Get(intent.fieldId)
        return field and { ok = true, closeSurface = true, route = field.access } or { ok = false, reason = 'field_not_found' }
    elseif intent.type == 'market.setRoute' then
        local market = findMarket(intent.marketId or 'grapeseed')
        return market and { ok = true, closeSurface = true, route = market.coords } or { ok = false, reason = 'market_not_found' }
    elseif intent.type == 'sell.setRoute' then return { ok = true, closeSurface = true, route = Config.Sell.Buyer.coords } end
    return { ok = false, reason = 'unsupported_intent' }
end)

lib.callback.register(CALLBACKS.HUB_SUBSCRIBE_FIELD, function(source, payload)
    local session, reason = HubRuntime.Validate(source, payload and payload.nonce)
    if not session then return { ok = false, reason = reason } end
    return { ok = Fields.Subscribe(source, tostring(payload.fieldId or ''), payload.afterSequence) }
end)
lib.callback.register(CALLBACKS.HUB_CLOSE, function(source, payload)
    if not payload or sessions[source] and sessions[source].nonce == payload.nonce then sessions[source] = nil end
    Fields.Unsubscribe(source); return { ok = true }
end)
AddEventHandler('playerDropped', function() sessions[source] = nil; Fields.Unsubscribe(source) end)
