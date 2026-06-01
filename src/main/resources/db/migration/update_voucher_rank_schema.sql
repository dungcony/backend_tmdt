BEGIN;

-- Bring old schemas up to the current rank and rank-voucher model.
-- Voucher.rank_id means the minimum rank required to use the voucher.

DO $$
BEGIN
    IF to_regclass('public.tbl_rank') IS NOT NULL
       AND to_regclass('public.tbl_ranks') IS NULL THEN
        ALTER TABLE public.tbl_rank RENAME TO tbl_ranks;
    END IF;

    IF to_regclass('public.rank') IS NOT NULL
       AND to_regclass('public.tbl_ranks') IS NULL THEN
        EXECUTE 'ALTER TABLE public."rank" RENAME TO tbl_ranks';
    END IF;
END $$;

CREATE TABLE IF NOT EXISTS tbl_ranks
(
    id           serial PRIMARY KEY,
    type         varchar(255),
    level        integer,
    min_purchase numeric(38, 2) DEFAULT 0 NOT NULL,
    expire_time  bigint
);

ALTER TABLE tbl_ranks
    ADD COLUMN IF NOT EXISTS type varchar(255),
    ADD COLUMN IF NOT EXISTS level integer,
    ADD COLUMN IF NOT EXISTS min_purchase numeric(38, 2) DEFAULT 0 NOT NULL,
    ADD COLUMN IF NOT EXISTS expire_time bigint;

CREATE UNIQUE INDEX IF NOT EXISTS uk_tbl_ranks_type ON tbl_ranks (type);
CREATE UNIQUE INDEX IF NOT EXISTS uk_tbl_ranks_level ON tbl_ranks (level);

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'chk_tbl_ranks_type'
          AND conrelid = 'tbl_ranks'::regclass
    ) THEN
        ALTER TABLE tbl_ranks
            ADD CONSTRAINT chk_tbl_ranks_type
                CHECK (type IN ('Bronze', 'Silver', 'Gold', 'Platinum', 'Diamond', 'Ultimate'));
    END IF;
END $$;

INSERT INTO tbl_ranks (id, type, level, min_purchase, expire_time)
VALUES
    (1, 'Bronze', 1, 0, NULL),
    (2, 'Silver', 2, 1000000, NULL),
    (3, 'Gold', 3, 5000000, NULL),
    (4, 'Platinum', 4, 10000000, NULL),
    (5, 'Diamond', 5, 20000000, NULL),
    (6, 'Ultimate', 6, 50000000, NULL)
ON CONFLICT (type) DO UPDATE
SET level = EXCLUDED.level,
    min_purchase = EXCLUDED.min_purchase,
    expire_time = EXCLUDED.expire_time;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'chk_tbl_ranks_level'
          AND conrelid = 'tbl_ranks'::regclass
    ) THEN
        ALTER TABLE tbl_ranks
            ADD CONSTRAINT chk_tbl_ranks_level
                CHECK (level > 0);
    END IF;
END $$;

ALTER TABLE tbl_ranks
    ALTER COLUMN level SET NOT NULL;

CREATE SEQUENCE IF NOT EXISTS tbl_ranks_id_seq;

DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'tbl_ranks'
          AND column_name = 'id'
          AND is_identity = 'NO'
          AND column_default IS NULL
    ) THEN
        ALTER TABLE tbl_ranks
            ALTER COLUMN id SET DEFAULT nextval('tbl_ranks_id_seq');
    END IF;
END $$;

SELECT setval('tbl_ranks_id_seq', COALESCE((SELECT MAX(id) FROM tbl_ranks), 1), true);

ALTER TABLE tbl_users
    ADD COLUMN IF NOT EXISTS last_purchase_time timestamp with time zone,
    ADD COLUMN IF NOT EXISTS toltal_purchase numeric(38, 2) DEFAULT 0,
    ADD COLUMN IF NOT EXISTS rank_id integer;

UPDATE tbl_users
SET toltal_purchase = 0
WHERE toltal_purchase IS NULL;

ALTER TABLE tbl_users
    ALTER COLUMN toltal_purchase SET DEFAULT 0;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'fk_users_rank'
          AND conrelid = 'tbl_users'::regclass
    ) THEN
        ALTER TABLE tbl_users
            ADD CONSTRAINT fk_users_rank
                FOREIGN KEY (rank_id) REFERENCES tbl_ranks (id);
    END IF;
END $$;

ALTER TABLE tbl_vouchers
    ADD COLUMN IF NOT EXISTS rank_id integer,
    ALTER COLUMN value TYPE numeric(38, 2) USING value::numeric,
    ALTER COLUMN value SET NOT NULL,
    ALTER COLUMN min_order_amount SET DEFAULT 0,
    ALTER COLUMN min_order_amount SET NOT NULL;

ALTER TABLE tbl_vouchers DROP CONSTRAINT IF EXISTS tbl_vouchers_voucher_type_check;
ALTER TABLE tbl_vouchers DROP CONSTRAINT IF EXISTS chk_voucher_type;
ALTER TABLE tbl_vouchers DROP CONSTRAINT IF EXISTS tbl_vouchers_discount_type_check;
ALTER TABLE tbl_vouchers DROP CONSTRAINT IF EXISTS chk_voucher_discount_type;
ALTER TABLE tbl_vouchers DROP CONSTRAINT IF EXISTS chk_voucher_status;
ALTER TABLE tbl_vouchers DROP CONSTRAINT IF EXISTS chk_voucher_value_valid;
ALTER TABLE tbl_vouchers DROP CONSTRAINT IF EXISTS chk_voucher_rank_required;

-- Old code treated value >= 100 as a fixed discount even when discount_type was PERCENT.
-- Normalize those rows before adding the stricter discount constraint.
UPDATE tbl_vouchers
SET discount_type = 'FIXED'
WHERE discount_type = 'PERCENT'
  AND value > 100;

UPDATE tbl_vouchers
SET value = 1
WHERE value <= 0;

ALTER TABLE tbl_vouchers
    ADD CONSTRAINT chk_voucher_type
        CHECK (voucher_type IN ('NEWBIE', 'GLOBAL', 'USER_RANK')),
    ADD CONSTRAINT chk_voucher_discount_type
        CHECK (discount_type IN ('PERCENT', 'FIXED')),
    ADD CONSTRAINT chk_voucher_status
        CHECK (status IN ('ACTIVE', 'INACTIVE', 'COMMING_SOON')),
    ADD CONSTRAINT chk_voucher_value_valid
        CHECK (value > 0 AND (discount_type <> 'PERCENT' OR value <= 100)) NOT VALID,
    ADD CONSTRAINT chk_voucher_rank_required
        CHECK (voucher_type <> 'USER_RANK' OR rank_id IS NOT NULL) NOT VALID;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'fk_vouchers_rank'
          AND conrelid = 'tbl_vouchers'::regclass
    ) THEN
        ALTER TABLE tbl_vouchers
            ADD CONSTRAINT fk_vouchers_rank
                FOREIGN KEY (rank_id) REFERENCES tbl_ranks (id);
    END IF;
END $$;

COMMIT;
