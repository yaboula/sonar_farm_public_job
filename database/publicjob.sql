-- Sonar Farm Public Job v0.1.0 manual schema.
-- Independent namespace: this file never reads or alters sonar_farm tables.

CREATE TABLE IF NOT EXISTS `sfpj_schema_migrations` (
  `version` INT NOT NULL, `applied_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`version`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `sfpj_players` (
  `identifier` VARCHAR(64) NOT NULL, `total_xp` BIGINT NOT NULL DEFAULT 0,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `sfpj_xp_ledger` (
  `operation_id` VARCHAR(64) NOT NULL, `identifier` VARCHAR(64) NOT NULL,
  `action` VARCHAR(32) NOT NULL, `crop_id` VARCHAR(36) DEFAULT NULL,
  `amount` INT NOT NULL, `payload` LONGTEXT DEFAULT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`operation_id`), KEY `idx_sfpj_xp_player` (`identifier`,`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `sfpj_fields` (
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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `sfpj_field_revisions` (
  `id` VARCHAR(36) NOT NULL, `field_id` VARCHAR(64) NOT NULL,
  `revision_number` INT NOT NULL, `checksum` VARCHAR(64) NOT NULL,
  `status` VARCHAR(16) NOT NULL, `orientation` FLOAT NOT NULL DEFAULT 0,
  `bounds_width` DOUBLE NOT NULL, `bounds_height` DOUBLE NOT NULL,
  `created_by` VARCHAR(64) NOT NULL, `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `activated_at` TIMESTAMP NULL DEFAULT NULL,
  PRIMARY KEY (`id`), UNIQUE KEY `uniq_sfpj_field_rev` (`field_id`,`revision_number`),
  UNIQUE KEY `uniq_sfpj_field_checksum` (`field_id`,`checksum`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `sfpj_field_rows` (
  `revision_id` VARCHAR(36) NOT NULL, `field_id` VARCHAR(64) NOT NULL,
  `id` VARCHAR(96) NOT NULL, `label` VARCHAR(64) NOT NULL, `row_order` INT NOT NULL,
  PRIMARY KEY (`revision_id`,`id`), UNIQUE KEY `uniq_sfpj_row_order` (`revision_id`,`row_order`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `sfpj_field_slots` (
  `revision_id` VARCHAR(36) NOT NULL, `field_id` VARCHAR(64) NOT NULL,
  `row_id` VARCHAR(96) NOT NULL, `id` VARCHAR(96) NOT NULL,
  `slot_order` INT NOT NULL, `legacy_index` INT NOT NULL,
  `pos_x` DOUBLE NOT NULL, `pos_y` DOUBLE NOT NULL, `pos_z` DOUBLE NOT NULL,
  `heading` FLOAT NOT NULL DEFAULT 0, `normalized_x` DOUBLE NOT NULL,
  `normalized_y` DOUBLE NOT NULL, `cell_key` VARCHAR(32) NOT NULL,
  PRIMARY KEY (`revision_id`,`id`), UNIQUE KEY `uniq_sfpj_slot_legacy` (`revision_id`,`legacy_index`),
  KEY `idx_sfpj_slot_cell` (`cell_key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `sfpj_reservations` (
  `id` VARCHAR(36) NOT NULL, `field_id` VARCHAR(64) NOT NULL,
  `owner_identifier` VARCHAR(64) NOT NULL, `status` VARCHAR(16) NOT NULL,
  `plan_hours` INT NOT NULL, `base_price` INT NOT NULL, `paid_price` INT NOT NULL,
  `started_at` BIGINT NOT NULL, `expires_at` BIGINT NOT NULL, `grace_until` BIGINT DEFAULT NULL,
  `released_at` BIGINT DEFAULT NULL, `release_reason` VARCHAR(32) DEFAULT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`), KEY `idx_sfpj_reservation_field` (`field_id`,`status`),
  KEY `idx_sfpj_reservation_owner` (`owner_identifier`,`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `sfpj_field_claims` (
  `field_id` VARCHAR(64) NOT NULL, `reservation_id` VARCHAR(36) NOT NULL,
  PRIMARY KEY (`field_id`), UNIQUE KEY `uniq_sfpj_claim_reservation` (`reservation_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `sfpj_reservation_members` (
  `reservation_id` VARCHAR(36) NOT NULL, `identifier` VARCHAR(64) NOT NULL,
  `display_name` VARCHAR(100) NOT NULL, `role` VARCHAR(16) NOT NULL,
  `status` VARCHAR(16) NOT NULL, `joined_at` BIGINT NOT NULL, `left_at` BIGINT DEFAULT NULL,
  PRIMARY KEY (`reservation_id`,`identifier`), KEY `idx_sfpj_member_identifier` (`identifier`,`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `sfpj_player_links` (
  `identifier` VARCHAR(64) NOT NULL, `reservation_id` VARCHAR(36) NOT NULL,
  `member_status` VARCHAR(16) NOT NULL, PRIMARY KEY (`identifier`),
  KEY `idx_sfpj_link_reservation` (`reservation_id`,`member_status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `sfpj_invites` (
  `id` VARCHAR(36) NOT NULL, `reservation_id` VARCHAR(36) NOT NULL,
  `inviter_identifier` VARCHAR(64) NOT NULL, `invitee_identifier` VARCHAR(64) NOT NULL,
  `status` VARCHAR(16) NOT NULL, `expires_at` BIGINT NOT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`), KEY `idx_sfpj_invitee` (`invitee_identifier`,`status`,`expires_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `sfpj_cooldowns` (
  `identifier` VARCHAR(64) NOT NULL, `field_id` VARCHAR(64) NOT NULL,
  `expires_at` BIGINT NOT NULL, PRIMARY KEY (`identifier`,`field_id`),
  KEY `idx_sfpj_cooldown_expiry` (`expires_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `sfpj_market_stock` (
  `tier` VARCHAR(16) NOT NULL, `quantity` INT NOT NULL,
  `last_restock_at` BIGINT NOT NULL, PRIMARY KEY (`tier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `sfpj_economy_operations` (
  `id` VARCHAR(64) NOT NULL, `identifier` VARCHAR(64) NOT NULL,
  `kind` VARCHAR(24) NOT NULL, `status` VARCHAR(24) NOT NULL,
  `amount` INT NOT NULL DEFAULT 0, `payload` LONGTEXT DEFAULT NULL,
  `last_error` VARCHAR(100) DEFAULT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`), KEY `idx_sfpj_economy_pending` (`status`,`created_at`),
  KEY `idx_sfpj_economy_player` (`identifier`,`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `sfpj_economy_receipts` (
  `operation_id` VARCHAR(64) NOT NULL, `identifier` VARCHAR(64) NOT NULL,
  `kind` VARCHAR(24) NOT NULL, `amount` INT NOT NULL, `payload` LONGTEXT DEFAULT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`operation_id`), KEY `idx_sfpj_receipt_player` (`identifier`,`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `sfpj_economy_outbox` (
  `id` VARCHAR(64) NOT NULL, `operation_id` VARCHAR(64) NOT NULL,
  `action` VARCHAR(24) NOT NULL, `status` VARCHAR(16) NOT NULL DEFAULT 'pending',
  `attempts` INT NOT NULL DEFAULT 0, `payload` LONGTEXT DEFAULT NULL,
  `last_error` VARCHAR(100) DEFAULT NULL, `next_attempt_at` BIGINT NOT NULL DEFAULT 0,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`), UNIQUE KEY `uniq_sfpj_outbox_action` (`operation_id`,`action`),
  KEY `idx_sfpj_outbox_pending` (`status`,`next_attempt_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `sfpj_field_events` (
  `id` VARCHAR(36) NOT NULL, `field_id` VARCHAR(64) NOT NULL,
  `reservation_id` VARCHAR(36) DEFAULT NULL, `actor_identifier` VARCHAR(64) NOT NULL,
  `event_type` VARCHAR(32) NOT NULL, `crop_id` VARCHAR(36) DEFAULT NULL,
  `row_id` VARCHAR(96) DEFAULT NULL, `slot_id` VARCHAR(96) DEFAULT NULL,
  `payload` LONGTEXT NOT NULL, `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`), KEY `idx_sfpj_event_field` (`field_id`,`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `sfpj_crops` (
  `id` VARCHAR(36) NOT NULL, `crop_type` VARCHAR(64) NOT NULL,
  `owner` VARCHAR(64) DEFAULT NULL, `zone` VARCHAR(64) DEFAULT NULL, `slot` INT DEFAULT NULL,
  `cell` VARCHAR(32) NOT NULL, `pos_x` DOUBLE NOT NULL, `pos_y` DOUBLE NOT NULL,
  `pos_z` DOUBLE NOT NULL, `heading` FLOAT NOT NULL DEFAULT 0,
  `planted_at` BIGINT NOT NULL, `growth_time` INT NOT NULL,
  `state` VARCHAR(32) NOT NULL, `data` LONGTEXT NOT NULL,
  PRIMARY KEY (`id`), UNIQUE KEY `uniq_zone_slot` (`zone`,`slot`),
  KEY `idx_sfpj_crop_cell` (`cell`), KEY `idx_sfpj_crop_owner` (`owner`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT IGNORE INTO `sfpj_schema_migrations` (`version`) VALUES (1);
