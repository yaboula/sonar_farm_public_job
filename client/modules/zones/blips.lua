-- Public Field, Market and Sell discovery markers.

local blips, fieldBlips = {}, {}

local function addBlip(coords, label, cfg, collection)
    if not coords or not cfg or not cfg.enabled then return end
    local blip = AddBlipForCoord(coords.x + 0.0, coords.y + 0.0, coords.z + 0.0)
    SetBlipSprite(blip, cfg.sprite or 496)
    SetBlipColour(blip, cfg.color or 25)
    SetBlipScale(blip, cfg.scale or 0.8)
    SetBlipAsShortRange(blip, cfg.shortRange ~= false)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(label)
    EndTextCommandSetBlipName(blip)
    collection[#collection + 1] = blip
end

local function clear(collection)
    for _, blip in ipairs(collection) do if DoesBlipExist(blip) then RemoveBlip(blip) end end
    for index = #collection, 1, -1 do collection[index] = nil end
end

local function refreshFields()
    clear(fieldBlips)
    if not Config.Features.PublicFieldAuthority then
        for _, zone in pairs(Config.Zones or {}) do
            addBlip(zone.center, zone.label or 'Farming Zone', zone.blip, fieldBlips)
        end
        return
    end
    local catalog = lib.callback.await(Sonar.Constants.CALLBACKS.FIELD_CATALOG, false)
    if type(catalog) ~= 'table' then catalog = Config.FieldSeeds or {} end
    for _, field in ipairs(catalog) do
        if (field.catalogVisible ~= false or Config.Debug) and field.blip and field.blip.enabled then
            addBlip(field.access, field.name or 'Public Field', field.blip, fieldBlips)
        end
    end
end

CreateThread(function()
    for _, market in ipairs(Config.Market.Markets or {}) do
        addBlip(market.coords, market.label or 'Farm Market', market.blip, blips)
    end
    addBlip(Config.Sell.Buyer.coords, Config.Sell.Buyer.label or 'Produce Buyer', Config.Sell.Buyer.blip, blips)
    Wait(1000)
    refreshFields()
end)

RegisterNetEvent(Sonar.Constants.EVENTS.RUNTIME_READY, refreshFields)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    clear(fieldBlips)
    clear(blips)
end)
