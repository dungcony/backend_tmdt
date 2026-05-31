ROLLBACK;

DROP MATERIALIZED VIEW IF EXISTS ai_view.vouchers;

ALTER TABLE tbl_vouchers
    DROP CONSTRAINT IF EXISTS chk_voucher_discount_type;

ALTER TABLE tbl_vouchers
    DROP CONSTRAINT IF EXISTS chk_voucher_type;

ALTER TABLE tbl_vouchers
    DROP COLUMN IF EXISTS "discountType";

ALTER TABLE tbl_vouchers
    DROP COLUMN IF EXISTS "voucherType";

ALTER TABLE tbl_vouchers
    ALTER COLUMN discount_type SET NOT NULL;

ALTER TABLE tbl_vouchers
    ALTER COLUMN voucher_type SET NOT NULL;

ALTER TABLE tbl_vouchers
    ADD CONSTRAINT chk_voucher_discount_type
        CHECK (discount_type IN ('PERCENT', 'FIXED'));

ALTER TABLE tbl_vouchers
    ADD CONSTRAINT chk_voucher_type
        CHECK (voucher_type IN ('NEWBIE', 'GLOBAL'));

SELECT column_name, is_nullable, data_type
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'tbl_vouchers'
ORDER BY ordinal_position;
