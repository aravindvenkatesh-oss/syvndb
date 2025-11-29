DROP PROCEDURE IF EXISTS migrate_payment_method;
DELIMITER $$

CREATE PROCEDURE migrate_payment_method()
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
    END;

    START TRANSACTION;

    -- SAFELY DROP OLD TABLE
    DROP TABLE IF EXISTS payment_method;

    -- CREATE TABLE WITH FINAL SCHEMA
    CREATE TABLE payment_method (
        id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
        name VARCHAR(100) NOT NULL,
        isNotDeleted TINYINT(1) NOT NULL DEFAULT 1,
        createdBy VARCHAR(50) NOT NULL,
        modifiedBy VARCHAR(50) NULL,
        createdAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        modifiedAt DATETIME NULL,
        orgId BIGINT NOT NULL DEFAULT 1,
        CONSTRAINT fk_payment_method_org FOREIGN KEY (orgId) REFERENCES organization(id)
    );

    -- DATA MIGRATION
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
