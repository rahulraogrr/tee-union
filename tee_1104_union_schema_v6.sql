-- =============================================================================
--  TEE 1104 Union — PostgreSQL Database Schema v6
--  One schema deployed per union. No shared platform DB.
--  All table names prefixed with t_ for namespacing.
--  Backend: NestJS + Prisma  |  DB: PostgreSQL
--  Generated: March 2026
-- =============================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- STEP 1: DROP all tables in reverse dependency order
--         (children before parents to respect FK constraints)
-- ---------------------------------------------------------------------------

DROP TABLE IF EXISTS t_audit_logs                  CASCADE;
DROP TABLE IF EXISTS t_push_tokens                 CASCADE;
DROP TABLE IF EXISTS t_notifications               CASCADE;
DROP TABLE IF EXISTS t_event_registrations         CASCADE;
DROP TABLE IF EXISTS t_events                      CASCADE;
DROP TABLE IF EXISTS t_news                        CASCADE;
DROP TABLE IF EXISTS t_ticket_status_history       CASCADE;
DROP TABLE IF EXISTS t_ticket_comments             CASCADE;
DROP TABLE IF EXISTS t_tickets                     CASCADE;
DROP TABLE IF EXISTS t_ticket_categories           CASCADE;
DROP TABLE IF EXISTS t_rep_assignments             CASCADE;
DROP TABLE IF EXISTS t_member_designation_history  CASCADE;
DROP TABLE IF EXISTS t_members                     CASCADE;
DROP TABLE IF EXISTS t_designations                CASCADE;
DROP TABLE IF EXISTS t_staff_profiles              CASCADE;
DROP TABLE IF EXISTS t_users                       CASCADE;
DROP TABLE IF EXISTS t_employers                   CASCADE;
DROP TABLE IF EXISTS t_work_units                  CASCADE;
DROP TABLE IF EXISTS t_districts                   CASCADE;
DROP TABLE IF EXISTS t_states                      CASCADE;
DROP TABLE IF EXISTS t_countries                   CASCADE;
DROP TABLE IF EXISTS t_translations                CASCADE;
DROP TABLE IF EXISTS t_languages                   CASCADE;
DROP TABLE IF EXISTS t_union                       CASCADE;

-- ---------------------------------------------------------------------------
-- STEP 2: DROP custom ENUM types (must be after tables that use them)
-- ---------------------------------------------------------------------------

DROP TYPE IF EXISTS user_role           CASCADE;
DROP TYPE IF EXISTS marital_status_type CASCADE;
DROP TYPE IF EXISTS ticket_priority     CASCADE;
DROP TYPE IF EXISTS ticket_status       CASCADE;
DROP TYPE IF EXISTS notification_type   CASCADE;
DROP TYPE IF EXISTS platform_type       CASCADE;
DROP TYPE IF EXISTS audit_action        CASCADE;
DROP TYPE IF EXISTS unit_type           CASCADE;

-- ---------------------------------------------------------------------------
-- STEP 3: CREATE ENUM types
-- ---------------------------------------------------------------------------

CREATE TYPE user_role AS ENUM (
    'super_admin',
    'admin',
    'zonal_officer',
    'rep',
    'member'
);

CREATE TYPE marital_status_type AS ENUM (
    'single',
    'married',
    'widowed',
    'divorced'
);

CREATE TYPE ticket_priority AS ENUM (
    'standard',
    'urgent',
    'critical'
);

CREATE TYPE ticket_status AS ENUM (
    'open',
    'in_progress',
    'escalated',
    'resolved',
    'closed'
);

CREATE TYPE notification_type AS ENUM (
    'ticket_update',
    'news',
    'event',
    'system'
);

CREATE TYPE platform_type AS ENUM (
    'ios',
    'android'
);

CREATE TYPE audit_action AS ENUM (
    'INSERT',
    'UPDATE',
    'DELETE'
);

CREATE TYPE unit_type AS ENUM (
    'circle',
    'branch',
    'depot',
    'division',
    'zone',
    'section'
);

-- ===========================================================================
-- STEP 4: CREATE TABLES in dependency order (parents before children)
-- ===========================================================================


-- ---------------------------------------------------------------------------
-- 1. UNION IDENTITY
--    Note: t_union replaces the reserved keyword 'union'. No quotes needed.
-- ---------------------------------------------------------------------------

CREATE TABLE t_union (
    id                  UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    name                VARCHAR(200)    NOT NULL,
    short_name          VARCHAR(50)     NOT NULL,
    description         TEXT,
    union_type          VARCHAR(100)    NOT NULL,
    registration_number VARCHAR(100),
    founded_date        DATE,
    ho_phone            VARCHAR(15),
    ho_email            VARCHAR(150),
    -- JSONB: { "line1", "line2", "city", "district_id", "state_id", "country_id", "pincode" }
    ho_address          JSONB,
    logo_url            VARCHAR(500),
    primary_color       VARCHAR(10)     NOT NULL DEFAULT '#1F4E79',
    -- default_language_id FK added after t_languages table is created (see below)
    default_language_id UUID,
    updated_at          TIMESTAMP       NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE  t_union                IS 'Single-row table. Union identity, branding, and config.';
COMMENT ON COLUMN t_union.ho_address     IS 'JSONB: { line1, line2, city, district_id, state_id, country_id, pincode }';
COMMENT ON COLUMN t_union.primary_color  IS 'Hex color used to theme the mobile app for this union.';


-- ---------------------------------------------------------------------------
-- 2. LANGUAGES
-- ---------------------------------------------------------------------------

CREATE TABLE t_languages (
    id          UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    code        VARCHAR(10)     NOT NULL UNIQUE,   -- BCP 47: en, te, hi, mr
    name        VARCHAR(100)    NOT NULL,           -- English, Telugu, Hindi
    native_name VARCHAR(100)    NOT NULL,           -- English, తెలుగు, हिंदी
    is_active   BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at  TIMESTAMP       NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE t_languages IS 'Languages supported by this union. Seeded with en-IN and te-IN.';

-- Now add the deferred FK on union.default_language_id
ALTER TABLE t_union
    ADD CONSTRAINT fk_union_default_language
    FOREIGN KEY (default_language_id) REFERENCES t_languages(id);


-- ---------------------------------------------------------------------------
-- 3. TRANSLATIONS
--    For dynamic admin-managed reference data only.
--    Static geo data (countries/states/districts) lives in i18next JSON.
-- ---------------------------------------------------------------------------

CREATE TABLE t_translations (
    id          UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    entity_type VARCHAR(100)    NOT NULL,   -- designation | ticket_category | work_unit | employer
    entity_id   UUID            NOT NULL,
    language_id UUID            NOT NULL REFERENCES t_languages(id),
    field       VARCHAR(100)    NOT NULL,   -- name | description
    value       TEXT            NOT NULL,
    created_at  TIMESTAMP       NOT NULL DEFAULT NOW(),

    UNIQUE (entity_type, entity_id, language_id, field)
);

COMMENT ON TABLE t_translations IS 'Translated values for admin-managed reference data. Not used for geo data (handled in app i18next JSON).';


-- ---------------------------------------------------------------------------
-- 4. GEOGRAPHY
-- ---------------------------------------------------------------------------

CREATE TABLE t_countries (
    id         UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    name       VARCHAR(100)    NOT NULL,
    code       VARCHAR(10)     NOT NULL UNIQUE,   -- ISO 3166-1 alpha-2: IN
    created_at TIMESTAMP       NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE t_countries IS 'Country reference. Seeded with India on setup.';

-- ----

CREATE TABLE t_states (
    id         UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    country_id UUID            NOT NULL REFERENCES t_countries(id),
    name       VARCHAR(100)    NOT NULL,
    code       VARCHAR(10)     NOT NULL UNIQUE,   -- TG, MH, TN
    created_at TIMESTAMP       NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE t_states IS 'Indian states and union territories.';

-- ----

CREATE TABLE t_districts (
    id         UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    state_id   UUID            NOT NULL REFERENCES t_states(id),
    name       VARCHAR(100)    NOT NULL,
    created_at TIMESTAMP       NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE t_districts IS 'Districts within a state. Seeded with all 33 Telangana districts.';

-- ----

CREATE TABLE t_work_units (
    id          UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    district_id UUID            NOT NULL REFERENCES t_districts(id),
    name        VARCHAR(150)    NOT NULL,
    unit_type   unit_type       NOT NULL,   -- circle | branch | depot | division | zone | section
    is_active   BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at  TIMESTAMP       NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE t_work_units IS 'Sub-district groupings (circles, branches, depots etc.). Generic — not electricity-specific.';

-- ----

CREATE TABLE t_employers (
    id         UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    state_id   UUID            NOT NULL REFERENCES t_states(id),
    name       VARCHAR(200)    NOT NULL,   -- TSSPDCL, TSNPDCL, BEST, SBI
    short_name VARCHAR(50)     NOT NULL,
    is_active  BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP       NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE t_employers IS 'Organisations that union t_members work for. Replaces hard-coded utility ENUMs.';


-- ---------------------------------------------------------------------------
-- 5. AUTHENTICATION & USERS
-- ---------------------------------------------------------------------------

CREATE TABLE t_users (
    id                  UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    employee_id         VARCHAR(50)     NOT NULL UNIQUE,
    mobile_no           VARCHAR(15)     NOT NULL,
    email               VARCHAR(150),
    pin_hash            VARCHAR(255)    NOT NULL,               -- bcrypt 4-digit PIN
    one_time_pin_hash   VARCHAR(255),                           -- cleared after first login
    role                user_role       NOT NULL,
    is_pin_changed      BOOLEAN         NOT NULL DEFAULT FALSE, -- gates all app access
    is_active           BOOLEAN         NOT NULL DEFAULT TRUE,
    created_by          UUID            REFERENCES t_users(id),   -- self-referential FK
    last_login_at       TIMESTAMP,
    created_at          TIMESTAMP       NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMP       NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE  t_users                    IS 'Central auth table. One row per person regardless of role.';
COMMENT ON COLUMN t_users.employee_id        IS 'Government-issued ID used as login username.';
COMMENT ON COLUMN t_users.one_time_pin_hash  IS 'Admin-issued temp PIN. Set to NULL immediately after first login.';
COMMENT ON COLUMN t_users.is_pin_changed     IS 'FALSE until member sets own PIN. Blocks all app access until changed.';

-- ----

CREATE TABLE t_staff_profiles (
    id          UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID            NOT NULL UNIQUE REFERENCES t_users(id),
    full_name   VARCHAR(150)    NOT NULL,
    mobile_no   VARCHAR(15)     NOT NULL,
    designation VARCHAR(100),   -- e.g. District Secretary, Zonal President
    created_at  TIMESTAMP       NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMP       NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE t_staff_profiles IS 'Profile for reps, zonal officers, and admins. Members use the t_members table instead.';


-- ---------------------------------------------------------------------------
-- 6. MEMBERS
-- ---------------------------------------------------------------------------

CREATE TABLE t_designations (
    id         UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    name       VARCHAR(150)    NOT NULL,   -- Lineman, Driver, Clerk, Junior Engineer
    is_active  BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP       NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE t_designations IS 'Job titles configurable per union. Names translated via t_translations table.';

-- ----

CREATE TABLE t_members (
    id                        UUID                PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id                   UUID                NOT NULL UNIQUE REFERENCES t_users(id),
    employee_id               VARCHAR(50)         NOT NULL,           -- denormalised from t_users for easy lookup
    employer_id               UUID                NOT NULL REFERENCES t_employers(id),
    designation_id            UUID                NOT NULL REFERENCES t_designations(id),
    full_name                 VARCHAR(200)        NOT NULL,
    district_id               UUID                NOT NULL REFERENCES t_districts(id),   -- posting district
    work_unit_id              UUID                REFERENCES t_work_units(id),
    member_since              DATE                NOT NULL,
    date_of_birth             DATE,
    mobile_no                 VARCHAR(15)         NOT NULL,
    marital_status            marital_status_type,
    marriage_anniversary_date DATE,
    -- JSONB: { "line1", "line2", "city", "district_id", "state_id", "country_id", "pincode" }
    current_address           JSONB,
    permanent_address         JSONB,
    profile_complete          BOOLEAN             NOT NULL DEFAULT FALSE,
    is_active                 BOOLEAN             NOT NULL DEFAULT TRUE,
    created_at                TIMESTAMP           NOT NULL DEFAULT NOW(),
    updated_at                TIMESTAMP           NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_anniversary CHECK (
        marriage_anniversary_date IS NULL OR marital_status = 'married'
    )
);

COMMENT ON TABLE  t_members                         IS 'Complete membership register. Addresses stored as JSONB columns (no join needed).';
COMMENT ON COLUMN t_members.current_address         IS 'JSONB: { line1, line2, city, district_id, state_id, country_id, pincode }';
COMMENT ON COLUMN t_members.permanent_address       IS 'JSONB: { line1, line2, city, district_id, state_id, country_id, pincode }';
COMMENT ON COLUMN t_members.designation_id          IS 'Current designation. Full history in t_member_designation_history.';
COMMENT ON COLUMN t_members.marriage_anniversary_date IS 'Must be NULL unless marital_status = married. Enforced by CHECK constraint.';

-- ----

CREATE TABLE t_member_designation_history (
    id             UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    member_id      UUID        NOT NULL REFERENCES t_members(id),
    designation_id UUID        NOT NULL REFERENCES t_designations(id),
    employer_id    UUID        NOT NULL REFERENCES t_employers(id),
    work_unit_id   UUID        REFERENCES t_work_units(id),
    district_id    UUID        REFERENCES t_districts(id),
    valid_from     DATE        NOT NULL,
    valid_to       DATE,       -- NULL = current record
    changed_by     UUID        NOT NULL REFERENCES t_users(id),
    notes          TEXT,       -- e.g. transfer order number, promotion order ref
    created_at     TIMESTAMP   NOT NULL DEFAULT NOW(),

    UNIQUE (member_id, valid_from)
);

COMMENT ON TABLE  t_member_designation_history           IS 'NEW in v6. Full history of every designation, employer, and posting change. valid_to NULL = current.';
COMMENT ON COLUMN t_member_designation_history.valid_to  IS 'NULL means this is the currently active record. Set when the next change is recorded.';
COMMENT ON COLUMN t_member_designation_history.notes     IS 'Transfer order number, promotion order reference, or other administrative notes.';

-- ----

CREATE TABLE t_rep_assignments (
    id           UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id      UUID        NOT NULL REFERENCES t_users(id),       -- rep or zonal officer
    district_id  UUID        NOT NULL REFERENCES t_districts(id),
    work_unit_id UUID        REFERENCES t_work_units(id),           -- NULL = district-wide
    assigned_at  TIMESTAMP   NOT NULL DEFAULT NOW(),
    assigned_by  UUID        REFERENCES t_users(id),
    is_active    BOOLEAN     NOT NULL DEFAULT TRUE                -- deactivate on reassignment
);

COMMENT ON TABLE t_rep_assignments IS 'Maps reps and zonal officers to districts or work units. Drives ticket auto-routing.';


-- ---------------------------------------------------------------------------
-- 7. TICKETING & GRIEVANCES
-- ---------------------------------------------------------------------------

CREATE TABLE t_ticket_categories (
    id         UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    name       VARCHAR(150)    NOT NULL,   -- Pay Dispute, Safety Issue, Transfer Request
    is_active  BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP       NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE t_ticket_categories IS 'Grievance categories managed by admin. Names translated via t_translations table.';

-- ----

CREATE TABLE t_tickets (
    id                        UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    member_id                 UUID            NOT NULL REFERENCES t_members(id),
    assigned_rep_id           UUID            REFERENCES t_users(id),
    assigned_zonal_officer_id UUID            REFERENCES t_users(id),
    category_id               UUID            REFERENCES t_ticket_categories(id),
    title                     VARCHAR(200)    NOT NULL,
    description               TEXT,           -- supports voice-to-text input
    priority                  ticket_priority NOT NULL DEFAULT 'standard',
    status                    ticket_status   NOT NULL DEFAULT 'open',
    district_id               UUID            REFERENCES t_districts(id),    -- copied from member at submission
    work_unit_id              UUID            REFERENCES t_work_units(id),   -- copied from member at submission
    sla_deadline              TIMESTAMP       NOT NULL,  -- standard=+30d | urgent=+10d | critical=+1d
    resolved_at               TIMESTAMP,
    created_at                TIMESTAMP       NOT NULL DEFAULT NOW(),
    updated_at                TIMESTAMP       NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE  t_tickets             IS 'Core grievance records.';
COMMENT ON COLUMN t_tickets.district_id IS 'Copied from member at submission time so routing is preserved even if member is later transferred.';
COMMENT ON COLUMN t_tickets.sla_deadline IS 'standard = +30 days, urgent = +10 days, critical = +1 day from created_at.';

-- ----

CREATE TABLE t_ticket_comments (
    id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    ticket_id   UUID        NOT NULL REFERENCES t_tickets(id),
    user_id     UUID        NOT NULL REFERENCES t_users(id),
    comment     TEXT        NOT NULL,
    is_internal BOOLEAN     NOT NULL DEFAULT FALSE,   -- TRUE = only reps and above can see
    created_at  TIMESTAMP   NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE t_ticket_comments IS 'Conversation thread on a ticket.';
COMMENT ON COLUMN t_ticket_comments.is_internal IS 'If TRUE, filtered from member-facing API responses. Only visible to reps and above.';

-- ----

CREATE TABLE t_ticket_status_history (
    id         UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    ticket_id  UUID            NOT NULL REFERENCES t_tickets(id),
    changed_by UUID            NOT NULL REFERENCES t_users(id),
    old_status ticket_status   NOT NULL,
    new_status ticket_status   NOT NULL,
    notes      TEXT,
    changed_at TIMESTAMP       NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE t_ticket_status_history IS 'Append-only audit trail of every status change. Never deleted or updated.';


-- ---------------------------------------------------------------------------
-- 8. NEWS & EVENTS
-- ---------------------------------------------------------------------------

CREATE TABLE t_news (
    id           UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    title_en     VARCHAR(250) NOT NULL,
    title_te     VARCHAR(250),
    body_en      TEXT        NOT NULL,
    body_te      TEXT,
    published_by UUID        REFERENCES t_users(id),
    is_published BOOLEAN     NOT NULL DEFAULT FALSE,
    published_at TIMESTAMP,
    created_at   TIMESTAMP   NOT NULL DEFAULT NOW(),
    updated_at   TIMESTAMP   NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE t_news IS 'Union announcements, circulars, and notices. Managed via Strapi CMS.';

-- ----

CREATE TABLE t_events (
    id             UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    title_en       VARCHAR(250) NOT NULL,
    title_te       VARCHAR(250),
    description_en TEXT,
    description_te TEXT,
    event_date     TIMESTAMP   NOT NULL,
    location       VARCHAR(300),
    max_capacity   INTEGER,
    is_virtual     BOOLEAN     NOT NULL DEFAULT FALSE,
    district_id    UUID        REFERENCES t_districts(id),   -- NULL = all districts
    created_by     UUID        REFERENCES t_users(id),
    is_published   BOOLEAN     NOT NULL DEFAULT FALSE,
    created_at     TIMESTAMP   NOT NULL DEFAULT NOW(),
    updated_at     TIMESTAMP   NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE t_events IS 'Union meetings, rallies, assemblies, and training sessions.';

-- ----

CREATE TABLE t_event_registrations (
    id            UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id      UUID        NOT NULL REFERENCES t_events(id),
    member_id     UUID        NOT NULL REFERENCES t_members(id),
    registered_at TIMESTAMP   NOT NULL DEFAULT NOW(),

    UNIQUE (event_id, member_id)
);

COMMENT ON TABLE t_event_registrations IS 'Member RSVPs for events. UNIQUE prevents duplicate registrations.';


-- ---------------------------------------------------------------------------
-- 9. NOTIFICATIONS
-- ---------------------------------------------------------------------------

CREATE TABLE t_notifications (
    id           UUID                PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id      UUID                NOT NULL REFERENCES t_users(id),
    title        VARCHAR(200)        NOT NULL,
    body         TEXT                NOT NULL,
    type         notification_type   NOT NULL,
    reference_id UUID,               -- related ticket, news, or event ID
    is_read      BOOLEAN             NOT NULL DEFAULT FALSE,
    sent_at      TIMESTAMP           NOT NULL DEFAULT NOW(),
    read_at      TIMESTAMP
);

COMMENT ON TABLE t_notifications IS 'Record of all notifications sent. Used for the in-app notification inbox.';

-- ----

CREATE TABLE t_push_tokens (
    id           UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id      UUID            NOT NULL REFERENCES t_users(id),
    token        TEXT            NOT NULL,
    platform     platform_type   NOT NULL,
    created_at   TIMESTAMP       NOT NULL DEFAULT NOW(),
    last_used_at TIMESTAMP
);

COMMENT ON TABLE t_push_tokens IS 'FCM device tokens. One user can have multiple tokens across devices.';


-- ---------------------------------------------------------------------------
-- 10. AUDIT LOG  (new in v6)
-- ---------------------------------------------------------------------------

CREATE TABLE t_audit_logs (
    id          UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    table_name  VARCHAR(100)    NOT NULL,
    record_id   UUID            NOT NULL,
    action      audit_action    NOT NULL,
    changed_by  UUID            REFERENCES t_users(id),   -- NULL for automated/system actions
    old_values  JSONB,          -- NULL for INSERT
    new_values  JSONB,          -- NULL for DELETE
    ip_address  VARCHAR(45),    -- IPv4 or IPv6
    user_agent  VARCHAR(500),
    created_at  TIMESTAMP       NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE  t_audit_logs            IS 'NEW in v6. Append-only. WHO changed WHAT on WHICH record and WHEN.';
COMMENT ON COLUMN t_audit_logs.old_values IS 'Full row before change as JSONB. NULL for INSERT.';
COMMENT ON COLUMN t_audit_logs.new_values IS 'Full row after change as JSONB. NULL for DELETE.';
COMMENT ON COLUMN t_audit_logs.changed_by IS 'NULL for system-triggered automated actions.';


-- ===========================================================================
-- STEP 5: INDEXES
--         Must be created AFTER tables. Covering all high-traffic FKs
--         and filter columns.
-- ===========================================================================

-- t_users
CREATE INDEX idx_users_employee_id       ON t_users (employee_id);
CREATE INDEX idx_users_role              ON t_users (role);

-- t_members
CREATE INDEX idx_members_district        ON t_members (district_id);
CREATE INDEX idx_members_work_unit       ON t_members (work_unit_id);
CREATE INDEX idx_members_employer        ON t_members (employer_id);
CREATE INDEX idx_members_designation     ON t_members (designation_id);
CREATE INDEX idx_members_is_active       ON t_members (is_active);
-- GIN index for JSONB address search
CREATE INDEX idx_members_current_addr    ON t_members USING GIN (current_address);
CREATE INDEX idx_members_permanent_addr  ON t_members USING GIN (permanent_address);

-- t_member_designation_history
CREATE INDEX idx_mdh_member_id           ON t_member_designation_history (member_id);
CREATE INDEX idx_mdh_member_valid_from   ON t_member_designation_history (member_id, valid_from);
CREATE INDEX idx_mdh_valid_to            ON t_member_designation_history (valid_to);   -- find current: WHERE valid_to IS NULL

-- t_rep_assignments
CREATE INDEX idx_rep_assign_district     ON t_rep_assignments (district_id, is_active);
CREATE INDEX idx_rep_assign_user         ON t_rep_assignments (user_id, is_active);

-- t_tickets
CREATE INDEX idx_tickets_status          ON t_tickets (status);
CREATE INDEX idx_tickets_member          ON t_tickets (member_id);
CREATE INDEX idx_tickets_rep             ON t_tickets (assigned_rep_id);
CREATE INDEX idx_tickets_zonal           ON t_tickets (assigned_zonal_officer_id);
CREATE INDEX idx_tickets_sla             ON t_tickets (sla_deadline);
CREATE INDEX idx_tickets_district        ON t_tickets (district_id);
CREATE INDEX idx_tickets_created_at      ON t_tickets (created_at);

-- t_ticket_comments
CREATE INDEX idx_ticket_comments_ticket  ON t_ticket_comments (ticket_id);

-- t_ticket_status_history
CREATE INDEX idx_tsh_ticket_id           ON t_ticket_status_history (ticket_id);
CREATE INDEX idx_tsh_changed_at          ON t_ticket_status_history (changed_at);

-- t_notifications
CREATE INDEX idx_notifications_user      ON t_notifications (user_id, is_read);
CREATE INDEX idx_notifications_sent_at   ON t_notifications (sent_at);

-- t_push_tokens
CREATE INDEX idx_push_tokens_user        ON t_push_tokens (user_id);

-- t_translations
CREATE INDEX idx_translations_lookup     ON t_translations (entity_type, entity_id, language_id);

-- t_news & t_events
CREATE INDEX idx_news_published          ON t_news (is_published, published_at);
CREATE INDEX idx_events_date             ON t_events (event_date);
CREATE INDEX idx_events_district         ON t_events (district_id);

-- t_audit_logs
CREATE INDEX idx_audit_record            ON t_audit_logs (table_name, record_id);
CREATE INDEX idx_audit_changed_by        ON t_audit_logs (changed_by);
CREATE INDEX idx_audit_created_at        ON t_audit_logs (created_at);
CREATE INDEX idx_audit_table_name        ON t_audit_logs (table_name);


-- ===========================================================================
-- STEP 6: SEED DATA — t_languages
-- ===========================================================================

INSERT INTO t_languages (code, name, native_name, is_active) VALUES
    ('en', 'English', 'English', TRUE),
    ('te', 'Telugu',  'తెలుగు',  TRUE);


COMMIT;

-- =============================================================================
-- Schema v6 applied successfully.
-- Tables: 24 (all prefixed t_) | ENUMs: 8 | Indexes: 34 | Seed rows: 2
--
-- Next steps:
--   1. Seed t_countries (India), t_states (Telangana), and t_districts (33 rows)
--   2. Seed t_employers (TSSPDCL, TSNPDCL)
--   3. Create the initial admin user (role = admin)
--   4. Seed t_ticket_categories with union-specific grievance types
--   5. INSERT INTO t_union with the union's name, short_name, and config
-- =============================================================================
