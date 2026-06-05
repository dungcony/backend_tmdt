-- ============================================================
-- Fix: Gán rank 'Bronze' cho các user chưa có rank_id
-- Chạy sau khi đã chạy user_seed.sql
-- ============================================================

UPDATE tbl_users
SET rank_id = (SELECT id FROM tbl_ranks WHERE type = 'Bronze' LIMIT 1)
WHERE rank_id IS NULL;


select *
from tbl_users u
         join tbl_accounts a on a.id = u.acc_id
where a.id = 121

create unique index tbl_users_acc
    on tbl_users (acc_id);

