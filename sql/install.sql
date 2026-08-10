-- st-core vehicle registration and insurance schema
-- Requires MySQL 8.0+ / MariaDB 10.5+ and oxmysql.

CREATE TABLE IF NOT EXISTS st_vehicle_registrations (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    vehicle_identifier VARCHAR(100) NOT NULL,
    owner_identifier VARCHAR(100) NOT NULL,
    plate VARCHAR(12) NOT NULL,
    plate_type ENUM('standard', 'custom') NOT NULL DEFAULT 'standard',
    registered_at BIGINT UNSIGNED NOT NULL,
    expires_at BIGINT UNSIGNED NOT NULL,
    status ENUM('active', 'expired', 'suspended', 'cancelled') NOT NULL DEFAULT 'active',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_vehicle_registration_vehicle (vehicle_identifier),
    UNIQUE KEY uq_vehicle_registration_plate (plate),
    KEY idx_vehicle_registration_owner (owner_identifier),
    KEY idx_vehicle_registration_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS st_insurance_plans (
    id VARCHAR(40) NOT NULL,
    name VARCHAR(80) NOT NULL,
    description VARCHAR(255) NULL,
    coverage_type ENUM('liability', 'standard', 'comprehensive', 'premium') NOT NULL,
    monthly_premium DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    liability_limit DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    collision_limit DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    comprehensive_limit DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    deductible DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    active TINYINT(1) NOT NULL DEFAULT 1,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_insurance_plans_active (active)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS st_vehicle_insurance (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    vehicle_identifier VARCHAR(100) NOT NULL,
    owner_identifier VARCHAR(100) NOT NULL,
    policy_number VARCHAR(40) NOT NULL,
    plan_id VARCHAR(40) NOT NULL,
    premium DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    effective_at BIGINT UNSIGNED NOT NULL,
    expires_at BIGINT UNSIGNED NOT NULL,
    status ENUM('active', 'expired', 'cancelled', 'suspended') NOT NULL DEFAULT 'active',
    cancellation_reason VARCHAR(255) NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_vehicle_insurance_policy (policy_number),
    KEY idx_vehicle_insurance_vehicle (vehicle_identifier),
    KEY idx_vehicle_insurance_owner (owner_identifier),
    KEY idx_vehicle_insurance_status (status),
    CONSTRAINT fk_vehicle_insurance_plan FOREIGN KEY (plan_id) REFERENCES st_insurance_plans(id)
        ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS st_insurance_claims (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    policy_id BIGINT UNSIGNED NOT NULL,
    claimant_identifier VARCHAR(100) NOT NULL,
    incident_date BIGINT UNSIGNED NOT NULL,
    claim_type VARCHAR(40) NOT NULL,
    description TEXT NULL,
    amount DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    status ENUM('submitted', 'under_review', 'approved', 'denied', 'paid') NOT NULL DEFAULT 'submitted',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_insurance_claims_policy (policy_id),
    KEY idx_insurance_claims_claimant (claimant_identifier),
    CONSTRAINT fk_insurance_claims_policy FOREIGN KEY (policy_id) REFERENCES st_vehicle_insurance(id)
        ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO st_insurance_plans
    (id, name, description, coverage_type, monthly_premium, liability_limit, collision_limit, comprehensive_limit, deductible)
VALUES
    ('liability', 'Liability', 'Required minimum coverage for legally operating a vehicle.', 'liability', 125.00, 100000.00, 0.00, 0.00, 0.00),
    ('standard', 'Standard', 'Liability coverage with collision protection.', 'standard', 225.00, 100000.00, 50000.00, 0.00, 1000.00),
    ('comprehensive', 'Comprehensive', 'Liability, collision, theft, weather, and other covered losses.', 'comprehensive', 325.00, 250000.00, 100000.00, 100000.00, 750.00),
    ('premium', 'Premium', 'High-limit comprehensive coverage with a lower deductible.', 'premium', 475.00, 500000.00, 250000.00, 250000.00, 500.00)
ON DUPLICATE KEY UPDATE
    name = VALUES(name),
    description = VALUES(description),
    coverage_type = VALUES(coverage_type),
    monthly_premium = VALUES(monthly_premium),
    liability_limit = VALUES(liability_limit),
    collision_limit = VALUES(collision_limit),
    comprehensive_limit = VALUES(comprehensive_limit),
    deductible = VALUES(deductible),
    updated_at = CURRENT_TIMESTAMP;
