-- Deterministic V3 S24 balance acceptance. Run from the resource root with:
--   lua scripts/simulate_s24.lua

function vec3(x, y, z) return { x = x, y = y, z = z } end
function GetCurrentResourceName() return 'sonar_farm_publicjob' end
function IsDuplicityVersion() return true end

Logger = { Info = function() end, Warn = function() end }

dofile('config/config.lua')
dofile('config/crops.lua')
dofile('shared/constants.lua')
dofile('shared/utils.lua')
dofile('shared/time.lua')
dofile('shared/crop_clock.lua')
dofile('shared/conditions.lua')
dofile('shared/growth.lua')
dofile('shared/physiology.lua')
dofile('server/modules/farming/quality.lua')

local plantedAt = 100000
local cropNames = { 'carrot', 'potato', 'lettuce', 'tomato' }
local delays = { 0, 30, 60, 90, 120 }

local function record(cropType, slot)
    local def = Config.Crops[cropType]
    return {
        id = ('simulation:%s:%d'):format(cropType, slot),
        crop_type = cropType,
        planted_at = plantedAt,
        growth_time = def.growthTime,
        state = Sonar.Constants.CROP_STATE.PLANTED,
        data = Sonar.CropClock.NewData(cropType, {
            simulationVersion = 3,
            water = 100,
            weedCover = 0,
            pestPressure = 0,
            lastCare = plantedAt,
            waterCareAt = plantedAt,
            nutrientCareAt = plantedAt,
            weedCareAt = plantedAt,
            pestCareAt = plantedAt,
        }),
    }
end

local function layoutFor(cropType)
    local output = {}
    for slot = 1, 24 do output[slot] = cropType end
    return output
end

local layouts = {}
for _, cropType in ipairs(cropNames) do
    layouts[#layouts + 1] = { name = cropType, slots = layoutFor(cropType) }
end
local mixed = {}
for slot = 1, 24 do mixed[slot] = cropNames[((slot - 1) % #cropNames) + 1] end
layouts[#layouts + 1] = { name = 'mixed', slots = mixed }

for _, layout in ipairs(layouts) do
    for _, delay in ipairs(delays) do
        local maximumWatch, maximumCritical, minimumQuality = 0, 0, 100
        for slot, cropType in ipairs(layout.slots) do
            local crop = record(cropType, slot)
            local at = plantedAt + Config.Farming.AdvancedCare.BasicWorkload.GreenWindowSeconds + delay
            local condition = Physiology.Evaluate(crop, at)
            local watch = condition.bandExposure.watch * crop.growth_time
            local critical = condition.bandExposure.critical * crop.growth_time
            local quality = Quality.Resolve(Config.Quality.DefaultScore, condition, { record = crop })
            maximumWatch = math.max(maximumWatch, watch)
            maximumCritical = math.max(maximumCritical, critical)
            minimumQuality = math.min(minimumQuality, quality)
            assert(condition.state ~= Sonar.Constants.CROP_STATE.DEAD, 'sudden death')
        end
        if delay <= 90 then
            assert(maximumWatch <= delay + 0.001, 'Watch exceeded accepted latency')
            assert(maximumCritical < 0.001, 'Critical before 90-second tolerance')
        else
            assert(maximumWatch > 90, '120 seconds must present a Watch warning')
            assert(maximumCritical < 0.001, '120 seconds must not cause sudden Critical')
        end
        if delay == 0 then assert(minimumQuality >= 70, 'ideal Basic cadence must remain Fine or Premium') end
        print(('%-8s delay=%3ds watch<=%5.1fs critical=%3.1fs quality>=%4.1f')
            :format(layout.name, delay, maximumWatch, maximumCritical, minimumQuality))
    end
end

print('S24 V3 simulation: passed')
