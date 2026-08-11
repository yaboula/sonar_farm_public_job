-- sonar_farm_publicjob - public-job configuration

Config = {}

Config.Framework = 'qb-core'
Config.FrameworkResources = { ['qb-core'] = 'qb-core' }
Config.FrameworkPriority = { 'qb-core' }
Config.Locale = 'en'
Config.Debug = false
Config.SaveInterval = 60

Config.Admin = { Ace = 'sonar_farm_publicjob.admin' }
Config.Database = { AutoCreateSchema = true, BatchChunkSize = 100 }

Config.Features = {
    Minigames = false,
    AdvancedCare = true,
    InspectionHud = true,
    Progression = true,
    Fields = true,
    Market = true,
    Sell = true,
    PublicFieldAuthority = true,
    Discord = false,
    DatabaseLogs = false,
}

Config.Job = {
    Name = 'farmer',
    RequireDuty = true,
    NearbyInviteDistance = 15.0,
}

Config.Progression = {
    MaxLevel = 20,
    CurveCoefficient = 220,
    PlantXp = 2,
    EffectiveCareXp = 1,
    QualityXpMultipliers = { poor = 0.50, standard = 1.00, fine = 1.50, premium = 2.00 },
    ItemTierLevels = { basic = 1, plus = 4, pro = 8 },
    FieldSizeLevels = { S = 1, M = 5, L = 10 },
    Perks = {
        { level = 1, rentDiscount = 0.00, sellBonus = 0.00 },
        { level = 5, rentDiscount = 0.05, sellBonus = 0.03 },
        { level = 10, rentDiscount = 0.12, sellBonus = 0.07 },
        { level = 15, rentDiscount = 0.18, sellBonus = 0.11 },
        { level = 20, rentDiscount = 0.25, sellBonus = 0.15 },
    },
}

Config.Reservations = {
    Plans = { [6] = 6 * 60 * 60, [12] = 12 * 60 * 60, [24] = 24 * 60 * 60 },
    Prices = {
        S = { [6] = 1500, [12] = 2700, [24] = 4800 },
        M = { [6] = 2400, [12] = 4300, [24] = 7600 },
        L = { [6] = 3600, [12] = 6500, [24] = 11500 },
    },
    MaximumRemainingSeconds = 24 * 60 * 60,
    GraceSeconds = 15 * 60,
    GraceSurcharge = 0.25,
    SameFieldCooldownSeconds = 30 * 60,
    InviteTtlSeconds = 60,
    MaxGuests = 3,
    WorkerSeconds = 15,
}

Config.Market = {
    SessionTtlSeconds = 10 * 60,
    InteractionDistance = 3.0,
    MaxLines = 10,
    MaxLineQuantity = 99,
    TabletItem = 'farm_tablet',
    TabletPrice = 1500,
    TabletCommand = 'farmtablet',
    Markets = {
        { id = 'grapeseed', label = 'Grapeseed Farm Market',
          coords = vec3(2448.38, 4977.18, 46.81), radius = 1.8,
          ped = 'a_m_m_farmer_01', heading = 135.0 },
        { id = 'paleto', label = 'Paleto Farm Market',
          coords = vec3(-160.12, 6322.47, 31.58), radius = 1.8,
          ped = 'a_m_m_farmer_01', heading = 315.0 },
    },
    Stock = {
        plus = { capacity = 20, restockAmount = 5, restockSeconds = 30 * 60 },
        pro = { capacity = 10, restockAmount = 2, restockSeconds = 60 * 60 },
    },
}

Config.Sell = {
    InteractionDistance = 3.0,
    Buyer = { label = 'Grapeseed Produce Buyer', coords = vec3(2441.84, 4968.77, 46.81),
        radius = 1.8, ped = 's_m_m_dockwork_01', heading = 225.0 },
    BasePrices = { carrot = 12, potato = 10, lettuce = 14, tomato = 16 },
    TierMultipliers = { poor = 0.50, standard = 1.00, fine = 1.50, premium = 2.00 },
}

Config.Inspection = {
    HistorySeconds = 10 * 60, HistoryCycleRatio = 0.25,
    ForecastSeconds = 10 * 60, DiagnosisCycleRatio = 0.10,
    SampleSeconds = 30, CurveRefreshSeconds = 5, ValueRefreshSeconds = 1,
    MaxEtaSeconds = 24 * 60 * 60, MaxEtaCycles = 4, CloseDistance = 4.0,
    MinimapWidthRatio = 0.168, MinimapGapPixels = 18, RightInsetPixels = 18,
    SevereConditionPercent = 50,
}

Config.Security = {
    TokenBucket = { capacity = 8, refillPerSecond = 2 },
    SubscriptionBucket = { capacity = 3, refillPerSecond = 1 },
    MinigameBucket = { capacity = 6, refillPerSecond = 2 },
    RateLimitLogInterval = 5000,
    AllowedRoutingBuckets = { 0 },
    MaxInteractDistance = 3.0,
    MaxSpeedMps = 60.0,
    PositionSampleTtl = 30,
    ConnectGracePeriod = 15,
}

Config.Cooldowns = { plant = 1000, water = 500, harvest = 1000, fertilize = 750, weed = 750, treat_pest = 750 }

Config.Farming = {
    NewCropSimulationVersion = 2,
    OwnerOnlyHarvest = true,
    AllowPublicCare = false,
    TheftQualityPenalty = 0.3,
    MaxCropsPerPlayer = 64,
    WaterRefillThreshold = 95,
    Tools = { water = 'watering_can', weed = 'hand_hoe' },
    ConditionEffects = { Nutrients = true, Weeds = true, Pests = true },
    AdvancedCare = {
        WaterDeficitThreshold = 35, CriticalStressMultiplier = 1.75,
        WeedWaterCompetition = 0.65, WeedNutrientCompetition = 0.8,
        PestWeedAcceleration = 1.0, PestGrowthPerHour = 200,
        PestDamagePerHour = 16, NutrientHealthLossPerHour = 8,
        GrowthPenaltyPerDeficitHour = { water = 0.35, nutrients = 0.45 },
        StressPerDeficitHour = { water = 12, nutrients = 14 },
        MinimumWeedCover = 8, MinimumPestPressure = 8,
        Cycle = {
            GreenGrowthBonus = 0.20, WatchGrowthPenalty = 0.10, CriticalGrowthPenalty = 0.55,
            WatchStressMultiplier = 0.35, DryHealthLossPerCycle = 1200,
            NutrientHealthLossPerCycle = 160, PestDamagePerCycle = 200,
            StressPerCycle = { water = 100, nutrients = 110 },
            WeedWaterCompetition = 0.35, WeedNutrientCompetition = 0.45,
            PestWeedAcceleration = 0.60, Water = { green = 60, critical = 35 },
            Pressure = { green = 20, critical = 50 }, NutrientWatchMargin = 20,
        },
    },
    MinigameDamageThreshold = 15,
}

Config.Quality = {
    DefaultScore = 75, MechanizedCap = 80, ScoreWeight = 0.6, CareWeight = 0.4,
    PlantingInfluence = 0.3, DefectWeight = 0.45,
    ProductionWeights = { nutrientStress = 0.55, pestDamage = 0.8 },
}

Config.Sync = { CellRadius = 1, TickNear = 500, TickFar = 2000 }
Config.Render = {
    Radius = 30.0, MaxProps = 50, GroundSnap = true, Variation = true,
    TargetDistance = 2.2, SkipInInteriors = true, FallbackModel = 'prop_plant_01a',
    SlotProp = false, SlotTargetRadius = 1.2, InteractionCacheMs = 750,
    VisualStageCacheMs = 5000, VisualStageJitterMs = 1500,
}

Config.Fields = {
    Ace = 'sonar_farm_publicjob.fields_admin', InteractionDistance = 3.0,
    DetailRefreshSeconds = 5, MaxEventsPerDetail = 100, MinimumSlotSpacing = 0.75,
}

Config.Logging = { ConsoleLevel = 'INFO', DiscordWebhook = '' }
