DROP PROCEDURE IF EXISTS migrate_currency;
DELIMITER $$

CREATE PROCEDURE migrate_currency()
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
    END;

    START TRANSACTION;

    -- SAFELY DROP OLD TABLE
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
        CONSTRAINT fk_currency_org FOREIGN KEY (orgId) REFERENCES organization(id)
    );

    -- DATA MIGRATION
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
      AND CHAR_LENGTH(currencycode) <= 3;

    COMMIT;
END$$

DELIMITER ;

CALL migrate_currency();
DROP PROCEDURE IF EXISTS migrate_currency;
