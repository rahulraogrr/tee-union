-- =============================================================================
--  TEE 1104 Union — Seed Data
--  Run AFTER tee_1104_union_schema_v6.sql
--  Covers: union identity, geography, employers, work units,
--          designations, and ticket categories.
--
--  All IDs are referenced by natural keys (code, name) using subqueries
--  so this file is safe to re-run after a schema reset.
-- =============================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- 1. UNION IDENTITY
--    Single row — the identity of TEE 1104 Union
-- ---------------------------------------------------------------------------

INSERT INTO t_union (
    name,
    short_name,
    description,
    union_type,
    registration_number,
    founded_date,
    ho_phone,
    ho_email,
    ho_address,
    logo_url,
    primary_color,
    default_language_id
) VALUES (
    'Telangana Electricity Employees 1104 Union',
    'TEE 1104',
    'A registered trade union representing electricity employees of TSSPDCL and TSNPDCL across all 33 districts of Telangana, India.',
    'electricity',
    'REG/TG/1104/2001',              -- replace with actual registration number
    '2001-01-01',                    -- replace with actual founding date
    '+91-40-00000000',               -- replace with actual HO phone
    'info@tee1104union.org',         -- replace with actual HO email
    '{
        "line1": "Union Bhavan, Road No. 12",
        "line2": "Banjara Hills",
        "city": "Hyderabad",
        "pincode": "500034"
    }',
    NULL,                            -- logo_url: add after branding is finalised
    '#1F4E79',
    (SELECT id FROM t_languages WHERE code = 'en')
);


-- ---------------------------------------------------------------------------
-- 2. GEOGRAPHY — Country
-- ---------------------------------------------------------------------------

INSERT INTO t_countries (name, code) VALUES
    ('India', 'IN');


-- ---------------------------------------------------------------------------
-- 3. GEOGRAPHY — States
--    Seeding Telangana + 4 neighbouring states for future extensibility.
-- ---------------------------------------------------------------------------

INSERT INTO t_states (country_id, name, code) VALUES
    ((SELECT id FROM t_countries WHERE code = 'IN'), 'Telangana',       'TG'),
    ((SELECT id FROM t_countries WHERE code = 'IN'), 'Andhra Pradesh',  'AP'),
    ((SELECT id FROM t_countries WHERE code = 'IN'), 'Karnataka',       'KA'),
    ((SELECT id FROM t_countries WHERE code = 'IN'), 'Maharashtra',     'MH'),
    ((SELECT id FROM t_countries WHERE code = 'IN'), 'Chhattisgarh',    'CG');


-- ---------------------------------------------------------------------------
-- 4. GEOGRAPHY — Districts (all 33 Telangana districts)
--    Source: Government of Telangana — district list as of 2022 reorganisation
-- ---------------------------------------------------------------------------

INSERT INTO t_districts (state_id, name)
SELECT
    (SELECT id FROM t_states WHERE code = 'TG'),
    name
FROM (VALUES
    ('Adilabad'),
    ('Bhadradri Kothagudem'),
    ('Hanumakonda'),
    ('Hyderabad'),
    ('Jagtial'),
    ('Jangaon'),
    ('Jayashankar Bhupalpally'),
    ('Jogulamba Gadwal'),
    ('Kamareddy'),
    ('Karimnagar'),
    ('Khammam'),
    ('Kumuram Bheem Asifabad'),
    ('Mahabubabad'),
    ('Mahabubnagar'),
    ('Mancherial'),
    ('Medak'),
    ('Medchal-Malkajgiri'),
    ('Mulugu'),
    ('Nagarkurnool'),
    ('Nalgonda'),
    ('Narayanpet'),
    ('Nirmal'),
    ('Nizamabad'),
    ('Peddapalli'),
    ('Rajanna Sircilla'),
    ('Rangareddy'),
    ('Sangareddy'),
    ('Siddipet'),
    ('Suryapet'),
    ('Vikarabad'),
    ('Wanaparthy'),
    ('Warangal'),
    ('Yadadri Bhuvanagiri')
) AS d(name);


-- ---------------------------------------------------------------------------
-- 5. EMPLOYERS — TSSPDCL & TSNPDCL
-- ---------------------------------------------------------------------------

INSERT INTO t_employers (state_id, name, short_name) VALUES
    (
        (SELECT id FROM t_states WHERE code = 'TG'),
        'Telangana State Southern Power Distribution Company Limited',
        'TSSPDCL'
    ),
    (
        (SELECT id FROM t_states WHERE code = 'TG'),
        'Telangana State Northern Power Distribution Company Limited',
        'TSNPDCL'
    );


-- ---------------------------------------------------------------------------
-- 6. WORK UNITS (Circles / Divisions)
--    Representative set — add more as needed.
--
--    TSSPDCL covers: Hyderabad, Rangareddy, Mahabubnagar,
--                    Nalgonda, Vikarabad, Medak (south & west)
--    TSNPDCL covers: Karimnagar, Warangal, Khammam, Nizamabad,
--                    Adilabad, Siddipet (north & east)
-- ---------------------------------------------------------------------------

-- TSSPDCL Circles
INSERT INTO t_work_units (district_id, name, unit_type)
SELECT d.id, w.name, 'circle'::unit_type
FROM (VALUES
    ('Hyderabad',       'Hyderabad City North Circle'),
    ('Hyderabad',       'Hyderabad City South Circle'),
    ('Hyderabad',       'Hyderabad City East Circle'),
    ('Hyderabad',       'Hyderabad City West Circle'),
    ('Rangareddy',      'Rangareddy Circle'),
    ('Medchal-Malkajgiri', 'Medchal Circle'),
    ('Nalgonda',        'Nalgonda Circle'),
    ('Mahabubnagar',    'Mahabubnagar Circle'),
    ('Vikarabad',       'Vikarabad Circle'),
    ('Medak',           'Medak Circle'),
    ('Sangareddy',      'Sangareddy Circle'),
    ('Nagarkurnool',    'Nagarkurnool Circle'),
    ('Suryapet',        'Suryapet Circle'),
    ('Wanaparthy',      'Wanaparthy Circle'),
    ('Narayanpet',      'Narayanpet Circle'),
    ('Jogulamba Gadwal','Gadwal Circle')
) AS w(district_name, name)
JOIN t_districts d ON d.name = w.district_name
JOIN t_states s ON s.id = d.state_id AND s.code = 'TG';

-- TSNPDCL Circles
INSERT INTO t_work_units (district_id, name, unit_type)
SELECT d.id, w.name, 'circle'::unit_type
FROM (VALUES
    ('Karimnagar',             'Karimnagar Circle'),
    ('Peddapalli',             'Peddapalli Circle'),
    ('Rajanna Sircilla',       'Sircilla Circle'),
    ('Jagtial',                'Jagtial Circle'),
    ('Nizamabad',              'Nizamabad Circle'),
    ('Kamareddy',              'Kamareddy Circle'),
    ('Nirmal',                 'Nirmal Circle'),
    ('Adilabad',               'Adilabad Circle'),
    ('Mancherial',             'Mancherial Circle'),
    ('Kumuram Bheem Asifabad', 'Asifabad Circle'),
    ('Warangal',               'Warangal Circle'),
    ('Hanumakonda',            'Hanumakonda Circle'),
    ('Jangaon',                'Jangaon Circle'),
    ('Mahabubabad',            'Mahabubabad Circle'),
    ('Khammam',                'Khammam Circle'),
    ('Bhadradri Kothagudem',   'Kothagudem Circle'),
    ('Siddipet',               'Siddipet Circle'),
    ('Medak',                  'Medak North Circle'),
    ('Jayashankar Bhupalpally','Bhupalpally Circle'),
    ('Mulugu',                 'Mulugu Circle'),
    ('Yadadri Bhuvanagiri',    'Yadadri Circle')
) AS w(district_name, name)
JOIN t_districts d ON d.name = w.district_name
JOIN t_states s ON s.id = d.state_id AND s.code = 'TG';


-- ---------------------------------------------------------------------------
-- 7. DESIGNATIONS
--    Standard electricity utility job titles used across TSSPDCL & TSNPDCL.
--    Ordered roughly by seniority (field → supervisory → engineering → admin).
-- ---------------------------------------------------------------------------

INSERT INTO t_designations (name) VALUES
    -- Field / Technical
    ('Helper'),
    ('Assistant Lineman'),
    ('Junior Lineman'),
    ('Lineman'),
    ('Senior Lineman'),
    ('Cable Jointer'),
    ('Sub-Station Operator'),
    ('Assistant Sub-Station Operator'),
    ('Meter Reader'),
    ('Bill Collector'),
    ('Technical Helper'),

    -- Supervisory
    ('Line Inspector'),
    ('Technical Supervisor'),
    ('Foreman'),
    ('Senior Supervisor'),

    -- Engineering
    ('Junior Engineer'),
    ('Assistant Engineer'),
    ('Deputy Executive Engineer'),
    ('Executive Engineer'),
    ('Superintendent Engineer'),
    ('Chief Engineer'),
    ('Director (Technical)'),

    -- Administrative / Support
    ('Office Assistant'),
    ('Junior Assistant'),
    ('Senior Assistant'),
    ('Accounts Officer'),
    ('Cashier'),
    ('Store Keeper'),
    ('Driver'),
    ('Watchman / Security'),
    ('Sweeper / Sanitation Worker');


-- ---------------------------------------------------------------------------
-- 8. TICKET CATEGORIES
--    Grievance types relevant to electricity utility employees.
-- ---------------------------------------------------------------------------

INSERT INTO t_ticket_categories (name) VALUES
    -- Pay & Benefits
    ('Pay & Allowances'),
    ('Arrears & Dues'),
    ('Overtime & Incentives'),
    ('Pension & Retirement Benefits'),
    ('Medical & Health Insurance'),
    ('Provident Fund (PF) / Gratuity'),

    -- Career
    ('Promotion & Seniority'),
    ('Transfer & Posting'),
    ('Regularisation / Contract to Permanent'),
    ('Increment & Grade Pay'),
    ('Suspension & Disciplinary Action'),

    -- Workplace
    ('Leave & Attendance'),
    ('Working Hours & Shift Duty'),
    ('Safety & Personal Protective Equipment'),
    ('Tools & Equipment Issues'),
    ('Workload & Manpower Shortage'),

    -- Welfare
    ('Accommodation / Quarter Allotment'),
    ('Harassment & Misconduct'),
    ('Caste / Reservation Issue'),
    ('Union Rights & Recognition'),

    -- General
    ('General Grievance');


-- ---------------------------------------------------------------------------
-- 9. VERIFICATION — quick row count check
-- ---------------------------------------------------------------------------

DO $$
DECLARE
    v_union       INT;
    v_languages   INT;
    v_countries   INT;
    v_states      INT;
    v_districts   INT;
    v_employers   INT;
    v_work_units  INT;
    v_desig       INT;
    v_categories  INT;
BEGIN
    SELECT COUNT(*) INTO v_union       FROM t_union;
    SELECT COUNT(*) INTO v_languages   FROM t_languages;
    SELECT COUNT(*) INTO v_countries   FROM t_countries;
    SELECT COUNT(*) INTO v_states      FROM t_states;
    SELECT COUNT(*) INTO v_districts   FROM t_districts;
    SELECT COUNT(*) INTO v_employers   FROM t_employers;
    SELECT COUNT(*) INTO v_work_units  FROM t_work_units;
    SELECT COUNT(*) INTO v_desig       FROM t_designations;
    SELECT COUNT(*) INTO v_categories  FROM t_ticket_categories;

    RAISE NOTICE '--------------------------------------------';
    RAISE NOTICE 'Seed verification:';
    RAISE NOTICE '  t_union            : % (expected 1)',  v_union;
    RAISE NOTICE '  t_languages        : % (expected 2)',  v_languages;
    RAISE NOTICE '  t_countries        : % (expected 1)',  v_countries;
    RAISE NOTICE '  t_states           : % (expected 5)',  v_states;
    RAISE NOTICE '  t_districts        : % (expected 33)', v_districts;
    RAISE NOTICE '  t_employers        : % (expected 2)',  v_employers;
    RAISE NOTICE '  t_work_units       : % (expected 37)', v_work_units;
    RAISE NOTICE '  t_designations     : % (expected 31)', v_desig;
    RAISE NOTICE '  t_ticket_categories: % (expected 21)', v_categories;
    RAISE NOTICE '--------------------------------------------';

    -- Fail loudly if counts are wrong
    IF v_union != 1 THEN
        RAISE EXCEPTION 't_union seed failed: expected 1 row, got %', v_union;
    END IF;
    IF v_districts != 33 THEN
        RAISE EXCEPTION 't_districts seed failed: expected 33 rows, got %', v_districts;
    END IF;
    IF v_employers != 2 THEN
        RAISE EXCEPTION 't_employers seed failed: expected 2 rows, got %', v_employers;
    END IF;
END;
$$;


COMMIT;

-- =============================================================================
-- Seed applied successfully.
--
-- Next seed files to create:
--   tee_1104_union_seed_admin.sql  — initial admin user + one-time PIN
--   tee_1104_union_seed_pilot.sql  — 200 pilot member accounts (CSV import)
--
-- To run both schema + seed together:
--   psql -U postgres -d tee_union -f tee_1104_union_schema_v6.sql
--   psql -U postgres -d tee_union -f tee_1104_union_seed.sql
-- =============================================================================
