CREATE TABLE IF NOT EXISTS `sfpj_crops` (
  `id` VARCHAR(36) NOT NULL, `crop_type` VARCHAR(64) NOT NULL,
  `owner` VARCHAR(64) DEFAULT NULL, `zone` VARCHAR(64) DEFAULT NULL,
  `slot` INT DEFAULT NULL, `cell` VARCHAR(32) NOT NULL,
  `pos_x` DOUBLE NOT NULL, `pos_y` DOUBLE NOT NULL, `pos_z` DOUBLE NOT NULL,
  `heading` FLOAT NOT NULL DEFAULT 0, `planted_at` BIGINT NOT NULL,
  `growth_time` INT NOT NULL DEFAULT 0, `state` VARCHAR(16) NOT NULL DEFAULT 'planted',
  `data` LONGTEXT DEFAULT NULL, `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`), UNIQUE KEY `uniq_zone_slot` (`zone`,`slot`),
  KEY `idx_cell` (`cell`), KEY `idx_zone` (`zone`), KEY `idx_owner` (`owner`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
