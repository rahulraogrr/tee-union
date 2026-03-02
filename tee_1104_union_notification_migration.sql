-- =============================================================================
--  TEE 1104 Union — Notification System Migration
--  Run AFTER tee_1104_union_schema_v6.sql and all seed files.
--
--  Changes:
--    1. t_users         → add Telegram linking columns
--    2. t_notifications → add multi-channel delivery tracking columns
--    3. CREATE t_telegram_link_tokens  (secure Telegram linking flow)
--    4. CREATE t_notification_jobs     (fallback job audit trail)
--
--  Run order:
--    psql -U postgres -d tee_union -f tee_1104_union_notification_migration.sql
-- =============================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- 1. t_users — Telegram linking columns
-- ---------------------------------------------------------------------------

ALTER TABLE t_users
    ADD COLUMN IF NOT EXISTS telegram_chat_id   BIGINT      UNIQUE,
    ADD COLUMN IF NOT EXISTS telegram_linked_at TIMESTAMP;

COMMENT ON COLUMN t_users.telegram_chat_id   IS 'Telegram chat ID linked by the member via /link token flow. NULL = not linked.';
COMMENT ON COLUMN t_users.telegram_linked_at IS 'Timestamp when the member successfully linked their Telegram account.';

-- Index for fast lookup when dispatching Telegram notifications
CREATE INDEX IF NOT EXISTS idx_users_telegram_chat_id
    ON t_users (telegram_chat_id)
    WHERE telegram_chat_id IS NOT NULL;


-- ---------------------------------------------------------------------------
-- 2. t_notifications — multi-channel delivery tracking
-- ---------------------------------------------------------------------------

ALTER TABLE t_notifications
    ADD COLUMN IF NOT EXISTS fcm_sent      BOOLEAN     NOT NULL DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS telegram_sent BOOLEAN     NOT NULL DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS sms_sent      BOOLEAN     NOT NULL DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS delivered_via VARCHAR(20),
    ADD COLUMN IF NOT EXISTS is_critical   BOOLEAN     NOT NULL DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS is_urgent     BOOLEAN     NOT NULL DEFAULT FALSE;

COMMENT ON COLUMN t_notifications.fcm_sent      IS 'TRUE after FCM push notification was successfully sent.';
COMMENT ON COLUMN t_notifications.telegram_sent IS 'TRUE after Telegram fallback message was sent.';
COMMENT ON COLUMN t_notifications.sms_sent      IS 'TRUE after SMS fallback was sent.';
COMMENT ON COLUMN t_notifications.delivered_via IS 'First channel that confirmed delivery: fcm | telegram | sms.';
COMMENT ON COLUMN t_notifications.is_critical   IS 'If TRUE, SMS fallback is triggered after 15 min if unread.';
COMMENT ON COLUMN t_notifications.is_urgent     IS 'If TRUE, FCM + Telegram fire simultaneously with no delay.';

-- Index for the fallback job processor — find unread notifications
-- where FCM was sent but member hasn't read yet
CREATE INDEX IF NOT EXISTS idx_notifications_fallback
    ON t_notifications (fcm_sent, is_read, sent_at)
    WHERE is_read = FALSE AND fcm_sent = TRUE;


-- ---------------------------------------------------------------------------
-- 3. t_telegram_link_tokens — secure one-time token for Telegram linking
--
--  Flow:
--    a) Member logs into app (already authenticated with Employee ID + PIN)
--    b) App calls POST /api/v1/telegram/link-token
--    c) Backend generates token e.g. "TG-X7K2P9", stores here, expires in 10 min
--    d) Member opens Telegram, sends /link TG-X7K2P9 to TEEBot
--    e) Bot verifies token → links telegram_chat_id to t_users
--    f) Token marked used_at, cannot be reused
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS t_telegram_link_tokens (
    id         UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id    UUID         NOT NULL REFERENCES t_users(id),
    token      VARCHAR(10)  NOT NULL UNIQUE,   -- e.g. TG-X7K2P9
    expires_at TIMESTAMP    NOT NULL,           -- 10 minutes from created_at
    used_at    TIMESTAMP,                       -- NULL = not yet used
    created_at TIMESTAMP    NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE  t_telegram_link_tokens            IS 'Short-lived one-time tokens for securely linking a Telegram account to a union member.';
COMMENT ON COLUMN t_telegram_link_tokens.token      IS 'Human-readable 8-10 char token e.g. TG-X7K2P9. Member types this into Telegram bot.';
COMMENT ON COLUMN t_telegram_link_tokens.expires_at IS 'Token is invalid after this time. Set to NOW() + 10 minutes on creation.';
COMMENT ON COLUMN t_telegram_link_tokens.used_at    IS 'Set when the bot successfully links the account. NULL = unused. Non-NULL = consumed.';

CREATE INDEX IF NOT EXISTS idx_telegram_link_tokens_token
    ON t_telegram_link_tokens (token)
    WHERE used_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_telegram_link_tokens_user
    ON t_telegram_link_tokens (user_id);


-- ---------------------------------------------------------------------------
-- 4. t_notification_jobs — fallback job audit trail
--
--  Tracks every scheduled fallback (Telegram / SMS) so you can:
--    - See why a member received a Telegram message
--    - Debug missed notifications
--    - Audit notification delivery performance
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS t_notification_jobs (
    id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    notification_id UUID        NOT NULL REFERENCES t_notifications(id),
    channel         VARCHAR(20) NOT NULL,    -- 'telegram' | 'sms'
    scheduled_at    TIMESTAMP   NOT NULL,    -- when the job was queued
    processed_at    TIMESTAMP,              -- when the job ran
    skipped         BOOLEAN     NOT NULL DEFAULT FALSE,
    skip_reason     VARCHAR(50),            -- 'already_read' | 'no_channel' | 'expired'
    created_at      TIMESTAMP   NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE  t_notification_jobs             IS 'Audit trail of all scheduled fallback notification jobs (Telegram and SMS).';
COMMENT ON COLUMN t_notification_jobs.channel     IS 'Delivery channel for this job: telegram or sms.';
COMMENT ON COLUMN t_notification_jobs.skipped     IS 'TRUE if the job ran but did not send — e.g. member already read the notification.';
COMMENT ON COLUMN t_notification_jobs.skip_reason IS 'Why the job was skipped: already_read | no_channel | expired.';

CREATE INDEX IF NOT EXISTS idx_notification_jobs_notification
    ON t_notification_jobs (notification_id);

CREATE INDEX IF NOT EXISTS idx_notification_jobs_processed
    ON t_notification_jobs (processed_at)
    WHERE processed_at IS NULL;   -- find pending jobs quickly


-- ---------------------------------------------------------------------------
-- VERIFICATION
-- ---------------------------------------------------------------------------

DO $$
DECLARE
    v_telegram_cols  INT;
    v_notif_cols     INT;
    v_link_table     INT;
    v_jobs_table     INT;
BEGIN
    -- Check t_users telegram columns
    SELECT COUNT(*) INTO v_telegram_cols
    FROM information_schema.columns
    WHERE table_name = 't_users'
      AND column_name IN ('telegram_chat_id', 'telegram_linked_at');

    -- Check t_notifications new columns
    SELECT COUNT(*) INTO v_notif_cols
    FROM information_schema.columns
    WHERE table_name = 't_notifications'
      AND column_name IN ('fcm_sent', 'telegram_sent', 'sms_sent',
                          'delivered_via', 'is_critical', 'is_urgent');

    -- Check new tables exist
    SELECT COUNT(*) INTO v_link_table
    FROM information_schema.tables
    WHERE table_name = 't_telegram_link_tokens';

    SELECT COUNT(*) INTO v_jobs_table
    FROM information_schema.tables
    WHERE table_name = 't_notification_jobs';

    RAISE NOTICE '============================================================';
    RAISE NOTICE 'Notification migration verification:';
    RAISE NOTICE '  t_users telegram columns    : % / 2', v_telegram_cols;
    RAISE NOTICE '  t_notifications new columns : % / 6', v_notif_cols;
    RAISE NOTICE '  t_telegram_link_tokens      : % (1=exists)', v_link_table;
    RAISE NOTICE '  t_notification_jobs         : % (1=exists)', v_jobs_table;
    RAISE NOTICE '============================================================';

    IF v_telegram_cols != 2 THEN
        RAISE EXCEPTION 'Migration failed: t_users telegram columns missing';
    END IF;
    IF v_notif_cols != 6 THEN
        RAISE EXCEPTION 'Migration failed: t_notifications columns missing';
    END IF;
    IF v_link_table != 1 THEN
        RAISE EXCEPTION 'Migration failed: t_telegram_link_tokens not created';
    END IF;
    IF v_jobs_table != 1 THEN
        RAISE EXCEPTION 'Migration failed: t_notification_jobs not created';
    END IF;

    RAISE NOTICE 'All checks passed ✅';
END;
$$;


COMMIT;

-- =============================================================================
-- Notification migration applied successfully.
--
-- Summary of changes:
--   t_users              → +2 columns (telegram_chat_id, telegram_linked_at)
--   t_notifications      → +6 columns (fcm_sent, telegram_sent, sms_sent,
--                                       delivered_via, is_critical, is_urgent)
--   t_telegram_link_tokens → NEW TABLE (secure Telegram linking flow)
--   t_notification_jobs    → NEW TABLE (fallback job audit trail)
--   New indexes            → 4 indexes for performance
--
-- Next step:
--   psql -U postgres -d tee_union -f tee_1104_union_notification_migration.sql
-- =============================================================================
