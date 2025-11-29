DROP PROCEDURE IF EXISTS migrate_expense_receipt;
DELIMITER $$

CREATE PROCEDURE migrate_expense_receipt()
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
    END;

    START TRANSACTION;

    -- SAFELY DROP OLD TABLE
    DROP TABLE IF EXISTS expense_receipt;

    -- CREATE TABLE WITH FINAL SCHEMA
    CREATE TABLE expense_receipt (
        id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
        createdBy VARCHAR(50) NULL,
        modifiedBy VARCHAR(50) NULL,
        createdAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        modifiedAt DATETIME NULL,
        isNotDeleted TINYINT(1) NOT NULL DEFAULT 1,
        url VARCHAR(1000) NULL,
        orgId BIGINT NOT NULL DEFAULT 1,
        CONSTRAINT fk_expense_receipt_org FOREIGN KEY (orgId) REFERENCES organization(id)
    );

    -- DATA MIGRATION
    INSERT INTO expense_receipt (
        createdBy,
        modifiedBy,
        createdAt,
        modifiedAt,
        isNotDeleted,
        url,
        orgId
    )
    SELECT
        'Samuel Durai',
        NULL,
        createddate,
        modifieddate,
        isactive,
        NULL AS url,
        1 AS orgId
    FROM expense_receipts;

    COMMIT;
END$$

DELIMITER ;

CALL migrate_expense_receipt();
DROP PROCEDURE IF EXISTS migrate_expense_receipt;
