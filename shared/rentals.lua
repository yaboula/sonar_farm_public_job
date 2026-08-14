-- Pure public-Field rental pricing shared by the service and regression suite.

Sonar = Sonar or {}

local Rentals = {}

function Rentals.Price(sizeClass, hours, rentDiscount, grace)
    local prices = Config.Reservations and Config.Reservations.Prices
    local base = prices and prices[sizeClass] and prices[sizeClass][tonumber(hours)]
    if not base then return nil end
    local discount = Sonar.Utils.Clamp(tonumber(rentDiscount) or 0, 0, 1)
    local paid = math.floor(base * (1 - discount) + 0.5)
    if grace then
        paid = math.floor(paid * (1 + (tonumber(Config.Reservations.GraceSurcharge) or 0)) + 0.5)
    end
    return paid, base
end

function Rentals.CanExtend(currentExpiry, timestamp, hours)
    timestamp = tonumber(timestamp) or 0
    local seconds = Config.Reservations and Config.Reservations.Plans
        and Config.Reservations.Plans[tonumber(hours)]
    if not seconds then return false, nil end
    local resultingExpiry = math.max(timestamp, tonumber(currentExpiry) or timestamp) + seconds
    return resultingExpiry <= timestamp + Config.Reservations.MaximumRemainingSeconds, resultingExpiry
end

Sonar.Rentals = Rentals
