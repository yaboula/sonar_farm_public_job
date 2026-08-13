-- Personal Market with global Plus/Pro stock and compensated purchases.

Market = Market or {}
local function encode(value) return json.encode(value or {}) end
local function now() return Sonar.Time.Now() end

local function marketById(id)
    for _, market in ipairs(Config.Market.Markets or {}) do if market.id == id then return market end end
end

local function nearMarket(source, market)
    if not market then return false end
    local ped = GetPlayerPed(source)
    if not ped or ped <= 0 then return false end
    return Sonar.Utils.IsWithin(GetEntityCoords(ped), market.coords,
        Config.Market.InteractionDistance + (market.radius or 0))
end

local function stockRows()
    local output = { basic = math.huge }
    for _, row in ipairs(MySQL.query.await('SELECT tier,quantity,last_restock_at FROM sfpj_market_stock') or {}) do
        output[row.tier] = tonumber(row.quantity) or 0
    end
    return output
end

local function operation(id, identifier, amount, payload)
    return MySQL.update.await([[INSERT IGNORE INTO sfpj_economy_operations
        (id,identifier,kind,status,amount,payload) VALUES (?,?,'market','prepared',?,?)]],
        { id, identifier, amount, encode(payload) })
end

local function compensate(identifier, amount, id, reason)
    if Bridge.CreditMoney(identifier, 'bank', amount, 'Market refund', id .. ':refund') then
        MySQL.update.await("UPDATE sfpj_economy_operations SET status='compensated',last_error=? WHERE id=?", { reason, id })
    else
        MySQL.transaction.await({
            { query = "UPDATE sfpj_economy_operations SET status='compensation_pending',last_error=? WHERE id=?", values = { reason, id } },
            { query = [[INSERT IGNORE INTO sfpj_economy_outbox (id,operation_id,action,payload)
                VALUES (?,?,'bank_credit',?)]], values = { Sonar.Utils.Uuid(), id,
                encode({ identifier = identifier, amount = amount, reason = 'Market refund' }) } },
        })
    end
end

function Market.Restock(timestamp)
    timestamp = tonumber(timestamp) or now()
    for tier, config in pairs(Config.Market.Stock or {}) do
        local row = MySQL.single.await('SELECT quantity,last_restock_at FROM sfpj_market_stock WHERE tier=?', { tier })
        if not row then
            MySQL.insert.await('INSERT IGNORE INTO sfpj_market_stock (tier,quantity,last_restock_at) VALUES (?,?,?)',
                { tier, config.capacity, timestamp })
        else
            local elapsed = math.max(0, timestamp - (tonumber(row.last_restock_at) or timestamp))
            local intervals = math.floor(elapsed / config.restockSeconds)
            if intervals > 0 then
                local quantity = math.min(config.capacity, tonumber(row.quantity) + intervals * config.restockAmount)
                MySQL.update.await('UPDATE sfpj_market_stock SET quantity=?,last_restock_at=? WHERE tier=?',
                    { quantity, tonumber(row.last_restock_at) + intervals * config.restockSeconds, tier })
            end
        end
    end
end

function Market.Init() Market.Restock(now()); return true end

function Market.Load(source)
    local actor, reason = PublicJob.Guard(source)
    if not actor then return nil, reason end
    Market.Restock(now())
    local progress, stocks, products = Progression.Get(actor.identifier), stockRows(), {}
    for _, item in ipairs(Sonar.ItemCatalog.market) do
        local required = Config.Progression.ItemTierLevels[item.tier or 'basic'] or 1
        products[#products + 1] = { id = item.id, label = item.label, description = item.description,
            category = item.category, tier = item.tier, price = item.price,
            stock = item.tier == 'basic' and nil or stocks[item.tier], requiredLevel = required,
            unlocked = progress.level >= required }
    end
    products[#products + 1] = { id = Config.Market.TabletItem, label = 'Farmer Tablet', category = 'Access',
        tier = 'basic', price = Config.Market.TabletPrice, stock = nil, requiredLevel = 1,
        unlocked = true, physicalOnly = true, owned = Bridge.Inventory.HasItem(source, Config.Market.TabletItem, 1) }
    return { products = products, stock = stocks, progression = progress,
        bankBalance = tonumber(Bridge.GetMoney(source, 'bank')) or 0 }
end

local function normalizeLines(lines, allowTablet)
    if type(lines) ~= 'table' or #lines < 1 or #lines > Config.Market.MaxLines then return nil, 'invalid_cart' end
    local output, seen = {}, {}
    for _, line in ipairs(lines) do
        local id, quantity = tostring(line.itemId or ''), math.floor(tonumber(line.quantity) or 0)
        if seen[id] or quantity < 1 or quantity > Config.Market.MaxLineQuantity then return nil, 'invalid_cart' end
        seen[id] = true
        local item = Sonar.ItemCatalog.byId[id]
        if id == Config.Market.TabletItem then
            if not allowTablet or quantity ~= 1 then return nil, 'tablet_physical_only' end
            item = { id = id, label = 'Farmer Tablet', tier = 'basic', price = Config.Market.TabletPrice }
        elseif not item or not item.market then return nil, 'invalid_item' end
        output[#output + 1] = { item = item, quantity = quantity }
    end
    return output
end

function Market.Purchase(source, input)
    local actor, reason = PublicJob.Guard(source)
    if not actor then return { ok = false, reason = reason } end
    input = input or {}
    local selectedMarket = marketById(tostring(input.marketId or ''))
    local physical = input.physical == true and nearMarket(source, selectedMarket)
    if input.physical == true and not physical then return { ok = false, reason = 'presence_required' } end
    if not physical and not Bridge.Inventory.HasItem(source, Config.Market.TabletItem, 1) then
        return { ok = false, reason = 'tablet_required' }
    end
    local lines, invalid = normalizeLines(input.lines, physical)
    if not lines then return { ok = false, reason = invalid } end
    local operationId = tostring(input.operationId or Sonar.Utils.Uuid())
    local acquired, result = Lock.With('market:global', function()
        local replay = MySQL.single.await("SELECT status,amount FROM sfpj_economy_operations WHERE id=? AND identifier=? AND kind='market'",
            { operationId, actor.identifier })
        if replay then return { ok = PublicJobEconomy.IsFulfilled(replay.status), reason = replay.status, replay = true } end
        local progress, requiredStock, total = Progression.Get(actor.identifier), {}, 0
        for _, line in ipairs(lines) do
            local required = Config.Progression.ItemTierLevels[line.item.tier or 'basic'] or 1
            if progress.level < required then return { ok = false, reason = 'level_required', requiredLevel = required } end
            if line.item.id == Config.Market.TabletItem and Bridge.Inventory.HasItem(source, line.item.id, 1) then
                return { ok = false, reason = 'tablet_already_owned' }
            end
            if not Bridge.Inventory.CanCarry(source, line.item.id, line.quantity) then
                return { ok = false, reason = 'inventory_full' }
            end
            total = total + line.item.price * line.quantity
            if line.item.tier ~= 'basic' then requiredStock[line.item.tier] = (requiredStock[line.item.tier] or 0) + line.quantity end
        end
        Market.Restock(now())
        local stocks = stockRows()
        for tier, quantity in pairs(requiredStock) do
            if (stocks[tier] or 0) < quantity then return { ok = false, reason = 'stock_unavailable', tier = tier } end
        end
        if tonumber(operation(operationId, actor.identifier, total, input.lines)) ~= 1 then
            return { ok = false, reason = 'operation_conflict' }
        end
        if not Bridge.DebitMoney(source, 'bank', total, 'Personal farm market', operationId) then
            MySQL.update.await("UPDATE sfpj_economy_operations SET status='failed',last_error='insufficient_funds' WHERE id=?", { operationId })
            return { ok = false, reason = 'insufficient_funds' }
        end
        local stockQueries = {}
        for tier, quantity in pairs(requiredStock) do
            stockQueries[#stockQueries + 1] = { query = [[UPDATE sfpj_market_stock SET quantity=quantity-?
                WHERE tier=? AND quantity>=?]], values = { quantity, tier, quantity } }
        end
        if #stockQueries > 0 and not MySQL.transaction.await(stockQueries) then
            compensate(actor.identifier, total, operationId, 'stock_changed')
            return { ok = false, reason = 'stock_unavailable' }
        end
        local delivered = {}
        for _, line in ipairs(lines) do
            if not Bridge.Inventory.AddItem(source, line.item.id, line.quantity) then
                for _, previous in ipairs(delivered) do Bridge.Inventory.RemoveItem(source, previous.item.id, previous.quantity) end
                for tier, quantity in pairs(requiredStock) do
                    MySQL.update.await('UPDATE sfpj_market_stock SET quantity=LEAST(?,quantity+?) WHERE tier=?',
                        { Config.Market.Stock[tier].capacity, quantity, tier })
                end
                compensate(actor.identifier, total, operationId, 'inventory_delivery_failed')
                return { ok = false, reason = 'inventory_full' }
            end
            delivered[#delivered + 1] = line
        end
        MySQL.update.await("UPDATE sfpj_economy_operations SET status='delivered',payload=?,last_error=NULL WHERE id=?",
            { encode(input.lines), operationId })
        PublicJobEconomy.Finalize(operationId)
        if HubRuntime and HubRuntime.BroadcastInvalidate then
            HubRuntime.BroadcastInvalidate({ scope = 'market', reason = 'purchase_completed' })
        end
        return { ok = true, operationId = operationId, total = total, data = Market.Load(source) }
    end)
    return acquired and result or { ok = false, reason = 'operation_in_progress' }
end
