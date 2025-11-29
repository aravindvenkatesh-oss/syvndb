-- Pure SQL migration (no PROCEDURE required). Review and backup DB before running.
SET @now = CURRENT_TIMESTAMP;
SET @prev_sql_safe_updates := @@SQL_SAFE_UPDATES;
SET @prev_fk_checks := @@FOREIGN_KEY_CHECKS;
SET SQL_SAFE_UPDATES = 0;
SET FOREIGN_KEY_CHECKS = 0;
TRUNCATE TABLE expense;
TRUNCATE TABLE expense_report;
ALTER TABLE expense_report MODIFY COLUMN id INT NOT NULL;
ALTER TABLE expense MODIFY COLUMN id INT NOT NULL;
SET FOREIGN_KEY_CHECKS = @prev_fk_checks;
START TRANSACTION;

-- Insert expense_report rows. Use a migration tag in createdBy to map newly created report ids back to original expense rows.
INSERT INTO expense_report (
    id,
    orgId, submittedAt, approverName, eventName, currencyId,
    accountCode, projectCode, empId, typeId, deptCode, division,
    amount, statusId, isReimbursable, isNotDeleted,
    createdBy, createdAt, modifiedBy, modifiedAt
)
SELECT
    s.id,
    1 AS orgId,
    COALESCE(s.expense_date, DATE(@now)) AS submittedAt,
    COALESCE(
      (SELECT mes.userfullname FROM main_employees_summary mes WHERE mes.user_id = s.manager_id LIMIT 1),
      ''
    ) AS approverName,
    (SELECT et.trip_name FROM expense_trips et WHERE et.id = s.trip_id LIMIT 1) AS eventName,
    s.expense_currency_id AS currencyId,
    (
      SELECT CASE
               WHEN a.code IS NULL THEN NULL
               ELSE LEFT(a.code, 4)
             END
      FROM account a
      WHERE a.id = s.accountId
      LIMIT 1
    ) AS accountCode,
    (
      SELECT CASE
               WHEN p.code IS NULL THEN NULL
               ELSE LEFT(p.code, 4)
             END
      FROM project p
      WHERE p.id = s.project_id
      LIMIT 1
    ) AS projectCode,
    COALESCE(
      (SELECT mes.employeeId FROM main_employees_summary mes WHERE mes.user_id = s.createdby LIMIT 1),
      s.createdby
    ) AS empId,
    CASE
      WHEN COALESCE(s.is_from_advance,0) = 1 THEN 2
      ELSE 1
    END AS typeId,
    (
      SELECT CASE
               WHEN mes.department_name IS NULL THEN NULL
               ELSE LEFT(mes.department_name, 3)
             END
      FROM main_employees_summary mes
      WHERE mes.user_id = s.createdby
      LIMIT 1
    ) AS deptCode,
    (
      SELECT CASE
               WHEN mes.division_json IS NULL OR JSON_VALID(mes.division_json) = 0 THEN NULL
               ELSE LEFT(
                      JSON_UNQUOTE(JSON_EXTRACT(mes.division_json, '$[0].code')),
                      3
                    )
             END
      FROM main_employees_summary mes
      WHERE mes.user_id = s.createdby
      LIMIT 1
    ) AS division,
    CASE
      WHEN s.sanitized_amount REGEXP '^-?[0-9]+(\\.[0-9]+)?$'
        THEN CAST(s.sanitized_amount AS DECIMAL(20,4))
      ELSE 0
    END AS amount,
    CASE COALESCE(s.status,'saved')
      WHEN 'saved' THEN 1
      WHEN 'submitted' THEN 2
      WHEN 'approved' THEN 3
      WHEN 'rejectedFND' THEN 4
      WHEN 'approvedFND' THEN 5
      WHEN 'paid' THEN 6
      WHEN 'rejected' THEN 7
      ELSE 1
    END AS statusId,
    COALESCE(s.is_reimbursable,0) AS isReimbursable,
    COALESCE(s.isactive,1) AS isNotDeleted,
    -- createdBy: include migration tag to map later: 'MIG_EXP#<expense_id>#<original_createdBy_or_name>'
    CONCAT('MIG_EXP#', s.id, '#',
      COALESCE(
        (SELECT mes.userfullname FROM main_employees_summary mes WHERE mes.user_id = s.createdby LIMIT 1),
        COALESCE(CAST(s.createdby AS CHAR), 'System')
      )
    ) AS createdBy,
    COALESCE(s.createddate, @now) AS createdAt,
    CASE
      WHEN s.modifiedby IS NULL OR s.modifiedby = 0 THEN NULL
      ELSE COALESCE(
             (SELECT mes.userfullname FROM main_employees_summary mes WHERE mes.user_id = s.modifiedby LIMIT 1),
             CAST(s.modifiedby AS CHAR)
           )
    END AS modifiedBy,
    s.modifieddate AS modifiedAt
FROM (
    SELECT
        e.*,
        REPLACE(
            REPLACE(
                REPLACE(
                    REPLACE(
                        REPLACE(
                            REPLACE(TRIM(e.expense_amount), ',', ''),
                        '(', ''),')', ''), '$',''), '€',''), '₹',''
        ) AS sanitized_amount
    FROM expenses e
) AS s;

-- Insert expense rows, matching the generated report via migration tag, and populate receiptId, emp/dept/division lookups.
INSERT INTO expense (
    id,
    categoryId, date, qty, rate, amount, paymentTypeId, description,
    createdBy, modifiedBy, createdAt, modifiedAt, isNotDeleted,
    expenseReportId, receiptId, vendorName, orgId, tax
)
SELECT
  s.id,
  COALESCE(s.category_id, 1) AS categoryId,
  COALESCE(s.expense_date, DATE(@now)) AS date,
  CAST(
    CASE
      WHEN s.sanitized_qty NOT REGEXP '^[0-9]+(\\.[0-9]+)?$' THEN 1
      WHEN CAST(s.sanitized_qty AS DECIMAL(20,4)) <= 0 THEN 1
      ELSE GREATEST(
               FLOOR(
                   CAST(s.sanitized_qty AS DECIMAL(20,4))
               ),
               1
           )
    END AS DECIMAL(20,4)
  ) AS qty,
  CASE
    WHEN s.sanitized_amount REGEXP '^-?[0-9]+(\\.[0-9]+)?$'
      THEN CAST(s.sanitized_amount AS DECIMAL(20,4))
    ELSE 0
  END AS rate,
  CASE
    WHEN s.sanitized_amount REGEXP '^-?[0-9]+(\\.[0-9]+)?$'
      THEN CAST(s.sanitized_amount AS DECIMAL(20,4))
    ELSE 0
  END AS amount,
  s.expense_payment_id AS paymentTypeId,
  COALESCE(s.expense_name, s.description) AS description,
  COALESCE(
    (SELECT mes.userfullname FROM main_employees_summary mes WHERE mes.user_id = s.createdby LIMIT 1),
    COALESCE(CAST(s.createdby AS CHAR),'System')
  ) AS createdBy,
  CASE
    WHEN s.modifiedby IS NULL OR s.modifiedby = 0 THEN NULL
    ELSE COALESCE(
           (SELECT mes.userfullname FROM main_employees_summary mes WHERE mes.user_id = s.modifiedby LIMIT 1),
           CAST(s.modifiedby AS CHAR)
         )
  END AS modifiedBy,
  COALESCE(s.createddate, @now) AS createdAt,
  s.modifieddate AS modifiedAt,
  COALESCE(s.isactive,1) AS isNotDeleted,
  (SELECT er.id FROM expense_report er WHERE er.createdBy LIKE CONCAT('MIG_EXP#', s.id, '#%') LIMIT 1) AS expenseReportId,
  (
    SELECT erc.id
    FROM expense_receipts erc
    WHERE erc.expense_id = s.id
    ORDER BY erc.modifieddate DESC, erc.id DESC
    LIMIT 1
  ) AS receiptId,
  NULL AS vendorName,
  1 AS orgId,
  0 AS tax
FROM (
    SELECT
        e.*,
        REPLACE(
            REPLACE(
                REPLACE(
                    REPLACE(
                        REPLACE(
                            REPLACE(TRIM(e.expense_amount), ',', ''),
                        '(', ''),')', ''), '$', ''), '€', ''), '₹', ''
        ) AS sanitized_amount,
        REPLACE(REPLACE(REPLACE(TRIM(e.expense_quantity), ',', ''), '(', ''), ')', '') AS sanitized_qty
    FROM expenses e
) AS s;

-- Restore createdBy in expense_report to the original value (remove the migration tag)
UPDATE expense_report
SET createdBy = SUBSTRING_INDEX(createdBy, '#', -1)
WHERE createdBy LIKE 'MIG_EXP#%';

SELECT id INTO @inrId
FROM currency
WHERE code = 'INR'
LIMIT 1;

UPDATE expense_report er
LEFT JOIN currency c ON er.currencyId = c.id
SET er.currencyId = @inrId
WHERE c.id IS NULL;

SET SQL_SAFE_UPDATES = 1;
COMMIT;
SET SQL_SAFE_UPDATES = @prev_sql_safe_updates;
SET FOREIGN_KEY_CHECKS = 0;
ALTER TABLE expense_report MODIFY COLUMN id INT NOT NULL AUTO_INCREMENT;
ALTER TABLE expense MODIFY COLUMN id INT NOT NULL AUTO_INCREMENT;
SET @max_report_id := (SELECT COALESCE(MAX(id), 0) + 1 FROM expense_report);
SET @max_expense_id := (SELECT COALESCE(MAX(id), 0) + 1 FROM expense);
SET @max_val := GREATEST(@max_report_id, @max_expense_id);
ALTER TABLE expense_report AUTO_INCREMENT = @max_report_id;
ALTER TABLE expense AUTO_INCREMENT = @max_expense_id;
SET FOREIGN_KEY_CHECKS = @prev_fk_checks;