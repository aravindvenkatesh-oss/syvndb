/*
    Azure Database for MySQL 8.0 migration script for the expense module.
    The script rebuilds the lookup tables, normalizes legacy data, and
    migrates transactional expenses while preserving receipts, employee
    assignments, approver metadata, and type identifiers.

    Assumptions:
      1. Legacy tables (expense_categories, main_currency, expense_trips,
         expense_payment_methods, expense_receipts, expenses, etc.) still
         exist in the same schema.
      2. `organization(id)` already contains the org that should own the
         migrated rows (default = 1).
      3. Legacy `expense_receipts` contains `id`, `receipt_url`,
         `createdby`, `modifiedby`, `createddate`, `modifieddate`,
         `isactive`, and `expense_id`. Adjust column names if they differ.
      4. Legacy `expenses` contains `type_id`, `emp_id`, `approver_name`
         and (optionally) `receipt_id`. Update the cursor SELECT if your
         schema uses different column names.
      5. `employees_main_summary_table` exposes `employee_id` and
         `employee_name` columns, which are used to derive creator and
         approver names. Update these column references if needed.
*/

-- ============================================================================
-- EXPENSE CATEGORY
-- ============================================================================
DROP PROCEDURE IF EXISTS migrate_expense_category;
DELIMITER $$

CREATE PROCEDURE migrate_expense_category()
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    DROP TABLE IF EXISTS expense_category;

    CREATE TABLE expense_category (
        id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
        name VARCHAR(50) NOT NULL,
        createdBy VARCHAR(50) NOT NULL,
        modifiedBy VARCHAR(50) NULL,
        createdAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        modifiedAt DATETIME NULL,
        isNotDeleted TINYINT(1) NOT NULL DEFAULT 1,
        orgId BIGINT NOT NULL DEFAULT 1,
        INDEX idx_expense_category_org (orgId),
        CONSTRAINT fk_expense_category_org
            FOREIGN KEY (orgId) REFERENCES organization(id)
    ) ENGINE = InnoDB;

    INSERT INTO expense_category (
        id,
        name,
        createdBy,
        modifiedBy,
        createdAt,
        modifiedAt,
        isNotDeleted,
        orgId
    )
    SELECT
        id,
        expense_category_name,
        'Samuel Durai',
        NULL,
        created_date,
        modifieddate,
        isactive,
        1
    FROM expense_categories;

    COMMIT;
END$$

DELIMITER ;
CALL migrate_expense_category();
DROP PROCEDURE IF EXISTS migrate_expense_category;


-- ============================================================================
-- CURRENCY
-- ============================================================================
DROP PROCEDURE IF EXISTS migrate_currency;
DELIMITER $$

CREATE PROCEDURE migrate_currency()
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    DROP TABLE IF EXISTS currency;

    CREATE TABLE currency (
        id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
        code CHAR(3) NOT NULL,
        isNotDeleted TINYINT(1) NOT NULL DEFAULT 1,
        createdBy VARCHAR(50) NOT NULL,
        modifiedBy VARCHAR(50) NULL,
        createdAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        modifiedAt DATETIME NULL,
        symbol VARCHAR(10) NULL,
        orgId BIGINT NOT NULL DEFAULT 1,
        INDEX idx_currency_org (orgId),
        CONSTRAINT fk_currency_org
            FOREIGN KEY (orgId) REFERENCES organization(id)
    ) ENGINE = InnoDB;

    INSERT INTO currency (
        id,
        code,
        isNotDeleted,
        createdBy,
        modifiedBy,
        createdAt,
        modifiedAt,
        orgId,
        symbol
    )
    SELECT
        id,
        currencycode,
        isactive,
        'Samuel Durai',
        NULL,
        createddate,
        modifieddate,
        1,
        NULL
    FROM main_currency
    WHERE currencycode IS NOT NULL
      AND CHAR_LENGTH(currencycode) BETWEEN 2 AND 3;

    COMMIT;
END$$

DELIMITER ;
CALL migrate_currency();
DROP PROCEDURE IF EXISTS migrate_currency;


-- ============================================================================
-- EVENT
-- ============================================================================
DROP PROCEDURE IF EXISTS migrate_event;
DELIMITER $$

CREATE PROCEDURE migrate_event()
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    DROP TABLE IF EXISTS event;

    CREATE TABLE event (
        id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
        name VARCHAR(100) NULL,
        description TEXT NULL,
        createdBy VARCHAR(50) NOT NULL,
        modifiedBy VARCHAR(50) NULL,
        createdAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        modifiedAt DATETIME NULL,
        isNotDeleted TINYINT(1) NOT NULL DEFAULT 1,
        orgId BIGINT NOT NULL DEFAULT 1,
        CONSTRAINT fk_event_org
            FOREIGN KEY (orgId) REFERENCES organization(id)
    ) ENGINE = InnoDB;

    INSERT INTO event (
        id,
        name,
        description,
        createdBy,
        modifiedBy,
        createdAt,
        modifiedAt,
        isNotDeleted,
        orgId
    )
    SELECT
        id,
        trip_name,
        description,
        'Samuel Durai',
        NULL,
        createddate,
        modifieddate,
        isactive,
        1
    FROM expense_trips;

    COMMIT;
END$$

DELIMITER ;
CALL migrate_event();
DROP PROCEDURE IF EXISTS migrate_event;


-- ============================================================================
-- PAYMENT METHOD
-- ============================================================================
DROP PROCEDURE IF EXISTS migrate_payment_method;
DELIMITER $$

CREATE PROCEDURE migrate_payment_method()
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    DROP TABLE IF EXISTS payment_method;

    CREATE TABLE payment_method (
        id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
        name VARCHAR(100) NOT NULL,
        isNotDeleted TINYINT(1) NOT NULL DEFAULT 1,
        createdBy VARCHAR(50) NOT NULL,
        modifiedBy VARCHAR(50) NULL,
        createdAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        modifiedAt DATETIME NULL,
        orgId BIGINT NOT NULL DEFAULT 1,
        CONSTRAINT fk_payment_method_org
            FOREIGN KEY (orgId) REFERENCES organization(id)
    ) ENGINE = InnoDB;

    INSERT INTO payment_method (
        id,
        name,
        isNotDeleted,
        createdBy,
        modifiedBy,
        createdAt,
        modifiedAt,
        orgId
    )
    SELECT
        id,
        payment_method_name,
        isactive,
        'Samuel Durai',
        NULL,
        created_date,
        modifieddate,
        1
    FROM expense_payment_methods
    WHERE payment_method_name IS NOT NULL;

    COMMIT;
END$$

DELIMITER ;
CALL migrate_payment_method();
DROP PROCEDURE IF EXISTS migrate_payment_method;


-- ============================================================================
-- RECEIPT
-- ============================================================================
DROP PROCEDURE IF EXISTS migrate_expense_receipt;
DELIMITER $$

CREATE PROCEDURE migrate_expense_receipt()
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    DROP TABLE IF EXISTS expense_receipt;

    CREATE TABLE expense_receipt (
        id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
        createdBy VARCHAR(50) NULL,
        modifiedBy VARCHAR(50) NULL,
        createdAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        modifiedAt DATETIME NULL,
        isNotDeleted TINYINT(1) NOT NULL DEFAULT 1,
        url VARCHAR(1000) NULL,
        orgId BIGINT NOT NULL DEFAULT 1,
        UNIQUE KEY uq_expense_receipt_url (url),
        CONSTRAINT fk_expense_receipt_org
            FOREIGN KEY (orgId) REFERENCES organization(id)
    ) ENGINE = InnoDB;

    INSERT INTO expense_receipt (
        id,
        createdBy,
        modifiedBy,
        createdAt,
        modifiedAt,
        isNotDeleted,
        url,
        orgId
    )
    SELECT
        id,
        COALESCE(createdby, 'Samuel Durai'),
        modifiedby,
        createddate,
        modifieddate,
        isactive,
        receipt_url, -- Replace with the actual legacy column if different
        1
    FROM expense_receipts;

    COMMIT;
END$$

DELIMITER ;
CALL migrate_expense_receipt();
DROP PROCEDURE IF EXISTS migrate_expense_receipt;


-- ============================================================================
-- SCHEMA NORMALIZATION
-- ============================================================================
ALTER TABLE expense_report
    MODIFY amount DECIMAL(20,4);

RENAME TABLE expense_status TO expense_report_status;

ALTER TABLE expense_report_type
    CHANGE COLUMN isActive isNotDeleted TINYINT(1) NOT NULL DEFAULT 1;

ALTER TABLE vendor
    CHANGE COLUMN isActive isNotDeleted TINYINT(1) NOT NULL DEFAULT 1;

ALTER TABLE expense_report
    CHANGE COLUMN isActive isNotDeleted TINYINT(1) NOT NULL DEFAULT 1;

ALTER TABLE expense_report_status
    CHANGE COLUMN isActive isNotDeleted TINYINT(1) NOT NULL DEFAULT 1;

INSERT INTO expense_report_status
    (name, hierarchy, isNotDeleted, createdBy, modifiedBy, createdAt, modifiedAt, orgId)
VALUES
    ('Draft',           0, 1, 'system', NULL, CURRENT_TIMESTAMP, NULL, 1),
    ('Submitted',       1, 1, 'system', NULL, CURRENT_TIMESTAMP, NULL, 1),
    ('Approved',        2, 1, 'system', NULL, CURRENT_TIMESTAMP, NULL, 1),
    ('Rejected (FND)',  3, 1, 'system', NULL, CURRENT_TIMESTAMP, NULL, 1),
    ('Processed',       4, 1, 'system', NULL, CURRENT_TIMESTAMP, NULL, 1),
    ('Paid',            5, 1, 'system', NULL, CURRENT_TIMESTAMP, NULL, 1),
    ('Rejected (DH)',   3, 1, 'system', NULL, CURRENT_TIMESTAMP, NULL, 1)
ON DUPLICATE KEY UPDATE
    modifiedAt = VALUES(modifiedAt);

INSERT INTO expense_report_type
    (id, name, isNotDeleted, createdBy, modifiedBy, createdAt, modifiedAt, orgId)
VALUES
    (1, 'Expense', 1, 'system', NULL, CURRENT_TIMESTAMP, NULL, 1),
    (2, 'XXM',     1, 'system', NULL, CURRENT_TIMESTAMP, NULL, 1)
ON DUPLICATE KEY UPDATE
    name = VALUES(name),
    modifiedAt = VALUES(modifiedAt);


START TRANSACTION;

DROP TABLE IF EXISTS expense;
CREATE TABLE IF NOT EXISTS expense (
    id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,

    categoryId INT UNSIGNED NULL,
    date DATE NULL,
    qty  DECIMAL(20,4) NULL DEFAULT 1,
    rate DECIMAL(20,4) NULL,
    amount DECIMAL(20,4) NULL,
    paymentTypeId INT UNSIGNED NULL,
    description TEXT NULL,

    createdBy VARCHAR(50) NOT NULL,
    modifiedBy VARCHAR(50) NULL,
    createdAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    modifiedAt DATETIME NULL,

    isNotDeleted TINYINT(1) NOT NULL DEFAULT 1,
    expenseReportId INT NULL,
    receiptId INT UNSIGNED NULL,
    vendorName VARCHAR(50) NULL,
    orgId BIGINT NOT NULL DEFAULT 1,
    tax DECIMAL(20,4) NULL,

    CONSTRAINT fk_expense_org
        FOREIGN KEY (orgId) REFERENCES organization(id),
    CONSTRAINT fk_expense_category
        FOREIGN KEY (categoryId) REFERENCES expense_category(id),
    CONSTRAINT fk_expense_paymentType
        FOREIGN KEY (paymentTypeId) REFERENCES payment_method(id),
    CONSTRAINT fk_expense_report
        FOREIGN KEY (expenseReportId) REFERENCES expense_report(id),
    CONSTRAINT fk_expense_receipt
        FOREIGN KEY (receiptId) REFERENCES expense_receipt(id)
) ENGINE = InnoDB;

COMMIT;


-- ============================================================================
-- EXPENSE + REPORT MIGRATION
-- ============================================================================
DELIMITER $$
DROP PROCEDURE IF EXISTS migrate_expenses$$

CREATE PROCEDURE migrate_expenses()
BEGIN
    DECLARE done INT DEFAULT 0;
    DECLARE v_id INT;
    DECLARE v_expense_name VARCHAR(100);
    DECLARE v_category_id INT;
    DECLARE v_project_id INT;
    DECLARE v_accountId INT;
    DECLARE v_trip_id INT;
    DECLARE v_manager_id INT;
    DECLARE v_expense_date DATE;
    DECLARE v_expense_quantity_raw VARCHAR(100);
    DECLARE v_unit_currency_id INT;
    DECLARE v_unit_amount_raw VARCHAR(100);
    DECLARE v_expense_currency_id INT;
    DECLARE v_expense_amount_raw VARCHAR(100);
    DECLARE v_expense_conversion_rate_raw VARCHAR(100);
    DECLARE v_application_currency_id INT;
    DECLARE v_application_amount_raw VARCHAR(100);
    DECLARE v_advance_amount_raw VARCHAR(100);
    DECLARE v_return_amount_raw VARCHAR(100);
    DECLARE v_is_reimbursable TINYINT(1);
    DECLARE v_is_from_advance TINYINT(1);
    DECLARE v_expense_payment_id INT;
    DECLARE v_expense_payment_ref_no VARCHAR(200);
    DECLARE v_description TEXT;
    DECLARE v_status ENUM('saved','submitted','approved','rejected','approvedFND','rejectedFND','paid');
    DECLARE v_createdby VARCHAR(100);
    DECLARE v_modifiedby VARCHAR(100);
    DECLARE v_createddate DATETIME;
    DECLARE v_modifieddate DATETIME;
    DECLARE v_isactive TINYINT(1);
    DECLARE v_expense_report_id INT;
    DECLARE v_report_type_id INT;
    DECLARE v_emp_id BIGINT;
    DECLARE v_approver_name VARCHAR(100);
    DECLARE v_legacy_receipt_id INT;
    DECLARE v_receipt_id INT;
    DECLARE v_event_name VARCHAR(255);
    DECLARE v_emp_name VARCHAR(100);
    DECLARE v_manager_name VARCHAR(100);

    DECLARE dec_amount DECIMAL(20,4);
    DECLARE dec_unit_amount DECIMAL(20,4);
    DECLARE dec_qty DECIMAL(20,4);
    DECLARE v_status_id INT;

    DECLARE cur CURSOR FOR
        SELECT id, expense_name, category_id, project_id, accountId, trip_id, manager_id,
               expense_date,
               expense_quantity, unit_currency_id, unit_amount,
               expense_currency_id, expense_amount, expense_conversion_rate,
               application_currency_id, application_amount, advance_amount, return_amount,
               is_reimbursable, is_from_advance, expense_payment_id, expense_payment_ref_no,
               description, status, createdby, modifiedby, createddate, modifieddate, isactive,
               type_id, emp_id, approver_name, receipt_id
        FROM expenses;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET SQL_SAFE_UPDATES = 0;
        DELETE FROM expense;
        DELETE FROM expense_report;
        SET SQL_SAFE_UPDATES = 1;
        RESIGNAL;
    END;

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;

    OPEN cur;

    read_loop: LOOP
        FETCH cur INTO
            v_id, v_expense_name, v_category_id, v_project_id, v_accountId, v_trip_id, v_manager_id,
            v_expense_date,
            v_expense_quantity_raw, v_unit_currency_id, v_unit_amount_raw,
            v_expense_currency_id, v_expense_amount_raw, v_expense_conversion_rate_raw,
            v_application_currency_id, v_application_amount_raw, v_advance_amount_raw, v_return_amount_raw,
            v_is_reimbursable, v_is_from_advance, v_expense_payment_id, v_expense_payment_ref_no,
            v_description, v_status, v_createdby, v_modifiedby, v_createddate, v_modifieddate, v_isactive,
            v_report_type_id, v_emp_id, v_approver_name, v_legacy_receipt_id;

        IF done THEN
            LEAVE read_loop;
        END IF;

        IF v_expense_date IS NULL THEN
            SET v_expense_date = CURRENT_DATE;
        END IF;

        IF v_category_id IS NULL OR
           NOT EXISTS (SELECT 1 FROM expense_category WHERE id = v_category_id) THEN
            SET v_category_id = 1;
        END IF;

        IF v_expense_payment_id IS NULL OR
           NOT EXISTS (SELECT 1 FROM payment_method WHERE id = v_expense_payment_id) THEN
            SET v_expense_payment_id = NULL;
        END IF;

        IF v_report_type_id IS NULL OR
           NOT EXISTS (SELECT 1 FROM expense_report_type WHERE id = v_report_type_id) THEN
            IF COALESCE(v_is_from_advance, 0) = 1 THEN
                SET v_report_type_id = 2;
            ELSE
                SET v_report_type_id = 1;
            END IF;
        END IF;

        IF v_emp_id IS NOT NULL AND v_emp_id <= 0 THEN
            SET v_emp_id = NULL;
        END IF;

        SET v_event_name = (
            SELECT trip_name
            FROM expense_trips
            WHERE id = v_trip_id
            LIMIT 1
        );

        SET v_manager_name = (
            SELECT employee_name
            FROM employees_main_summary_table
            WHERE employee_id = v_manager_id
            LIMIT 1
        );

        IF v_manager_name IS NOT NULL THEN
            SET v_approver_name = v_manager_name;
        ELSEIF v_approver_name IS NULL AND v_manager_id IS NOT NULL THEN
            SET v_approver_name = CONCAT('Manager #', v_manager_id);
        END IF;

        SET v_emp_name = (
            SELECT employee_name
            FROM employees_main_summary_table
            WHERE employee_id = v_emp_id
            LIMIT 1
        );

        IF v_emp_name IS NULL THEN
            SET v_emp_name = COALESCE(v_createdby,'System');
        END IF;

        SET v_receipt_id = v_legacy_receipt_id;

        IF v_receipt_id IS NULL THEN
            SET v_receipt_id = (
                SELECT er.id
                FROM expense_receipts er
                WHERE er.expense_id = v_id
                ORDER BY er.modifieddate DESC, er.id DESC
                LIMIT 1
            );
        END IF;

        IF v_receipt_id IS NOT NULL AND
           NOT EXISTS (SELECT 1 FROM expense_receipt WHERE id = v_receipt_id) THEN
            SET v_receipt_id = NULL;
        END IF;

        IF v_expense_amount_raw REGEXP '^[0-9]+(\\.[0-9]+)?$'
           AND (v_expense_quantity_raw IS NULL
                OR v_expense_quantity_raw = ''
                OR v_expense_quantity_raw REGEXP '^[0-9]+(\\.[0-9]+)?$') THEN

            SET dec_amount = CAST(COALESCE(NULLIF(v_expense_amount_raw,''),'0') AS DECIMAL(20,4));
            SET dec_unit_amount = CAST(COALESCE(NULLIF(v_unit_amount_raw,''),'0') AS DECIMAL(20,4));
            SET dec_qty = CAST(COALESCE(NULLIF(v_expense_quantity_raw,''),'1') AS DECIMAL(20,4));

            IF dec_qty > 9999999999999999.9999 THEN
                SET dec_qty = 9999999999999999.9999;
            END IF;

            CASE v_status
                WHEN 'saved' THEN SET v_status_id = 1;
                WHEN 'submitted' THEN SET v_status_id = 2;
                WHEN 'approved' THEN SET v_status_id = 3;
                WHEN 'rejectedFND' THEN SET v_status_id = 4;
                WHEN 'approvedFND' THEN SET v_status_id = 5;
                WHEN 'paid' THEN SET v_status_id = 6;
                WHEN 'rejected' THEN SET v_status_id = 7;
                ELSE SET v_status_id = 1;
            END CASE;

            START TRANSACTION;

            INSERT INTO expense_report (
                orgId, submittedAt, approverName, eventName, currencyId,
                accountCode, projectCode, empId, typeId, deptCode, division,
                amount, statusId, isReimbursable, isNotDeleted,
                createdBy, createdAt, modifiedBy, modifiedAt
            ) VALUES (
                1,
                v_expense_date,
                v_approver_name,
                v_event_name,
                v_expense_currency_id,
                v_accountId,
                v_project_id,
                v_emp_id,
                v_report_type_id,
                NULL,
                NULL,
                dec_amount,
                v_status_id,
                COALESCE(v_is_reimbursable,0),
                COALESCE(v_isactive,1),
                v_emp_name,
                COALESCE(v_createddate, CURRENT_TIMESTAMP),
                COALESCE(v_modifiedby,NULL),
                v_modifieddate
            );

            SET v_expense_report_id = LAST_INSERT_ID();

            INSERT INTO expense (
                categoryId, date, qty, rate, amount, paymentTypeId, description,
                createdBy, modifiedBy, createdAt, modifiedAt, isNotDeleted,
                expenseReportId, receiptId, vendorName, orgId, tax
            ) VALUES (
                v_category_id,
                v_expense_date,
                dec_qty,
                dec_unit_amount,
                dec_amount,
                v_expense_payment_id,
                COALESCE(v_expense_name, v_description),
                v_emp_name,
                COALESCE(v_modifiedby,NULL),
                v_createddate,
                v_modifieddate,
                COALESCE(v_isactive,1),
                v_expense_report_id,
                v_receipt_id,
                NULL,
                1,
                0
            );

            COMMIT;
        END IF;
    END LOOP;

    CLOSE cur;
END$$

DELIMITER ;
CALL migrate_expenses();
DROP PROCEDURE IF EXISTS migrate_expenses;
