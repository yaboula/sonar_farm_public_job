-- Persistent personal farming progression.

Progression = Progression or {}

local function encode(value) return json.encode(value or {}) end

function Progression.Threshold(level)
    level = math.max(1, math.min(Config.Progression.MaxLevel, tonumber(level) or 1))
    return math.floor(Config.Progression.CurveCoefficient * ((level - 1) ^ 2) + 0.5)
end

function Progression.LevelForXp(xp)
    xp = math.max(0, tonumber(xp) or 0)
    local level = 1
    for candidate = 2, Config.Progression.MaxLevel do
        if xp < Progression.Threshold(candidate) then break end
        level = candidate
    end
    return level
end

function Progression.Perks(level)
    local result = { rentDiscount = 0, sellBonus = 0 }
    for _, entry in ipairs(Config.Progression.Perks or {}) do
        if level >= entry.level then result = { rentDiscount = entry.rentDiscount, sellBonus = entry.sellBonus } end
    end
    return result
end

function Progression.Get(identifier)
    if not identifier then return nil end
    MySQL.insert.await('INSERT IGNORE INTO sfpj_players (identifier,total_xp) VALUES (?,0)', { identifier })
    local xp = tonumber(MySQL.scalar.await('SELECT total_xp FROM sfpj_players WHERE identifier=?', { identifier })) or 0
    local level = Progression.LevelForXp(xp)
    local nextLevel = math.min(Config.Progression.MaxLevel, level + 1)
    local perks = Progression.Perks(level)
    return {
        identifier = identifier, xp = xp, level = level, maxLevel = Config.Progression.MaxLevel,
        levelStartXp = Progression.Threshold(level),
        nextLevelXp = level == Config.Progression.MaxLevel and xp or Progression.Threshold(nextLevel),
        rentDiscount = perks.rentDiscount, sellBonus = perks.sellBonus,
        unlocks = {
            plus = level >= Config.Progression.ItemTierLevels.plus,
            pro = level >= Config.Progression.ItemTierLevels.pro,
            medium = level >= Config.Progression.FieldSizeLevels.M,
            large = level >= Config.Progression.FieldSizeLevels.L,
        },
    }
end

function Progression.ForSource(source)
    return Progression.Get(Bridge.GetIdentifier(source))
end

function Progression.CanUseTier(identifier, tier)
    local required = Config.Progression.ItemTierLevels[tier or 'basic'] or 1
    local snapshot = Progression.Get(identifier)
    return snapshot and snapshot.level >= required, required, snapshot
end

function Progression.CanReserveSize(identifier, sizeClass)
    local required = Config.Progression.FieldSizeLevels[sizeClass or 'S'] or 1
    local snapshot = Progression.Get(identifier)
    return snapshot and snapshot.level >= required, required, snapshot
end

function Progression.Award(identifier, operationId, action, cropId, amount, payload)
    amount = math.max(0, math.floor(tonumber(amount) or 0))
    if not identifier or not operationId or amount == 0 then return false end
    Progression.Get(identifier)
    local inserted = MySQL.update.await([[INSERT IGNORE INTO sfpj_xp_ledger
        (operation_id,identifier,action,crop_id,amount,payload) VALUES (?,?,?,?,?,?)]],
        { operationId, identifier, action, cropId, amount, encode(payload) })
    if tonumber(inserted) ~= 1 then return false end
    MySQL.update.await('UPDATE sfpj_players SET total_xp=total_xp+? WHERE identifier=?', { amount, identifier })
    local source = PublicJob.SourceForIdentifier(identifier)
    if source then TriggerClientEvent('sonar_farm_publicjob:xpAwarded', source, Progression.Get(identifier), amount, action) end
    return true
end

function Progression.HarvestXp(cropType, tier)
    local crop = Config.Crops[cropType]
    local base = crop and tonumber(crop.xpReward) or 0
    local multiplier = Config.Progression.QualityXpMultipliers[tier] or 1
    return math.max(1, math.floor(base * multiplier + 0.5))
end

function Progression.Set(identifier, xp, operationId)
    xp = math.max(0, math.floor(tonumber(xp) or 0))
    MySQL.insert.await([[INSERT INTO sfpj_players (identifier,total_xp) VALUES (?,?)
        ON DUPLICATE KEY UPDATE total_xp=VALUES(total_xp)]], { identifier, xp })
    MySQL.insert.await([[INSERT IGNORE INTO sfpj_xp_ledger
        (operation_id,identifier,action,amount,payload) VALUES (?,?, 'admin_set',0,?)]],
        { operationId or Sonar.Utils.Uuid(), identifier, encode({ totalXp = xp }) })
    return Progression.Get(identifier)
end
