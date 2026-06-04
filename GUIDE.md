# Dokploy Enterprise — Activation & SSO

Step-by-step guide to unlock Enterprise features (license) and configure SSO OIDC/SAML on a self-hosted Dokploy instance.

## 1. Clone the repository

```bash
git clone https://github.com/your-org/dokploy-activation.git
cd dokploy-activation
```

## 2. Activate the Enterprise license

```bash
./unlock.sh
```

The script:

- Automatically finds Dokploy's Postgres container
- Lists all users
- Sets `enableEnterpriseFeatures = true`, `isValidEnterpriseLicense = true`, `licenseKey = NULL`
- The re-validation cron (every 3 hours) won't invalidate because `licenseKey` is empty

**Manual SQL alternative:**

```sql
UPDATE "user"
SET "enableEnterpriseFeatures" = true,
    "isValidEnterpriseLicense" = true,
    "licenseKey" = NULL
WHERE email = 'your@email.com';
```

> ⚠️ Do not set `licenseKey`. If a value is present, the cron will re-validate the license against the remote server and disable it.

> ℹ️ This activation is **server-wide**. The `unlock.sh` script sets the flags on the organization owner. All users in the organization benefit from the unlocked Enterprise features.

## 3. Add the trusted SSO origin

In the Dokploy UI: **Settings → SSO → Manage origins → Add trusted origin**

Add only the **root URL** of your identity provider (**without any path**):

```
https://auth.domain.com
```

**Do not include the path** (`/application/o/dokploy`). Better-auth compares the origin (scheme + host), not the full URL.

> Example: if your OIDC issuer is `https://auth.domain.com/application/o/dokploy`, only add `https://auth.domain.com` to trusted origins.

## 4. Restart Dokploy

The Dokploy server reads trusted origins at startup. A restart is required for the change to take effect.

```bash
docker service scale dokploy=0
docker service scale dokploy=1
```

> Run `docker service ls` if you need to confirm the exact service name.

## 5. Add your OIDC / SAML configuration

Go back to **Settings → SSO** and click **Add provider**.

Fill in:

- **Provider ID**: a unique identifier (e.g. `authentik`)
- **Issuer URL**: the OIDC issuer URL (the `issuer` field from `/.well-known/openid-configuration`)
- **Client ID / Client Secret**: provided by your IdP
- **Domains**: allowed email domains

Save. If the "Untrusted" error persists, check that:

1. The restart was actually performed
2. The trusted origin URL is **only** `https://auth.domain.com` (no path)
3. The Dokploy container can reach your auth server (DNS, network, TLS certificate)

## Troubleshooting

### Check trusted origins in the database

```bash
docker exec <postgres-container> psql -U dokploy -d dokploy \
  -c 'SELECT id, email, "trustedOrigins" FROM "user";'
```

### Check connectivity from the Dokploy container

```bash
docker exec <dokploy-container> wget -qO- --timeout=5 --no-check-certificate \
  https://auth.domain.com/application/o/dokploy/.well-known/openid-configuration
```
