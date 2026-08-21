-- Central produce buyer. Only buys this resource's produce from its producer.

Sell = Sell or {}
local function encode(value) return json.encode(value or {}) end

local productToCrop = {}
for cropType, crop in pairs(Config.Crops or {}) do productToCrop[crop.productItem] = cropType end

local function eligible(source, identifier)
    local groups = {}
    for itemId, cropType in pairs(productToCrop) do
        for _, slot in pairs(Bridge.Inventory.GetSlotsWithItem(source, itemId) or {}) do
            local metadata = slot.metadata or {}
            local tier = tostring(metadata._tier or metadata.tier or 'standard'):lower()
            if metadata.resource == Sonar.Constants.RESOURCE and metadata.producer == identifier
                and Config.Sell.TierMultipliers[tier] then
                local key = cropType .. ':' .. tier
                local group = groups[key] or { key = key, cropType = cropType, itemId = itemId,
                    tier = tier, quantity = 0, slots = {} }
                local count = tonumber(slot.count) or 0
                group.quantity = group.quantity + count
                group.slots[#group.slots + 1] = { slot = tonumber(slot.slot), count = count, metadata = metadata }
                groups[key] = group
            end
        end
    end
    return groups
end

local function quote(groups, selections, bonus)
    local lines, total = {}, 0
    for key, quantity in pairs(selections) do
        local group = groups[key]
        quantity = math.floor(tonumber(quantity) or 0)
        if not group or quantity < 1 or quantity > group.quantity then return nil, 'invalid_quantity' end
        local base = Config.Sell.BasePrices[group.cropType]
        local multiplier = Config.Sell.TierMultipliers[group.tier]
        local subtotal = math.floor(quantity * base * multiplier * (1 + bonus) + 0.5)
        lines[#lines + 1] = { key = key, cropType = group.cropType, itemId = group.itemId,
            tier = group.tier, quantity = quantity, unitBase = base, subtotal = subtotal }
        total = total + subtotal
    end
    if #lines == 0 then return nil, 'nothing_to_sell' end
    table.sort(lines, function(a, b) return a.key < b.key end)
    return { lines = lines, total = total, bonus = bonus }
end

function Sell.Load(source)
    local actor, reason = PublicJob.Guard(source)
    if not actor then return nil, reason end
    local groups, progress, output = eligible(source, actor.identifier), Progression.Get(actor.identifier), {}
    for _, group in pairs(groups) do output[#output + 1] = { key = group.key, cropType = group.cropType,
        itemId = group.itemId, tier = group.tier, quantity = group.quantity,
        basePrice = Config.Sell.BasePrices[group.cropType], multiplier = Config.Sell.TierMultipliers[group.tier],
        unitPrice = math.floor(Config.Sell.BasePrices[group.cropType] * Config.Sell.TierMultipliers[group.tier]
            * (1 + progress.sellBonus) + 0.5) } end
    table.sort(output, function(a, b) return a.key < b.key end)
    return { groups = output, sellBonus = progress.sellBonus, progression = progress,
        bankBalance = tonumber(Bridge.GetMoney(source, 'bank')) or 0 }
end

function Sell.Preview(source, selections, sellAll)
    local actor, reason = PublicJob.Guard(source)
    if not actor then return nil, reason end
    local groups, progress = eligible(source, actor.identifier), Progression.Get(actor.identifier)
    if sellAll then selections = {}; for key, group in pairs(groups) do selections[key] = group.quantity end end
    return quote(groups, selections or {}, progress.sellBonus)
end

function Sell.Confirm(source, input)
    local actor, reason = PublicJob.Guard(source)
    if not actor then return { ok = false, reason = reason } end
    input = input or {}
    local ped, buyer = GetPlayerPed(source), Config.Sell.Buyer.coords
    local coords = ped and ped > 0 and GetEntityCoords(ped) or nil
    if not coords or #(coords - buyer) > Config.Sell.InteractionDistance then
        return { ok = false, reason = 'presence_required' }
    end
    local operationId = tostring(input.operationId or Sonar.Utils.Uuid())
    local acquired, result = Lock.With('sell:' .. actor.identifier, function()
        local replay = MySQL.single.await("SELECT status,amount FROM sfpj_economy_operations WHERE id=? AND identifier=? AND kind='sell'",
            { operationId, actor.identifier })
        if replay then return { ok = PublicJobEconomy.IsFulfilled(replay.status), reason = replay.status,
            total = tonumber(replay.amount), replay = true } end
        local groups, progress = eligible(source, actor.identifier), Progression.Get(actor.identifier)
        local selections = input.selections or {}
        if input.sellAll then selections = {}; for key, group in pairs(groups) do selections[key] = group.quantity end end
        local preview, invalid = quote(groups, selections, progress.sellBonus)
        if not preview then return { ok = false, reason = invalid } end
        local inserted = MySQL.update.await([[INSERT IGNORE INTO sfpj_economy_operations
            (id,identifier,kind,status,amount,payload) VALUES (?,?,'sell','prepared',?,?)]],
            { operationId, actor.identifier, preview.total, encode(preview) })
        if tonumber(inserted) ~= 1 then return { ok = false, reason = 'operation_conflict' } end
        local removed = {}
        for _, line in ipairs(preview.lines) do
            local remaining = line.quantity
            for _, slot in ipairs(groups[line.key].slots) do
                if remaining <= 0 then break end
                local take = math.min(remaining, slot.count)
                if not Bridge.Inventory.RemoveFromSlot(source, line.itemId, take, slot.slot, slot.metadata) then
                    for _, value in ipairs(removed) do Bridge.Inventory.AddItem(source, value.itemId, value.count, value.metadata) end
                    MySQL.update.await("UPDATE sfpj_economy_operations SET status='failed',last_error='inventory_changed' WHERE id=?", { operationId })
                    return { ok = false, reason = 'inventory_changed' }
                end
                removed[#removed + 1] = { itemId = line.itemId, count = take, metadata = slot.metadata }
                remaining = remaining - take
            end
        end
        if not Bridge.CreditMoney(actor.identifier, 'bank', preview.total, 'Produce sale', operationId) then
            MySQL.transaction.await({
                { query = "UPDATE sfpj_economy_operations SET status='credit_pending',last_error='bank_credit_failed' WHERE id=?", values = { operationId } },
                { query = [[INSERT IGNORE INTO sfpj_economy_outbox (id,operation_id,action,payload)
                    VALUES (?,?,'bank_credit',?)]], values = { Sonar.Utils.Uuid(), operationId,
                    encode({ identifier = actor.identifier, amount = preview.total, reason = 'Produce sale' }) } },
            })
            return { ok = false, reason = 'sale_pending', operationId = operationId }
        end
        MySQL.update.await("UPDATE sfpj_economy_operations SET status='credited',payload=?,last_error=NULL WHERE id=?",
            { encode(preview), operationId })
        PublicJobEconomy.Finalize(operationId)
        if HubRuntime and HubRuntime.Invalidate then
            HubRuntime.Invalidate(source, { scope = 'sell', reason = 'sale_completed' })
        end
        return { ok = true, operationId = operationId, total = preview.total, receipt = preview }
    end)
    return acquired and result or { ok = false, reason = 'operation_in_progress' }
end

function Sell.Reconcile()
    PublicJobEconomy.ReconcileFinalizations(Sonar.Time.Now())
    for _, row in ipairs(MySQL.query.await([[SELECT o.id,o.operation_id,o.payload FROM sfpj_economy_outbox o
        WHERE o.status='pending' AND o.action='bank_credit' AND o.next_attempt_at<=? ORDER BY o.created_at LIMIT 25]],
        { Sonar.Time.Now() }) or {}) do
        local claimed = MySQL.update.await([[UPDATE sfpj_economy_outbox SET status='processing',attempts=attempts+1
            WHERE id=? AND status='pending']], { row.id })
        if tonumber(claimed) == 1 then
            local ok, payload = pcall(json.decode, row.payload or '')
            payload = ok and payload or {}
            if payload.identifier and Bridge.CreditMoney(payload.identifier, 'bank', tonumber(payload.amount) or 0,
                payload.reason or 'Economy reconciliation', row.operation_id .. ':reconcile') then
                local operation = MySQL.single.await('SELECT kind FROM sfpj_economy_operations WHERE id=?', { row.operation_id })
                local nextStatus = operation and operation.kind == 'sell' and 'credited' or 'compensated'
                local committed = MySQL.transaction.await({
                    { query = "UPDATE sfpj_economy_outbox SET status='completed',last_error=NULL WHERE id=? AND status='processing'",
                      values = { row.id } },
                    { query = 'UPDATE sfpj_economy_operations SET status=?,last_error=NULL WHERE id=?',
                      values = { nextStatus, row.operation_id } },
                })
                if committed == true and nextStatus == 'credited' then PublicJobEconomy.Finalize(row.operation_id) end
            else
                MySQL.update.await([[UPDATE sfpj_economy_outbox SET status='pending',last_error='bank_credit_failed',
                    next_attempt_at=? WHERE id=? AND status='processing']], { Sonar.Time.Now() + 30, row.id })
            end
        end
    end
end

function Sell.Init()
    local ambiguous = tonumber(MySQL.scalar.await([[SELECT COUNT(*) FROM sfpj_economy_outbox
        WHERE status='processing' AND action='bank_credit']])) or 0
    if ambiguous > 0 then
        Logger.Warn(('%d bank credit outbox row(s) require transaction-log review before retry.'):format(ambiguous), 'economy')
    end
    Sell.Reconcile()
    return true
end
