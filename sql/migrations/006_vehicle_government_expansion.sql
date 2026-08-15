-- st-core vehicle/DMV expansion: titles, liens, history, licenses, claims, appointments and enforcement.

CREATE TABLE IF NOT EXISTS st_vehicle_titles (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    title_number VARCHAR(40) NOT NULL,
    vehicle_identifier VARCHAR(100) NOT NULL,
    owner_identifier VARCHAR(100) NOT NULL,
    owner_name VARCHAR(120) NOT NULL,
    title_status ENUM('clear','lien','salvage','rebuilt','branded','cancelled') NOT NULL DEFAULT 'clear',
    issue_date BIGINT UNSIGNED NOT NULL,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id), UNIQUE KEY uq_title_number (title_number), UNIQUE KEY uq_title_vehicle (vehicle_identifier),
    KEY idx_title_owner (owner_identifier)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS st_vehicle_liens (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    vehicle_identifier VARCHAR(100) NOT NULL,
    lienholder_identifier VARCHAR(100) NOT NULL,
    lienholder_name VARCHAR(160) NOT NULL,
    original_amount DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    remaining_balance DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    monthly_payment DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    next_payment_at BIGINT UNSIGNED NULL,
    status ENUM('active','paid','defaulted','released','repossessed') NOT NULL DEFAULT 'active',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id), KEY idx_lien_vehicle (vehicle_identifier), KEY idx_lienholder (lienholder_identifier)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS st_vehicle_history (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    vehicle_identifier VARCHAR(100) NOT NULL,
    event_type VARCHAR(40) NOT NULL,
    actor_identifier VARCHAR(100) NULL,
    actor_name VARCHAR(120) NULL,
    old_owner_identifier VARCHAR(100) NULL,
    old_owner_name VARCHAR(120) NULL,
    new_owner_identifier VARCHAR(100) NULL,
    new_owner_name VARCHAR(120) NULL,
    old_plate VARCHAR(12) NULL,
    new_plate VARCHAR(12) NULL,
    details LONGTEXT NULL,
    occurred_at BIGINT UNSIGNED NOT NULL,
    PRIMARY KEY (id), KEY idx_vehicle_history_vehicle (vehicle_identifier), KEY idx_vehicle_history_event (event_type)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS st_driver_licenses (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    license_number VARCHAR(40) NOT NULL,
    owner_identifier VARCHAR(100) NOT NULL,
    owner_name VARCHAR(120) NOT NULL,
    class VARCHAR(20) NOT NULL DEFAULT 'C',
    endorsements VARCHAR(255) NULL,
    restrictions VARCHAR(255) NULL,
    points INT NOT NULL DEFAULT 0,
    status ENUM('valid','expired','suspended','revoked') NOT NULL DEFAULT 'valid',
    issued_at BIGINT UNSIGNED NOT NULL,
    expires_at BIGINT UNSIGNED NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id), UNIQUE KEY uq_license_number (license_number), UNIQUE KEY uq_license_owner (owner_identifier), KEY idx_license_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS st_driver_license_events (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    license_number VARCHAR(40) NOT NULL,
    actor_identifier VARCHAR(100) NULL,
    event_type VARCHAR(40) NOT NULL,
    points_delta INT NOT NULL DEFAULT 0,
    reason VARCHAR(255) NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id), KEY idx_license_events_number (license_number)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS st_insurance_claims (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    claim_number VARCHAR(40) NOT NULL,
    policy_id BIGINT UNSIGNED NULL,
    vehicle_identifier VARCHAR(100) NOT NULL,
    claimant_identifier VARCHAR(100) NOT NULL,
    claimant_name VARCHAR(120) NOT NULL,
    other_vehicle_identifier VARCHAR(100) NULL,
    other_plate VARCHAR(12) NULL,
    fault_percent INT NOT NULL DEFAULT 0,
    damage_estimate DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    payout DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    description TEXT NULL,
    status ENUM('open','investigating','approved','denied','paid','closed') NOT NULL DEFAULT 'open',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id), UNIQUE KEY uq_claim_number (claim_number), KEY idx_claim_vehicle (vehicle_identifier), KEY idx_claimant (claimant_identifier)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS st_dmv_appointments (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    appointment_number VARCHAR(40) NOT NULL,
    owner_identifier VARCHAR(100) NOT NULL,
    owner_name VARCHAR(120) NOT NULL,
    appointment_type VARCHAR(40) NOT NULL,
    scheduled_at BIGINT UNSIGNED NOT NULL,
    status ENUM('scheduled','completed','cancelled','missed') NOT NULL DEFAULT 'scheduled',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id), UNIQUE KEY uq_appointment_number (appointment_number), KEY idx_appointment_owner (owner_identifier), KEY idx_appointment_time (scheduled_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS st_vehicle_enforcement (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    vehicle_identifier VARCHAR(100) NOT NULL,
    plate VARCHAR(12) NOT NULL,
    event_type VARCHAR(40) NOT NULL,
    status VARCHAR(24) NOT NULL DEFAULT 'active',
    officer_identifier VARCHAR(100) NULL,
    notes TEXT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    resolved_at BIGINT UNSIGNED NULL,
    PRIMARY KEY (id), KEY idx_enforcement_vehicle (vehicle_identifier), KEY idx_enforcement_plate (plate), KEY idx_enforcement_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS st_vehicle_mileage (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    vehicle_identifier VARCHAR(100) NOT NULL,
    mileage DECIMAL(12,1) NOT NULL DEFAULT 0.0,
    source VARCHAR(40) NOT NULL DEFAULT 'manual',
    recorded_by VARCHAR(100) NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id), KEY idx_mileage_vehicle (vehicle_identifier)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS st_vehicle_accidents (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    accident_number VARCHAR(40) NOT NULL,
    vehicle_identifier VARCHAR(100) NOT NULL,
    plate VARCHAR(12) NOT NULL,
    reported_by VARCHAR(100) NULL,
    damage_estimate DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    fault_percent INT NOT NULL DEFAULT 0,
    description TEXT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id), UNIQUE KEY uq_accident_number (accident_number), KEY idx_accident_vehicle (vehicle_identifier)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS st_dmv_transactions (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    actor_identifier VARCHAR(100) NOT NULL,
    transaction_type VARCHAR(40) NOT NULL,
    amount DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    reference_id VARCHAR(80) NULL,
    metadata LONGTEXT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id), KEY idx_dmv_transactions_actor (actor_identifier), KEY idx_dmv_transactions_type (transaction_type)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
