-- Focus-safe presentation controller for every physical farming action.

GameplayFeedback = GameplayFeedback or {}

local active
local sequence = 0

local function warn(message)
    if Config.Debug then Bridge.Log('warn', message) end
end

local function playerCanWork(preview)
    local ped = PlayerPedId()
    if not ped or ped == 0 or IsEntityDead(ped) or IsPedRagdoll(ped) or IsPedInAnyVehicle(ped, false) then
        return false
    end
    if preview then return true end
    local data = Bridge.GetPlayerData()
    local job = data and data.job
    if not job or job.name ~= Config.Job.Name then return false end
    return not Config.Job.RequireDuty or job.onduty == true
end

local function loadModel(model)
    local hash = type(model) == 'number' and model or joaat(model)
    if not IsModelInCdimage(hash) or not IsModelValid(hash) then
        warn(('Action prop model is invalid: %s'):format(tostring(model)))
        return nil
    end
    RequestModel(hash)
    local deadline = GetGameTimer() + (Config.Gameplay.FeedbackLoadTimeoutMs or 2500)
    while not HasModelLoaded(hash) and GetGameTimer() < deadline do Wait(0) end
    if not HasModelLoaded(hash) then
        warn(('Action prop model timed out: %s'):format(tostring(model)))
        SetModelAsNoLongerNeeded(hash)
        return nil
    end
    return hash
end

local function loadAnim(dict)
    if not dict then return false end
    RequestAnimDict(dict)
    local deadline = GetGameTimer() + (Config.Gameplay.FeedbackLoadTimeoutMs or 2500)
    while not HasAnimDictLoaded(dict) and GetGameTimer() < deadline do Wait(0) end
    if not HasAnimDictLoaded(dict) then
        warn(('Action animation timed out: %s'):format(dict))
        RemoveAnimDict(dict)
        return false
    end
    return true
end

local function loadParticle(asset)
    if not asset then return false end
    RequestNamedPtfxAsset(asset)
    local deadline = GetGameTimer() + (Config.Gameplay.FeedbackLoadTimeoutMs or 2500)
    while not HasNamedPtfxAssetLoaded(asset) and GetGameTimer() < deadline do Wait(0) end
    if not HasNamedPtfxAssetLoaded(asset) then
        warn(('Action particle asset timed out: %s'):format(asset))
        RemoveNamedPtfxAsset(asset)
        return false
    end
    return true
end

local function sound(session, event)
    local cfg = session.config.sound
    if not cfg then return end
    SendNUIMessage({
        type = 'gameplay:sound',
        payload = {
            event = event,
            token = session.token,
            id = cfg.id,
            volume = (Config.Gameplay.FeedbackVolume or 0.42) * (cfg.volume or 1.0),
            fadeMs = event == 'stop' and 40 or 120,
            loadTimeoutMs = Config.Gameplay.FeedbackLoadTimeoutMs or 2500,
        },
    })
end

local function stopParticle(session)
    if session.particleHandle then
        StopParticleFxLooped(session.particleHandle, false)
        session.particleHandle = nil
    end
end

local function cleanup(session)
    if not session or session.cleaned then return end
    session.cleaned = true
    sound(session, 'stop')
    stopParticle(session)
    if session.config.particle and session.particleLoaded then
        RemoveNamedPtfxAsset(session.config.particle.asset)
    end
    if session.prop and DoesEntityExist(session.prop) then
        DetachEntity(session.prop, true, true)
        DeleteEntity(session.prop)
    end
    if session.model then SetModelAsNoLongerNeeded(session.model) end
    if session.animLoaded and session.config.anim then
        StopAnimTask(session.ped, session.config.anim.dict, session.config.anim.clip, 1.0)
        RemoveAnimDict(session.config.anim.dict)
    elseif session.startedScenario then
        ClearPedTasks(session.ped)
    end
end

local function startParticle(session)
    local cfg = session.config.particle
    if not cfg or not session.particleLoaded or active ~= session then return end
    UseParticleFxAssetNextCall(cfg.asset)
    local offset, rotation = cfg.offset or vec3(0.0, 0.0, 0.0), cfg.rot or vec3(0.0, 0.0, 0.0)
    if cfg.mode == 'loop' then
        local target = cfg.attachToProp and session.prop or session.ped
        if target and DoesEntityExist(target) then
            session.particleHandle = StartParticleFxLoopedOnEntity(cfg.name, target,
                offset.x, offset.y, offset.z, rotation.x, rotation.y, rotation.z,
                cfg.scale or 0.1, false, false, false)
        end
    else
        local coords = GetOffsetFromEntityInWorldCoords(session.ped, offset.x, offset.y, offset.z)
        StartParticleFxNonLoopedAtCoord(cfg.name, coords.x, coords.y, coords.z,
            rotation.x, rotation.y, rotation.z, cfg.scale or 0.1, false, false, false)
    end
end


local function prepare(label, action, options)
    local cfg = Config.Gameplay.ActionFeedback and Config.Gameplay.ActionFeedback[action]
    if not cfg then return nil, 'missing_feedback' end
    if active then return nil, 'already_active' end
    if not playerCanWork(options.preview) then return nil, 'player_unavailable' end

    sequence = sequence + 1
    local ped = PlayerPedId()
    local session = {
        token = ('%s:%d'):format(action, sequence), action = action, label = label,
        config = cfg, ped = ped, origin = GetEntityCoords(ped), preview = options.preview == true,
        phase = 'prepare',
    }
    active = session

    if cfg.prop then session.model = loadModel(cfg.prop.model) end
    if cfg.anim then session.animLoaded = loadAnim(cfg.anim.dict) end
    if cfg.particle then session.particleLoaded = loadParticle(cfg.particle.asset) end
    if active ~= session or not playerCanWork(session.preview) then cleanup(session); active = nil; return nil, 'cancelled' end

    if session.model then
        local coords = GetEntityCoords(ped)
        session.prop = CreateObjectNoOffset(session.model, coords.x, coords.y, coords.z, false, false, false)
        if session.prop and session.prop ~= 0 then
            local prop = cfg.prop
            local pos, rot = prop.pos or vec3(0.0, 0.0, 0.0), prop.rot or vec3(0.0, 0.0, 0.0)
            AttachEntityToEntity(session.prop, ped, GetPedBoneIndex(ped, prop.bone or 57005),
                pos.x, pos.y, pos.z, rot.x, rot.y, rot.z, true, true, false, true, 1, true)
        end
    end
    return session
end

local function perform(session)
    local cfg = session.config
    session.phase = 'perform'
    if session.animLoaded and cfg.anim then
        TaskPlayAnim(session.ped, cfg.anim.dict, cfg.anim.clip, 2.0, 2.0, cfg.duration or 2000,
            cfg.anim.flag or 49, 0.0, false, false, false)
    elseif cfg.scenario or cfg.fallbackScenario then
        TaskStartScenarioInPlace(session.ped, cfg.scenario or cfg.fallbackScenario, 0, true)
        session.startedScenario = true
    end

    if cfg.sound then
        CreateThread(function()
            Wait(math.max(0, tonumber(cfg.sound.delay) or 0))
            if active ~= session then return end
            sound(session, 'play')
            Wait(math.max(0, tonumber(cfg.sound.duration) or cfg.duration or 0))
            if active == session then sound(session, 'stop') end
        end)
    end
    if cfg.particle then
        CreateThread(function()
            Wait(math.max(0, tonumber(cfg.particle.delay) or 0))
            if active ~= session then return end
            startParticle(session)
            if cfg.particle.mode == 'loop' then
                Wait(math.max(100, tonumber(cfg.particle.duration) or 500))
                if active == session then stopParticle(session) end
            end
        end)
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
        duration = tonumber(cfg.duration) or 2000,
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
    local completed = perform(session)
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

RegisterNUICallback('gameplay:warning', function(data, cb)
    warn(('Action audio unavailable: %s'):format(tostring(data and data.message or 'unknown error')))
    cb({ ok = true })
end)

if Config.Debug then
    RegisterCommand('sfpj_action_preview', function(_, args)
        if not Admin.RequireAuthorization() then return end
        local action = tostring(args[1] or '')
        if not Config.Gameplay.ActionFeedback[action] then
            return Bridge.Notify('Use plant, water, fertilize, weed, treat_pest or harvest.', Sonar.Constants.NOTIFY.ERROR)
        end
        GameplayFeedback.Run(('Previewing %s...'):format(action), action, { preview = true })
    end, false)
end

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then GameplayFeedback.Cancel() end
end)
