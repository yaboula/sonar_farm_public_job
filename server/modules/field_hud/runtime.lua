-- Privacy-safe authoritative reservation snapshot for the passive Field HUD.

FieldHudRuntime = FieldHudRuntime or {}

local listeners = {}

local function accessState(source)
    local job = Bridge.GetJobState(source) or {}
    local correctJob = job.name == Config.Job.Name
    local onDuty = job.onDuty == true
    return {
        job = job.name,
        onDuty = onDuty,
        allowed = correctJob and (not Config.Job.RequireDuty or onDuty),
        reason = not correctJob and Sonar.Constants.REJECT.JOB_REQUIRED
            or Config.Job.RequireDuty and not onDuty and Sonar.Constants.REJECT.DUTY_REQUIRED or nil,
    }
end

function FieldHudRuntime.Snapshot(source)
    local guard = Runtime.GuardPlayer(source)
    if not guard.ok then return guard end

    local link = Reservations.GetLink(guard.identifier)
    if not link or (link.reservation_status ~= 'active' and link.reservation_status ~= 'grace')
        or (link.status ~= 'active' and link.status ~= 'departing') then
        listeners[source] = nil
        return { ok = true, data = nil, serverTime = Sonar.Time.Now() }
    end

    local field = Fields.Get(link.field_id)
    local snapshot = Reservations.Snapshot(link.reservation_id, guard.identifier)
    if not field or not snapshot then
        listeners[source] = nil
        return { ok = true, data = nil, serverTime = Sonar.Time.Now() }
    end

    listeners[source] = field.id
    return {
        ok = true,
        serverTime = Sonar.Time.Now(),
        data = Sonar.FieldHud.BuildPayload(field, link, snapshot, accessState(source)),
    }
end

function FieldHudRuntime.InvalidateField(fieldId, reason)
    for source, subscribedField in pairs(listeners) do
        if subscribedField == fieldId then
            TriggerClientEvent(Sonar.Constants.EVENTS.FIELD_HUD_INVALIDATE, source,
                { fieldId = fieldId, reason = reason })
        end
    end
end

lib.callback.register(Sonar.Constants.CALLBACKS.FIELD_HUD_STATE, function(source)
    return FieldHudRuntime.Snapshot(source)
end)

AddEventHandler('playerDropped', function() listeners[source] = nil end)
