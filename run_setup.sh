#!/usr/bin/env bash
# =============================================================================
#  TEE 1104 Union — Full Database Setup Script
#  Runs all 4 SQL files in the correct order.
#
#  USAGE
#  -----
#  1. Open Terminal (Mac/Linux) or Git Bash / WSL (Windows)
#  2. cd into the folder containing this script:
#       cd /path/to/your/tee-union/folder
#  3. Make it executable (first time only):
#       chmod +x run_setup.sh
#  4. Run it:
#       ./run_setup.sh
#
#  CONFIGURATION
#  -------------
#  Edit the variables below to match your local PostgreSQL setup.
#  Default values assume a local Postgres with a "tee_union" database.
# =============================================================================

set -e   # Exit immediately on any error

# ── Configuration ─────────────────────────────────────────────────────────────
DB_HOST="localhost"
DB_PORT="5432"
DB_NAME="tee_union"
DB_USER="postgres"
# DB_PASS=""   # Uncomment and set if your postgres user requires a password
#              # Or set PGPASSWORD in your environment before running:
#              #   export PGPASSWORD=yourpassword
# ──────────────────────────────────────────────────────────────────────────────

# Colour helpers
GREEN='\033[0;32m'
CYAN='\033[0;36m'
RED='\033[0;31m'
RESET='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

banner() { echo -e "\n${CYAN}══════════════════════════════════════════════${RESET}"; echo -e "${CYAN}  $1${RESET}"; echo -e "${CYAN}══════════════════════════════════════════════${RESET}"; }
ok()     { echo -e "${GREEN}  ✅  $1${RESET}"; }
fail()   { echo -e "${RED}  ❌  $1${RESET}"; exit 1; }

PSQL="psql -h $DB_HOST -p $DB_PORT -U $DB_USER"

# ── Step 0: Create the database if it doesn't exist ───────────────────────────
banner "Step 0 — Create database '$DB_NAME' (if not exists)"
$PSQL -d postgres -tc "SELECT 1 FROM pg_database WHERE datname='$DB_NAME'" \
    | grep -q 1 \
    || $PSQL -d postgres -c "CREATE DATABASE $DB_NAME;" \
    && ok "Database '$DB_NAME' is ready"

# ── Step 1: Schema (DROP + CREATE all tables) ─────────────────────────────────
banner "Step 1 — Apply schema (tee_1104_union_schema_v6.sql)"
$PSQL -d "$DB_NAME" -f "$SCRIPT_DIR/tee_1104_union_schema_v6.sql" \
    && ok "Schema applied — 24 tables, 8 ENUMs, 34 indexes"

# ── Step 2: Reference data seed ───────────────────────────────────────────────
banner "Step 2 — Seed reference data (tee_1104_union_seed.sql)"
$PSQL -d "$DB_NAME" -f "$SCRIPT_DIR/tee_1104_union_seed.sql" \
    && ok "Reference data seeded — union, districts, employers, designations, categories"

# ── Step 3: Admin users ───────────────────────────────────────────────────────
banner "Step 3 — Seed admin accounts (tee_1104_union_seed_admin.sql)"
$PSQL -d "$DB_NAME" -f "$SCRIPT_DIR/tee_1104_union_seed_admin.sql" \
    && ok "Admin accounts created — TEE-SA-001 (super_admin) + TEE-ADM-001 (admin)"

# ── Step 4: Pilot members ─────────────────────────────────────────────────────
banner "Step 4 — Seed 200 pilot members (tee_1104_union_seed_pilot.sql)"
$PSQL -d "$DB_NAME" -f "$SCRIPT_DIR/tee_1104_union_seed_pilot.sql" \
    && ok "200 pilot member accounts created (PILOT-0001 … PILOT-0200)"

# ── Done ──────────────────────────────────────────────────────────────────────
banner "Setup complete ✅"
echo ""
echo -e "  Database  : ${GREEN}$DB_NAME${RESET}  (host: $DB_HOST:$DB_PORT)"
echo ""
echo -e "  Admin login credentials:"
echo -e "    ${CYAN}TEE-SA-001${RESET}   (super_admin)  → one-time PIN: ${GREEN}7788${RESET}"
echo -e "    ${CYAN}TEE-ADM-001${RESET}  (admin)        → one-time PIN: ${GREEN}1104${RESET}"
echo ""
echo -e "  Pilot members:"
echo -e "    ${CYAN}PILOT-0001 … PILOT-0200${RESET}  → one-time PIN: ${GREEN}1104${RESET}"
echo ""
echo -e "  Quick sanity check:"
echo -e "    ${CYAN}psql -U $DB_USER -d $DB_NAME -c \"\\dt t_*\"${RESET}"
echo ""
