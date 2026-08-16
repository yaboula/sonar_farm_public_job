-- Persistent passive HUD and projected slot indicators for the reserved Field.

FieldHud = FieldHud or {}

local CALLBACKS, EVENTS = Sonar.Constants.CALLBACKS, Sonar.Constants.EVENTS
local state, expanded, hidden, refreshing = nil, Config.FieldHud.DefaultExpanded == true, false, false
local currentReservationId = nil
local syncedServerTime, syncedAt, lastSuccessAt = 0, 0, 0

local function now()
    if syncedAt == 0 then return 0 end
    return syncedServerTime + math.floor((GetGameTimer() - syncedAt) / 1000)
end

local function ui(messageType, payload)
    SendNUIMessage({ type = messageType, payload = payload })
end

local function remaining()
    if not state then return 0 end
    local reservation = state.reservation or {}
    local deadline = reservation.status == 'grace' and reservation.graceUntil or reservation.expiresAt
    return math.max(0, (tonumber(deadline) or 0) - now())
end

local function markerSnapshot()
    if FieldMarkers and FieldMarkers.Snapshot then return FieldMarkers.Snapshot() end
    return { counts = { empty = 0, healthy = 0, care = 0, critical = 0,
        ready = 0, blocked = 0, own = 0 }, streamedSlots = 0 }
end

local function nextAction(prioritySlot)
    if not state then return { label = 'Waiting for reservation' } end
    if not state.access.allowed then
        return { label = state.access.reason == Sonar.Constants.REJECT.JOB_REQUIRED and 'Return to the farmer job' or 'Go on duty' }
    end
    if state.reservation.status == 'grace' then return { label = 'Extend or finish harvesting', urgent = true } end
    if prioritySlot then
        return { label = prioritySlot.action, slotId = prioritySlot.id, rowId = prioritySlot.rowId,
            distance = math.floor(prioritySlot.distance * 10 + 0.5) / 10, kind = prioritySlot.kind }
    end
    return { label = 'Move closer to your Field' }
end

local function pushUpdate(messageType, syncState, stale)
    if not state or hidden then return end
    local age = (GetGameTimer() - lastSuccessAt) / 1000
    local markers = markerSnapshot()
    ui(messageType or 'fieldHud:update', {
        state = state, expanded = expanded, position = Config.FieldHud.Position,
        serverNow = now(), remainingSeconds = remaining(), counts = markers.counts,
        nextAction = nextAction(markers.priority), streamedSlots = markers.streamedSlots,
        sync = syncState or (age > Config.FieldHud.StaleSeconds and 'stale' or 'ready'),
        stale = stale == true,
    })
end

local function refresh()
    if refreshing or not Config.FieldHud.Enabled then return end
    refreshing = true
    local wasVisible = state ~= nil
    local response = lib.callback.await(CALLBACKS.FIELD_HUD_STATE, false)
    refreshing = false
    if not response or not response.ok then
        if state and not hidden then pushUpdate('fieldHud:update', 'unavailable', true) end
        return
    end
    syncedServerTime, syncedAt, lastSuccessAt = tonumber(response.serverTime) or 0, GetGameTimer(), GetGameTimer()
    if not response.data then
        state = nil
        currentReservationId = nil
        if FieldMarkers and FieldMarkers.Clear then FieldMarkers.Clear() end
        ui('fieldHud:hide')
        return
    end

    local newResId = response.data.reservation and response.data.reservation.id
    if newResId and newResId ~= currentReservationId then
        currentReservationId = newResId
        hidden = false
    end

    state = response.data
    if FieldMarkers and FieldMarkers.SetState then FieldMarkers.SetState(state) end
    if hidden then
        ui('fieldHud:hide')
    else
        pushUpdate(wasVisible and 'fieldHud:update' or 'fieldHud:show', 'ready', false)
    end
end

function FieldHud.Refresh() CreateThread(refresh) end

local function toggleHide()
    if not state then return end
    hidden = not hidden
    if hidden then
        ui('fieldHud:hide')
    else
        pushUpdate('fieldHud:show', 'ready', false)
    end
end

RegisterCommand(Config.FieldHud.ToggleCommand, function()
    if not state then return end
    if hidden then
        hidden = false
        pushUpdate('fieldHud:show', 'ready', false)
        return
    end
    expanded = not expanded
    ui('fieldHud:mode', { expanded = expanded })
    pushUpdate()
end, false)
RegisterKeyMapping(Config.FieldHud.ToggleCommand, 'Expand Field Operations HUD', 'keyboard', Config.FieldHud.ToggleKey or 'C')

RegisterCommand(Config.FieldHud.HideCommand or 'sfpj_field_hud_hide', function()
    toggleHide()
end, false)
RegisterKeyMapping(Config.FieldHud.HideCommand or 'sfpj_field_hud_hide', 'Hide/Show Field Operations HUD', 'keyboard', Config.FieldHud.HideKey or 'Z')

RegisterNetEvent(EVENTS.FIELD_HUD_INVALIDATE, function()
    FieldHud.Refresh()
    if Sync and Sync.RefreshNow then Sync.RefreshNow() end
end)
RegisterNetEvent(EVENTS.RUNTIME_READY, function() FieldHud.Refresh() end)
RegisterNetEvent('QBCore:Client:OnJobUpdate', function() FieldHud.Refresh() end)
RegisterNetEvent('QBCore:Client:SetDuty', function() FieldHud.Refresh() end)

CreateThread(function()
    Wait(1500)
    refresh()
    while true do Wait(Config.FieldHud.RefreshSeconds * 1000); refresh() end
end)

CreateThread(function()
    while true do
        if state then pushUpdate() end
        Wait(Config.FieldHud.UiUpdateMs)
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then ui('fieldHud:hide') end
end)
