-- =============================================================================
--  TEE 1104 Union — Admin User Seed
--  Run AFTER tee_1104_union_schema_v6.sql AND tee_1104_union_seed.sql
--
--  Creates two privileged accounts:
--    1. super_admin (TEE-SA-001)  — IT / App Administrator (Anthropic / dev team)
--    2. admin       (TEE-ADM-001) — Union General Secretary (day-to-day admin)
--
--  Security rules:
--    • Both accounts are seeded with is_pin_changed = FALSE.
--      The app BLOCKS all access until the user changes the one-time PIN.
--    • one_time_pin_hash is cleared by the backend after the first login.
--    • pin_hash ('0000') is a non-guessable placeholder that is immediately
--      overwritten the moment the user sets their own PIN.
--    • Share one-time PINs via a secure out-of-band channel (Signal, in-person).
--      Never transmit via email or SMS.
--
--  Requires: pgcrypto extension (enabled automatically below)
-- =============================================================================

BEGIN;

-- Enable pgcrypto for bcrypt PIN hashing
CREATE EXTENSION IF NOT EXISTS pgcrypto;


-- ---------------------------------------------------------------------------
-- 1. SUPER ADMIN — IT / App Administrator
--    Manages the database, deploys updates, handles outages.
--    Should be locked down or removed after go-live.
--    One-time PIN: 7788
-- ---------------------------------------------------------------------------

INSERT INTO t_users (
    employee_id,
    mobile_no,
    email,
    pin_hash,
    one_time_pin_hash,
    role,
    is_pin_changed,
    is_active
) VALUES (
    'TEE-SA-001',
    '+91-98765-00001',
    'superadmin@tee1104union.org',
    crypt('0000', gen_salt('bf', 12)),   -- placeholder; overwritten on first PIN change
    crypt('7788', gen_salt('bf', 12)),   -- ★ one-time PIN: 7788
    'super_admin',
    FALSE,
    TRUE
);

INSERT INTO t_staff_profiles (user_id, full_name, mobile_no, designation)
SELECT
    id,
    'App Administrator',
    '+91-98765-00001',
    'IT / App Administrator'
FROM t_users
WHERE employee_id = 'TEE-SA-001';


-- ---------------------------------------------------------------------------
-- 2. ADMIN — Union General Secretary
--    Day-to-day app admin: approves members, manages reps, posts news/events.
--    One-time PIN: 1104
-- ---------------------------------------------------------------------------

INSERT INTO t_users (
    employee_id,
    mobile_no,
    email,
    pin_hash,
    one_time_pin_hash,
    role,
    is_pin_changed,
    is_active
) VALUES (
    'TEE-ADM-001',
    '+91-98765-00002',
    'secretary@tee1104union.org',
    crypt('0000', gen_salt('bf', 12)),   -- placeholder; overwritten on first PIN change
    crypt('1104', gen_salt('bf', 12)),   -- ★ one-time PIN: 1104 (union number — easy to remember)
    'admin',
    FALSE,
    TRUE
);

INSERT INTO t_staff_profiles (user_id, full_name, mobile_no, designation)
SELECT
    id,
    'G. Venkatesh Rao',          -- UPDATE with actual General Secretary name before go-live
    '+91-98765-00002',
    'General Secretary'
FROM t_users
WHERE employee_id = 'TEE-ADM-001';


-- ---------------------------------------------------------------------------
-- 3. VERIFICATION — printed to psql console via RAISE NOTICE
-- ---------------------------------------------------------------------------

DO $$
DECLARE
    v_users   INT;
    v_staff   INT;
BEGIN
    SELECT COUNT(*) INTO v_users
    FROM t_users
    WHERE role IN ('super_admin', 'admin');

    SELECT COUNT(*) INTO v_staff
    FROM t_staff_profiles;

    RAISE NOTICE '============================================================';
    RAISE NOTICE 'Admin seed verification:';
    RAISE NOTICE '  t_users  (admin-level) : % (expected 2)', v_users;
    RAISE NOTICE '  t_staff_profiles       : % (expected 2)', v_staff;
    RAISE NOTICE '------------------------------------------------------------';
    RAISE NOTICE 'Login credentials — share via secure channel (NOT email/SMS):';
    RAISE NOTICE '';
    RAISE NOTICE '  Employee ID  : TEE-SA-001';
    RAISE NOTICE '  Role         : super_admin';
    RAISE NOTICE '  One-time PIN : 7788';
    RAISE NOTICE '';
    RAISE NOTICE '  Employee ID  : TEE-ADM-001';
    RAISE NOTICE '  Role         : admin';
    RAISE NOTICE '  One-time PIN : 1104';
    RAISE NOTICE '============================================================';

    IF v_users != 2 THEN
        RAISE EXCEPTION 'Admin seed failed: expected 2 admin-level users, got %', v_users;
    END IF;
    IF v_staff != 2 THEN
        RAISE EXCEPTION 'Staff profile seed failed: expected 2 rows, got %', v_staff;
    END IF;
END;
$$;


COMMIT;

-- =============================================================================
-- Admin seed applied successfully.
--
-- IMPORTANT post-seed actions:
--   1. Update t_staff_profiles.full_name for TEE-ADM-001 with the actual
--      General Secretary's name before distributing the app to members.
--   2. Update mobile_no and email placeholders with real contact details.
--   3. Share one-time PINs with respective users via a secure channel.
--   4. Consider disabling TEE-SA-001 (set is_active = FALSE) after go-live
--      and re-enabling only when technical access is required.
--
-- Next step:
--   psql -U postgres -d tee_union -f tee_1104_union_seed_pilot.sql
-- =============================================================================
