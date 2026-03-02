-- =============================================================================
--  TEE 1104 Union — Pilot Member Seed (200 accounts)
--  Run AFTER tee_1104_union_seed_admin.sql
--
--  PURPOSE
--  -------
--  Creates 200 test member accounts (t_users + t_members) for User Acceptance
--  Testing (UAT) during the pilot phase. These are NOT real members. They
--  should be deleted before production go-live (cleanup query at bottom).
--
--  WHAT IS SEEDED
--  --------------
--  • 200 rows in t_users  (role = 'member', is_pin_changed = FALSE)
--  • 200 rows in t_members (spread across employers, districts, designations)
--  • employee_id range  : PILOT-0001 … PILOT-0200
--  • One-time PIN        : 1104 for ALL pilot accounts
--
--  DISTRIBUTION
--  ------------
--  • Employers     : alternates TSNPDCL / TSSPDCL (~100 each)
--  • Districts     : cycles through all 33 Telangana districts
--  • Designations  : cycles through all 31 active designations
--  • Marital status: ~65% married, ~25% single, ~10% widowed / divorced
--  • Member since  : spread between 2015 and 2024
--  • Date of birth : ages 28–58 (born 1968–1998)
--
--  PERFORMANCE NOTE
--  ----------------
--  bcrypt hashes are computed ONCE and reused for all 200 rows.
--  This keeps runtime under 3 seconds on a standard dev machine.
--
--  DEPENDENCY
--  ----------
--  Requires tee_1104_union_seed_admin.sql to have run first so that
--  the TEE-ADM-001 admin user exists for created_by references.
--
--  Requires: pgcrypto extension (enabled by admin seed)
-- =============================================================================

BEGIN;

DO $$
DECLARE
    -- -----------------------------------------------------------------------
    -- Name pools: 30 first names × 20 surnames = 600 unique combinations.
    -- Names drawn from common Telangana / South Indian naming conventions.
    -- -----------------------------------------------------------------------
    first_names TEXT[] := ARRAY[
        'Ramesh',   'Suresh',   'Naresh',   'Ganesh',   'Mahesh',
        'Rajesh',   'Lokesh',   'Srikanth', 'Venkatesh','Krishna',
        'Ravi',     'Siva',     'Prasad',   'Nag',      'Srinivas',
        'Mohan',    'Vijay',    'Arun',     'Kiran',    'Raju',
        'Satish',   'Hari',     'Pavan',    'Ajay',     'Sai',
        'Chandra',  'Balaji',   'Deepak',   'Rakesh',   'Anand'
    ];
    last_names TEXT[] := ARRAY[
        'Rao',    'Reddy',  'Kumar',  'Naik',   'Goud',
        'Yadav',  'Sharma', 'Raju',   'Murthy', 'Prasad',
        'Verma',  'Babu',   'Chary',  'Patel',  'Nayak',
        'Swamy',  'Varma',  'Pillai', 'Varma',  'Naidu'
    ];

    -- -----------------------------------------------------------------------
    -- Reference data arrays (populated once from the DB before the loop)
    -- -----------------------------------------------------------------------
    employer_ids    UUID[];
    district_ids    UUID[];
    designation_ids UUID[];

    -- -----------------------------------------------------------------------
    -- Scalar lookups
    -- -----------------------------------------------------------------------
    admin_id        UUID;

    -- -----------------------------------------------------------------------
    -- Per-iteration variables
    -- -----------------------------------------------------------------------
    v_user_id        UUID;
    v_employer_id    UUID;
    v_district_id    UUID;
    v_designation_id UUID;
    v_work_unit_id   UUID;
    v_employee_no    TEXT;
    v_full_name      TEXT;
    v_mobile         TEXT;
    v_dob            DATE;
    v_member_since   DATE;
    v_marital        marital_status_type;

    -- -----------------------------------------------------------------------
    -- Bcrypt hashes: computed ONCE and reused for all 200 members
    -- -----------------------------------------------------------------------
    v_otp_hash  TEXT;   -- one-time PIN hash  (PIN: 1104)
    v_pin_hash  TEXT;   -- placeholder permanent PIN hash

BEGIN

    -- -----------------------------------------------------------------------
    -- Pre-compute hashes (work factor 8 is sufficient for pilot/dev data)
    -- -----------------------------------------------------------------------
    v_otp_hash := crypt('1104', gen_salt('bf', 8));
    v_pin_hash  := crypt('0000', gen_salt('bf', 8));

    -- -----------------------------------------------------------------------
    -- Load reference IDs into arrays (single round-trip each)
    -- -----------------------------------------------------------------------
    SELECT ARRAY_AGG(id ORDER BY short_name) INTO employer_ids
    FROM t_employers
    WHERE is_active = TRUE;

    SELECT ARRAY_AGG(id ORDER BY name) INTO district_ids
    FROM t_districts;

    SELECT ARRAY_AGG(id ORDER BY name) INTO designation_ids
    FROM t_designations
    WHERE is_active = TRUE;

    SELECT id INTO admin_id
    FROM t_users
    WHERE employee_id = 'TEE-ADM-001';

    -- Guard: fail loudly if reference data is missing
    IF array_length(employer_ids, 1) IS NULL THEN
        RAISE EXCEPTION 'Pilot seed failed: t_employers is empty. Run reference seed first.';
    END IF;
    IF array_length(district_ids, 1) IS NULL THEN
        RAISE EXCEPTION 'Pilot seed failed: t_districts is empty. Run reference seed first.';
    END IF;
    IF admin_id IS NULL THEN
        RAISE EXCEPTION 'Pilot seed failed: TEE-ADM-001 not found. Run admin seed first.';
    END IF;

    -- -----------------------------------------------------------------------
    -- Main loop — 200 pilot members
    -- -----------------------------------------------------------------------
    FOR i IN 1..200 LOOP

        -- Employee ID: PILOT-0001 … PILOT-0200
        v_employee_no := 'PILOT-' || LPAD(i::TEXT, 4, '0');

        -- Full name: cycle through name arrays
        v_full_name :=
            first_names[((i - 1) % ARRAY_LENGTH(first_names, 1)) + 1]
            || ' '
            || last_names[(((i - 1) / ARRAY_LENGTH(first_names, 1)) % ARRAY_LENGTH(last_names, 1)) + 1];

        -- Mobile: synthetic +91-9XXXXXXXXX numbers (unique per member)
        v_mobile := '+91-9' || LPAD((100000000 + i)::TEXT, 9, '0');

        -- Date of birth: ages 28–58 spread (born 1968–1998)
        -- Multiply by prime 54 to avoid clustering on a single month
        v_dob := (DATE '1968-01-01' + (((i - 1) * 54) % 10957))::DATE;

        -- Member since: spread between 2015-01-01 and 2024-12-31
        v_member_since := (DATE '2015-01-01' + (((i - 1) * 17) % 3285))::DATE;

        -- Marital status: 65% married, 25% single, 5% widowed, 5% divorced
        v_marital := CASE
            WHEN i % 20 IN (1, 2, 3, 4, 5) THEN 'single'::marital_status_type
            WHEN i % 20 = 10               THEN 'widowed'::marital_status_type
            WHEN i % 20 = 15               THEN 'divorced'::marital_status_type
            ELSE                                'married'::marital_status_type
        END;

        -- Reference data: cycle deterministically through all reference rows
        v_employer_id    := employer_ids   [((i - 1) % ARRAY_LENGTH(employer_ids,    1)) + 1];
        v_district_id    := district_ids   [((i - 1) % ARRAY_LENGTH(district_ids,    1)) + 1];
        v_designation_id := designation_ids[((i - 1) % ARRAY_LENGTH(designation_ids, 1)) + 1];

        -- Work unit: pick the first active work unit in this district if any
        -- (nullable — some districts may not have a work unit seeded yet)
        SELECT id INTO v_work_unit_id
        FROM t_work_units
        WHERE district_id = v_district_id
          AND is_active = TRUE
        ORDER BY name
        LIMIT 1;

        -- -------------------------------------------------------------------
        -- INSERT t_users
        -- -------------------------------------------------------------------
        INSERT INTO t_users (
            employee_id,
            mobile_no,
            pin_hash,
            one_time_pin_hash,
            role,
            is_pin_changed,
            is_active,
            created_by
        ) VALUES (
            v_employee_no,
            v_mobile,
            v_pin_hash,       -- placeholder '0000' hash (overwritten on first login)
            v_otp_hash,       -- one-time PIN 1104
            'member',
            FALSE,            -- app blocks all access until PIN is changed
            TRUE,
            admin_id          -- created by TEE-ADM-001 (General Secretary)
        ) RETURNING id INTO v_user_id;

        -- -------------------------------------------------------------------
        -- INSERT t_members
        -- -------------------------------------------------------------------
        INSERT INTO t_members (
            user_id,
            employee_id,
            employer_id,
            designation_id,
            full_name,
            district_id,
            work_unit_id,
            member_since,
            date_of_birth,
            mobile_no,
            marital_status,
            profile_complete,
            is_active
        ) VALUES (
            v_user_id,
            v_employee_no,
            v_employer_id,
            v_designation_id,
            v_full_name,
            v_district_id,
            v_work_unit_id,   -- may be NULL if district has no work unit yet
            v_member_since,
            v_dob,
            v_mobile,
            v_marital,
            FALSE,            -- profile not yet completed (triggers onboarding prompt)
            TRUE
        );

    END LOOP;

    RAISE NOTICE '200 pilot member accounts created successfully.';

END;
$$;


-- ---------------------------------------------------------------------------
-- VERIFICATION — row counts and distribution breakdown
-- ---------------------------------------------------------------------------

DO $$
DECLARE
    v_pilot_users   INT;
    v_pilot_members INT;
    v_rec           RECORD;
BEGIN
    SELECT COUNT(*) INTO v_pilot_users
    FROM t_users
    WHERE employee_id LIKE 'PILOT-%';

    SELECT COUNT(*) INTO v_pilot_members
    FROM t_members
    WHERE employee_id LIKE 'PILOT-%';

    RAISE NOTICE '============================================================';
    RAISE NOTICE 'Pilot seed verification:';
    RAISE NOTICE '  t_users   (PILOT-*) : % (expected 200)', v_pilot_users;
    RAISE NOTICE '  t_members (PILOT-*) : % (expected 200)', v_pilot_members;
    RAISE NOTICE '------------------------------------------------------------';
    RAISE NOTICE 'Breakdown by employer:';

    FOR v_rec IN
        SELECT e.short_name, COUNT(m.id) AS cnt
        FROM t_members m
        JOIN t_employers e ON e.id = m.employer_id
        WHERE m.employee_id LIKE 'PILOT-%'
        GROUP BY e.short_name
        ORDER BY e.short_name
    LOOP
        RAISE NOTICE '  %-22s : % members', v_rec.short_name, v_rec.cnt;
    END LOOP;

    RAISE NOTICE '------------------------------------------------------------';
    RAISE NOTICE 'Breakdown by marital status:';

    FOR v_rec IN
        SELECT marital_status::TEXT AS status, COUNT(*) AS cnt
        FROM t_members
        WHERE employee_id LIKE 'PILOT-%'
        GROUP BY marital_status
        ORDER BY marital_status
    LOOP
        RAISE NOTICE '  %-22s : % members', v_rec.status, v_rec.cnt;
    END LOOP;

    RAISE NOTICE '------------------------------------------------------------';
    RAISE NOTICE 'Login credentials (all 200 pilot accounts):';
    RAISE NOTICE '  Employee ID  : PILOT-0001 … PILOT-0200';
    RAISE NOTICE '  One-time PIN : 1104';
    RAISE NOTICE '  Action       : Must change PIN on first login';
    RAISE NOTICE '============================================================';

    IF v_pilot_users != 200 THEN
        RAISE EXCEPTION 'Pilot seed failed: expected 200 t_users rows, got %', v_pilot_users;
    END IF;
    IF v_pilot_members != 200 THEN
        RAISE EXCEPTION 'Pilot seed failed: expected 200 t_members rows, got %', v_pilot_members;
    END IF;
END;
$$;


COMMIT;

-- =============================================================================
-- Pilot seed applied successfully.
--
-- SHARING WITH TESTERS
-- --------------------
--   Distribute the following to each pilot tester via a secure channel:
--     Employee ID  : PILOT-XXXX (assign one per tester)
--     One-time PIN : 1104
--   Testers log in, are immediately prompted to set their own 4-digit PIN,
--   and then explore the app normally.
--
-- CLEANUP BEFORE PRODUCTION GO-LIVE
-- -----------------------------------
--   Run the following to remove all pilot data cleanly:
--
--     BEGIN;
--     DELETE FROM t_member_designation_history
--         WHERE member_id IN (SELECT id FROM t_members WHERE employee_id LIKE 'PILOT-%');
--     DELETE FROM t_members WHERE employee_id LIKE 'PILOT-%';
--     DELETE FROM t_users   WHERE employee_id LIKE 'PILOT-%';
--     COMMIT;
--
-- PRODUCTION MEMBER IMPORT
-- ------------------------
--   Real members are NOT seeded via SQL. Use the Admin Portal:
--     Admin → Members → Import CSV
--   The CSV template is in /docs/member_import_template.csv.
--   The backend generates a unique employee_id and issues a one-time PIN
--   for each imported member via bulk SMS.
--
-- FULL SETUP SEQUENCE
-- -------------------
--   psql -U postgres -d tee_union -f tee_1104_union_schema_v6.sql
--   psql -U postgres -d tee_union -f tee_1104_union_seed.sql
--   psql -U postgres -d tee_union -f tee_1104_union_seed_admin.sql
--   psql -U postgres -d tee_union -f tee_1104_union_seed_pilot.sql
-- =============================================================================
