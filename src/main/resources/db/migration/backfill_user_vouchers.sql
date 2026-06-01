-- Backfill tbl_user_vouchers for vouchers created before automatic granting existed.
-- This is idempotent because it uses ON CONFLICT DO NOTHING.

INSERT INTO tbl_user_vouchers (voucher_id, user_id, status, end_at, min_price_apply, version)
SELECT v.id, u.id, 'AVAILABLE', v.end_at, v.min_order_amount, 0
FROM tbl_vouchers v
CROSS JOIN tbl_users u
WHERE v.status <> 'INACTIVE'
  AND v.voucher_type = 'GLOBAL'
ON CONFLICT (voucher_id, user_id) DO NOTHING;

INSERT INTO tbl_user_vouchers (voucher_id, user_id, status, end_at, min_price_apply, version)
SELECT v.id, u.id, 'AVAILABLE', v.end_at, v.min_order_amount, 0
FROM tbl_vouchers v
CROSS JOIN tbl_users u
WHERE v.status <> 'INACTIVE'
  AND v.voucher_type = 'NEWBIE'
  AND u.created_at > now() - interval '90 days'
ON CONFLICT (voucher_id, user_id) DO NOTHING;

INSERT INTO tbl_user_vouchers (voucher_id, user_id, status, end_at, min_price_apply, version)
SELECT v.id, u.id, 'AVAILABLE', v.end_at, v.min_order_amount, 0
FROM tbl_vouchers v
JOIN tbl_ranks required_rank ON required_rank.id = v.rank_id
JOIN tbl_users u ON TRUE
JOIN tbl_ranks user_rank ON user_rank.id = u.rank_id
WHERE v.status <> 'INACTIVE'
  AND v.voucher_type = 'USER_RANK'
  AND user_rank.level >= required_rank.level
ON CONFLICT (voucher_id, user_id) DO NOTHING;
