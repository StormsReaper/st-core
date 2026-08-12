-- ST-Core Section 3: DMV, vehicle insurance, DOT, property, devices, PCs, and fictional crypto systems

CREATE TABLE IF NOT EXISTS st_driver_licenses (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    character_id BIGINT UNSIGNED NOT NULL,
    license_number CHAR(12) NOT NULL,
    class VARCHAR(20) NOT NULL DEFAULT 'C',
    status ENUM('valid','suspended','revoked','expired') NOT NULL DEFAULT 'valid',
    issued_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP NULL,
    PRIMARY KEY (id), UNIQUE KEY uq_license_number (license_number), UNIQUE KEY uq_license_character (character_id),
    CONSTRAINT fk_license_character FOREIGN KEY (character_id) REFERENCES st_characters(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS st_vehicle_registrations (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    vehicle_id BIGINT UNSIGNED NOT NULL,
    character_id BIGINT UNSIGNED NOT NULL,
    registration_number CHAR(12) NOT NULL,
    plate_number VARCHAR(12) NOT NULL,
    registered_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP NULL,
    status ENUM('active','expired','suspended','cancelled') NOT NULL DEFAULT 'active',
    PRIMARY KEY (id), UNIQUE KEY uq_registration_number (registration_number), UNIQUE KEY uq_registered_vehicle (vehicle_id),
    CONSTRAINT fk_registration_vehicle FOREIGN KEY (vehicle_id) REFERENCES st_vehicles(id) ON DELETE CASCADE,
    CONSTRAINT fk_registration_character FOREIGN KEY (character_id) REFERENCES st_characters(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS st_vehicle_insurance_policies (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    vehicle_id BIGINT UNSIGNED NOT NULL,
    policy_number CHAR(16) NOT NULL,
    coverage_type ENUM('liability','collision','comprehensive','full') NOT NULL,
    premium DECIMAL(12,2) NOT NULL,
    deductible DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    coverage_limit DECIMAL(15,2) NOT NULL DEFAULT 0.00,
    provider_business_id BIGINT UNSIGNED NULL,
    status ENUM('active','lapsed','cancelled') NOT NULL DEFAULT 'active',
    starts_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP NULL,
    PRIMARY KEY (id), UNIQUE KEY uq_policy_number (policy_number), KEY idx_policy_vehicle (vehicle_id),
    CONSTRAINT fk_policy_vehicle FOREIGN KEY (vehicle_id) REFERENCES st_vehicles(id) ON DELETE CASCADE,
    CONSTRAINT fk_policy_provider FOREIGN KEY (provider_business_id) REFERENCES st_businesses(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS st_insurance_claims (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    policy_id BIGINT UNSIGNED NOT NULL,
    claimant_character_id BIGINT UNSIGNED NULL,
    incident_description TEXT NOT NULL,
    claim_amount DECIMAL(15,2) NOT NULL DEFAULT 0.00,
    approved_amount DECIMAL(15,2) NOT NULL DEFAULT 0.00,
    status ENUM('open','investigating','approved','denied','paid','closed') NOT NULL DEFAULT 'open',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id), CONSTRAINT fk_claim_policy FOREIGN KEY (policy_id) REFERENCES st_vehicle_insurance_policies(id) ON DELETE CASCADE,
    CONSTRAINT fk_claimant_character FOREIGN KEY (claimant_character_id) REFERENCES st_characters(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS st_dot_requests (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    requested_by_character_id BIGINT UNSIGNED NULL,
    assigned_character_id BIGINT UNSIGNED NULL,
    request_type ENUM('tow','road_closure','roadside','impound_recovery','other') NOT NULL,
    vehicle_id BIGINT UNSIGNED NULL,
    location_data JSON NOT NULL,
    notes TEXT NULL,
    status ENUM('queued','assigned','enroute','onsite','completed','cancelled') NOT NULL DEFAULT 'queued',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMP NULL,
    PRIMARY KEY (id), KEY idx_dot_status (status),
    CONSTRAINT fk_dot_requester FOREIGN KEY (requested_by_character_id) REFERENCES st_characters(id) ON DELETE SET NULL,
    CONSTRAINT fk_dot_assignee FOREIGN KEY (assigned_character_id) REFERENCES st_characters(id) ON DELETE SET NULL,
    CONSTRAINT fk_dot_vehicle FOREIGN KEY (vehicle_id) REFERENCES st_vehicles(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS st_impound_records (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    vehicle_id BIGINT UNSIGNED NOT NULL,
    impounded_by_character_id BIGINT UNSIGNED NULL,
    reason VARCHAR(255) NOT NULL,
    location VARCHAR(100) NULL,
    fee DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    released_at TIMESTAMP NULL,
    status ENUM('impounded','released','auctioned','destroyed') NOT NULL DEFAULT 'impounded',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id), KEY idx_impound_vehicle (vehicle_id), KEY idx_impound_status (status),
    CONSTRAINT fk_impound_vehicle FOREIGN KEY (vehicle_id) REFERENCES st_vehicles(id) ON DELETE CASCADE,
    CONSTRAINT fk_impound_character FOREIGN KEY (impounded_by_character_id) REFERENCES st_characters(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS st_properties (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    address VARCHAR(180) NOT NULL,
    property_type ENUM('house','apartment','business','garage','office','other') NOT NULL,
    owner_character_id BIGINT UNSIGNED NULL,
    owner_business_id BIGINT UNSIGNED NULL,
    purchase_price DECIMAL(15,2) NULL,
    rent_price DECIMAL(12,2) NULL,
    mortgage_loan_id BIGINT UNSIGNED NULL,
    state ENUM('owned','rented','vacant','foreclosed') NOT NULL DEFAULT 'vacant',
    property_data JSON NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id), KEY idx_property_owner (owner_character_id), KEY idx_property_business (owner_business_id),
    CONSTRAINT fk_property_character FOREIGN KEY (owner_character_id) REFERENCES st_characters(id) ON DELETE SET NULL,
    CONSTRAINT fk_property_business FOREIGN KEY (owner_business_id) REFERENCES st_businesses(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS st_property_tenants (
    property_id BIGINT UNSIGNED NOT NULL,
    character_id BIGINT UNSIGNED NOT NULL,
    rent_amount DECIMAL(12,2) NOT NULL,
    lease_start DATE NOT NULL,
    lease_end DATE NULL,
    active TINYINT(1) NOT NULL DEFAULT 1,
    PRIMARY KEY (property_id, character_id),
    CONSTRAINT fk_tenant_property FOREIGN KEY (property_id) REFERENCES st_properties(id) ON DELETE CASCADE,
    CONSTRAINT fk_tenant_character FOREIGN KEY (character_id) REFERENCES st_characters(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS st_devices (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    owner_character_id BIGINT UNSIGNED NULL,
    device_type ENUM('phone','tablet','laptop','radio','desktop','monitor','modem','other') NOT NULL,
    brand VARCHAR(60) NULL,
    model VARCHAR(100) NOT NULL,
    serial_number VARCHAR(64) NOT NULL,
    device_data JSON NULL,
    status ENUM('active','lost','disabled','destroyed') NOT NULL DEFAULT 'active',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id), UNIQUE KEY uq_device_serial (serial_number), KEY idx_device_owner (owner_character_id),
    CONSTRAINT fk_device_owner FOREIGN KEY (owner_character_id) REFERENCES st_characters(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS st_pc_components (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    component_type ENUM('motherboard','cpu','ram','hdd','ssd','gpu','cooling','psu','case') NOT NULL,
    manufacturer VARCHAR(60) NULL,
    model VARCHAR(120) NOT NULL,
    performance_score INT UNSIGNED NOT NULL DEFAULT 1,
    power_watts INT UNSIGNED NOT NULL DEFAULT 0,
    capacity_value DECIMAL(12,2) NULL,
    price DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    component_data JSON NULL,
    PRIMARY KEY (id), KEY idx_component_type (component_type)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS st_pcs (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    owner_character_id BIGINT UNSIGNED NULL,
    name VARCHAR(100) NOT NULL,
    motherboard_id BIGINT UNSIGNED NULL,
    cpu_id BIGINT UNSIGNED NULL,
    ram_id BIGINT UNSIGNED NULL,
    storage_id BIGINT UNSIGNED NULL,
    gpu_id BIGINT UNSIGNED NULL,
    cooling_id BIGINT UNSIGNED NULL,
    psu_id BIGINT UNSIGNED NULL,
    case_id BIGINT UNSIGNED NULL,
    performance_score INT UNSIGNED NOT NULL DEFAULT 0,
    assembled TINYINT(1) NOT NULL DEFAULT 0,
    pc_data JSON NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id), KEY idx_pc_owner (owner_character_id),
    CONSTRAINT fk_pc_owner FOREIGN KEY (owner_character_id) REFERENCES st_characters(id) ON DELETE SET NULL,
    CONSTRAINT fk_pc_motherboard FOREIGN KEY (motherboard_id) REFERENCES st_pc_components(id) ON DELETE SET NULL,
    CONSTRAINT fk_pc_cpu FOREIGN KEY (cpu_id) REFERENCES st_pc_components(id) ON DELETE SET NULL,
    CONSTRAINT fk_pc_ram FOREIGN KEY (ram_id) REFERENCES st_pc_components(id) ON DELETE SET NULL,
    CONSTRAINT fk_pc_storage FOREIGN KEY (storage_id) REFERENCES st_pc_components(id) ON DELETE SET NULL,
    CONSTRAINT fk_pc_gpu FOREIGN KEY (gpu_id) REFERENCES st_pc_components(id) ON DELETE SET NULL,
    CONSTRAINT fk_pc_cooling FOREIGN KEY (cooling_id) REFERENCES st_pc_components(id) ON DELETE SET NULL,
    CONSTRAINT fk_pc_psu FOREIGN KEY (psu_id) REFERENCES st_pc_components(id) ON DELETE SET NULL,
    CONSTRAINT fk_pc_case FOREIGN KEY (case_id) REFERENCES st_pc_components(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS st_pc_network_connections (
    pc_id BIGINT UNSIGNED NOT NULL,
    property_id BIGINT UNSIGNED NOT NULL,
    modem_device_id BIGINT UNSIGNED NULL,
    connected_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (pc_id),
    CONSTRAINT fk_pc_network_pc FOREIGN KEY (pc_id) REFERENCES st_pcs(id) ON DELETE CASCADE,
    CONSTRAINT fk_pc_network_property FOREIGN KEY (property_id) REFERENCES st_properties(id) ON DELETE CASCADE,
    CONSTRAINT fk_pc_network_modem FOREIGN KEY (modem_device_id) REFERENCES st_devices(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS st_crypto_wallets (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    character_id BIGINT UNSIGNED NOT NULL,
    wallet_address CHAR(64) NOT NULL,
    balance DECIMAL(30,8) NOT NULL DEFAULT 0.00000000,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id), UNIQUE KEY uq_wallet_address (wallet_address), UNIQUE KEY uq_wallet_character (character_id),
    CONSTRAINT fk_wallet_character FOREIGN KEY (character_id) REFERENCES st_characters(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS st_crypto_transactions (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    from_wallet_id BIGINT UNSIGNED NULL,
    to_wallet_id BIGINT UNSIGNED NULL,
    amount DECIMAL(30,8) NOT NULL,
    transaction_hash CHAR(64) NOT NULL,
    transaction_type ENUM('transfer','mining_reward','market_purchase','other') NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id), UNIQUE KEY uq_crypto_hash (transaction_hash),
    CONSTRAINT fk_crypto_from FOREIGN KEY (from_wallet_id) REFERENCES st_crypto_wallets(id) ON DELETE SET NULL,
    CONSTRAINT fk_crypto_to FOREIGN KEY (to_wallet_id) REFERENCES st_crypto_wallets(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS st_crypto_mining_sessions (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    pc_id BIGINT UNSIGNED NOT NULL,
    wallet_id BIGINT UNSIGNED NOT NULL,
    performance_score INT UNSIGNED NOT NULL,
    mining_rate DECIMAL(18,8) NOT NULL,
    started_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    ended_at TIMESTAMP NULL,
    status ENUM('active','stopped','completed') NOT NULL DEFAULT 'active',
    PRIMARY KEY (id), KEY idx_mining_pc (pc_id),
    CONSTRAINT fk_mining_pc FOREIGN KEY (pc_id) REFERENCES st_pcs(id) ON DELETE CASCADE,
    CONSTRAINT fk_mining_wallet FOREIGN KEY (wallet_id) REFERENCES st_crypto_wallets(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Fictional in-game marketplace for ST-Core's roleplay economy.
CREATE TABLE IF NOT EXISTS st_marketplace_listings (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    listing_type ENUM('legal','restricted','black_market') NOT NULL,
    name VARCHAR(120) NOT NULL,
    description TEXT NULL,
    price_crypto DECIMAL(30,8) NOT NULL,
    stock INT UNSIGNED NOT NULL DEFAULT 0,
    item_definition_id BIGINT UNSIGNED NULL,
    active TINYINT(1) NOT NULL DEFAULT 1,
    metadata JSON NULL,
    PRIMARY KEY (id), KEY idx_marketplace_type (listing_type),
    CONSTRAINT fk_marketplace_item FOREIGN KEY (item_definition_id) REFERENCES st_item_definitions(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS st_marketplace_orders (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    listing_id BIGINT UNSIGNED NOT NULL,
    buyer_character_id BIGINT UNSIGNED NOT NULL,
    wallet_id BIGINT UNSIGNED NOT NULL,
    quantity INT UNSIGNED NOT NULL DEFAULT 1,
    total_crypto DECIMAL(30,8) NOT NULL,
    status ENUM('pending','paid','fulfilled','cancelled') NOT NULL DEFAULT 'pending',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fulfilled_at TIMESTAMP NULL,
    PRIMARY KEY (id), KEY idx_market_order_buyer (buyer_character_id),
    CONSTRAINT fk_market_order_listing FOREIGN KEY (listing_id) REFERENCES st_marketplace_listings(id) ON DELETE RESTRICT,
    CONSTRAINT fk_market_order_buyer FOREIGN KEY (buyer_character_id) REFERENCES st_characters(id) ON DELETE CASCADE,
    CONSTRAINT fk_market_order_wallet FOREIGN KEY (wallet_id) REFERENCES st_crypto_wallets(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
