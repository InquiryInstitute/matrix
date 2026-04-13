# Castalia: Element + Matrix + Supabase (OIDC)

Element does **not** talk to Supabase directly. The supported pattern is:

1. **Element Web** (e.g. `https://element.castalia.institute`) loads its config and defaults to homeserver **`https://matrix.castalia.institute`**.
2. **Synapse** on that URL is configured with **`oidc_providers`** pointing at **Supabase Auth** (OpenID Connect).
3. The user clicks **Sign in with …** (SSO) in Element; Synapse redirects to Supabase, then back to Synapse’s OIDC callback; Synapse issues the Matrix session.

You still need **`https://castalia.institute/.well-known/matrix/client`** (or the user enters the homeserver URL manually) so clients discover the right API base.

## 1. Supabase (OAuth 2.1 IdP + redirects)

Supabase can act as an **OAuth 2.1 / OIDC identity provider** for Synapse. That flow uses **`/auth/v1/oauth/authorize`**. It is **not** the same as “Redirect URLs” for magic links or social sign-in.

### 1a — Register Matrix as an OAuth client (required for current hosted projects)

In the Supabase Dashboard:

1. **Authentication → OAuth Apps** (under Manage) → **Add a new client**.
2. **Client type**: **Public** (Synapse uses PKCE; no client secret on the homeserver).
3. **Redirect URIs**: add the Synapse callback **exactly** (no trailing slash unless Synapse sends one):

   - `https://matrix.castalia.institute/_synapse/client/oidc/callback`

   Each homeserver **public_baseurl** you use needs its callback registered on **this OAuth client**.

4. Copy the **Client ID** (a UUID). Put it in **`SUPABASE_OIDC_CLIENT_ID`** / Synapse **`client_id`** — **not** the anon JWT.

If **`client_id`** is still the anon key (starts with `eyJ…`), **`/oauth/authorize` often returns HTTP 400** (`invalid_client` / validation), because the IdP expects the registered OAuth App client id.

See also: [OAuth 2.1 Server](https://supabase.com/docs/guides/auth/oauth-server) (register clients, redirect URI rules).

### 1b — Enable OAuth server + consent UI (if you turned it on)

If **Authentication → OAuth Server** is enabled, you must also configure **`authorization_url_path`** and host a **consent** UI on **Site URL + path** (e.g. `https://castalia.institute/oauth/consent`). Repo defaults keep **`[auth.oauth_server] enabled = false`** in `supabase/config.toml` until you intentionally enable this.

### Option A — Supabase CLI (general Auth URLs)

This repo includes **`supabase/config.toml`**. The **`[auth]`** section sets **`site_url`** and **`additional_redirect_urls`** (helpful for other flows; **distinct** from OAuth App redirect URIs in §1a).

1. Install the CLI: [Supabase CLI](https://supabase.com/docs/guides/cli/getting-started).
2. Log in once: `supabase login`
3. Set **`SUPABASE_PROJECT_REF`** in `.env` (see `.env.example`).
4. From the repo root:

   ```bash
   ./scripts/supabase-config-push.sh
   ```

### Option B — Dashboard (magic-link / social redirects)

**Authentication → URL configuration** — keep **Site URL** and any app redirects you need; this does **not** replace §1a for Synapse OIDC.

## 2. Synapse (`homeserver.yaml`)

- **`public_baseurl`**: `https://matrix.castalia.institute`
- **`server_name`**: must match the deployment (often `matrix.castalia.institute` if that is your Matrix hostname).

Run from the machine that has `matrix-data/homeserver.yaml` (or set `MATRIX_DIR`):

```bash
export SUPABASE_PROJECT_REF="your-project-ref"
export SUPABASE_OIDC_CLIENT_ID="uuid-from-oauth-apps"   # not the anon JWT
export SYNAPSE_PUBLIC_BASEURL="https://matrix.castalia.institute"
export OIDC_IDP_NAME="Castalia"
export OIDC_IDP_BRAND="castalia.institute"
./scripts/configure-matrix-oidc.sh
docker compose restart synapse
```

See **`scripts/configure-matrix-oidc.sh`** for the YAML it appends (`client_auth_method: none`, `pkce_method: always` for public clients). Adjust **`user_mapping_provider`** templates if your Supabase `userinfo` claims differ (e.g. email vs `preferred_username`).

### Troubleshooting: 400 on `…/auth/v1/oauth/authorize`

- **Wrong `client_id`**: Use the **OAuth App** Client ID from §1a, not the anon key.
- **Wrong `redirect_uri`**: Must match an OAuth App redirect URI **exactly** (scheme, host, path).
- **Response body**: Open DevTools → Network → failed request → JSON often includes `error` / `error_description`.

## 3. Element Web (Docker / static host)

- Deploy **`configs/element-config.castalia.example.json`** as **`config.json`** for the Element container (path depends on image; this repo’s compose mounts `./element-config.json`).
- **`server_name`** in that file must match Synapse’s **`server_name`**.

## 4. Caddy / TLS

- **`matrix.castalia.institute`** → Synapse (`reverse_proxy` to Synapse HTTP port).
- **`element.castalia.institute`** → Element static UI (`reverse_proxy` to Element :8080).

## 5. Optional: password + OIDC

Keeping **local password** login alongside OIDC requires leaving **`password_config`** enabled in Synapse and **not** relying only on `enable_registration: false` without reviewing policy. The configure script only adds **OIDC**; tighten registration in Synapse explicitly if needed.
