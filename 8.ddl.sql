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

    CONSTRAINT fk_expense_org          FOREIGN KEY (orgId)           REFERENCES organization(id),
    CONSTRAINT fk_expense_category     FOREIGN KEY (categoryId)      REFERENCES expense_category(id),
    CONSTRAINT fk_expense_paymentType  FOREIGN KEY (paymentTypeId)   REFERENCES payment_method(id),
    CONSTRAINT fk_expense_report       FOREIGN KEY (expenseReportId) REFERENCES expense_report(id),
    CONSTRAINT fk_expense_receipt      FOREIGN KEY (receiptId)       REFERENCES expense_receipt(id)
);

COMMIT;
