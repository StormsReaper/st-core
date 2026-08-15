-- ST-Core foundation schema
-- MySQL 8 / MariaDB compatible.
-- QBCore/ESX vehicle ownership remains the framework source of truth.
-- st_vehicle_registrations, st_vehicle_insurance, and st_vehicle_records are the ST-Core regulatory layer.
-- VINs are intentionally not required by ST-Core.

CREATE TABLE IF NOT EXISTS st_players (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    license VARCHAR(100) NULL,
    license2 VARCHAR(100) NULL,
    fivem VARCHAR(100) NULL,
    discord VARCHAR(100) NULL,
    steam VARCHAR(100) NULL,
    xbox VARCHAR(100) NULL,
    live VARCHAR(100) NULL,
    ip VARCHAR(45) NULL,
    last_joined_at TIMESTAMP NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_st_players_license (license),
    UNIQUE KEY uq_st_players_fivem (fivem),
    KEY idx_st_players_discord (discord),
    KEY idx_st_players_steam (steam)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS st_characters (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    player_id BIGINT UNSIGNED NOT NULL,
    slot TINYINT UNSIGNED NOT NULL,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    date_of_birth DATE NOT NULL,
    height_cm SMALLINT UNSIGNED NULL,
    weight_kg DECIMAL(5,2) NULL,
    eye_color VARCHAR(32) NULL,
    hair_color VARCHAR(32) NULL,
    occupation VARCHAR(100) NULL,
    fingerprint VARCHAR(128) NOT NULL,
    blood_type ENUM('A+','A-','B+','B-','AB+','AB-','O+','O-') NOT NULL,
    hair_dna VARCHAR(128) NOT NULL,
    ssn CHAR(11) NOT NULL,
    state_id CHAR(12) NOT NULL,
    is_active TINYINT(1) NOT NULL DEFAULT 0,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_character_slot (player_id, slot),
    UNIQUE KEY uq_character_fingerprint (fingerprint),
    UNIQUE KEY uq_character_ssn (ssn),
    UNIQUE KEY uq_character_state_id (state_id),
    KEY idx_character_name (last_name, first_name),
    CONSTRAINT fk_character_player FOREIGN KEY (player_id) REFERENCES st_players(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Legacy ST vehicle cache. It is retained for compatibility with future ST-Core systems,
-- but VIN is optional and is never used as the authoritative vehicle identifier.
CREATE TABLE IF NOT EXISTS st_vehicles (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    owner_character_id BIGINT UNSIGNED NULL,
    vin CHAR(17) NULL,
    plate VARCHAR(12) NOT NULL,
    plate_type ENUM('standard','custom','government','dealer') NOT NULL DEFAULT 'standard',
    make VARCHAR(50) NULL,
    model VARCHAR(100) NOT NULL,
    display_name VARCHAR(100) NULL,
    model_hash BIGINT NULL,
    year SMALLINT UNSIGNED NULL,
    fuel_type ENUM('gas','diesel','electric') NOT NULL DEFAULT 'gas',
    fuel_level DECIMAL(5,2) NOT NULL DEFAULT 100.00,
    mileage DECIMAL(10,1) NOT NULL DEFAULT 0.0,
    engine_health DECIMAL(6,2) NOT NULL DEFAULT 1000.0,
    body_health DECIMAL(6,2) NOT NULL DEFAULT 1000.0,
    state ENUM('stored','out','impounded','destroyed') NOT NULL DEFAULT 'stored',
    garage VARCHAR(100) NULL,
    properties JSON NULL,
    vehicle_data JSON NULL,
    purchased_at TIMESTAMP NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_vehicle_plate (plate),
    KEY idx_vehicle_vin (vin),
    KEY idx_vehicle_owner (owner_character_id),
    KEY idx_vehicle_model (model),
    CONSTRAINT fk_vehicle_owner FOREIGN KEY (owner_character_id) REFERENCES st_characters(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS st_item_definitions (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    name VARCHAR(100) NOT NULL,
    label VARCHAR(100) NOT NULL,
    description TEXT NULL,
    item_type ENUM('item','weapon','phone','document','food','medical','material','tool','currency','other') NOT NULL DEFAULT 'item',
    category VARCHAR(50) NULL,
    weight_grams INT UNSIGNED NOT NULL DEFAULT 0,
    stackable TINYINT(1) NOT NULL DEFAULT 1,
    max_stack INT UNSIGNED NOT NULL DEFAULT 1,
    usable TINYINT(1) NOT NULL DEFAULT 0,
    droppable TINYINT(1) NOT NULL DEFAULT 1,
    metadata_schema JSON NULL,
    properties JSON NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_item_name (name),
    KEY idx_item_type (item_type),
    KEY idx_item_category (category)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS st_inventories (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    owner_character_id BIGINT UNSIGNED NULL,
    inventory_type ENUM('player','vehicle','stash','container','drop','trunk','glovebox','other') NOT NULL DEFAULT 'player',
    name VARCHAR(100) NULL,
    slots SMALLINT UNSIGNED NOT NULL DEFAULT 40,
    max_weight_grams BIGINT UNSIGNED NOT NULL DEFAULT 30000,
    metadata JSON NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_inventory_owner (owner_character_id),
    KEY idx_inventory_type (inventory_type),
    CONSTRAINT fk_inventory_owner FOREIGN KEY (owner_character_id) REFERENCES st_characters(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS st_inventory_items (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    inventory_id BIGINT UNSIGNED NOT NULL,
    item_definition_id BIGINT UNSIGNED NOT NULL,
    slot SMALLINT UNSIGNED NOT NULL,
    quantity INT UNSIGNED NOT NULL DEFAULT 1,
    metadata JSON NULL,
    serial_number VARCHAR(64) NULL,
    durability DECIMAL(6,2) NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_inventory_slot (inventory_id, slot),
    UNIQUE KEY uq_item_serial (serial_number),
    KEY idx_inventory_item_definition (item_definition_id),
    CONSTRAINT fk_inventory_item_inventory FOREIGN KEY (inventory_id) REFERENCES st_inventories(id) ON DELETE CASCADE,
    CONSTRAINT fk_inventory_item_definition FOREIGN KEY (item_definition_id) REFERENCES st_item_definitions(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS st_weapon_instances (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    inventory_item_id BIGINT UNSIGNED NOT NULL,
    weapon_name VARCHAR(100) NOT NULL,
    serial_number VARCHAR(64) NOT NULL,
    ammo INT UNSIGNED NOT NULL DEFAULT 0,
    components JSON NULL,
    condition_percent DECIMAL(5,2) NOT NULL DEFAULT 100.00,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_weapon_inventory_item (inventory_item_id),
    UNIQUE KEY uq_weapon_serial (serial_number),
    CONSTRAINT fk_weapon_inventory_item FOREIGN KEY (inventory_item_id) REFERENCES st_inventory_items(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS st_character_inventories (
    character_id BIGINT UNSIGNED NOT NULL,
    inventory_id BIGINT UNSIGNED NOT NULL,
    PRIMARY KEY (character_id),
    UNIQUE KEY uq_character_inventory (inventory_id),
    CONSTRAINT fk_character_inventory_character FOREIGN KEY (character_id) REFERENCES st_characters(id) ON DELETE CASCADE,
    CONSTRAINT fk_character_inventory_inventory FOREIGN KEY (inventory_id) REFERENCES st_inventories(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
