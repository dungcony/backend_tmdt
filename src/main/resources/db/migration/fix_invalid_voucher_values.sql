BEGIN;

ALTER TABLE tbl_vouchers DROP CONSTRAINT IF EXISTS chk_voucher_value_valid;

-- Rows created before strict validation may have discount_type=PERCENT with value > 100.
-- The old runtime logic treated value >= 100 as a fixed discount, so preserve behavior.
UPDATE tbl_vouchers
SET discount_type = 'FIXED'
WHERE discount_type = 'PERCENT'
  AND value > 100;

UPDATE tbl_vouchers
SET value = 1
WHERE value <= 0;

ALTER TABLE tbl_vouchers
    ADD CONSTRAINT chk_voucher_value_valid
        CHECK (value > 0 AND (discount_type <> 'PERCENT' OR value <= 100));

COMMIT;
