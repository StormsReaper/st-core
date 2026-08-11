-- st-core v0.5.0: normalized vehicle registry + legally signed private-sale contracts.
-- Run once after sql/install.sql.

ALTER TABLE st_vehicle_registrations
    ADD COLUMN vin VARCHAR(32) NULL AFTER vehicle_identifier,
    ADD COLUMN owner_name VARCHAR(120) NULL AFTER owner_identifier,
    ADD COLUMN vehicle_model VARCHAR(120) NULL AFTER owner_name,
    ADD COLUMN vehicle_display_name VARCHAR(160) NULL AFTER vehicle_model,
    ADD COLUMN purchase_price DECIMAL(12,2) NOT NULL DEFAULT 0.00 AFTER vehicle_display_name,
    ADD COLUMN purchase_type VARCHAR(32) NULL AFTER purchase_price,
    ADD COLUMN payment_method VARCHAR(32) NULL AFTER purchase_type,
    ADD COLUMN financed TINYINT(1) NOT NULL DEFAULT 0 AFTER payment_method,
    ADD COLUMN dealership VARCHAR(120) NULL AFTER financed;

ALTER TABLE st_vehicle_registrations
    ADD UNIQUE KEY uq_vehicle_registration_vin (vin);

ALTER TABLE st_vehicle_purchases
    ADD COLUMN temporary_plate VARCHAR(12) NULL AFTER vehicle_identifier,
    ADD COLUMN purchase_type VARCHAR(32) NULL AFTER purchase_price,
    ADD COLUMN payment_method VARCHAR(32) NULL AFTER purchase_type,
    ADD COLUMN financed TINYINT(1) NOT NULL DEFAULT 0 AFTER payment_method,
    ADD COLUMN dealership VARCHAR(120) NULL AFTER financed;

CREATE TABLE IF NOT EXISTS st_vehicle_records (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    vehicle_identifier VARCHAR(100) NOT NULL,
    vin VARCHAR(32) NOT NULL,
    plate VARCHAR(12) NOT NULL,
    owner_identifier VARCHAR(100) NOT NULL,
    owner_name VARCHAR(120) NOT NULL,
    vehicle_model VARCHAR(120) NULL,
    vehicle_display_name VARCHAR(160) NULL,
    purchase_price DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    dealership VARCHAR(120) NULL,
    registration_status VARCHAR(24) NOT NULL DEFAULT 'active',
    registration_expires_at BIGINT UNSIGNED NULL,
    insurance_policy_number VARCHAR(40) NULL,
    insurance_status VARCHAR(24) NULL,
    insurance_expires_at BIGINT UNSIGNED NULL,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_st_vehicle_records_identifier (vehicle_identifier),
    UNIQUE KEY uq_st_vehicle_records_vin (vin),
    UNIQUE KEY uq_st_vehicle_records_plate (plate),
    KEY idx_st_vehicle_records_owner (owner_identifier),
    KEY idx_st_vehicle_records_name (owner_name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS st_vehicle_sale_contracts (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    contract_number VARCHAR(40) NOT NULL,
    vehicle_identifier VARCHAR(100) NOT NULL,
    vin VARCHAR(32) NOT NULL,
    plate VARCHAR(12) NOT NULL,
    vehicle_model VARCHAR(120) NULL,
    vehicle_display_name VARCHAR(160) NULL,
    seller_identifier VARCHAR(100) NOT NULL,
    seller_name VARCHAR(120) NOT NULL,
    buyer_identifier VARCHAR(100) NOT NULL,
    buyer_name VARCHAR(120) NOT NULL,
    sale_price DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    seller_signature LONGTEXT NULL,
    buyer_signature LONGTEXT NULL,
    seller_signed_at BIGINT UNSIGNED NULL,
    buyer_signed_at BIGINT UNSIGNED NULL,
    status ENUM('draft','seller_signed','completed','cancelled','expired') NOT NULL DEFAULT 'draft',
    issued_at BIGINT UNSIGNED NOT NULL,
    expires_at BIGINT UNSIGNED NOT NULL,
    completed_at BIGINT UNSIGNED NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_sale_contract_number (contract_number),
    KEY idx_sale_contract_vehicle (vehicle_identifier),
    KEY idx_sale_contract_seller (seller_identifier),
    KEY idx_sale_contract_buyer (buyer_identifier),
    KEY idx_sale_contract_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS st_vehicle_transfer_audit (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    contract_id BIGINT UNSIGNED NULL,
    vehicle_identifier VARCHAR(100) NOT NULL,
    vin VARCHAR(32) NOT NULL,
    old_owner_identifier VARCHAR(100) NOT NULL,
    old_owner_name VARCHAR(120) NOT NULL,
    new_owner_identifier VARCHAR(100) NOT NULL,
    new_owner_name VARCHAR(120) NOT NULL,
    sale_price DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    old_plate VARCHAR(12) NOT NULL,
    new_plate VARCHAR(12) NOT NULL,
    transferred_at BIGINT UNSIGNED NOT NULL,
    PRIMARY KEY (id),
    KEY idx_transfer_vehicle (vehicle_identifier),
    KEY idx_transfer_old_owner (old_owner_identifier),
    KEY idx_transfer_new_owner (new_owner_identifier),
    CONSTRAINT fk_transfer_contract FOREIGN KEY (contract_id) REFERENCES st_vehicle_sale_contracts(id)
        ON UPDATE CASCADE ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS st_dmv_document_audit (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    document_type VARCHAR(40) NOT NULL,
    document_id VARCHAR(80) NOT NULL,
    actor_identifier VARCHAR(100) NOT NULL,
    action VARCHAR(40) NOT NULL,
    metadata LONGTEXT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_dmv_document_audit_document (document_type, document_id),
    KEY idx_dmv_document_audit_actor (actor_identifier)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
