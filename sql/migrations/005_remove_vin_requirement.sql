-- ST-Core migration 005
-- Existing installations: make VIN optional in the legacy ST vehicle cache.
-- ST-Core does not read or require VIN for DMV, registration, insurance, or transfers.

ALTER TABLE st_vehicles
    MODIFY COLUMN vin CHAR(17) NULL;

-- Keep any existing VIN data intact for compatibility, but do not enforce uniqueness.
-- MariaDB/MySQL allow multiple NULL values in a unique index; the index itself is retained
-- only for legacy lookups that may still use it. New ST-Core code never depends on VIN.
