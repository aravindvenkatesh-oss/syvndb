DROP PROCEDURE IF EXISTS migrate_expense_category;
DELIMITER $$

CREATE PROCEDURE migrate_expense_category()
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
    END;

    START TRANSACTION;

    -- SAFELY DROP OLD TABLE
    DROP TABLE IF EXISTS expense_category;

    -- CREATE TABLE WITH FINAL SCHEMA
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
        CONSTRAINT fk_expense_category_org FOREIGN KEY (orgId) REFERENCES organization(id)
    );

    -- DATA MIGRATION
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
