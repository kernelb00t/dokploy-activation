#!/usr/bin/env bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

# ─────────────────────────────────────────────────────────
#  Check & fix trusted origins for SSO in Dokploy
#  Works with Docker Swarm (secrets) and plain Docker
# ─────────────────────────────────────────────────────────

POSTGRES_CONTAINER=$(docker ps --format '{{.Names}}' | grep -i 'postgres' | head -1 || true)

if [ -z "$POSTGRES_CONTAINER" ]; then
  echo -e "${RED}No Postgres container found.${NC}"
  echo "  docker ps --format '{{.Names}}' | grep postgres"
  exit 1
fi

echo -e "Container : ${GREEN}$POSTGRES_CONTAINER${NC}"

# ── Figure out Postgres password ────────────────────────
DB_USER="${DB_USER:-dokploy}"
DB_NAME="${DB_NAME:-dokploy}"

# Try known default first
PGPASSWORD="${PGPASSWORD:-amukds4wi9001583845717ad2}"

# Check if password file secret exists (Docker Swarm style)
PW_FILE="/run/secrets/POSTGRES_PASSWORD"
if docker exec "$POSTGRES_CONTAINER" test -f "$PW_FILE" 2>/dev/null; then
  PGPASSWORD=$(docker exec "$POSTGRES_CONTAINER" cat "$PW_FILE" 2>/dev/null | tr -d '\n')
  echo "Password   : read from $PW_FILE"
else
  echo "Password   : using default (or PGPASSWORD env var)"
fi

echo "DB user    : $DB_USER"
echo "DB name    : $DB_NAME"
echo ""

# ── Show all users ─────────────────────────────────────
echo "=== All users ==="
docker exec -e PGPASSWORD="$PGPASSWORD" "$POSTGRES_CONTAINER" \
  psql -U "$DB_USER" -d "$DB_NAME" \
  -c 'SELECT id, email, "firstName", "trustedOrigins" FROM "user";' 2>&1 || true
echo ""

# ── Show owner user specifically ────────────────────────
echo "=== Owner user (joined with member) ==="
docker exec -e PGPASSWORD="$PGPASSWORD" "$POSTGRES_CONTAINER" \
  psql -U "$DB_USER" -d "$DB_NAME" \
  -c "SELECT u.id, u.email, u.\"firstName\", u.\"trustedOrigins\", m.role
FROM \"user\" u
JOIN member m ON m.\"userId\" = u.id
WHERE m.role = 'owner';" 2>&1 || true
echo ""

# ── Fix commands ────────────────────────────────────────
echo -e "${GREEN}══════════════════════════════════════════════${NC}"
echo -e "${GREEN}  To add trusted origins directly in DB:${NC}"
echo -e "${GREEN}══════════════════════════════════════════════${NC}"
echo ""
echo "  1. Copy the user ID from above"
echo "  2. Run:"
echo ""
echo "  docker exec -e PGPASSWORD='$PGPASSWORD' $POSTGRES_CONTAINER \\"
echo "    psql -U $DB_USER -d $DB_NAME -c \""
echo "      UPDATE \\\"user\\\" SET \\\"trustedOrigins\\\" = ARRAY["
echo "        'https://auth.thivillon.org',"
echo "        'https://auth.thivillon.org/application/o/dokploy'"
echo "      ] WHERE id = '<USER_ID>';\""
echo ""
echo -e "${GREEN}  Then restart the Dokploy server container!${NC}"
echo "  docker restart <dokploy-server-container>"
echo ""
echo "  (Or use the UI: Settings → SSO → Manage origins → Add)"
echo ""
