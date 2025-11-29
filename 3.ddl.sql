DROP PROCEDURE IF EXISTS migrate_event;
DELIMITER $$

CREATE PROCEDURE migrate_event()
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
    END;

    START TRANSACTION;

    -- DROP OLD TABLE IF EXISTS
    DROP TABLE IF EXISTS event;

    -- CREATE TABLE WITH FINAL SCHEMA
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
        CONSTRAINT fk_event_org FOREIGN KEY (orgId) REFERENCES organization(id)
    );

    -- DATA MIGRATION
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
