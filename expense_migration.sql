-- Pure SQL migration (no PROCEDURE required). Review and backup DB before running.
SET @now = CURRENT_TIMESTAMP;

START TRANSACTION;

-- Insert expense_report rows. Use a migration tag in createdBy to map newly created report ids back to original expense rows.
INSERT INTO expense_report (
    orgId, submittedAt, approverName, eventName, currencyId,
    accountCode, projectCode, empId, typeId, deptCode, division,
    amount, statusId, isReimbursable, isNotDeleted,
    createdBy, createdAt, modifiedBy, modifiedAt
)
SELECT
    1 AS orgId,
    COALESCE(e.expense_date, DATE(@now)) AS submittedAt,
    COALESCE(
      (SELECT mes.userfullname FROM main_employees_summary mes WHERE mes.user_id = e.manager_id LIMIT 1),
      ''
    ) AS approverName,
    (SELECT et.trip_name FROM expense_trips et WHERE et.id = e.trip_id LIMIT 1) AS eventName,
    e.expense_currency_id AS currencyId,
    (SELECT a.code FROM account a WHERE a.id = e.accountId LIMIT 1) AS accountCode,
    (SELECT p.code FROM project p WHERE p.id = e.project_id LIMIT 1) AS projectCode,
    COALESCE(
      (SELECT mes.employeeId FROM main_employees_summary mes WHERE mes.user_id = e.createdby LIMIT 1),
      e.createdby
    ) AS empId,
    CASE
      WHEN COALESCE(e.is_from_advance,0) = 1 THEN 2
      ELSE 1
    END AS typeId,
    LEFT(
      (SELECT mes.department_name FROM main_employees_summary mes WHERE mes.user_id = e.createdby LIMIT 1),
      4
    ) AS deptCode,
    -- division: take first element of division_json if present
    (SELECT JSON_UNQUOTE(JSON_EXTRACT(mes.division_json, '$[0]'))
       FROM main_employees_summary mes WHERE mes.user_id = e.createdby LIMIT 1) AS division,
    -- amount: sanitized and cast; rows with invalid amount are excluded below via WHERE
    CAST(
      REPLACE(
        REPLACE(
          REPLACE(
            REPLACE(
              REPLACE(
                REPLACE(TRIM(e.expense_amount), ',', ''),
              '(', ''),' )', ''), '$',''), '€',''), '₹',''
      ) AS DECIMAL(20,4)
    ) AS amount,
    CASE COALESCE(e.status,'saved')
      WHEN 'saved' THEN 1
      WHEN 'submitted' THEN 2
      WHEN 'approved' THEN 3
      WHEN 'rejectedFND' THEN 4
      WHEN 'approvedFND' THEN 5
      WHEN 'paid' THEN 6
      WHEN 'rejected' THEN 7
      ELSE 1
    END AS statusId,
    COALESCE(e.is_reimbursable,0) AS isReimbursable,
    COALESCE(e.isactive,1) AS isNotDeleted,
    -- createdBy: include migration tag to map later: 'MIG_EXP#<expense_id>#<original_createdBy_or_name>'
    CONCAT('MIG_EXP#', e.id, '#',
      COALESCE(
        (SELECT mes.userfullname FROM main_employees_summary mes WHERE mes.user_id = e.createdby LIMIT 1),
        COALESCE(CAST(e.createdby AS CHAR), 'System')
      )
    ) AS createdBy,
    COALESCE(e.createddate, @now) AS createdAt,
    COALESCE(e.modifiedby, NULL) AS modifiedBy,
    e.modifieddate AS modifiedAt
FROM expenses e
WHERE
  REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(TRIM(e.expense_amount), ',', ''), '(', ''), ')', ''), '$', ''), '€', ''), '₹', '') REGEXP '^-?[0-9]+(\\.[0-9]+)?$'
;

-- Insert expense rows, matching the generated report via migration tag, and populate receiptId, emp/dept/division lookups.
INSERT INTO expense (
    categoryId, date, qty, rate, amount, paymentTypeId, description,
    createdBy, modifiedBy, createdAt, modifiedAt, isNotDeleted,
    expenseReportId, receiptId, vendorName, orgId, tax
)
SELECT
  COALESCE(e.category_id, 1) AS categoryId,
  COALESCE(e.expense_date, DATE(@now)) AS date,
  CAST(
    CASE
      WHEN REPLACE(REPLACE(REPLACE(TRIM(e.expense_quantity), ',', ''), '(', ''), ')', '') REGEXP '^-?[0-9]+(\\.[0-9]+)?$'
      THEN REPLACE(REPLACE(REPLACE(TRIM(e.expense_quantity), ',', ''), '(', ''), ')', '')
      ELSE '1'
    END AS DECIMAL(20,4)
  ) AS qty,
  CAST(
    CASE
      WHEN REPLACE(REPLACE(REPLACE(TRIM(e.unit_amount), ',', ''), '(', ''), ')', '') REGEXP '^-?[0-9]+(\\.[0-9]+)?$'
      THEN REPLACE(REPLACE(REPLACE(TRIM(e.unit_amount), ',', ''), '(', ''), ')', '')
      ELSE '0'
    END AS DECIMAL(20,4)
  ) AS rate,
  CAST(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(TRIM(e.expense_amount), ',', ''), '(', ''), ')', ''), '$', ''), '€', ''), '₹', '') AS DECIMAL(20,4)) AS amount,
  e.expense_payment_id AS paymentTypeId,
  COALESCE(e.expense_name, e.description) AS description,
  COALESCE(
    (SELECT mes.userfullname FROM main_employees_summary mes WHERE mes.user_id = e.createdby LIMIT 1),
    COALESCE(CAST(e.createdby AS CHAR),'System')
  ) AS createdBy,
  COALESCE(e.modifiedby, NULL) AS modifiedBy,
  COALESCE(e.createddate, @now) AS createdAt,
  e.modifieddate AS modifiedAt,
  COALESCE(e.isactive,1) AS isNotDeleted,
  (SELECT er.id FROM expense_report er WHERE er.createdBy LIKE CONCAT('MIG_EXP#', e.id, '#%') LIMIT 1) AS expenseReportId,
  (
    SELECT erc.id
    FROM expense_receipts erc
    WHERE erc.expense_id = e.id
    ORDER BY erc.modifieddate DESC, erc.id DESC
    LIMIT 1
  ) AS receiptId,
  NULL AS vendorName,
  1 AS orgId,
  0 AS tax
FROM expenses e
WHERE
  REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(TRIM(e.expense_amount), ',', ''), '(', ''), ')', ''), '$', ''), '€', ''), '₹', '') REGEXP '^-?[0-9]+(\\.[0-9]+)?$'
;

-- Restore createdBy in expense_report to the original value (remove the migration tag)
UPDATE expense_report
SET createdBy = SUBSTRING_INDEX(createdBy, '#', -1)
WHERE createdBy LIKE 'MIG_EXP#%';

COMMIT;