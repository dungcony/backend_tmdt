BEGIN;

-- Recalculate user purchase totals from existing orders, then assign a non-null rank.
-- This counts active/successful order states and excludes UNPAID, CANCELLED, RETURNED.
-- If your business only counts fully completed orders, change the status list to ('COMPLETED').

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

CREATE UNIQUE INDEX IF NOT EXISTS uk_tbl_ranks_type ON tbl_ranks (type);
CREATE UNIQUE INDEX IF NOT EXISTS uk_tbl_ranks_level ON tbl_ranks (level);

ALTER TABLE tbl_users
    ADD COLUMN IF NOT EXISTS toltal_purchase numeric(38, 2) DEFAULT 0,
    ADD COLUMN IF NOT EXISTS last_purchase_time timestamp with time zone,
    ADD COLUMN IF NOT EXISTS rank_id integer;

WITH user_order_totals AS (
    SELECT
        o.user_id,
        COALESCE(SUM(o.final_price), 0) AS total_purchase,
        MAX(COALESCE(o.updated_at, o.created_at)) AS last_purchase_time
    FROM tbl_orders o
    WHERE o.status IN ('PENDING', 'CONFIRMED', 'SHIPPING', 'DELIVERED', 'COMPLETED')
    GROUP BY o.user_id
)
UPDATE tbl_users u
SET toltal_purchase = t.total_purchase,
    last_purchase_time = t.last_purchase_time
FROM user_order_totals t
WHERE u.id = t.user_id;

UPDATE tbl_users
SET toltal_purchase = 0
WHERE toltal_purchase IS NULL;

UPDATE tbl_users u
SET rank_id = COALESCE(
    (
        SELECT r.id
        FROM tbl_ranks r
        WHERE r.min_purchase <= u.toltal_purchase
        ORDER BY r.min_purchase DESC, r.level DESC
        LIMIT 1
    ),
    (
        SELECT r.id
        FROM tbl_ranks r
        WHERE r.type = 'Bronze'
        LIMIT 1
    )
);

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM tbl_users WHERE rank_id IS NULL) THEN
        RAISE EXCEPTION 'Cannot set tbl_users.rank_id NOT NULL: some users still have NULL rank_id';
    END IF;
END $$;

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

ALTER TABLE tbl_users
    ALTER COLUMN toltal_purchase SET DEFAULT 0,
    ALTER COLUMN toltal_purchase SET NOT NULL,
    ALTER COLUMN rank_id SET NOT NULL;

COMMIT;
