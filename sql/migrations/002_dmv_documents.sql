-- st-core DMV/purchase/document additions

CREATE TABLE IF NOT EXISTS st_vehicle_purchases (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    owner_identifier VARCHAR(100) NOT NULL,
    vehicle_identifier VARCHAR(100) NOT NULL,
    model VARCHAR(80) NOT NULL,
    display_name VARCHAR(120) NOT NULL,
    purchase_price DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    purchased_at BIGINT UNSIGNED NOT NULL,
    registered_at BIGINT UNSIGNED NULL,
    status ENUM('pending', 'registered', 'cancelled') NOT NULL DEFAULT 'pending',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_vehicle_purchase_identifier (vehicle_identifier),
    KEY idx_vehicle_purchase_owner_status (owner_identifier, status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

ALTER TABLE st_vehicle_registrations
    MODIFY registered_at BIGINT UNSIGNED NOT NULL,
    MODIFY expires_at BIGINT UNSIGNED NOT NULL;
