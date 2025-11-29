ALTER TABLE expense_report
    MODIFY amount DECIMAL(20,4);

-- Rename table for consistency
RENAME TABLE expense_status TO expense_report_status;

-- Normalize isActive → isNotDeleted across tables
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
    ('Draft',     0, 1, 'system', NULL, CURRENT_TIMESTAMP, NULL, 1),
    ('Submitted', 1, 1, 'system', NULL, CURRENT_TIMESTAMP, NULL, 1),
    ('Approved',  2, 1, 'system', NULL, CURRENT_TIMESTAMP, NULL, 1),
    ('Rejected (FND)',  3, 1, 'system', NULL, CURRENT_TIMESTAMP, NULL, 1),
    ('Processed', 4, 1, 'system', NULL, CURRENT_TIMESTAMP, NULL, 1),
    ('Paid',      5, 1, 'system', NULL, CURRENT_TIMESTAMP, NULL, 1),
    ('Rejected (DH)',  3, 1, 'system', NULL, CURRENT_TIMESTAMP, NULL, 1);

INSERT INTO expense_report_type
    (id, name, isNotDeleted, createdBy, modifiedBy, createdAt, modifiedAt, orgId)
VALUES
    (1, 'Expense', 1, 'system', NULL, CURRENT_TIMESTAMP, NULL, 1),
    (2, 'XXM',     1, 'system', NULL, CURRENT_TIMESTAMP, NULL, 1);
