-- Public-job domain schema and common job/duty authority.

PublicJob = PublicJob or {}
PublicJobDatabase = PublicJobDatabase or {}
PublicJobEconomy = PublicJobEconomy or {}

local statements = {
[[CREATE TABLE IF NOT EXISTS `sfpj_schema_migrations` (
  `version` INT NOT NULL, `applied_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`version`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
[[CREATE TABLE IF NOT EXISTS `sfpj_players` (
  `identifier` VARCHAR(64) NOT NULL, `total_xp` BIGINT NOT NULL DEFAULT 0,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
[[CREATE TABLE IF NOT EXISTS `sfpj_xp_ledger` (
  `operation_id` VARCHAR(64) NOT NULL, `identifier` VARCHAR(64) NOT NULL,
  `action` VARCHAR(32) NOT NULL, `crop_id` VARCHAR(36) DEFAULT NULL,
  `amount` INT NOT NULL, `payload` LONGTEXT DEFAULT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`operation_id`), KEY `idx_sfpj_xp_player` (`identifier`,`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
[[CREATE TABLE IF NOT EXISTS `sfpj_fields` (
  `id` VARCHAR(64) NOT NULL, `legacy_zone` VARCHAR(64) DEFAULT NULL,
  `name` VARCHAR(100) NOT NULL, `location` VARCHAR(160) NOT NULL,
  `region` VARCHAR(32) NOT NULL, `size_class` CHAR(1) NOT NULL,
  `catalog_visible` TINYINT(1) NOT NULL DEFAULT 1,
  `active_revision_id` VARCHAR(36) DEFAULT NULL, `state_sequence` BIGINT NOT NULL DEFAULT 0,
  `access_x` DOUBLE NOT NULL, `access_y` DOUBLE NOT NULL, `access_z` DOUBLE NOT NULL,
  `allowed_crops` LONGTEXT NOT NULL, `blip` LONGTEXT NOT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`), UNIQUE KEY `uniq_sfpj_field_zone` (`legacy_zone`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
[[CREATE TABLE IF NOT EXISTS `sfpj_field_revisions` (
  `id` VARCHAR(36) NOT NULL, `field_id` VARCHAR(64) NOT NULL,
  `revision_number` INT NOT NULL, `checksum` VARCHAR(64) NOT NULL,
  `status` VARCHAR(16) NOT NULL, `orientation` FLOAT NOT NULL DEFAULT 0,
  `bounds_width` DOUBLE NOT NULL, `bounds_height` DOUBLE NOT NULL,
  `created_by` VARCHAR(64) NOT NULL, `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `activated_at` TIMESTAMP NULL DEFAULT NULL,
  PRIMARY KEY (`id`), UNIQUE KEY `uniq_sfpj_field_rev` (`field_id`,`revision_number`),
  UNIQUE KEY `uniq_sfpj_field_checksum` (`field_id`,`checksum`),
  KEY `idx_sfpj_field_revision_status` (`field_id`,`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
[[CREATE TABLE IF NOT EXISTS `sfpj_field_rows` (
  `revision_id` VARCHAR(36) NOT NULL, `field_id` VARCHAR(64) NOT NULL,
  `id` VARCHAR(96) NOT NULL, `label` VARCHAR(64) NOT NULL, `row_order` INT NOT NULL,
  PRIMARY KEY (`revision_id`,`id`), UNIQUE KEY `uniq_sfpj_row_order` (`revision_id`,`row_order`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
[[CREATE TABLE IF NOT EXISTS `sfpj_field_slots` (
  `revision_id` VARCHAR(36) NOT NULL, `field_id` VARCHAR(64) NOT NULL,
  `row_id` VARCHAR(96) NOT NULL, `id` VARCHAR(96) NOT NULL,
  `slot_order` INT NOT NULL, `legacy_index` INT NOT NULL,
  `pos_x` DOUBLE NOT NULL, `pos_y` DOUBLE NOT NULL, `pos_z` DOUBLE NOT NULL,
  `heading` FLOAT NOT NULL DEFAULT 0, `normalized_x` DOUBLE NOT NULL,
  `normalized_y` DOUBLE NOT NULL, `cell_key` VARCHAR(32) NOT NULL,
  PRIMARY KEY (`revision_id`,`id`), UNIQUE KEY `uniq_sfpj_slot_legacy` (`revision_id`,`legacy_index`),
  KEY `idx_sfpj_slot_cell` (`cell_key`), KEY `idx_sfpj_slot_row` (`revision_id`,`row_id`,`slot_order`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
[[CREATE TABLE IF NOT EXISTS `sfpj_reservations` (
  `id` VARCHAR(36) NOT NULL, `field_id` VARCHAR(64) NOT NULL,
  `owner_identifier` VARCHAR(64) NOT NULL, `status` VARCHAR(16) NOT NULL,
  `plan_hours` INT NOT NULL, `base_price` INT NOT NULL, `paid_price` INT NOT NULL,
  `started_at` BIGINT NOT NULL, `expires_at` BIGINT NOT NULL, `grace_until` BIGINT DEFAULT NULL,
  `released_at` BIGINT DEFAULT NULL, `release_reason` VARCHAR(32) DEFAULT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`), KEY `idx_sfpj_reservation_field` (`field_id`,`status`),
  KEY `idx_sfpj_reservation_owner` (`owner_identifier`,`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
[[CREATE TABLE IF NOT EXISTS `sfpj_field_claims` (
  `field_id` VARCHAR(64) NOT NULL, `reservation_id` VARCHAR(36) NOT NULL,
  PRIMARY KEY (`field_id`), UNIQUE KEY `uniq_sfpj_claim_reservation` (`reservation_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
[[CREATE TABLE IF NOT EXISTS `sfpj_reservation_members` (
  `reservation_id` VARCHAR(36) NOT NULL, `identifier` VARCHAR(64) NOT NULL,
  `display_name` VARCHAR(100) NOT NULL, `role` VARCHAR(16) NOT NULL,
  `status` VARCHAR(16) NOT NULL, `joined_at` BIGINT NOT NULL, `left_at` BIGINT DEFAULT NULL,
  PRIMARY KEY (`reservation_id`,`identifier`), KEY `idx_sfpj_member_identifier` (`identifier`,`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
[[CREATE TABLE IF NOT EXISTS `sfpj_player_links` (
  `identifier` VARCHAR(64) NOT NULL, `reservation_id` VARCHAR(36) NOT NULL,
  `member_status` VARCHAR(16) NOT NULL, PRIMARY KEY (`identifier`),
  KEY `idx_sfpj_link_reservation` (`reservation_id`,`member_status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
[[CREATE TABLE IF NOT EXISTS `sfpj_invites` (
  `id` VARCHAR(36) NOT NULL, `reservation_id` VARCHAR(36) NOT NULL,
  `inviter_identifier` VARCHAR(64) NOT NULL, `invitee_identifier` VARCHAR(64) NOT NULL,
  `status` VARCHAR(16) NOT NULL, `expires_at` BIGINT NOT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`), KEY `idx_sfpj_invitee` (`invitee_identifier`,`status`,`expires_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
[[CREATE TABLE IF NOT EXISTS `sfpj_cooldowns` (
  `identifier` VARCHAR(64) NOT NULL, `field_id` VARCHAR(64) NOT NULL,
  `expires_at` BIGINT NOT NULL, PRIMARY KEY (`identifier`,`field_id`),
  KEY `idx_sfpj_cooldown_expiry` (`expires_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
[[CREATE TABLE IF NOT EXISTS `sfpj_market_stock` (
  `tier` VARCHAR(16) NOT NULL, `quantity` INT NOT NULL,
  `last_restock_at` BIGINT NOT NULL, PRIMARY KEY (`tier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
[[CREATE TABLE IF NOT EXISTS `sfpj_economy_operations` (
  `id` VARCHAR(64) NOT NULL, `identifier` VARCHAR(64) NOT NULL,
  `kind` VARCHAR(24) NOT NULL, `status` VARCHAR(24) NOT NULL,
  `amount` INT NOT NULL DEFAULT 0, `payload` LONGTEXT DEFAULT NULL,
  `last_error` VARCHAR(100) DEFAULT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`), KEY `idx_sfpj_economy_pending` (`status`,`created_at`),
  KEY `idx_sfpj_economy_player` (`identifier`,`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
[[CREATE TABLE IF NOT EXISTS `sfpj_economy_receipts` (
  `operation_id` VARCHAR(64) NOT NULL, `identifier` VARCHAR(64) NOT NULL,
  `kind` VARCHAR(24) NOT NULL, `amount` INT NOT NULL, `payload` LONGTEXT DEFAULT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`operation_id`), KEY `idx_sfpj_receipt_player` (`identifier`,`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
[[CREATE TABLE IF NOT EXISTS `sfpj_economy_outbox` (
  `id` VARCHAR(64) NOT NULL, `operation_id` VARCHAR(64) NOT NULL,
  `action` VARCHAR(24) NOT NULL, `status` VARCHAR(16) NOT NULL DEFAULT 'pending',
  `attempts` INT NOT NULL DEFAULT 0, `payload` LONGTEXT DEFAULT NULL,
  `last_error` VARCHAR(100) DEFAULT NULL, `next_attempt_at` BIGINT NOT NULL DEFAULT 0,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`), UNIQUE KEY `uniq_sfpj_outbox_action` (`operation_id`,`action`),
  KEY `idx_sfpj_outbox_pending` (`status`,`next_attempt_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
[[CREATE TABLE IF NOT EXISTS `sfpj_field_events` (
  `id` VARCHAR(36) NOT NULL, `field_id` VARCHAR(64) NOT NULL,
  `reservation_id` VARCHAR(36) DEFAULT NULL, `actor_identifier` VARCHAR(64) NOT NULL,
  `event_type` VARCHAR(32) NOT NULL, `crop_id` VARCHAR(36) DEFAULT NULL,
  `row_id` VARCHAR(96) DEFAULT NULL, `slot_id` VARCHAR(96) DEFAULT NULL,
  `payload` LONGTEXT NOT NULL, `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`), KEY `idx_sfpj_event_field` (`field_id`,`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
}

local requiredTables = {
    'sfpj_schema_migrations', 'sfpj_players', 'sfpj_xp_ledger', 'sfpj_fields',
    'sfpj_field_revisions', 'sfpj_field_rows', 'sfpj_field_slots', 'sfpj_reservations',
    'sfpj_field_claims', 'sfpj_reservation_members', 'sfpj_player_links', 'sfpj_invites',
    'sfpj_cooldowns', 'sfpj_market_stock', 'sfpj_economy_operations',
    'sfpj_economy_receipts', 'sfpj_economy_outbox', 'sfpj_field_events',
}

local requiredColumns = {
    sfpj_players = { 'identifier', 'total_xp' },
    sfpj_xp_ledger = { 'operation_id', 'identifier', 'amount' },
    sfpj_fields = { 'id', 'active_revision_id', 'state_sequence' },
    sfpj_field_slots = { 'revision_id', 'id', 'cell_key' },
    sfpj_reservations = { 'id', 'field_id', 'owner_identifier', 'status', 'expires_at', 'grace_until' },
    sfpj_field_claims = { 'field_id', 'reservation_id' },
    sfpj_reservation_members = { 'reservation_id', 'identifier', 'role', 'status' },
    sfpj_player_links = { 'identifier', 'reservation_id', 'member_status' },
    sfpj_market_stock = { 'tier', 'quantity', 'last_restock_at' },
    sfpj_economy_operations = { 'id', 'identifier', 'kind', 'status', 'amount', 'payload' },
    sfpj_economy_receipts = { 'operation_id', 'identifier', 'kind', 'amount' },
    sfpj_economy_outbox = { 'id', 'operation_id', 'action', 'status', 'next_attempt_at' },
}

local function scalar(query, values)
    local ok, result = pcall(function() return MySQL.scalar.await(query, values) end)
    return ok and result or nil
end

local function transaction(queries)
    local ok, result = pcall(function() return MySQL.transaction.await(queries) end)
    return ok and result == true
end

function PublicJobDatabase.ValidateSchema()
    for _, tableName in ipairs(requiredTables) do
        local present = scalar([[SELECT COUNT(*) FROM information_schema.TABLES
            WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME=?]], { tableName })
        if tonumber(present) ~= 1 then
            Logger.Warn(('Required table %s is missing; import database/publicjob.sql.'):format(tableName), 'db')
            return false
        end
        for _, columnName in ipairs(requiredColumns[tableName] or {}) do
            local columnPresent = scalar([[SELECT COUNT(*) FROM information_schema.COLUMNS
                WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME=? AND COLUMN_NAME=?]], { tableName, columnName })
            if tonumber(columnPresent) ~= 1 then
                Logger.Warn(('Table %s is incompatible; missing column %s.'):format(tableName, columnName), 'db')
                return false
            end
        end
    end
    return true
end

function PublicJobDatabase.Init()
    if not Config.Database.AutoCreateSchema then
        return PublicJobDatabase.ValidateSchema()
    end
    for index, statement in ipairs(statements) do
        local ok, err = pcall(function() MySQL.query.await(statement) end)
        if not ok then
            Logger.Warn(('Public-job schema statement %d failed: %s'):format(index, tostring(err)), 'db')
            return false
        end
    end
    MySQL.insert.await('INSERT IGNORE INTO sfpj_schema_migrations (version) VALUES (1)')
    return PublicJobDatabase.ValidateSchema()
end

local function encode(value) return json.encode(value or {}) end

function PublicJobEconomy.IsFulfilled(status)
    return status == 'completed' or status == 'finalize_pending' or status == 'committed'
        or status == 'delivered' or status == 'credited'
end

function PublicJobEconomy.QueueFinalization(operationId, finalStatus, lastError)
    return transaction({
        { query = "UPDATE sfpj_economy_operations SET status='finalize_pending',last_error=? WHERE id=?",
          values = { lastError or 'receipt_finalize_failed', operationId } },
        { query = [[INSERT INTO sfpj_economy_outbox (id,operation_id,action,status,payload)
            VALUES (?,?,'finalize_operation','pending',?)
            ON DUPLICATE KEY UPDATE status='pending',payload=VALUES(payload),next_attempt_at=0]],
          values = { Sonar.Utils.Uuid(), operationId, encode({ finalStatus = finalStatus or 'completed' }) } },
    })
end

function PublicJobEconomy.Finalize(operationId, finalStatus)
    finalStatus = finalStatus or 'completed'
    local queries = {
        { query = 'UPDATE sfpj_economy_operations SET status=?,last_error=NULL WHERE id=?',
          values = { finalStatus, operationId } },
    }
    if finalStatus == 'completed' then
        queries[#queries + 1] = { query = [[INSERT IGNORE INTO sfpj_economy_receipts
            (operation_id,identifier,kind,amount,payload)
            SELECT id,identifier,kind,amount,payload FROM sfpj_economy_operations WHERE id=?]],
          values = { operationId } }
    end
    if transaction(queries) then return true end
    PublicJobEconomy.QueueFinalization(operationId, finalStatus, 'receipt_finalize_failed')
    return false
end

function PublicJobEconomy.ReconcileFinalizations(timestamp)
    timestamp = tonumber(timestamp) or Sonar.Time.Now()
    for _, row in ipairs(MySQL.query.await([[SELECT id,operation_id,payload FROM sfpj_economy_outbox
        WHERE status='pending' AND action='finalize_operation' AND next_attempt_at<=?
        ORDER BY created_at LIMIT 25]], { timestamp }) or {}) do
        local ok, payload = pcall(json.decode, row.payload or '')
        payload = ok and payload or {}
        local finalStatus = payload.finalStatus or 'completed'
        local queries = {
            { query = "UPDATE sfpj_economy_outbox SET status='completed',attempts=attempts+1,last_error=NULL WHERE id=?",
              values = { row.id } },
            { query = 'UPDATE sfpj_economy_operations SET status=?,last_error=NULL WHERE id=?',
              values = { finalStatus, row.operation_id } },
        }
        if finalStatus == 'completed' then
            queries[#queries + 1] = { query = [[INSERT IGNORE INTO sfpj_economy_receipts
                (operation_id,identifier,kind,amount,payload)
                SELECT id,identifier,kind,amount,payload FROM sfpj_economy_operations WHERE id=?]],
              values = { row.operation_id } }
        end
        if not transaction(queries) then
            MySQL.update.await([[UPDATE sfpj_economy_outbox SET attempts=attempts+1,
                last_error='receipt_finalize_failed',next_attempt_at=? WHERE id=?]], { timestamp + 30, row.id })
        end
    end
end

function PublicJob.Guard(source)
    local identifier = Bridge.GetIdentifier(source)
    if not identifier then return nil, 'player_not_ready' end
    local job = Bridge.GetJobState(source)
    if not job or job.name ~= Config.Job.Name then return nil, 'job_required' end
    if Config.Job.RequireDuty and not job.onDuty then return nil, 'duty_required' end
    return { source = source, identifier = identifier, name = Bridge.GetPlayerName(source), job = job }
end

function PublicJob.IsOnDuty(source)
    return PublicJob.Guard(source) ~= nil
end

function PublicJob.SourceForIdentifier(identifier)
    for _, sourceValue in ipairs(GetPlayers()) do
        local source = tonumber(sourceValue)
        if source and Bridge.GetIdentifier(source) == identifier then return source end
    end
    return nil
end
