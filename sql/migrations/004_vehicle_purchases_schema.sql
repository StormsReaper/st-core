-- st-core vehicle purchase tracking.
-- Plate-based DMV lookup does not depend on this table, but the pending-purchase
-- UI and JG integration use it when available.

CREATE TABLE IF NOT EXISTS st_vehicle_purchases (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    owner_identifier VARCHAR(100) NOT NULL,
    vehicle_identifier VARCHAR(100) NOT NULL,
    temporary_plate VARCHAR(12) NULL,
    model VARCHAR(80) NOT NULL,
    display_name VARCHAR(120) NOT NULL,
    purchase_price DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    purchase_type VARCHAR(32) NULL,
    payment_method VARCHAR(32) NULL,
    financed TINYINT(1) NOT NULL DEFAULT 0,
    dealership VARCHAR(120) NULL,
    purchased_at BIGINT UNSIGNED NOT NULL,
    registered_at BIGINT UNSIGNED NULL,
    status ENUM('pending', 'registered', 'cancelled') NOT NULL DEFAULT 'pending',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_vehicle_purchase_identifier (vehicle_identifier),
    KEY idx_vehicle_purchase_owner_status (owner_identifier, status),
    KEY idx_vehicle_purchase_plate (temporary_plate)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
