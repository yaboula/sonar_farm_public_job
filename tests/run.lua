-- sonar_farm_publicjob - Dependency-free Lua regression suite.

local passed = 0

local function test(name, fn)
    local ok, err = pcall(fn)
    if not ok then
        io.stderr:write(('FAIL %s: %s\n'):format(name, tostring(err)))
        os.exit(1)
    end
    passed = passed + 1
    print(('PASS %s'):format(name))
end

local function equal(actual, expected, message)
    if actual ~= expected then
        error(('%s (expected %s, got %s)'):format(message or 'values differ', tostring(expected), tostring(actual)))
    end
end

-- Minimal FiveM/ox environment used by shared and server-pure modules.
function vec3(x, y, z) return { x = x, y = y, z = z } end
function GetCurrentResourceName() return 'sonar_farm_publicjob' end
function IsDuplicityVersion() return true end
function GetNetworkTimeAccurate() return os.time() * 1000 end
function AddEventHandler() end
function RegisterCommand() end
function GetPlayerPed() return 1 end
function GetEntityCoords() return vec3(2236.0, 5031.0, 44.2) end
function GetPlayerRoutingBucket() return 0 end

local gameTimer = 1000
function GetGameTimer() return gameTimer end

json = {
    encode = function() return '{}' end,
    decode = function() return {} end,
}

Logger = {
    Info = function() end,
    Warn = function() end,
    Exploit = function() end,
}

Bridge = {
    Ready = true,
    GetIdentifier = function() return 'citizen-test' end,
    GetPlayerName = function() return 'Test Player' end,
    Inventory = {
        HasItem = function() return true end,
        GetSlotsWithItem = function() return {} end,
        SetDurability = function() return true end,
        RemoveFromSlot = function() return true end,
    },
}

dofile('config/config.lua')
dofile('config/crops.lua')
dofile('config/zones.lua')
dofile('config/minigames.lua')
dofile('data/fields.lua')
dofile('shared/item_catalog.lua')
dofile('shared/constants.lua')
dofile('shared/utils.lua')
dofile('shared/rentals.lua')
dofile('shared/time.lua')
dofile('shared/crop_clock.lua')
dofile('shared/conditions.lua')
dofile('shared/growth.lua')
dofile('shared/physiology.lua')
dofile('shared/inspection.lua')
dofile('shared/zones.lua')
dofile('shared/fields.lua')
dofile('shared/config_validation.lua')
dofile('server/modules/minigames/tomato_plant_scoring.lua')
dofile('server/modules/inventory/items.lua')

test('production config validates', function()
    local errors = Sonar.ConfigValidation.Validate()
    equal(#errors, 0, table.concat(errors, '; '))
end)

test('configured Field seeds compile stable versioned topology', function()
    local first, errors = Sonar.Fields.CompileSeeds()
    equal(#errors, 0, table.concat(errors, '; '))
    equal(#first, #(Config.FieldSeeds or {}), 'every configured Field seed must compile')
    local ids = {}
    for _, field in ipairs(first) do
        local expectedSlots = ({ S = 24, M = 40, L = 64 })[field.size]
        if expectedSlots then equal(#field.slots, expectedSlots, field.id .. ' slot count') end
        assert(#field.rows >= 1 and #field.rows <= 20, 'row bounds')
        for _, slot in ipairs(field.slots) do
            assert(not ids[slot.id], 'stable Slot ids must be globally unique')
            ids[slot.id] = true
            assert(slot.position.x >= 0 and slot.position.x <= 1, 'normalized x')
            assert(slot.position.y >= 0 and slot.position.y <= 1, 'normalized y')
        end
        local again = assert(Sonar.Fields.Compile((function()
            for _, seed in ipairs(Config.FieldSeeds) do if seed.id == field.id then return seed end end
        end)()))
        equal(again.checksum, field.checksum, 'topology checksum must be deterministic')
    end
end)

test('Field topology validator rejects unsafe geometry and cross-Field overlap', function()
    local invalid = {
        id = 'invalid', name = 'Invalid', access = { x = 0, y = 0, z = 0 },
        allowedCrops = {}, rows = { { slots = { { x = 0, y = 0, z = 0 } } } },
    }
    local compiled, errors = Sonar.Fields.Compile(invalid)
    assert(not compiled and #errors > 0, 'a one-Slot Row must be rejected')

    local original = Config.FieldSeeds
    local function seed(id)
        return { id = id, name = id, access = { x = 0, y = 0, z = 0 }, allowedCrops = {},
            rows = { { slots = { { x = 10, y = 10, z = 1 }, { x = 12, y = 10, z = 1 } } } } }
    end
    Config.FieldSeeds = { seed('overlap_a'), seed('overlap_b') }
    local _, overlapErrors = Sonar.Fields.CompileSeeds()
    Config.FieldSeeds = original
    assert(#overlapErrors > 0 and table.concat(overlapErrors, '; '):find('overlaps', 1, true),
        'cross-Field overlap must be rejected')
end)

test('public-job runtime streams topology without company schema', function()
    local function read(path)
        local file = assert(io.open(path, 'rb')); local value = file:read('*a'); file:close(); return value
    end
    local hub = read('server/modules/hub/runtime.lua')
    local slots = read('client/modules/zones/slots.lua')
    local schema = read('server/modules/publicjob/database.lua')
    assert(hub:find("Reservations.Reserve", 1, true), 'Hub must dispatch public reservations')
    assert(hub:find("Fields.Subscribe", 1, true), 'Field Detail must use an authoritative subscription')
    assert(slots:find('function Slots.ReplaceFields', 1, true), 'nearby topology must replace Slot targets')
    assert(schema:find('sfpj_field_revisions', 1, true) and schema:find('sfpj_economy_outbox', 1, true),
        'versioned topology and economy recovery outbox tables are required')
end)

test('gameplay feedback defines six distinct actions and guaranteed cleanup', function()
    local expectedDurations = {
        plant = 3200, water = 2800, fertilize = 2600,
        weed = 3000, treat_pest = 2600, harvest = 2800,
    }
    local soundIds = {}
    for action, duration in pairs(expectedDurations) do
        local feedback = assert(Config.Gameplay.ActionFeedback[action], action .. ' feedback')
        equal(feedback.duration, duration, action .. ' duration')
        assert(feedback.anim or feedback.scenario, action .. ' animation')
        assert(feedback.sound and feedback.sound.id, action .. ' local audio')
        assert(not soundIds[feedback.sound.id]
            or (feedback.sound.id == 'soil_scrape'
                and ((soundIds[feedback.sound.id] == 'plant' and action == 'weed')
                    or (soundIds[feedback.sound.id] == 'weed' and action == 'plant'))),
            'only Plant and Weed may share the scrape sound')
        soundIds[feedback.sound.id] = action
        assert(feedback.particle, action .. ' local particle contract')
    end
    equal(Config.Gameplay.ActionFeedback.harvest.prop, nil, 'harvest must use hands, never a planting tool')
    local file = assert(io.open('client/modules/interaction/feedback.lua', 'rb'))
    local source = file:read('*a'); file:close()
    for _, contract in ipairs({ 'already_active', 'IsEntityDead', 'IsPedInAnyVehicle',
        'FeedbackCancelDistance', 'lib.cancelProgress()', 'DeleteEntity(session.prop)',
        "sound(session, 'stop')", 'StopParticleFxLooped', 'onResourceStop',
        'sfpj_action_preview', 'Admin.RequireAuthorization', "RegisterNUICallback('gameplay:warning'" }) do
        assert(source:find(contract, 1, true), 'missing feedback lifecycle contract: ' .. contract)
    end
end)

test('procedural gameplay audio stays local compact and reproducible', function()
    local total = 0
    for _, name in ipairs({ 'soil_scrape', 'water_pour', 'granules', 'spray', 'crop_pick' }) do
        local file = assert(io.open('nui-shell/audio/' .. name .. '.ogg', 'rb'))
        local header = file:read(4)
        local size = assert(file:seek('end'))
        file:close()
        equal(header, 'OggS', name .. ' OGG header')
        assert(size > 0 and size < 100000, name .. ' should remain a compact local effect')
        total = total + size
    end
    assert(total < 500000, 'all gameplay audio must remain below 500 KB')
    local generator = assert(io.open('scripts/generate_gameplay_audio.py', 'rb'))
    local source = generator:read('*a'); generator:close()
    assert(source:find('RATE = 48_000', 1, true), 'audio generator must stay mono 48 kHz')
    assert(source:find('loudnorm=I=-16', 1, true), 'audio generator must normalize near -16 LUFS')
end)

test('invalid operational config is rejected', function()
    local ace = Config.Admin.Ace
    local buckets = Config.Security.AllowedRoutingBuckets
    Config.Admin.Ace = ''
    Config.Security.AllowedRoutingBuckets = { -1 }

    local errors = Sonar.ConfigValidation.Validate()
    assert(#errors >= 2, 'admin ACE and routing bucket errors expected')

    Config.Admin.Ace = ace
    Config.Security.AllowedRoutingBuckets = buckets
end)

test('malformed crop config reports an error instead of crashing validation', function()
    local stage = Config.Crops.carrot.stages[1]
    Config.Crops.carrot.stages[1] = 'invalid'

    local ok, errors = pcall(Sonar.ConfigValidation.Validate)
    equal(ok, true, 'validator must not crash')
    assert(#errors > 0, 'malformed crop must be rejected')

    Config.Crops.carrot.stages[1] = stage
end)

test('advanced care config rejects malformed bounds and overrides', function()
    local window = Config.Crops.carrot.criticalWindow
    local effects = Config.Crops.carrot.conditionEffects
    Config.Crops.carrot.criticalWindow = { from = 0.8, to = 0.2 }
    Config.Crops.carrot.conditionEffects = { pests = 'yes', weather = true }
    local errors = Sonar.ConfigValidation.Validate()
    assert(#errors >= 3, 'window, boolean and unsupported override errors expected')
    Config.Crops.carrot.criticalWindow = window
    Config.Crops.carrot.conditionEffects = effects
end)

test('advanced care config rejects incomplete operational effects', function()
    local advanced = Config.Farming.AdvancedCare
    local fertilizer = Sonar.ItemCatalog.byId.fertilizer_organic.consumable.amount
    local treatment = Sonar.ItemCatalog.byId.pest_spray_chemical.consumable.reduction
    local weedRemoval = Sonar.ItemCatalog.byId.hand_hoe.tool.weedRemoval
    local waterPenalty = advanced.GrowthPenaltyPerDeficitHour.water
    local nutrientPenalty = advanced.GrowthPenaltyPerDeficitHour.nutrients

    Sonar.ItemCatalog.byId.fertilizer_organic.consumable.amount = nil
    Sonar.ItemCatalog.byId.pest_spray_chemical.consumable.reduction = nil
    Sonar.ItemCatalog.byId.hand_hoe.tool.weedRemoval = 0
    advanced.GrowthPenaltyPerDeficitHour.water = 0.7
    advanced.GrowthPenaltyPerDeficitHour.nutrients = 0.6

    local errors = Sonar.ConfigValidation.Validate()
    local report = table.concat(errors, '\n')
    assert(report:find('fertilizer_organic', 1, true), 'missing fertilizer effect rejected')
    assert(report:find('pest_spray_chemical', 1, true), 'missing treatment effect rejected')
    assert(report:find('hand_hoe', 1, true), 'ineffective weed removal rejected')
    assert(report:find('sum to at most 1', 1, true), 'growth rates that can reverse progress rejected')

    Sonar.ItemCatalog.byId.fertilizer_organic.consumable.amount = fertilizer
    Sonar.ItemCatalog.byId.pest_spray_chemical.consumable.reduction = treatment
    Sonar.ItemCatalog.byId.hand_hoe.tool.weedRemoval = weedRemoval
    advanced.GrowthPenaltyPerDeficitHour.water = waterPenalty
    advanced.GrowthPenaltyPerDeficitHour.nutrients = nutrientPenalty
end)

test('zone grids and explicit slots resolve', function()
    equal(Sonar.Zones.Count('grapeseed_east'), 40, 'east slot count')
    equal(Sonar.Zones.Count('grapeseed_south'), 24, 'south slot count')
    equal(Sonar.Zones.Count('zone1'), 24, 'explicit slot count')
    equal(Sonar.Zones.Slot('zone1', 1).zone, 'zone1', 'slot zone')
end)

test('growth is timestamp based and clamped', function()
    local record = {
        crop_type = 'carrot',
        planted_at = 1000,
        growth_time = 100,
        data = {},
    }
    equal(Growth.Evaluate(record, 1050).progress, 0.5, 'half growth')
    equal(Growth.Evaluate(record, 1200).state, Sonar.Constants.CROP_STATE.MATURE, 'mature state')
end)

test('physiology derives drought and spoilage without mutation', function()
    local record = {
        crop_type = 'lettuce',
        planted_at = 1000,
        growth_time = 100,
        data = { water = 0, health = 100, spoilage = 0, lastCare = 1000 },
    }
    local condition = Physiology.Evaluate(record, 4600)
    assert(condition.health < 100, 'dry crop should lose health')
    assert(condition.spoilage > 0, 'mature crop should spoil')
    equal(record.data.health, 100, 'evaluation must be pure')
end)

test('incomplete planting never progresses or dries out', function()
    local record = {
        crop_type = 'tomato',
        state = Sonar.Constants.CROP_STATE.PLANTING_FAILED,
        planted_at = 1000,
        growth_time = 100,
        data = { water = 0, health = 100, lastCare = 1000 },
    }
    local condition = Physiology.Evaluate(record, 9999)
    equal(condition.state, Sonar.Constants.CROP_STATE.PLANTING_FAILED, 'incomplete state')
    equal(condition.progress, 0, 'incomplete progress')
    equal(condition.health, 100, 'incomplete health')
end)

test('advanced condition gating respects global and per-crop ceilings', function()
    local enabled = Config.Features.AdvancedCare
    Config.Features.AdvancedCare = true
    equal(Sonar.Conditions.IsEnabled('carrot', 'nutrients'), true, 'configured crop inherits global gate')
    local tomatoEffects = Config.Crops.tomato.conditionEffects
    Config.Crops.tomato.conditionEffects = { weeds = false, pests = false }
    equal(Sonar.Conditions.IsEnabled('tomato', 'weeds'), false, 'crop override narrows global gate')
    Config.Crops.tomato.conditionEffects = tomatoEffects
    local global = Config.Farming.ConditionEffects.Pests
    Config.Farming.ConditionEffects.Pests = false
    equal(Sonar.Conditions.IsEnabled('carrot', 'pests'), false, 'global off and crop unset stays off')
    local override = Config.Crops.carrot.conditionEffects
    Config.Crops.carrot.conditionEffects = { pests = true }
    equal(Sonar.Conditions.IsEnabled('carrot', 'pests'), false, 'crop cannot widen global gate')
    Config.Crops.carrot.conditionEffects = override
    Config.Farming.ConditionEffects.Pests = global
    Config.Features.AdvancedCare = enabled
end)

test('inspection builds authoritative history and disabled conditions', function()
    local enabled = Config.Features.AdvancedCare
    local pests = Config.Farming.ConditionEffects.Pests
    Config.Features.AdvancedCare = true
    local record = {
        id = 'inspection-crop', crop_type = 'carrot', zone = 'east', slot = 7,
        planted_at = 1000, growth_time = 900, state = Sonar.Constants.CROP_STATE.GROWING,
        isMine = true,
        data = { lastCare = 1000, water = 44, health = 92, nutrients = 62, weedCover = 38,
            pestPressure = 12, plantingQuality = 20,
            waterProtectionTier = 'basic', waterProtectionUntil = 1700,
            nutrientProtectionTier = 'plus', nutrientProtectionUntil = 1900,
            weedProtectionTier = 'pro', weedProtectionUntil = 1800 },
    }
    local payload = Sonar.Inspection.Build(record, 1600)
    equal(payload.version, 1, 'inspection contract version')
    equal(payload.series.historyStart, 1000, 'history starts at last care')
    equal(payload.series.now, 1600, 'series marks server now')
    equal(payload.series.forecastEnd, 1600, 'compatibility boundary ends at current time')
    equal(#payload.series.samples, 51, 'adaptive samples cover only reliable history and now')
    for _, point in ipairs(payload.series.samples) do
        assert(point.phase == 'history' or point.phase == 'now', 'inspection must not invent forecast samples')
        assert(point.at <= payload.series.now, 'inspection samples cannot be in the future')
    end
    equal(payload.subject.stage, 'Root development', 'data-driven stage label')
    assert(payload.timing.readyAt and payload.timing.readyAt > 1600, 'stress-aware ETA resolved')
    equal(payload.metrics[1].protectionTier, 'basic', 'water protection tier exposed')
    equal(payload.metrics[2].protectionTier, 'plus', 'protection tier exposed')
    equal(payload.metrics[3].protectionTier, 'pro', 'weed protection tier exposed')
    equal(payload.metrics[2].thresholds[1].value, 42, 'nutrient minimum comes from crop config')
    equal(payload.metrics[2].thresholds[2].value, 82, 'nutrient maximum comes from crop config')
    assert(payload.outcome.quality < 80, 'estimated quality includes poor authoritative planting score')

    Config.Farming.ConditionEffects.Pests = false
    local withoutPests = Sonar.Inspection.Build(record, 1600, { includeSeries = false })
    equal(withoutPests.metrics[4].value, 0, 'disabled condition is a real flat zero')
    equal(withoutPests.metrics[4].status, 'unaffected', 'disabled condition is labelled unaffected')
    equal(withoutPests.series, nil, 'lightweight refresh omits series')
    Config.Farming.ConditionEffects.Pests = pests
    Config.Features.AdvancedCare = enabled
end)

test('optimal green zone accelerates growth by fifteen percent', function()
    local enabled = Config.Features.AdvancedCare
    local crop = Config.Crops.carrot
    local waterRate = crop.water.decayPerHour
    local nutrientRate = crop.nutrients.decayPerHour
    local weedRate = crop.weeds.growthPerHour
    local pestRate = Config.Farming.AdvancedCare.PestGrowthPerHour
    Config.Features.AdvancedCare = true
    crop.water.decayPerHour = 0
    crop.nutrients.decayPerHour = 0
    crop.weeds.growthPerHour = 0
    Config.Farming.AdvancedCare.PestGrowthPerHour = 0

    local record = {
        crop_type = 'carrot', planted_at = 1000, growth_time = 3600,
        data = { water = 100, health = 100, nutrients = 62, weedCover = 0,
            pestPressure = 0, growthPenaltyHours = 0, lastCare = 1000 },
    }
    local condition = Physiology.Evaluate(record, 2800)
    assert(math.abs(condition.growthPenaltyHours - (-0.075)) < 0.0001,
        'green-zone bonus must persist as a signed growth adjustment')
    assert(math.abs(condition.progress - 0.575) < 0.0001,
        'thirty minutes in green zone must advance 34.5 biological minutes')

    crop.water.decayPerHour = waterRate
    crop.nutrients.decayPerHour = nutrientRate
    crop.weeds.growthPerHour = weedRate
    Config.Farming.AdvancedCare.PestGrowthPerHour = pestRate
    Config.Features.AdvancedCare = enabled
end)

test('water protection delays drought and health loss across its expiry', function()
    local enabled = Config.Features.AdvancedCare
    local effects = Config.Crops.lettuce.conditionEffects
    Config.Features.AdvancedCare = true
    Config.Crops.lettuce.conditionEffects = { nutrients = false, weeds = false, pests = false }
    local base = {
        crop_type = 'lettuce', planted_at = 1000, growth_time = 7200,
        data = { water = 100, health = 100, nutrients = 70, weedCover = 0,
            pestPressure = 0, lastCare = 1000 },
    }
    local protected = {
        crop_type = base.crop_type, planted_at = base.planted_at, growth_time = base.growth_time,
        data = {
            water = 100, health = 100, nutrients = 70, weedCover = 0, pestPressure = 0,
            lastCare = 1000, waterProtectionStrength = 0.75,
            waterProtectionUntil = 1900, waterProtectionTier = 'pro',
        },
    }
    local ordinaryResult = Physiology.Evaluate(base, 2800)
    local protectedResult = Physiology.Evaluate(protected, 2800)
    assert(protectedResult.water > ordinaryResult.water,
        'water protection must reduce decay during its active segment')
    assert(protectedResult.health > ordinaryResult.health,
        'protected time must delay drought health damage after protection expires')
    equal(protectedResult.waterProtectionTier, 'pro', 'protection metadata survives evaluation')
    equal(protectedResult.waterProtectionUntil, 1900, 'protection expiry survives evaluation')
    Config.Crops.lettuce.conditionEffects = effects
    Config.Features.AdvancedCare = enabled
end)

test('inspection diagnoses immediate water stress and can report stalled growth', function()
    local enabled = Config.Features.AdvancedCare
    local rates = Config.Farming.AdvancedCare.GrowthPenaltyPerDeficitHour
    Config.Features.AdvancedCare = true
    local record = {
        id = 'stressed-crop', crop_type = 'lettuce', zone = 'east', slot = 8,
        planted_at = 1000, growth_time = 600, state = Sonar.Constants.CROP_STATE.GROWING,
        data = { lastCare = 1000, water = 0, health = 100, nutrients = 0, weedCover = 0, pestPressure = 0 },
    }
    local urgent = Sonar.Inspection.Build(record, 1060, { includeSeries = false })
    equal(urgent.diagnosis.cause, 'water', 'immediate deficit wins deterministic diagnosis')
    Config.Farming.AdvancedCare.GrowthPenaltyPerDeficitHour = { water = 0.5, nutrients = 0.5 }
    local stalled = Sonar.Inspection.Build(record, 1060, { includeSeries = false })
    equal(stalled.timing.readyAt, nil, 'fully stalled crop has no fake ETA')
    Config.Farming.AdvancedCare.GrowthPenaltyPerDeficitHour = rates
    Config.Features.AdvancedCare = enabled
end)

test('inspection callback accepts only crop identity and revalidates authority', function()
    local file = assert(io.open('server/modules/farming/inspection.lua', 'rb'))
    local source = file:read('*a')
    file:close()
    assert(source:find('Runtime.GuardPlayer(source)', 1, true), 'runtime gate')
    assert(source:find('PublicJob.Guard(source)', 1, true), 'job and duty gate')
    assert(source:find("Security.Consume(source, 1, 'inspection')", 1, true), 'inspection rate limit')
    assert(source:find('local cropId = request and request.cropId', 1, true), 'crop id is the only request input')
    assert(source:find('State.Get(cropId)', 1, true), 'authoritative crop lookup')
    assert(source:find('Validation.Distance(source', 1, true), 'server distance validation')
    assert(source:find('Sync.RenderPayload(record, actor.identifier)', 1, true), 'minimal synchronized snapshot')
    assert(not source:find('request.coords', 1, true), 'client coordinates are never trusted')

    local syncFile = assert(io.open('server/modules/sync/subscriptions.lua', 'rb'))
    local syncSource = syncFile:read('*a')
    syncFile:close()
    assert(syncSource:find('payload.plantingQuality = data.plantingQuality or data.plantScore', 1, true),
        'authoritative planting quality reaches inspection prediction')
    assert(syncSource:find('payload.waterProtectionUntil = data.waterProtectionUntil', 1, true),
        'water protection reaches client evaluator')
    assert(syncSource:find('payload.weedProtectionUntil = data.weedProtectionUntil', 1, true),
        'weed protection reaches client evaluator')
end)

test('advanced trajectories are causal and old records stay compatible', function()
    local enabled = Config.Features.AdvancedCare
    Config.Features.AdvancedCare = true
    local base = {
        crop_type = 'carrot', planted_at = 1000, growth_time = 7200,
        data = { water = 100, health = 100, lastCare = 1000 },
    }
    local old = Sonar.Conditions.Evaluate(base, 4600)
    assert(old.nutrients < 100, 'missing nutrient state defaults safely then decays')
    assert(old.weedCover > 0, 'missing weed state defaults safely then grows')

    local clean = {
        crop_type = 'carrot', planted_at = 1000, growth_time = 7200,
        data = { water = 100, nutrients = 100, weedCover = 0, pestPressure = 0, lastCare = 1000 },
    }
    local weedy = {
        crop_type = 'carrot', planted_at = 1000, growth_time = 7200,
        data = { water = 100, nutrients = 100, weedCover = 70, pestPressure = 0, lastCare = 1000 },
    }
    local cleanResult = Sonar.Conditions.Evaluate(clean, 1600)
    local weedyResult = Sonar.Conditions.Evaluate(weedy, 1600)
    assert(weedyResult.water < cleanResult.water, 'weeds accelerate water loss')
    assert(weedyResult.nutrients < cleanResult.nutrients, 'weeds accelerate nutrient loss')
    assert(weedyResult.pestPressure > cleanResult.pestPressure, 'weeds accelerate pest pressure')
    Config.Features.AdvancedCare = enabled
end)

test('sustained deficits slow growth and critical windows amplify stress', function()
    local enabled = Config.Features.AdvancedCare
    Config.Features.AdvancedCare = true
    local stressed = {
        crop_type = 'carrot', planted_at = 1000, growth_time = 3600,
        data = { water = 0, nutrients = 0, weedCover = 0, pestPressure = 0, lastCare = 1000 },
    }
    assert(Growth.Evaluate(stressed, 4600).progress < 1, 'deficit penalty stretches maturation')

    local outside = {
        crop_type = 'carrot', planted_at = 0, growth_time = 10000,
        data = { water = 0, nutrients = 0, weedCover = 0, pestPressure = 0, lastCare = 100 },
    }
    local inside = {
        crop_type = 'carrot', planted_at = 0, growth_time = 10000,
        data = { water = 0, nutrients = 0, weedCover = 0, pestPressure = 0, lastCare = 4000 },
    }
    local outsideResult = Sonar.Conditions.Evaluate(outside, 1100)
    local insideResult = Sonar.Conditions.Evaluate(inside, 5000)
    assert(insideResult.waterStressDelta > outsideResult.waterStressDelta, 'critical window weights equal stress more')
    Config.Features.AdvancedCare = false
    local originalGrowth = Growth.Evaluate(stressed, 4600)
    equal(originalGrowth.progress, 1, 'disabled feature preserves original growth')
    equal(originalGrowth.effectiveElapsed, nil, 'disabled feature preserves original response shape')
    Config.Features.AdvancedCare = enabled
end)

test('neglect never reverses growth and critical windows follow effective progress', function()
    local enabled = Config.Features.AdvancedCare
    Config.Features.AdvancedCare = true
    local delayed = {
        crop_type = 'carrot', planted_at = 0, growth_time = 3600,
        data = { water = 0, nutrients = 0, weedCover = 0, pestPressure = 0,
            growthPenaltyHours = 0, lastCare = 0 },
    }

    local previous = 0
    for now = 300, 7200, 300 do
        local progress = Growth.Evaluate(delayed, now).progress
        assert(progress + 1e-9 >= previous, ('growth reversed at %d seconds'):format(now))
        previous = progress
    end
    assert(previous > 0, 'neglect may stop growth but cannot erase completed growth')

    local rates = Config.Farming.AdvancedCare.GrowthPenaltyPerDeficitHour
    local waterRate, nutrientRate = rates.water, rates.nutrients
    rates.water, rates.nutrients = 2, 3
    previous = 0
    for now = 300, 7200, 300 do
        local progress = Growth.Evaluate(delayed, now).progress
        assert(progress + 1e-9 >= previous, ('runtime safety failed at %d seconds'):format(now))
        previous = progress
    end
    rates.water, rates.nutrients = waterRate, nutrientRate

    local nominallyInside = Sonar.Conditions.Evaluate(delayed, 1800)
    equal(nominallyInside.criticalFactor, 1, 'wall-clock critical window ignored before biological stage')

    local biologicallyInside = {
        crop_type = 'carrot', planted_at = 0, growth_time = 3600,
        data = { water = 0, nutrients = 0, weedCover = 0, pestPressure = 0,
            growthPenaltyHours = 1.4, lastCare = 6300 },
    }
    local actualWindow = Sonar.Conditions.Evaluate(biologicallyInside, 7200)
    equal(actualWindow.criticalFactor, Config.Farming.AdvancedCare.CriticalStressMultiplier,
        'delayed crop receives critical stress only at effective critical progress')
    Config.Features.AdvancedCare = enabled
end)

test('tomato planting traces are bounded and scored deterministically', function()
    local cfg = Config.Minigames.Plant.tomato
    local prepare = { durationMs = 4000, samples = {} }
    for index = 1, 32 do
        local angle = (index - 1) / 32 * math.pi * 2
        prepare.samples[index] = {
            t = (index - 1) * 100,
            x = 0.5 + math.cos(angle) * 0.083,
            y = (750 / 1536) + math.sin(angle) * 0.083,
            down = true,
            pressure = 0.4,
        }
    end

    local place = { durationMs = 3000, samples = {} }
    for index = 1, 12 do
        place.samples[index] = {
            t = (index - 1) * 200,
            x = 0.70 - (index - 1) / 11 * 0.20,
            y = 0.35 + (index - 1) / 11 * ((720 / 1536) - 0.35),
            down = true,
            tilt = 0,
        }
    end

    local cover = { durationMs = 4000, samples = {} }
    for index = 1, 32 do
        cover.samples[index] = {
            t = (index - 1) * 100,
            x = ((index - 1) % 8 + 0.5) / 8,
            y = 0.45 + (math.floor((index - 1) / 8) + 0.5) / 4 * 0.30,
            down = true,
            pressure = 0.35,
            side = index % 2 == 0 and 1 or -1,
        }
    end

    local water = { durationMs = 6000, samples = {} }
    for index = 1, 54 do
        local gx = (index - 1) % 6
        local gy = math.floor((index - 1) / 6) % 4
        water.samples[index] = {
            t = (index - 1) * 100,
            x = 0.405 + gx / 5 * 0.19,
            y = 0.35 + gy / 3 * 0.14,
            pouring = true,
            tilt = 0.5,
        }
    end

    local steps = {}
    for step, trace in pairs({ prepare = prepare, place = place, cover = cover, water = water }) do
        local result, reason = TomatoPlantScoring.ScoreStep(step, trace, cfg)
        assert(result, reason)
        steps[step] = result
    end
    local final, reason = TomatoPlantScoring.Finalize(steps, cfg, 0)
    assert(final, reason)
    assert(final.score >= 70 and final.score <= 100, 'good evidence should produce bounded quality')
    equal(final.outcomes.depth ~= nil, true, 'depth outcome')
    equal(final.outcomes.alignment ~= nil, true, 'alignment outcome')

    local compact = { durationMs = 4000, samples = {} }
    for index, sample in ipairs(prepare.samples) do
        compact.samples[index] = {
            (index - 1) * 2,
            math.floor(sample.x * 2048 + 0.5),
            math.floor(sample.y * 1536 + 0.5),
            3,
            0,
            102,
        }
    end
    local compactResult, compactReason = TomatoPlantScoring.ScoreStep('prepare', compact, cfg)
    assert(compactResult, compactReason)
    assert(math.abs(compactResult.score - steps.prepare.score) < 2, 'compact trace matches object trace')

    prepare.samples[1].x = 2
    local invalid = TomatoPlantScoring.ScoreStep('prepare', prepare, cfg)
    equal(invalid, nil, 'out-of-bounds sample rejected')
end)

dofile('server/modules/farming/quality.lua')

test('validated planting quality contributes to final harvest quality', function()
    local condition = { health = 100, spoilage = 0 }
    local poorPlanting = Quality.Resolve(50, condition, { plantingQuality = 0 })
    local strongPlanting = Quality.Resolve(50, condition, { plantingQuality = 100 })
    assert(strongPlanting > poorPlanting, 'planting quality must remain economically meaningful')
end)

test('production and quality respond independently with visible defects', function()
    local enabled = Config.Features.AdvancedCare
    Config.Features.AdvancedCare = true
    local record = { crop_type = 'carrot', data = {} }
    local waterDamaged = {
        health = 100, spoilage = 0, waterStressAccumulated = 80,
        nutrientStressAccumulated = 0, pestDamageAccumulated = 0, overfertilizeExcess = 0,
    }
    local pestDamaged = {
        health = 100, spoilage = 0, waterStressAccumulated = 0,
        nutrientStressAccumulated = 0, pestDamageAccumulated = 80, overfertilizeExcess = 0,
    }
    equal(Quality.ResolveProduction(record, waterDamaged, 0), 100, 'water stress does not reduce quantity directly')
    assert(Quality.ResolveProduction(record, pestDamaged, 0) < 100, 'pests reduce production')
    equal(Quality.DominantDefect(record, waterDamaged), 'water_stress', 'water defect')
    equal(Quality.DominantDefect(record, pestDamaged), 'pest_damage', 'pest defect')
    local tied = {
        waterStressAccumulated = 100, nutrientStressAccumulated = 100,
        pestDamageAccumulated = 100, overfertilizeExcess = 0,
    }
    equal(Sonar.Conditions.DominantDefect(tied), 'water_stress', 'shared tie order is stable')
    equal(Quality.DominantDefect(record, tied), 'water_stress', 'harvest uses shared tie order')
    assert(Quality.Resolve(100, waterDamaged) < 100, 'water history still reduces quality')
    Config.Features.AdvancedCare = enabled
end)

Database = {
    LoadAllCrops = function() return {} end,
    UpsertCrops = function() return true end,
    DeleteCrops = function() return true end,
}

dofile('server/modules/state/state.lua')
dofile('server/modules/farming/physiology.lua')

test('state keeps cell, owner and slot indexes consistent', function()
    Sonar.Utils.SeedRandom(1234, 5678)
    local id, record = State.Add({
        crop_type = 'carrot',
        owner = 'owner-a',
        zone = 'grapeseed_east',
        slot = 1,
        pos_x = 2236.0,
        pos_y = 5031.0,
        pos_z = 44.2,
    })
    equal(#id, 36, 'UUID length')
    equal(State.CountByOwner('owner-a'), 1, 'owner index')
    equal(State.SlotOccupant('grapeseed_east', 1), id, 'slot index')

    State.Update(id, { owner = 'owner-b', pos_x = 2000.0 })
    equal(State.CountByOwner('owner-a'), 0, 'old owner removed')
    equal(State.CountByOwner('owner-b'), 1, 'new owner added')
    equal(record.cell, State.CellKey(2000.0, record.pos_y), 'cell reindexed')

    State.Remove(id)
    equal(State.Count(), 0, 'crop removed')
    equal(State.SlotOccupant('grapeseed_east', 1), nil, 'slot released')
end)

test('advanced care mutators settle weeds pests and overfertilize consequences', function()
    local enabled = Config.Features.AdvancedCare
    Config.Features.AdvancedCare = true
    local id, record = State.Add({
        crop_type = 'carrot', owner = 'owner-a', zone = 'grapeseed_east', slot = 2,
        pos_x = 2237.0, pos_y = 5031.0, pos_z = 44.2, planted_at = Sonar.Time.Now(),
        growth_time = 900,
        data = { water = 100, health = 100, nutrients = 75, weedCover = 80,
            pestPressure = 70, lastCare = Sonar.Time.Now() },
    })
    local nutrients, excess = Physiology.Fertilize(record, 30, 1)
    equal(nutrients, 100, 'fertilizer respects crop ceiling')
    assert(excess > 0, 'overfertilizing creates a durable consequence')
    assert(Physiology.Weed(record, 70) < 80, 'weeding removes cover')
    assert(Physiology.TreatPests(record, 45) < 70, 'treatment reduces pressure')
    State.Remove(id)
    Config.Features.AdvancedCare = enabled
end)

test('V3 Basic care restores exact windows while V2 protection remains unchanged', function()
    local timestamp = Sonar.Time.Now()
    local basicWater = Sonar.ItemCatalog.byId.watering_can
    local basicFertilizer = Sonar.ItemCatalog.byId.fertilizer_organic
    local basicHoe = Sonar.ItemCatalog.byId.hand_hoe
    local basicSpray = Sonar.ItemCatalog.byId.pest_spray_organic
    local id, record = State.Add({
        crop_type = 'tomato', owner = 'owner-v3', zone = 'grapeseed_east', slot = 3,
        pos_x = 2238.0, pos_y = 5031.0, pos_z = 44.2, planted_at = timestamp,
        growth_time = 2400,
        data = { simulationVersion = 3, water = 60, health = 100,
            nutrients = Config.Crops.tomato.nutrients.optimalMin, weedCover = 20,
            pestPressure = 20, lastCare = timestamp },
    })
    Physiology.Water(record, basicWater.tool, basicWater, timestamp)
    equal(record.data.water, 100, 'Basic watering restores forty points')
    equal(record.data.waterProtectionStrength, 0, 'V3 Basic water has no residual protection')
    local nutrients = Physiology.Fertilize(record, basicFertilizer.consumable, basicFertilizer)
    equal(nutrients, Config.Crops.tomato.nutrients.optimalMin + 25,
        'Basic fertilizer restores one nutrient window')
    equal(record.data.nutrientProtectionStrength, 0, 'V3 Basic fertilizer has no residual protection')
    equal(Physiology.Weed(record, basicHoe.tool, basicHoe), 0, 'Basic hoe resets green weed pressure')
    equal(Physiology.TreatPests(record, basicSpray.consumable, basicSpray), 0,
        'Basic treatment resets green pest pressure')
    equal(record.data.pestProtectionStrength, 0, 'V3 Basic treatment has no residual protection')
    State.Remove(id)

    local legacyId, legacy = State.Add({
        crop_type = 'tomato', owner = 'owner-v2', zone = 'grapeseed_east', slot = 4,
        pos_x = 2239.0, pos_y = 5031.0, pos_z = 44.2, planted_at = timestamp,
        growth_time = 2400,
        data = { simulationVersion = 2, water = 60, health = 100, nutrients = 52,
            weedCover = 20, pestPressure = 20, lastCare = timestamp },
    })
    Physiology.Fertilize(legacy, basicFertilizer.consumable, basicFertilizer)
    equal(legacy.data.nutrientProtectionStrength, 0.2,
        'existing V2 fertilizer protection is preserved')
    State.Remove(legacyId)
end)

test('protection trajectories split exactly at expiry', function()
    local enabled = Config.Features.AdvancedCare
    local weeds = Config.Farming.ConditionEffects.Weeds
    local pests = Config.Farming.ConditionEffects.Pests
    Config.Features.AdvancedCare = true
    Config.Farming.ConditionEffects.Weeds = false
    Config.Farming.ConditionEffects.Pests = true

    local def = Config.Crops.carrot
    local record = {
        crop_type = 'carrot', planted_at = -100000, growth_time = 999999,
        data = {
            lastCare = 1000, water = 100, nutrients = 80, pestPressure = 10,
            nutrientProtectionStrength = 0.5, nutrientProtectionUntil = 1000 + 2 * 3600,
            pestProtectionStrength = 0.5, pestProtectionUntil = 1000 + 2 * 3600,
        },
    }
    local trajectory = Sonar.Conditions.Evaluate(record, 1000 + 4 * 3600)
    local expectedNutrients = Sonar.Utils.Clamp(80 - def.nutrients.decayPerHour * 3, 0, 100)
    equal(Sonar.Utils.Round(trajectory.nutrients, 4), Sonar.Utils.Round(expectedNutrients, 4), 'nutrient protection split')
    local pestRate = Config.Farming.AdvancedCare.PestGrowthPerHour * def.pests.susceptibility
    local expectedPests = Sonar.Utils.Clamp(10 + pestRate * 3, 0, 100)
    equal(Sonar.Utils.Round(trajectory.pestPressure, 4), Sonar.Utils.Round(expectedPests, 4), 'pest protection split')

    Config.Features.AdvancedCare = enabled
    Config.Farming.ConditionEffects.Weeds = weeds
    Config.Farming.ConditionEffects.Pests = pests
end)

test('item runtime selects lowest durability and breaks exact slot', function()
    local slots = {
        { slot = 8, count = 1, metadata = { durability = 80 } },
        { slot = 3, count = 1, metadata = { durability = 30 } },
    }
    local setSlot, setValue, removedSlot
    Bridge.Inventory.GetSlotsWithItem = function(_, item)
        return item == 'watering_can' and slots or {}
    end
    Bridge.Inventory.SetDurability = function(_, slot, value) setSlot, setValue = slot, value; return true end
    Bridge.Inventory.RemoveFromSlot = function(_, _, _, slot) removedSlot = slot; return true end

    local selected = assert(Items.Resolve(1, 'water', 'watering_can'))
    equal(selected.slot, 3, 'lowest durability slot selected')
    local consumed, broken = Items.Consume(1, selected)
    equal(consumed, true, 'tool use committed')
    equal(broken, false, 'tool remains')
    equal(setSlot, 3, 'exact slot durability updated')
    equal(Sonar.Utils.Round(setValue, 4), 25, 'one of twenty uses consumed')

    slots = { { slot = 9, count = 1, metadata = { durability = 5 } } }
    selected = assert(Items.Resolve(1, 'water', 'watering_can'))
    consumed, broken = Items.Consume(1, selected)
    equal(consumed, true, 'final use committed')
    equal(broken, true, 'tool broke')
    equal(removedSlot, 9, 'broken tool removed from exact slot')

    slots = {
        { slot = 10, count = 1, metadata = { durability = 0 } },
        { slot = 11, count = 1, metadata = { durability = 50 } },
    }
    selected = assert(Items.Resolve(1, 'water', 'watering_can'))
    equal(selected.slot, 11, 'zero durability tools are never offered')
    local options = Items.ListForAction(1, 'water')
    equal(options[1].usesRemaining, 10, 'menu excludes broken tool uses')
end)

test('state load fails closed on database errors', function()
    Database.LoadAllCrops = function() return nil, 'database unavailable' end
    local ok, err = State.LoadAll()
    equal(ok, false, 'load must fail')
    assert(tostring(err):find('database unavailable', 1, true), 'database error must propagate')
end)

test('state load rejects invalid persisted growth data', function()
    Database.LoadAllCrops = function()
        return {
            {
                id = '00000000-0000-4000-8000-000000000099',
                crop_type = 'carrot',
                pos_x = 2236.0,
                pos_y = 5031.0,
                pos_z = 44.2,
                planted_at = 1000,
                growth_time = 0,
            },
        }
    end
    local ok = State.LoadAll()
    equal(ok, false, 'invalid row must fail boot')
    equal(State.loaded, false, 'state remains unavailable')
end)

test('state load repairs stale spatial cells', function()
    Database.LoadAllCrops = function()
        return {
            {
                id = '00000000-0000-4000-8000-000000000001',
                crop_type = 'carrot',
                owner = 'owner-a',
                zone = 'grapeseed_east',
                slot = 1,
                cell = 'stale',
                pos_x = 2236.0,
                pos_y = 5031.0,
                pos_z = 44.2,
                planted_at = 1000,
                growth_time = 900,
                data = nil,
            },
        }
    end
    local ok, loaded = State.LoadAll()
    equal(ok, true, 'load should succeed')
    equal(loaded, 1, 'loaded count')
    equal(State.Get('00000000-0000-4000-8000-000000000001').cell, State.CellKey(2236.0, 5031.0), 'cell repaired')
    equal(State.dirty['00000000-0000-4000-8000-000000000001'], true, 'repair queued')
end)

dofile('server/modules/farming/lock.lua')

test('locks reject concurrent acquisition and release after errors', function()
    equal(Lock.Acquire('crop'), true, 'first lock')
    equal(Lock.Acquire('crop'), false, 'second lock')
    Lock.Release('crop')
    local ok = pcall(function()
        Lock.With('crop', function() error('expected') end)
    end)
    equal(ok, false, 'error propagated')
    equal(Lock.Acquire('crop'), true, 'lock released after error')
    Lock.Release('crop')
end)

dofile('server/modules/runtime/runtime.lua')

test('runtime gate enforces lifecycle, bucket and identifier', function()
    Runtime.SetStatus(Runtime.STATUS.BOOTING)
    equal(Runtime.GuardPlayer(1).reason, Sonar.Constants.REJECT.SERVICE_UNAVAILABLE, 'boot gate')

    Runtime.SetStatus(Runtime.STATUS.READY)
    equal(Runtime.GuardPlayer(1).ok, true, 'ready player')

    local originalBucket = GetPlayerRoutingBucket
    GetPlayerRoutingBucket = function() return 99 end
    equal(Runtime.GuardPlayer(1).reason, Sonar.Constants.REJECT.WRONG_INSTANCE, 'bucket gate')
    GetPlayerRoutingBucket = originalBucket

    local originalIdentifier = Bridge.GetIdentifier
    Bridge.GetIdentifier = function() return nil end
    equal(Runtime.GuardPlayer(1).reason, Sonar.Constants.REJECT.PLAYER_NOT_READY, 'identifier gate')
    Bridge.GetIdentifier = originalIdentifier
end)

dofile('server/modules/security/ratelimit.lua')

test('rate limit scopes are independent and refill lazily', function()
    Security.Release(1)
    for _ = 1, Config.Security.SubscriptionBucket.capacity do
        equal(Security.Consume(1, 1, 'subscribe'), true, 'subscription token')
    end
    equal(Security.Consume(1, 1, 'subscribe'), false, 'subscription limited')
    equal(Security.Consume(1, 1, 'action'), true, 'action scope unaffected')
    gameTimer = gameTimer + 1000
    equal(Security.Consume(1, 1, 'subscribe'), true, 'subscription refilled')
end)

test('database serializes nullable slots and reports failed transactions', function()
    local captured
    MySQL = {
        transaction = {
            await = function(queries)
                captured = queries
                return true
            end,
        },
    }

    dofile('server/modules/database/database.lua')
    local ok = Database.UpsertCrops({
        {
            id = '00000000-0000-4000-8000-000000000002',
            crop_type = 'carrot',
            cell = '1:1',
            pos_x = 1,
            pos_y = 2,
            pos_z = 3,
            planted_at = 1000,
            growth_time = 900,
        },
    })

    equal(ok, true, 'upsert succeeds')
    assert(captured[1].query:find('NULLIF%(%?, 0%)'), 'numeric NULLIF placeholder')
    equal(captured[1].values[5], 0, 'slot sentinel')
    equal(#captured[1].values, 14, 'dense parameter array')

    MySQL.transaction.await = function()
        return false
    end
    equal(Database.UpsertCrops({
        {
            id = '00000000-0000-4000-8000-000000000003',
            crop_type = 'carrot',
            cell = '1:1',
            pos_x = 1,
            pos_y = 2,
            pos_z = 3,
            planted_at = 1000,
            growth_time = 900,
        },
    }), false, 'failed transaction is reported')
end)

test('database rejects an empty but incompatible schema', function()
    local columns = {
        'id', 'crop_type', 'owner', 'zone', 'slot', 'cell',
        'pos_x', 'pos_y', 'pos_z', 'heading',
        'planted_at', 'growth_time', 'state', 'data',
    }

    MySQL.query = {
        await = function(sql)
            if sql:find('information_schema.COLUMNS', 1, true) then
                local rows = {}
                for _, name in ipairs(columns) do
                    rows[#rows + 1] = { COLUMN_NAME = name }
                end
                return rows
            end
            return {
                { COLUMN_NAME = 'zone', NON_UNIQUE = 0, SEQ_IN_INDEX = 1 },
                { COLUMN_NAME = 'slot', NON_UNIQUE = 0, SEQ_IN_INDEX = 2 },
            }
        end,
    }

    equal(Database.ValidateSchema(), true, 'complete schema')
    table.remove(columns)
    equal(Database.ValidateSchema(), false, 'missing data column')
end)

test('progression ledger and reservation constraints are idempotent', function()
    local function read(path)
        local file = assert(io.open(path, 'rb'))
        local value = file:read('*a')
        file:close()
        return value
    end
    local schema = read('server/modules/publicjob/database.lua')
    local progression = read('server/modules/progression/service.lua')
    local reservations = read('server/modules/reservations/service.lua')
    assert(schema:find('PRIMARY KEY (`operation_id`)', 1, true), 'XP operation ids must be unique')
    assert(schema:find('PRIMARY KEY (`field_id`)', 1, true), 'one active Field claim must be enforced')
    assert(schema:find('PRIMARY KEY (`identifier`)', 1, true), 'one active player link must be enforced')
    assert(progression:find('INSERT IGNORE INTO sfpj_xp_ledger', 1, true), 'XP awards must be idempotent')
    assert(reservations:find("Lock.With('reservation:player:'", 1, true), 'reservation acceptance must share a player lock')
end)

test('personal economy persists receipts and a recovery outbox', function()
    local function read(path)
        local file = assert(io.open(path, 'rb')); local value = file:read('*a'); file:close(); return value
    end
    local schema = read('server/modules/publicjob/database.lua')
    local market = read('server/modules/market/service.lua')
    local sell = read('server/modules/sell/service.lua')
    assert(schema:find('sfpj_economy_receipts', 1, true), 'economy receipts required')
    assert(schema:find('sfpj_economy_outbox', 1, true), 'economy outbox required')
    assert(market:find("Lock.With('market:global'", 1, true), 'Market stock mutations require a global lock')
    assert(sell:find("metadata.producer == identifier", 1, true), 'Sell must enforce producer ownership')
    assert(sell:find("metadata.resource == Sonar.Constants.RESOURCE", 1, true), 'Sell rejects foreign produce')
end)

local function versionedRecord(version, cropType, growthTime, plantedAt, values)
    values = values or {}
    values.water = values.water == nil and 100 or values.water
    values.health = values.health == nil and 100 or values.health
    values.spoilage = values.spoilage == nil and 0 or values.spoilage
    values.lastCare = values.lastCare or plantedAt
    local original = Config.Farming.NewCropSimulationVersion
    Config.Farming.NewCropSimulationVersion = version
    local data = Sonar.CropClock.NewData(cropType, values)
    Config.Farming.NewCropSimulationVersion = original
    return {
        id = cropType .. '-' .. tostring(growthTime),
        crop_type = cropType,
        planted_at = plantedAt,
        growth_time = growthTime,
        state = Sonar.Constants.CROP_STATE.PLANTED,
        data = data,
    }
end

local function v2Record(cropType, growthTime, plantedAt, values)
    return versionedRecord(2, cropType, growthTime, plantedAt, values)
end

local function v3Record(cropType, growthTime, plantedAt, values)
    return versionedRecord(3, cropType, growthTime, plantedAt, values)
end

test('V2 crop clock initializes normalized state and preserves rollback to V1', function()
    local original = Config.Farming.NewCropSimulationVersion
    Config.Farming.NewCropSimulationVersion = 2
    local data = Sonar.CropClock.NewData('tomato', {})
    equal(data.simulationVersion, 2, 'new crops opt into V2')
    equal(data.nutrients, 65, 'nutrients start at the crop optimal midpoint')
    equal(data.growthAdjustmentRatio, 0, 'growth adjustment starts neutral')

    Config.Farming.NewCropSimulationVersion = 1
    local legacy = Sonar.CropClock.NewData('tomato', {})
    equal(legacy.simulationVersion, 1, 'rollback creates legacy records without reinterpreting V2 crops')
    equal(legacy.nutrients, nil, 'legacy initialization remains unchanged')
    Config.Farming.NewCropSimulationVersion = original
end)

test('V3 crop clock uses prepared-soil nutrients without reinterpreting V2 crops', function()
    local v3 = v3Record('tomato', 2400, 100000)
    equal(v3.data.simulationVersion, 3, 'new crops opt into V3')
    equal(v3.data.nutrients, 77, 'V3 nutrients start at optimalMin plus one Basic window')
    assert(Sonar.CropClock.IsV3(v3), 'V3 discriminator')

    local v2 = v2Record('tomato', 2400, 100000)
    equal(v2.data.nutrients, 65, 'V2 nutrient initialization remains unchanged')
    assert(not Sonar.CropClock.IsV3(v2), 'V2 records must never enter V3 balance')
end)

test('V3 factor windows derive from 570 real seconds with staged first onset', function()
    local plantedAt = 100000
    local workload = Config.Farming.AdvancedCare.BasicWorkload
    local factors = {
        water = { value = 'water', boundary = 60 },
        nutrients = { value = 'nutrients', boundary = Config.Crops.tomato.nutrients.optimalMin },
        weeds = { value = 'weedCover', boundary = 20 },
        pests = { value = 'pestPressure', boundary = 20 },
    }
    for factor, expected in pairs(factors) do
        local values = {
            waterProtectionStrength = factor == 'water' and 0 or 1,
            waterProtectionUntil = plantedAt + 10000,
            nutrientProtectionStrength = factor == 'nutrients' and 0 or 1,
            nutrientProtectionUntil = plantedAt + 10000,
            weedProtectionStrength = factor == 'weeds' and 0 or 1,
            weedProtectionUntil = plantedAt + 10000,
            pestProtectionStrength = factor == 'pests' and 0 or 1,
            pestProtectionUntil = plantedAt + 10000,
        }
        local record = v3Record('tomato', 2400, plantedAt, values)
        local delay = workload.InitialDelaySeconds[factor]
        local before = Sonar.Conditions.Evaluate(record, plantedAt + delay)
        local initial = factor == 'water' and 100
            or factor == 'nutrients' and 77 or 0
        assert(math.abs(before[expected.value] - initial) < 0.000001,
            factor .. ' must not move before its first-round onset')
        local boundary = Sonar.Conditions.Evaluate(record,
            plantedAt + delay + workload.GreenWindowSeconds)
        assert(math.abs(boundary[expected.value] - expected.boundary) < 0.000001,
            factor .. ' must reach its green boundary at exactly 570 seconds')
    end
end)

test('V3 weed competition starts only after weeds leave green', function()
    local plantedAt, growthTime = 100000, Config.Crops.tomato.growthTime
    local common = {
        waterCareAt = plantedAt, nutrientCareAt = plantedAt,
        weedCareAt = plantedAt, pestCareAt = plantedAt,
        pestProtectionStrength = 1, pestProtectionUntil = plantedAt + 10000,
        nutrientProtectionStrength = 1, nutrientProtectionUntil = plantedAt + 10000,
    }
    local weedyValues, cleanValues = {}, {}
    for key, value in pairs(common) do weedyValues[key], cleanValues[key] = value, value end
    cleanValues.weedProtectionStrength, cleanValues.weedProtectionUntil = 1, plantedAt + 10000
    local weedy = v3Record('tomato', growthTime, plantedAt, weedyValues)
    local clean = v3Record('tomato', growthTime, plantedAt, cleanValues)
    local atBoundary = plantedAt + 570
    local weedyBoundary = Sonar.Conditions.Evaluate(weedy, atBoundary)
    local cleanBoundary = Sonar.Conditions.Evaluate(clean, atBoundary)
    assert(math.abs(weedyBoundary.water - cleanBoundary.water) < 0.000001,
        'green weeds must not shorten the water window')
    local afterBoundary = plantedAt + 690
    assert(Sonar.Conditions.Evaluate(weedy, afterBoundary).water
        < Sonar.Conditions.Evaluate(clean, afterBoundary).water,
        'weed competition must begin after pressure exceeds 20')
end)

test('V3 S24 Basic cadence tolerates 90 seconds and warns at 120 without Critical', function()
    local plantedAt = 100000
    local crops = { 'carrot', 'potato', 'lettuce', 'tomato' }
    local factors = {
        { key = 'water', careKey = 'waterCareAt', value = 'water', baseline = function() return 100 end },
        { key = 'nutrients', careKey = 'nutrientCareAt', value = 'nutrients', baseline = function(def)
            return math.min(def.nutrients.optimalMax, def.nutrients.optimalMin + 25)
        end },
        { key = 'weeds', careKey = 'weedCareAt', value = 'weedCover', baseline = function() return 0 end },
        { key = 'pests', careKey = 'pestCareAt', value = 'pestPressure', baseline = function() return 0 end },
    }
    local delays = { 0, 30, 60, 90, 120 }
    local layouts = {
        homogeneous = {},
        mixed = {},
    }
    for _, crop in ipairs(crops) do
        layouts.homogeneous[crop] = {}
        for slot = 1, 24 do layouts.homogeneous[crop][slot] = crop end
    end
    for slot = 1, 24 do layouts.mixed[slot] = crops[((slot - 1) % #crops) + 1] end

    local function verify(layout, label)
        for slot, crop in pairs(layout) do
            local def = Config.Crops[crop]
            for _, factor in ipairs(factors) do
                for _, delay in ipairs(delays) do
                    local values = {
                        waterProtectionStrength = factor.key == 'water' and 0 or 1,
                        waterProtectionUntil = plantedAt + 10000,
                        nutrientProtectionStrength = factor.key == 'nutrients' and 0 or 1,
                        nutrientProtectionUntil = plantedAt + 10000,
                        weedProtectionStrength = factor.key == 'weeds' and 0 or 1,
                        weedProtectionUntil = plantedAt + 10000,
                        pestProtectionStrength = factor.key == 'pests' and 0 or 1,
                        pestProtectionUntil = plantedAt + 10000,
                    }
                    values[factor.value] = factor.baseline(def)
                    values[factor.careKey] = plantedAt
                    local record = v3Record(crop, def.growthTime, plantedAt, values)
                    local at = plantedAt + 570 + delay
                    local trajectory = Sonar.Conditions.Evaluate(record, at)
                    local watchSeconds = trajectory.bandExposure.watch * def.growthTime
                    local criticalSeconds = trajectory.bandExposure.critical * def.growthTime
                    assert(criticalSeconds < 0.000001,
                        ('%s slot %s %s +%ss entered Critical'):format(label, slot, factor.key, delay))
                    assert(watchSeconds <= delay + 0.0001,
                        ('%s slot %s %s Watch exceeded accepted latency'):format(label, slot, factor.key))
                    if delay == 120 then assert(watchSeconds > 90, '120 seconds must produce a visible Watch warning') end
                    local condition = Physiology.Evaluate(record, at)
                    assert(condition.state ~= Sonar.Constants.CROP_STATE.DEAD,
                        'accepted latency must never cause sudden death')
                end
            end
        end
    end

    for crop, layout in pairs(layouts.homogeneous) do verify(layout, crop .. '-S24') end
    verify(layouts.mixed, 'mixed-S24')
end)

test('V3 timestamps remain deterministic across a persisted restart boundary', function()
    local plantedAt = 100000
    local record = v3Record('lettuce', Config.Crops.lettuce.growthTime, plantedAt, {
        water = 88, nutrients = 72, weedCover = 7, pestPressure = 4,
        lastCare = plantedAt + 180,
        waterCareAt = plantedAt + 180, nutrientCareAt = plantedAt + 180,
        weedCareAt = plantedAt + 180, pestCareAt = plantedAt + 180,
    })
    local function clone(value)
        if type(value) ~= 'table' then return value end
        local copy = {}
        for key, item in pairs(value) do copy[key] = clone(item) end
        return copy
    end
    local restored = clone(record)
    local at = plantedAt + 811
    local live = Physiology.Evaluate(record, at)
    local afterRestart = Physiology.Evaluate(restored, at)
    for _, key in ipairs({ 'water', 'health', 'nutrients', 'weedCover', 'pestPressure',
        'growthAdjustmentRatio', 'waterStressAccumulated', 'nutrientStressAccumulated',
        'pestDamageAccumulated', 'progress' }) do
        assert(math.abs((live[key] or 0) - (afterRestart[key] or 0)) < 0.000001,
            key .. ' changed after persistence restore')
    end
    for _, band in ipairs({ 'green', 'watch', 'critical' }) do
        assert(math.abs(live.bandExposure[band] - afterRestart.bandExposure[band]) < 0.000001,
            band .. ' exposure changed after persistence restore')
    end
end)

test('V2 biology is invariant across 20 minute 40 minute and 6 hour cycles', function()
    local plantedAt = 100000
    local durations = { 20 * 60, 40 * 60, 6 * 60 * 60 }
    local keys = { 'water', 'health', 'nutrients', 'weedCover', 'pestPressure',
        'growthAdjustmentRatio', 'waterStressAccumulated', 'nutrientStressAccumulated',
        'pestDamageAccumulated', 'progress' }
    local baseline
    for _, duration in ipairs(durations) do
        local condition = Physiology.Evaluate(v2Record('tomato', duration, plantedAt),
            plantedAt + duration * 0.30)
        if not baseline then baseline = condition else
            for _, key in ipairs(keys) do
                assert(math.abs((condition[key] or 0) - (baseline[key] or 0)) < 0.000001,
                    ('%s changes with growthTime'):format(key))
            end
        end
    end
end)

test('V2 physiology reuses one trajectory and memoizes historical maturity', function()
    local originalEvaluate = Sonar.Conditions.Evaluate
    local calls = 0
    Sonar.Conditions.Evaluate = function(...)
        calls = calls + 1
        return originalEvaluate(...)
    end

    local ok, err = pcall(function()
        local plantedAt, duration = 100000, 2400
        local growing = v2Record('tomato', duration, plantedAt)
        local at = plantedAt + duration * 0.20
        Physiology.Evaluate(growing, at)
        equal(calls, 1, 'physiology must integrate Conditions only once')

        local trajectory = originalEvaluate(growing, at)
        calls = 0
        Growth.Evaluate(growing, at, trajectory)
        equal(calls, 0, 'Growth must accept its caller precomputed trajectory')

        local mature = v2Record('tomato', duration, plantedAt, {
            waterProtectionStrength = 1, waterProtectionUntil = plantedAt + duration * 4,
            nutrientProtectionStrength = 1, nutrientProtectionUntil = plantedAt + duration * 4,
            weedProtectionStrength = 1, weedProtectionUntil = plantedAt + duration * 4,
            pestProtectionStrength = 1, pestProtectionUntil = plantedAt + duration * 4,
        })
        local matureAt = plantedAt + duration * 0.90
        local first = Physiology.Evaluate(mature, matureAt)
        assert(first.maturedAt, 'V2 maturity timestamp is derived')
        calls = 0
        local second = Physiology.Evaluate(mature, matureAt + 1)
        equal(calls, 1, 'repeated mature evaluation must not repeat the binary search')
        equal(second.maturedAt, first.maturedAt, 'historical maturity timestamp remains stable')
    end)
    Sonar.Conditions.Evaluate = originalEvaluate
    if not ok then error(err) end
end)

test('client target and render paths use bounded presentation caches', function()
    local function read(path)
        local file = assert(io.open(path, 'rb'))
        local value = file:read('*a')
        file:close()
        return value
    end
    local crops = read('client/modules/render/crops.lua')
    local slots = read('client/modules/zones/slots.lua')
    assert(crops:find('function Crops.InteractionState', 1, true), 'interaction snapshot cache is required')
    assert(crops:find('function Crops.VisualStage', 1, true), 'visual stage cache is required')
    assert(crops:find('spawn(id, Crops.VisualStage(id))', 1, true), 'render refresh must use cached stages')
    assert(not slots:find('Crops.Condition(', 1, true), 'ox_target predicates must not run physiology directly')
    assert(slots:find('Crops.InteractionState(cropId)', 1, true), 'ox_target must consume cached booleans')
end)

test('V2 protection duration and inspection windows scale with the selected crop', function()
    local plantedAt = 100000
    for _, duration in ipairs({ 1200, 2400, 21600 }) do
        local record = v2Record('tomato', duration, plantedAt)
        local effect = Sonar.ItemCatalog.byId.fertilizer_balanced.consumable
        equal(Sonar.CropClock.ProtectionSeconds(record, effect), duration * 0.18,
            'Plus protection covers 18 percent of the cycle')

        local now = plantedAt + duration * 0.50
        local payload = Sonar.Inspection.Build(record, now)
        equal(payload.timing.forecastSeconds, duration * 0.10,
            'diagnosis uses ten percent of the cycle')
        equal(payload.series.historyStart, now - duration * 0.25,
            'history uses twenty five percent of the cycle')
        equal(payload.series.forecastEnd, now, 'inspection curve remains historical through NOW only')
    end
end)

test('V2 unattended crops die inside their calibrated biological windows', function()
    local windows = {
        lettuce = { 0.25, 0.35 },
        tomato = { 0.32, 0.40 },
        carrot = { 0.50, 0.58 },
        potato = { 0.58, 0.65 },
    }
    local plantedAt = 100000
    for cropType, window in pairs(windows) do
        local duration = Config.Crops[cropType].growthTime
        local record = v2Record(cropType, duration, plantedAt)
        local deathRatio
        for index = 0, 1000 do
            local ratio = index / 1000
            local condition = Physiology.Evaluate(record, plantedAt + duration * ratio)
            if condition.health <= 0 then deathRatio = ratio break end
        end
        assert(deathRatio and deathRatio >= window[1] and deathRatio <= window[2],
            ('%s death ratio %.3f is outside %.2f..%.2f'):format(cropType, deathRatio or -1, window[1], window[2]))
        assert(Physiology.Evaluate(record, plantedAt + duration * deathRatio).progress < 1,
            cropType .. ' must die before maturity when abandoned')
    end
end)

test('V2 Green and Watch outcomes match normalized maturity and harvest targets', function()
    local plantedAt, duration = 100000, 2400
    local green = v2Record('tomato', duration, plantedAt, {
        plantScore = 100,
        waterProtectionStrength = 1, waterProtectionUntil = plantedAt + duration * 4,
        nutrientProtectionStrength = 1, nutrientProtectionUntil = plantedAt + duration * 4,
        weedProtectionStrength = 1, weedProtectionUntil = plantedAt + duration * 4,
        pestProtectionStrength = 1, pestProtectionUntil = plantedAt + duration * 4,
    })
    local greenCondition = Physiology.Evaluate(green, plantedAt + duration * (5 / 6))
    assert(math.abs(greenCondition.progress - 1) < 0.001, 'always Green matures at about 83.3 percent')
    local greenQuality = Quality.Resolve(Config.Quality.DefaultScore, greenCondition, { record = green })
    assert(greenQuality >= 90, 'always Green quality is at least 90')
    assert(Quality.ResolveProduction(green, greenCondition, greenQuality) >= 90,
        'always Green production is at least 90')

    local watch = v2Record('tomato', duration, plantedAt, {
        water = 50, nutrients = 47,
        waterProtectionStrength = 1, waterProtectionUntil = plantedAt + duration * 4,
        nutrientProtectionStrength = 1, nutrientProtectionUntil = plantedAt + duration * 4,
        weedProtectionStrength = 1, weedProtectionUntil = plantedAt + duration * 4,
        pestProtectionStrength = 1, pestProtectionUntil = plantedAt + duration * 4,
    })
    local watchCondition = Physiology.Evaluate(watch, plantedAt + duration * 1.12)
    assert(watchCondition.progress >= 1, 'managed Watch matures within 112 percent of the cycle')
    local watchQuality = Quality.Resolve(Config.Quality.DefaultScore, watchCondition, { record = watch })
    local watchProduction = Quality.ResolveProduction(watch, watchCondition, watchQuality)
    assert(watchQuality >= 55 and watchQuality <= 75, 'Watch quality remains within 55..75')
    assert(watchProduction >= 50 and watchProduction <= 75, 'Watch production remains within 50..75')
end)

test('V2 material tiers cover the tomato cycle within seven four and two rounds', function()
    local def = Config.Crops.tomato
    local matureRatio = 1 / (1 + Config.Farming.AdvancedCare.Cycle.GreenGrowthBonus)
    local caps = { basic = 7, plus = 4, pro = 2 }
    local rates = {
        water = def.cycle.waterLoss,
        fertilize = def.cycle.nutrientLoss,
        weed = def.cycle.weedGrowth,
        treat_pest = def.cycle.pestGrowth,
    }
    local baseDemand = {
        water = rates.water * matureRatio,
        fertilize = rates.fertilize * matureRatio,
        weed = rates.weed * matureRatio,
        treat_pest = rates.treat_pest * math.max(0, matureRatio - def.cycle.pestOnset),
    }
    for _, item in ipairs(Sonar.ItemCatalog.market) do
        local effect = item.tool or item.consumable
        if effect and rates[effect.action] then
            local immediate = tonumber(effect.amount or effect.weedRemoval or effect.reduction) or 0
            local prevented = rates[effect.action] * (tonumber(effect.protectionCycleRatio) or 0)
                * (tonumber(effect.protectionStrength) or 0)
            local applications = math.ceil(baseDemand[effect.action] / (immediate + prevented) - 0.000001)
            assert(applications <= caps[item.tier],
                ('%s needs %d applications, above the %s cap'):format(item.id, applications, item.tier))
        end
    end
end)

dofile('server/modules/progression/service.lua')

test('public progression curve unlocks and perks match the v1 contract', function()
    equal(Progression.Threshold(1), 0, 'level one threshold')
    equal(Progression.Threshold(10), 17820, 'level ten threshold')
    equal(Progression.Threshold(20), 79420, 'level twenty threshold')
    equal(Progression.LevelForXp(17819), 9, 'level ten lower boundary')
    equal(Progression.LevelForXp(17820), 10, 'level ten unlock boundary')
    equal(Progression.LevelForXp(79420), 20, 'maximum level boundary')
    equal(Progression.Perks(5).rentDiscount, 0.05, 'level five rent discount')
    equal(Progression.Perks(10).sellBonus, 0.07, 'level ten sell bonus')
    equal(Progression.Perks(20).rentDiscount, 0.25, 'level twenty rent discount')
    equal(Config.Progression.ItemTierLevels.plus, 4, 'Plus unlock')
    equal(Config.Progression.ItemTierLevels.pro, 8, 'Pro unlock')
    equal(Config.Progression.FieldSizeLevels.M, 5, 'medium Field unlock')
    equal(Config.Progression.FieldSizeLevels.L, 10, 'large Field unlock')
end)

test('reservation economy and expiry settings match the v1 contract', function()
    local expected = {
        S = { [1] = 300, [3] = 800, [6] = 1500, [8] = 1900 },
        M = { [1] = 480, [3] = 1300, [6] = 2400, [8] = 3000 },
        L = { [1] = 720, [3] = 1950, [6] = 3600, [8] = 4500 },
    }
    equal(table.concat(Config.Reservations.PlanOrder, ','), '1,3,6,8', 'rental plan order')
    for size, prices in pairs(expected) do
        for hours, price in pairs(prices) do
            equal(Config.Reservations.Plans[hours], hours * 3600, size .. ' plan duration')
            equal(Config.Reservations.Prices[size][hours], price,
                ('%s %d-hour price'):format(size, hours))
        end
    end
    equal(Config.Reservations.MaximumRemainingSeconds, 28800, 'maximum remaining rental')
    equal(Config.Reservations.GraceSeconds, 900, 'grace duration')
    equal(Config.Reservations.GraceSurcharge, 0.25, 'grace surcharge')
    equal(Config.Reservations.SameFieldCooldownSeconds, 1800, 'same Field cooldown')
    equal(Config.Reservations.InviteTtlSeconds, 60, 'invite expiry')
    equal(Config.Reservations.MaxGuests, 3, 'co-op guest cap')
    equal(Config.Job.NearbyInviteDistance, 15.0, 'invite proximity')
end)

test('short rentals apply discounts grace and legacy remaining-time rules exactly', function()
    local paid, base = Sonar.Rentals.Price('S', 3, 0.05, false)
    equal(base, 800, 'S three-hour base')
    equal(paid, 760, 'level discount rounds once')
    equal(Sonar.Rentals.Price('S', 3, 0.05, true), 950,
        'grace surcharge applies after the level discount')
    equal(Sonar.Rentals.Price('S', 12, 0, false), nil, 'legacy plan cannot be newly selected')

    local allowed, expiry = Sonar.Rentals.CanExtend(1000, 1000, 8)
    equal(allowed, true, 'exactly eight remaining hours is allowed')
    equal(expiry, 1000 + 8 * 3600, 'resulting eight-hour expiry')
    allowed = Sonar.Rentals.CanExtend(1001, 1000, 8)
    equal(allowed, false, 'remaining time may not exceed eight hours')
    allowed, expiry = Sonar.Rentals.CanExtend(1000 + 12 * 3600, 1000, 1)
    equal(allowed, false, 'legacy reservation above the cap cannot extend')
    equal(expiry, 1000 + 13 * 3600, 'legacy expiry is inspected, never shortened')
end)

test('personal market and Sell settings match the v1 contract', function()
    equal(Config.Market.MaxLines, 10, 'cart line cap')
    equal(Config.Market.MaxLineQuantity, 99, 'per-line quantity cap')
    equal(Config.Market.TabletPrice, 1500, 'tablet price')
    equal(Config.Market.Stock.plus.capacity, 20, 'Plus stock capacity')
    equal(Config.Market.Stock.plus.restockAmount, 5, 'Plus restock quantity')
    equal(Config.Market.Stock.plus.restockSeconds, 1800, 'Plus restock interval')
    equal(Config.Market.Stock.pro.capacity, 10, 'Pro stock capacity')
    equal(Config.Market.Stock.pro.restockAmount, 2, 'Pro restock quantity')
    equal(Config.Market.Stock.pro.restockSeconds, 3600, 'Pro restock interval')
    equal(Config.Sell.BasePrices.carrot, 12, 'carrot price')
    equal(Config.Sell.BasePrices.potato, 10, 'potato price')
    equal(Config.Sell.BasePrices.lettuce, 14, 'lettuce price')
    equal(Config.Sell.BasePrices.tomato, 16, 'tomato price')
    equal(Config.Sell.TierMultipliers.premium, 2.0, 'Premium multiplier')
    equal(Config.Features.Minigames, false, 'v1 minigames remain disabled')
end)

test('public callbacks retain server-side authority and recovery hooks', function()
    local function read(path)
        local file = assert(io.open(path, 'rb')); local value = file:read('*a'); file:close(); return value
    end
    local guard = read('server/modules/publicjob/database.lua')
    local hub = read('server/modules/hub/runtime.lua')
    local reservations = read('server/modules/reservations/service.lua')
    local fields = read('server/modules/fields/service.lua')
    local market = read('server/modules/market/service.lua')
    local sell = read('server/modules/sell/service.lua')
    assert(guard:find('job.name ~= Config.Job.Name', 1, true), 'job must be checked server-side')
    assert(guard:find('Config.Job.RequireDuty and not job.onDuty', 1, true), 'duty must be checked server-side')
    assert(hub:find("session.surface == 'tablet'", 1, true), 'tablet sessions must be distinguished')
    assert(hub:find('Bridge.Inventory.HasItem', 1, true), 'tablet ownership must be revalidated')
    assert(hub:find("session.surface ~= 'sell'", 1, true), 'sale confirmation requires the Sell surface')
    assert(reservations:find("status='departing'", 1, true), 'departing co-op state must persist')
    assert(reservations:find("return nil, 'reservation_grace'", 1, true), 'planting must stop in grace')
    assert(reservations:find('return MySQL.update.await([[INSERT INTO sfpj_economy_operations', 1, true),
        'reservation operation insert result must drive idempotency')
    assert(fields:find('reservation = overview.reservation', 1, true),
        'Field Detail may expose only the authenticated viewer own participation')
    assert(fields:find('local claim = Reservations.GetByField(field.id)', 1, true)
        and not fields:find('owner_identifier', 1, true),
        'Field Detail must never disclose another holder identity')
    assert(market:find('sfpj_economy_outbox', 1, true), 'Market compensation must use the outbox')
    assert(sell:find('metadata.producer == identifier', 1, true), 'Sell must enforce producer ownership')
    assert(sell:find('metadata.resource == Sonar.Constants.RESOURCE', 1, true), 'Sell must reject foreign produce')
end)

test('release critical recovery and client permissions stay fail closed', function()
    local function read(path)
        local file = assert(io.open(path, 'rb')); local value = file:read('*a'); file:close(); return value
    end
    local database = read('server/modules/publicjob/database.lua')
    local progression = read('server/modules/progression/service.lua')
    local reservations = read('server/modules/reservations/service.lua')
    local fields = read('server/modules/fields/service.lua')
    local sell = read('server/modules/sell/service.lua')
    local slots = read('client/modules/zones/slots.lua')
    local hub = read('client/modules/hub/controller.lua')
    local purgeDelete = assert(reservations:find('DELETE FROM sfpj_crops WHERE id IN', 1, true))
    local purgeState = assert(reservations:find('State.Remove(crop.id)', 1, true))
    assert(purgeDelete < purgeState, 'persistent crop deletion must commit before hot-state removal')
    assert(reservations:find('tonumber(reservation.expires_at)', 1, true)
        and reservations:find("Reservations.Purge(reservation.id, 'grace_expired')", 1, true),
        'restart grace must derive from original expiry and purge elapsed grace')
    assert(progression:find('MySQL.transaction.await({', 1, true)
        and progression:find('UPDATE sfpj_players SET total_xp=total_xp+?', 1, true),
        'XP ledger and total update must share one transaction')
    assert(database:find("'finalize_operation'", 1, true)
        and database:find('function PublicJobEconomy.ReconcileFinalizations', 1, true),
        'receipt finalization must have a durable recovery path')
    assert(sell:find("status='processing'", 1, true), 'bank credits must be claimed before external mutation')
    assert(fields:find('local participates = link and link.field_id == id', 1, true),
        'slot topology must stream only to active Field participants')
    assert(slots:find("slot.memberStatus == 'active'", 1, true)
        and slots:find('crop and crop.isMine', 1, true),
        'client target affordances must mirror active/departing ownership rules')
    assert(hub:find("payload.scope == 'field'", 1, true) and hub:find('Sync.RefreshNow()', 1, true),
        'reservation invalidation must refresh the gameplay subscription')
end)

print(('All %d tests passed.'):format(passed))
