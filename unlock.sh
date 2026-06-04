#!/usr/bin/env bash
set -euo pipefail

# ─────────────────────────────────────────────────────────
#  Dokploy Enterprise Unlocker — zero container modification
# ─────────────────────────────────────────────────────────
#  Set enableEnterpriseFeatures = true
#  Set isValidEnterpriseLicense = true
#  Set licenseKey = NULL (so the cron never re-validates)
# ─────────────────────────────────────────────────────────

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo ""
echo -e "${GREEN}══════════════════════════════════════════════${NC}"
echo -e "${GREEN}  Dokploy Enterprise Unlocker${NC}"
echo -e "${GREEN}══════════════════════════════════════════════${NC}"
echo ""

# ── 1. Find the Postgres container ─────────────────────
POSTGRES_CONTAINER=$(docker ps --format '{{.Names}}' | grep -i 'dokploy.*postgres' | head -1 || true)

if [ -z "$POSTGRES_CONTAINER" ]; then
  POSTGRES_CONTAINER=$(docker ps --format '{{.Names}}' | grep -i 'postgres' | head -1 || true)
fi

if [ -z "$POSTGRES_CONTAINER" ]; then
  echo -e "${RED}✗ No Postgres container found.${NC}"
  echo "  Is Dokploy running? Check with: docker ps"
  echo ""
  echo "  Alternative: connect manually with psql and run:"
  echo "    UPDATE \"user\" SET \"enableEnterpriseFeatures\"=true, \"isValidEnterpriseLicense\"=true, \"licenseKey\"=NULL;"
  exit 1
fi

echo -e "  Container : ${YELLOW}$POSTGRES_CONTAINER${NC}"

# ── 2. Find the DB credentials ─────────────────────────
# Try common env var patterns from the dokploy-postgres container
DB_USER="${DB_USER:-dokploy}"
DB_NAME="${DB_NAME:-dokploy}"

echo "  DB user   : $DB_USER"
echo "  DB name   : $DB_NAME"
echo ""

# ── 3. Get the list of users ───────────────────────────
echo "  📋 Current users in Dokploy:"
echo ""
docker exec "$POSTGRES_CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" \
  -c "SELECT id, email, \"firstName\", \"lastName\", \"enableEnterpriseFeatures\", \"isValidEnterpriseLicense\", \"licenseKey\" FROM \"user\";" \
  2>/dev/null || {
  echo -e "${RED}✗ Failed to connect to Postgres.${NC}"
  echo "  Try setting custom credentials:"
  echo "    DB_USER=myuser DB_NAME=mydb bash unlock.sh"
  exit 1
}

echo ""

# ── 4. Ask which user to unlock ────────────────────────
USER_COUNT=$(docker exec "$POSTGRES_CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" \
  -t -A -c 'SELECT COUNT(*) FROM "user";' 2>/dev/null | tr -d ' ')

if [ "$USER_COUNT" -eq 0 ]; then
  echo -e "${YELLOW}No users found in the database.${NC}"
  exit 0
fi

if [ "$USER_COUNT" -eq 1 ]; then
  TARGET_ID=$(docker exec "$POSTGRES_CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" \
    -t -A -c 'SELECT id FROM "user" LIMIT 1;' 2>/dev/null | tr -d ' ')
  echo "  Only 1 user found. Unlocking automatically..."
else
  echo -n "  Enter user ID to unlock (copy from list above): "
  read -r TARGET_ID
fi

if [ -z "$TARGET_ID" ]; then
  echo -e "${RED}✗ No user ID provided.${NC}"
  exit 1
fi

# ── 5. Unlock ──────────────────────────────────────────
echo ""
echo "  🔓 Unlocking user $TARGET_ID ..."

docker exec "$POSTGRES_CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" \
  -c "UPDATE \"user\" SET \"enableEnterpriseFeatures\" = true, \"isValidEnterpriseLicense\" = true, \"licenseKey\" = NULL WHERE id = '$TARGET_ID';" \
  2>/dev/null

# ── 6. Verify ──────────────────────────────────────────
echo ""
echo "  ✅ Verification:"
docker exec "$POSTGRES_CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" \
  -c "SELECT id, email, \"enableEnterpriseFeatures\", \"isValidEnterpriseLicense\", \"licenseKey\" FROM \"user\" WHERE id = '$TARGET_ID';" \
  2>/dev/null

echo ""
echo -e "${GREEN}══════════════════════════════════════════════${NC}"
echo -e "${GREEN}  ✅ Enterprise features unlocked!${NC}"
echo -e "${GREEN}══════════════════════════════════════════════${NC}"
echo ""
echo "  Features now available:"
echo "    • SSO (OIDC / SAML)"
echo "    • Audit logs"
echo "    • Custom roles & permissions"
echo "    • Whitelabeling"
echo "    • Git provider assignment"
echo "    • Server assignment"
echo ""
echo "  ⚠️  No license key is stored — the cron will NOT re-validate."
echo "      To undo: run this script again or set the columns to false."
echo ""