-- ST-Core insurance claims schema
-- Safe to run multiple times.

CREATE TABLE IF NOT EXISTS st_insurance_claims (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    claim_number VARCHAR(32) NOT NULL,
    policy_id BIGINT UNSIGNED NOT NULL,
    vehicle_identifier VARCHAR(100) NOT NULL,
    claimant_identifier VARCHAR(100) NOT NULL,
    claimant_name VARCHAR(160) NOT NULL,
    other_vehicle_identifier VARCHAR(100) NULL,
    other_plate VARCHAR(20) NULL,
    fault_percent DECIMAL(5,2) NOT NULL DEFAULT 0.00,
    damage_estimate DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    payout DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    description TEXT NOT NULL,
    status ENUM('filed','under_review','approved','denied','paid','closed') NOT NULL DEFAULT 'filed',
    adjuster_notes TEXT NULL,
    payout_processed_at BIGINT UNSIGNED NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_st_claim_number (claim_number),
    KEY idx_st_claim_policy (policy_id),
    KEY idx_st_claim_vehicle (vehicle_identifier),
    KEY idx_st_claimant_status (claimant_identifier,status),
    KEY idx_st_claim_status_created (status,created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS st_insurance_claim_audit (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    claim_id BIGINT UNSIGNED NOT NULL,
    actor_identifier VARCHAR(100) NOT NULL,
    actor_name VARCHAR(160) NOT NULL,
    action VARCHAR(60) NOT NULL,
    notes TEXT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_st_claim_audit_claim (claim_id,created_at),
    CONSTRAINT fk_st_claim_audit_claim FOREIGN KEY (claim_id) REFERENCES st_insurance_claims(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
