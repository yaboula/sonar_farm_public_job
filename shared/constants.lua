--[[
    sonar_farm_publicjob - Shared constants
    Single source of truth for enums, event names and magic values used across
    client and server. Namespaced under the global `Sonar` table.
]]

Sonar = Sonar or {}

local Constants = {}

-- Resource identity.
Constants.RESOURCE = GetCurrentResourceName()

-- Spatial-hash cell size in meters. Used to compute a crop's "gx:gy" cell key
-- for the streaming/culling grid (Stage 4). Default matches config zone cells.
Constants.SPATIAL_CELL_SIZE = 100

-- Log severity levels. Ordered for threshold comparisons (see logger).
Constants.LOG_LEVELS = {
    INFO = 1,
    WARN = 2,
    EXPLOIT = 3,
}

-- Supported frameworks (Bridge adapters).
Constants.FRAMEWORKS = {
    QBCORE = 'qb-core',
}

-- Crop lifecycle states (used from Stage 3+).
Constants.CROP_STATE = {
    PLANTING = 'planting',
    PLANTING_FAILED = 'planting_failed',
    PLANTED = 'planted',
    GROWING = 'growing',
    MATURE = 'mature',
    WITHERED = 'withered',
    DEAD = 'dead',
}

-- Product quality tiers, mapped from a 0..100 quality score (Stage 8).
Constants.QUALITY_TIERS = {
    { key = 'poor', min = 0, label = 'Poor' },
    { key = 'standard', min = 40, label = 'Standard' },
    { key = 'fine', min = 70, label = 'Fine' },
    { key = 'premium', min = 90, label = 'Premium' },
}

-- Player-initiated farming actions. Used for cooldowns, rate limiting and
-- quality providers.
Constants.ACTIONS = {
    PLANT = 'plant',
    WATER = 'water',
    HARVEST = 'harvest',
    FERTILIZE = 'fertilize',
    WEED = 'weed',
    TREAT_PEST = 'treat_pest',
}

-- ox_lib callback names (client intent -> authoritative server handler).
Constants.CALLBACKS = {
    PLANT = 'sonar_farm_publicjob:plant',
    WATER = 'sonar_farm_publicjob:water',
    HARVEST = 'sonar_farm_publicjob:harvest',
    FERTILIZE = 'sonar_farm_publicjob:fertilize',
    WEED = 'sonar_farm_publicjob:weed',
    TREAT_PEST = 'sonar_farm_publicjob:treatPest',
    CARE_OPTIONS = 'sonar_farm_publicjob:careOptions',
    INSPECT = 'sonar_farm_publicjob:inspect',
    HUB_OPEN = 'sonar_farm_publicjob:hub:open',
    HUB_LOAD = 'sonar_farm_publicjob:hub:load',
    HUB_DISPATCH = 'sonar_farm_publicjob:hub:dispatch',
    HUB_SUBSCRIBE_FIELD = 'sonar_farm_publicjob:hub:subscribeField',
    HUB_CLOSE = 'sonar_farm_publicjob:hub:close',
    MINIGAME_BEGIN = 'sonar_farm_publicjob:minigame:begin',
    MINIGAME_CHECKPOINT = 'sonar_farm_publicjob:minigame:checkpoint',
    MINIGAME_CANCEL = 'sonar_farm_publicjob:minigame:cancel',
    MINIGAME_RESUME = 'sonar_farm_publicjob:minigame:resume',
    MINIGAME_CLEAR_INCOMPLETE = 'sonar_farm_publicjob:minigame:clearIncomplete',
    SUBSCRIBE = 'sonar_farm_publicjob:subscribe',
    ADMIN_AUTHORIZED = 'sonar_farm_publicjob:adminAuthorized',
    FIELD_DRAFT_SAVE = 'sonar_farm_publicjob:fieldDraftSave',
    FIELD_CATALOG = 'sonar_farm_publicjob:fieldCatalog',
    FIELD_HUD_STATE = 'sonar_farm_publicjob:fieldHud:state',
}

-- Networked event names. Prefixed to avoid collisions with other resources.
Constants.EVENTS = {
    BRIDGE_READY = 'sonar_farm_publicjob:bridgeReady',
    -- Server -> client render deltas (Stage 4). Sent only to the players
    -- subscribed to the affected spatial cell.
    CROP_SYNC = 'sonar_farm_publicjob:cropSync',
    CROP_REMOVE = 'sonar_farm_publicjob:cropRemove',
    SYNC_RESET = 'sonar_farm_publicjob:syncReset',
    RUNTIME_READY = 'sonar_farm_publicjob:runtimeReady',
    FIELD_DELTA = 'sonar_farm_publicjob:fieldDelta',
    FIELD_HUD_INVALIDATE = 'sonar_farm_publicjob:fieldHud:invalidate',
}

-- Public server events other resources can listen to (platform API).
Constants.PUBLIC_EVENTS = {
    CROP_PLANTED = 'sonar_farm_publicjob:cropPlanted',
    CROP_WATERED = 'sonar_farm_publicjob:cropWatered',
    CROP_HARVESTED = 'sonar_farm_publicjob:cropHarvested',
    CROP_FERTILIZED = 'sonar_farm_publicjob:cropFertilized',
    CROP_WEEDED = 'sonar_farm_publicjob:cropWeeded',
    CROP_TREATED = 'sonar_farm_publicjob:cropTreated',
}

-- Machine-readable rejection reasons returned by server handlers. The client
-- maps these to user-facing text; never build player messages on the server.
Constants.REJECT = {
    RATE_LIMITED = 'rate_limited',
    SERVICE_UNAVAILABLE = 'service_unavailable',
    PLAYER_NOT_READY = 'player_not_ready',
    WRONG_INSTANCE = 'wrong_instance',
    COOLDOWN = 'cooldown',
    TOO_FAR = 'too_far',
    SUSPICIOUS_MOVEMENT = 'suspicious_movement',
    NOT_IN_ZONE = 'not_in_zone',
    CROP_NOT_ALLOWED_HERE = 'crop_not_allowed_here',
    -- Slot system: the requested plot does not exist in config, or something is
    -- already growing in it (the client's view was stale).
    SLOT_NOT_FOUND = 'slot_not_found',
    SLOT_OCCUPIED = 'slot_occupied',
    UNKNOWN_CROP = 'unknown_crop',
    MISSING_SEED = 'missing_seed',
    MISSING_TOOL = 'missing_tool',
    CROP_NOT_FOUND = 'crop_not_found',
    CROP_NOT_MATURE = 'crop_not_mature',
    CROP_DEAD = 'crop_dead',
    NOT_OWNER = 'not_owner',
    CROP_LIMIT_REACHED = 'crop_limit_reached',
    INVENTORY_FULL = 'inventory_full',
    ALREADY_IN_PROGRESS = 'already_in_progress',
    ALREADY_WATERED = 'already_watered',
    NUTRIENTS_SATURATED = 'nutrients_saturated',
    NO_WEEDS_DETECTED = 'no_weeds_detected',
    NO_PEST_DETECTED = 'no_pest_detected',
    CONDITION_DISABLED = 'condition_disabled',
    MINIGAME_REQUIRED = 'minigame_required',
    MINIGAME_DISABLED = 'minigame_disabled',
    MINIGAME_SESSION_NOT_FOUND = 'minigame_session_not_found',
    MINIGAME_SESSION_EXPIRED = 'minigame_session_expired',
    MINIGAME_INVALID_STEP = 'minigame_invalid_step',
    MINIGAME_INVALID_TRACE = 'minigame_invalid_trace',
    PLANTING_INCOMPLETE = 'planting_incomplete',
    PLANTING_NOT_FAILED = 'planting_not_failed',
    INTERNAL_ERROR = 'internal_error',
    INVALID_ITEM = 'invalid_item',
    JOB_REQUIRED = 'job_required',
    DUTY_REQUIRED = 'duty_required',
    RESERVATION_REQUIRED = 'reservation_required',
    RESERVATION_GRACE = 'reservation_grace',
    LEVEL_REQUIRED = 'level_required',
    STOCK_UNAVAILABLE = 'stock_unavailable',
    PRESENCE_REQUIRED = 'presence_required',
}

-- ox_lib notification types.
Constants.NOTIFY = {
    INFO = 'inform',
    SUCCESS = 'success',
    WARNING = 'warning',
    ERROR = 'error',
}

Sonar.Constants = Constants
