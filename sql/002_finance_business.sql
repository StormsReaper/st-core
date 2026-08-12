-- ST-Core Section 2: Finance, credit, and player-owned businesses

CREATE TABLE IF NOT EXISTS st_bank_accounts (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    account_number CHAR(12) NOT NULL,
    account_type ENUM('checking','savings','shared','business') NOT NULL,
    character_id BIGINT UNSIGNED NULL,
    business_id BIGINT UNSIGNED NULL,
    balance DECIMAL(15,2) NOT NULL DEFAULT 0.00,
    status ENUM('active','frozen','closed') NOT NULL DEFAULT 'active',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id), UNIQUE KEY uq_bank_account_number (account_number),
    KEY idx_bank_character (character_id), KEY idx_bank_business (business_id),
    CONSTRAINT fk_bank_character FOREIGN KEY (character_id) REFERENCES st_characters(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS st_bank_account_access (
    account_id BIGINT UNSIGNED NOT NULL,
    character_id BIGINT UNSIGNED NOT NULL,
    access_level ENUM('owner','full','deposit','withdraw','view') NOT NULL DEFAULT 'view',
    PRIMARY KEY (account_id, character_id),
    CONSTRAINT fk_bank_access_account FOREIGN KEY (account_id) REFERENCES st_bank_accounts(id) ON DELETE CASCADE,
    CONSTRAINT fk_bank_access_character FOREIGN KEY (character_id) REFERENCES st_characters(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS st_bank_transactions (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    account_id BIGINT UNSIGNED NOT NULL,
    related_account_id BIGINT UNSIGNED NULL,
    character_id BIGINT UNSIGNED NULL,
    transaction_type ENUM('deposit','withdrawal','transfer','payment','payroll','loan','interest','fee','refund','purchase','other') NOT NULL,
    amount DECIMAL(15,2) NOT NULL,
    balance_after DECIMAL(15,2) NOT NULL,
    description VARCHAR(255) NULL,
    reference VARCHAR(100) NULL,
    metadata JSON NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id), KEY idx_bank_tx_account (account_id), KEY idx_bank_tx_character (character_id),
    CONSTRAINT fk_bank_tx_account FOREIGN KEY (account_id) REFERENCES st_bank_accounts(id) ON DELETE CASCADE,
    CONSTRAINT fk_bank_tx_related FOREIGN KEY (related_account_id) REFERENCES st_bank_accounts(id) ON DELETE SET NULL,
    CONSTRAINT fk_bank_tx_character FOREIGN KEY (character_id) REFERENCES st_characters(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS st_credit_profiles (
    character_id BIGINT UNSIGNED NOT NULL,
    score SMALLINT UNSIGNED NOT NULL DEFAULT 650,
    total_debt DECIMAL(15,2) NOT NULL DEFAULT 0.00,
    utilization_percent DECIMAL(5,2) NOT NULL DEFAULT 0.00,
    payment_history_score DECIMAL(5,2) NOT NULL DEFAULT 100.00,
    account_age_days INT UNSIGNED NOT NULL DEFAULT 0,
    last_calculated_at TIMESTAMP NULL,
    PRIMARY KEY (character_id),
    CONSTRAINT fk_credit_character FOREIGN KEY (character_id) REFERENCES st_characters(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS st_credit_events (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    character_id BIGINT UNSIGNED NOT NULL,
    event_type ENUM('account_opened','payment_on_time','late_payment','missed_payment','default','loan_paid','credit_check','utilization_change') NOT NULL,
    impact SMALLINT NOT NULL DEFAULT 0,
    reference_id BIGINT UNSIGNED NULL,
    notes VARCHAR(255) NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id), KEY idx_credit_events_character (character_id),
    CONSTRAINT fk_credit_event_character FOREIGN KEY (character_id) REFERENCES st_characters(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS st_loans (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    character_id BIGINT UNSIGNED NOT NULL,
    account_id BIGINT UNSIGNED NOT NULL,
    loan_type ENUM('vehicle','property','personal','business','other') NOT NULL,
    principal DECIMAL(15,2) NOT NULL,
    interest_rate DECIMAL(7,4) NOT NULL,
    term_months SMALLINT UNSIGNED NOT NULL,
    monthly_payment DECIMAL(15,2) NOT NULL,
    remaining_balance DECIMAL(15,2) NOT NULL,
    collateral_type VARCHAR(50) NULL,
    collateral_id BIGINT UNSIGNED NULL,
    status ENUM('active','paid','defaulted','repossessed','foreclosed') NOT NULL DEFAULT 'active',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id), KEY idx_loan_character (character_id), KEY idx_loan_account (account_id),
    CONSTRAINT fk_loan_character FOREIGN KEY (character_id) REFERENCES st_characters(id) ON DELETE CASCADE,
    CONSTRAINT fk_loan_account FOREIGN KEY (account_id) REFERENCES st_bank_accounts(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS st_loan_payments (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    loan_id BIGINT UNSIGNED NOT NULL,
    amount DECIMAL(15,2) NOT NULL,
    principal_paid DECIMAL(15,2) NOT NULL,
    interest_paid DECIMAL(15,2) NOT NULL,
    due_at TIMESTAMP NOT NULL,
    paid_at TIMESTAMP NULL,
    status ENUM('scheduled','paid','late','missed') NOT NULL DEFAULT 'scheduled',
    PRIMARY KEY (id), KEY idx_loan_payment_loan (loan_id),
    CONSTRAINT fk_loan_payment_loan FOREIGN KEY (loan_id) REFERENCES st_loans(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS st_businesses (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    legal_name VARCHAR(120) NOT NULL,
    display_name VARCHAR(120) NOT NULL,
    business_type VARCHAR(60) NOT NULL,
    owner_character_id BIGINT UNSIGNED NULL,
    bank_account_id BIGINT UNSIGNED NULL,
    tax_id CHAR(12) NOT NULL,
    location_data JSON NULL,
    status ENUM('active','suspended','closed') NOT NULL DEFAULT 'active',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id), UNIQUE KEY uq_business_tax_id (tax_id),
    KEY idx_business_owner (owner_character_id),
    CONSTRAINT fk_business_owner FOREIGN KEY (owner_character_id) REFERENCES st_characters(id) ON DELETE SET NULL,
    CONSTRAINT fk_business_bank FOREIGN KEY (bank_account_id) REFERENCES st_bank_accounts(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS st_business_employees (
    business_id BIGINT UNSIGNED NOT NULL,
    character_id BIGINT UNSIGNED NOT NULL,
    job_title VARCHAR(100) NOT NULL,
    role_level INT UNSIGNED NOT NULL DEFAULT 0,
    hourly_rate DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    salary DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    payroll_frequency ENUM('hourly','weekly','biweekly','monthly') NOT NULL DEFAULT 'weekly',
    hired_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    active TINYINT(1) NOT NULL DEFAULT 1,
    PRIMARY KEY (business_id, character_id),
    CONSTRAINT fk_employee_business FOREIGN KEY (business_id) REFERENCES st_businesses(id) ON DELETE CASCADE,
    CONSTRAINT fk_employee_character FOREIGN KEY (character_id) REFERENCES st_characters(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS st_payroll_records (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    business_id BIGINT UNSIGNED NOT NULL,
    character_id BIGINT UNSIGNED NOT NULL,
    account_id BIGINT UNSIGNED NOT NULL,
    gross_amount DECIMAL(12,2) NOT NULL,
    net_amount DECIMAL(12,2) NOT NULL,
    pay_period_start DATE NOT NULL,
    pay_period_end DATE NOT NULL,
    paid_at TIMESTAMP NULL,
    status ENUM('pending','paid','failed') NOT NULL DEFAULT 'pending',
    PRIMARY KEY (id), KEY idx_payroll_business (business_id), KEY idx_payroll_character (character_id),
    CONSTRAINT fk_payroll_business FOREIGN KEY (business_id) REFERENCES st_businesses(id) ON DELETE CASCADE,
    CONSTRAINT fk_payroll_character FOREIGN KEY (character_id) REFERENCES st_characters(id) ON DELETE CASCADE,
    CONSTRAINT fk_payroll_account FOREIGN KEY (account_id) REFERENCES st_bank_accounts(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS st_credit_checks (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    subject_character_id BIGINT UNSIGNED NOT NULL,
    requesting_business_id BIGINT UNSIGNED NOT NULL,
    score_at_check SMALLINT UNSIGNED NOT NULL,
    purpose VARCHAR(100) NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id), KEY idx_credit_check_subject (subject_character_id),
    CONSTRAINT fk_credit_check_subject FOREIGN KEY (subject_character_id) REFERENCES st_characters(id) ON DELETE CASCADE,
    CONSTRAINT fk_credit_check_business FOREIGN KEY (requesting_business_id) REFERENCES st_businesses(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
