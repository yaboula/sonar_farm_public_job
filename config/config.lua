-- sonar_farm_publicjob - public-job configuration

Config = {}

Config.Framework = 'qb-core'
Config.FrameworkResources = { ['qb-core'] = 'qb-core' }
Config.FrameworkPriority = { 'qb-core' }
Config.Locale = 'en'
Config.Debug = true
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

Config.Gameplay = {
    AnimationLoadTimeoutMs = 2500,
    FeedbackCancelDistance = 1.75,
    ApproachTimeoutMs = 4500,
    ApproachSpeed = 1.0,
    ApproachStandOffDistance = 0.58,
    ApproachTolerance = 0.10,
    ApproachHeadingTolerance = 5.0,
    ActionFeedback = {
        plant = {
            duration = 3200,
            anim = { dict = 'amb@world_human_gardener_plant@male@base', clip = 'base', flag = 1 },
        },
        water = {
            duration = 2800,
            anim = { dict = 'weapon@w_sp_jerrycan', clip = 'fire', flag = 49 },
        },
        fertilize = {
            duration = 2600,
            anim = { dict = 'anim@mp_snowball', clip = 'pickup_snowball', flag = 1 },
        },
        weed = {
            duration = 3000,
            anim = { dict = 'amb@world_human_gardener_plant@male@idle_a', clip = 'idle_a', flag = 1 },
        },
        treat_pest = {
            duration = 2600,
            anim = { dict = 'weapon@w_sp_jerrycan', clip = 'fire', flag = 49 },
        },
        harvest = {
            duration = 2800,
            anim = { dict = 'anim@mp_snowball', clip = 'pickup_snowball', flag = 1 },
        },
    },
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
    PlanOrder = { 1, 3, 6, 8 },
    Plans = { [1] = 1 * 60 * 60, [3] = 3 * 60 * 60, [6] = 6 * 60 * 60, [8] = 8 * 60 * 60 },
    Prices = {
        S = { [1] = 300, [3] = 800, [6] = 1500, [8] = 1900 },
        M = { [1] = 480, [3] = 1300, [6] = 2400, [8] = 3000 },
        L = { [1] = 720, [3] = 1950, [6] = 3600, [8] = 4500 },
    },
    MaximumRemainingSeconds = 8 * 60 * 60,
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
        { id = 'mercado_granja', label = 'Mercado de la Granja',
            coords = vec3(1710.26, 4728.50, 42.14), radius = 1.8,
            ped = 'a_m_m_farmer_01', heading = 104.88,
            blip = { enabled = true, sprite = 52, color = 5, scale = 0.75 } },
        { id = 'paleto', label = 'Paleto Farm Market',
            coords = vec3(-160.12, 6322.47, 31.58), radius = 1.8,
            ped = 'a_m_m_farmer_01', heading = 315.0,
            blip = { enabled = true, sprite = 52, color = 5, scale = 0.75 } },
    },
    Stock = {
        plus = { capacity = 20, restockAmount = 5, restockSeconds = 30 * 60 },
        pro = { capacity = 10, restockAmount = 2, restockSeconds = 60 * 60 },
    },
}

Config.Sell = {
    InteractionDistance = 3.0,
    Buyer = { label = 'Comprador de Cosecha', coords = vec3(1718.70, 4712.93, 42.22), -- Desplazado ligeramente 1 metro para que no se pise con el mercado
        radius = 1.8, ped = 's_m_m_dockwork_01', heading = 104.88,
        blip = { enabled = true, sprite = 500, color = 25, scale = 0.75 } },
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

Config.FieldHud = {
    Enabled = true,
    Position = 'left-center', -- left-center | top-left
    ToggleCommand = 'sfpj_field_hud',
    ToggleKey = 'C',
    DefaultExpanded = false,
    RefreshSeconds = 10,
    UiUpdateMs = 1000,
    ClassificationMs = 1000,
    StaleSeconds = 25,
    MarkerTexture = 'slot_marker',
    MarkerHeight = 0.68,
    MarkerMinScale = 0.015,
    MarkerMaxScale = 0.028,
    MarkerPriorityScale = 1.22,
    MarkerGroundScale = 0.58,
    MarkerGroundOnlyPriority = true,
    MarkerMaxDistance = 180.0,
    MarkerMinAlpha = 90,
    MarkerMaxAlpha = 225,
    MapBlipsEnabled = true,
    MapBlipSprite = 1,
    MapBlipScale = 0.26,
    MapBlipPriorityScale = 0.32,
    MapBlipAlpha = 190,
    MapBlipShortRange = false,
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
    NewCropSimulationVersion = 3,
    OwnerOnlyHarvest = true,
    AllowPublicCare = false,
    TheftQualityPenalty = 0.3,
    MaxCropsPerPlayer = 64,
    WaterRefillThreshold = 95,
    Tools = { water = 'watering_can', weed = 'hand_hoe' },
    ConditionEffects = { Nutrients = true, Weeds = true, Pests = true },
    AdvancedCare = {
        BasicWorkload = {
            GreenWindowSeconds = 9.5 * 60,
            InitialDelaySeconds = { water = 0, nutrients = 2 * 60, weeds = 4 * 60, pests = 6 * 60 },
            GreenDelta = { water = 40, nutrients = 25, weeds = 20, pests = 20 },
        },
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
