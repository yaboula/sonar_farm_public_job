-- Animation-only presentation controller for every physical farming action.

GameplayFeedback = GameplayFeedback or {}

local active

local function warn(message)
    if Config.Debug then Bridge.Log('warn', message) end
end

local function playerCanWork(preview)
    local ped = PlayerPedId()
    if not ped or ped == 0 or IsEntityDead(ped) or IsPedRagdoll(ped)
        or IsPedInAnyVehicle(ped, false) then return false end
    if preview then return true end
    local data = Bridge.GetPlayerData()
    local job = data and data.job
    if not job or job.name ~= Config.Job.Name then return false end
    return not Config.Job.RequireDuty or job.onduty == true
end

local function loadAnimation(dict)
    RequestAnimDict(dict)
    local deadline = GetGameTimer() + (Config.Gameplay.AnimationLoadTimeoutMs or 2500)
    while not HasAnimDictLoaded(dict) and GetGameTimer() < deadline do Wait(0) end
    if HasAnimDictLoaded(dict) then return true end
    RemoveAnimDict(dict)
    warn(('Action animation timed out: %s'):format(dict))
    return false
end

local function synchronizedDuration(config, loaded)
    local target = math.max(250, math.floor(tonumber(config.duration) or 2500))
    if not loaded or type(GetAnimDuration) ~= 'function' then return target end
    local seconds = tonumber(GetAnimDuration(config.anim.dict, config.anim.clip)) or 0
    if seconds <= 0.1 then
        warn(('Action animation has no readable duration: %s/%s'):format(config.anim.dict, config.anim.clip))
        return target
    end
    local nativeDuration = seconds * 1000
    local cycles = math.max(1, math.floor((target / nativeDuration) + 0.5))
    return math.max(250, math.min(15000, math.floor((nativeDuration * cycles) + 0.5)))
end

local function cleanup(session)
    if not session or session.cleaned then return end
    session.cleaned = true
    if session.animLoaded and session.config.anim then
        StopAnimTask(session.ped, session.config.anim.dict, session.config.anim.clip, 1.0)
        RemoveAnimDict(session.config.anim.dict)
    end
end

local function prepare(label, action, options)
    local config = Config.Gameplay.ActionFeedback and Config.Gameplay.ActionFeedback[action]
    if not config then return nil, 'missing_feedback' end
    if active then return nil, 'already_active' end
    if not playerCanWork(options.preview) then return nil, 'player_unavailable' end

    local ped = PlayerPedId()
    local session = {
        action = action,
        label = label,
        config = config,
        ped = ped,
        origin = GetEntityCoords(ped),
        preview = options.preview == true,
        phase = 'prepare',
    }
    active = session
    session.animLoaded = loadAnimation(config.anim.dict)
    session.duration = synchronizedDuration(config, session.animLoaded)
    if active ~= session or not playerCanWork(session.preview) then
        cleanup(session)
        active = nil
        return nil, 'cancelled'
    end
    return session
end

local function perform(session)
    local config = session.config
    session.phase = 'perform'
    if session.animLoaded then
        TaskPlayAnim(session.ped, config.anim.dict, config.anim.clip, 2.0, 2.0,
            session.duration, config.anim.flag or 49, 0.0, false, false, false)
    end

    CreateThread(function()
        while active == session and session.phase == 'perform' do
            local ped = PlayerPedId()
            local coords = ped ~= 0 and GetEntityCoords(ped) or session.origin
            local tooFar = #(coords - session.origin) > (Config.Gameplay.FeedbackCancelDistance or 1.75)
            if ped ~= session.ped or tooFar or not playerCanWork(session.preview) then
                lib.cancelProgress()
                break
            end
            Wait(100)
        end
    end)

    return lib.progressCircle({
        duration = session.duration,
        label = session.label,
        position = 'bottom',
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, car = true, combat = true, sprint = true },
    }) == true
end

function GameplayFeedback.Run(label, action, options)
    local session, reason = prepare(label, action, options or {})
    if not session then return false, reason end
    local ok, completed = pcall(perform, session)
    if not ok then warn(('Action animation failed: %s'):format(tostring(completed))) end
    completed = ok and completed == true
    session.phase = completed and 'finish' or 'cancel'
    cleanup(session)
    if active == session then active = nil end
    return completed, completed and nil or 'cancelled'
end

function GameplayFeedback.IsActive()
    return active ~= nil
end

function GameplayFeedback.Cancel()
    if not active then return end
    lib.cancelProgress()
    local session = active
    session.phase = 'cancel'
    cleanup(session)
    if active == session then active = nil end
end

if Config.Debug then
    RegisterCommand('sfpj_action_preview', function(_, args)
        if not Admin.RequireAuthorization() then return end
        local action = tostring(args[1] or '')
        if not Config.Gameplay.ActionFeedback[action] then
            return Bridge.Notify('Use plant, water, fertilize, weed, treat_pest or harvest.',
                Sonar.Constants.NOTIFY.ERROR)
        end
        GameplayFeedback.Run(('Previewing %s...'):format(action), action, { preview = true })
    end, false)
end

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then GameplayFeedback.Cancel() end
end)
