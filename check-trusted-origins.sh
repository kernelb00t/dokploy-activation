#!/usr/bin/env bash
set -euo pipefail

# ─────────────────────────────────────────────────────────
#  Check & fix trusted origins for SSO in Dokploy
# ─────────────────────────────────────────────────────────

POSTGRES_CONTAINER=$(docker ps --format '{{.Names}}' | grep -i 'postgres' | head -1 || true)

if [ -z "$POSTGRES_CONTAINER" ]; then
  echo "No Postgres container found. Set POSTGRES_CONTAINER= manually."
  exit 1
fi

DB_USER="${DB_USER:-dokploy}"
DB_NAME="${DB_NAME:-dokploy}"

echo "Container: $POSTGRES_CONTAINER"
echo ""

# Show current trusted origins for the owner
echo "=== Current trustedOrigins for owner ==="
docker exec "$POSTGRES_CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" -c "
SELECT u.id, u.email, u.\"trustedOrigins\"
FROM \"user\" u
JOIN member m ON m.\"userId\" = u.id
WHERE m.role = 'owner';
" 2>/dev/null

echo ""
echo "=== If trustedOrigins is NULL or wrong, add the correct origin ==="
echo ""
echo "Example command to fix manually:"
echo "  docker exec $POSTGRES_CONTAINER psql -U $DB_USER -d $DB_NAME -c \""
echo "    UPDATE \"user\" SET \"trustedOrigins\" = ARRAY['https://auth.thivillon.org']"
echo "    WHERE id = '<OWNER_USER_ID>';"
echo "  \""
echo ""
echo "Or simply add via Dokploy UI → Settings → SSO → Manage origins → Add trusted origin"
echo ""
echo "⚠️  Try adding JUST the base origin (no path):"
echo "    https://auth.thivillon.org"
echo ""
echo "Better-auth checks if the discovery endpoint URL STARTS WITH a trusted origin."
echo "If you add 'https://auth.thivillon.org/application/o/dokploy' it should match the"
echo "discovery endpoint 'https://auth.thivillon.org/application/o/dokploy/.well-known/...'"
echo ""
echo "But if better-auth compares against the ORIGIN only (scheme+host, no path), then"
echo "you need to add 'https://auth.thivillon.org' instead."
echo ""
echo "After changing trusted origins, RESTART the Dokploy server container"
echo "so better-auth picks up the new trusted origins."