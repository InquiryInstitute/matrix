# Castalia: Element + Matrix + Supabase (OIDC)

Element does **not** talk to Supabase directly. The supported pattern is:

1. **Element Web** (e.g. `https://element.castalia.institute`) loads its config and defaults to homeserver **`https://matrix.castalia.institute`** (same host as **`server_name`** and **`public_baseurl`**).
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

   - `https://matrix.castalia.institute/_synapse/client/oidc/callback` (must match live **`public_baseurl`**)

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

### Supabase CLI (hosted Auth `config.toml`)

Use the CLI to **link** the repo and **push** `[auth]` settings (including **`additional_redirect_urls`** for Matrix callbacks):

```bash
# once: brew install supabase/tap/supabase && supabase login
export SUPABASE_PROJECT_REF=pilmscrodlitdrygabvo   # or set in .env

./scripts/supabase-cli-matrix.sh doctor    # curl OIDC discovery + reminders
./scripts/supabase-cli-matrix.sh push-config
```

Same as **`./scripts/supabase-config-push.sh`** (loads `.env`). Pushing updates **general** Auth redirect allow-list in **`supabase/config.toml`**; the **OAuth App** redirect URIs in the Dashboard (§1a) are still required for the code/PKCE flow.

**Hosted Auth error logs** (e.g. **500** on `/oauth/token`) are viewed in **Dashboard → Logs**, not via the CLI today.

## 2. Synapse (`homeserver.yaml`)

- **`server_name`** and **`public_baseurl`** must use the **same hostname** (e.g. `matrix.castalia.institute`). Synapse OIDC macaroons use `server_name` as location; **`public_baseurl`** drives the OAuth **`redirect_uri`**. If they diverge, **`/_synapse/client/oidc/callback`** can return **400**.
- Renaming an existing homeserver domain requires **PostgreSQL updates** to MXIDs plus config changes. On a **nearly empty** server we used **`scripts/migrate-synapse-domain-minimal.sql`** (stop Synapse, run SQL, edit **`homeserver.yaml`**, start Synapse). Large servers need a full migration plan.

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
- **Wrong `redirect_uri`**: Must appear on the **OAuth App** in **Dashboard → OAuth Apps** (not only in `config.toml` **`additional_redirect_urls`**). Match **exactly** (scheme, host, path, trailing slash). Third Room uses `https://thirdroom.castalia.institute/` — see **§6b**.
- **Response body**: Open DevTools → Network → failed request → JSON often includes `error` / `error_description`.

### Troubleshooting: 400 on `…/_synapse/client/oidc/callback?code=…`

**First, read Synapse logs** (`docker compose logs synapse` on the Matrix host) for the exact line after `Received OIDC callback`.

1. **`POST https://<project>.supabase.co/auth/v1/oauth/token: 500`** (often shows as **500** or **400** on `/_synapse/client/oidc/callback` in the browser)  
   Supabase returned **500** while exchanging the code for tokens. Synapse then shows an error page on the callback URL instead of redirecting to Element. This is **not** fixed by Element `sso_redirect_options` — the failure is on **Supabase** (token endpoint).

   **On the Matrix VM:**  
   `sudo docker compose logs synapse --tail 100 | grep -E 'oauth/token|oidc|callback'`  
   You should see `Received response to POST …/oauth/token: 500` and `Could not exchange OAuth2 code`.

   **In Supabase:** open **Dashboard → Logs** (filter **Auth** / **API**, same minute as login) and read the stack trace for **`/auth/v1/oauth/token`**. Typical fixes:
   - **Authentication → OAuth Apps**: **Public** client, redirect URI **exactly** `https://matrix.castalia.institute/_synapse/client/oidc/callback`, **Client ID** matches Synapse `oidc_providers.client_id`.
   - If **OAuth Server** / consent flows are enabled, ensure consent URL and **[auth.oauth_server]** settings match [Supabase OAuth server docs](https://supabase.com/docs/guides/auth/oauth-server); misconfiguration often surfaces as **500** on token exchange.
   - **Project pause**, Auth version regressions, or IdP bugs — use Supabase status / support if logs show an internal error with no clear config fix.

2. **No 500 from Supabase** — then usual causes are **`public_baseurl` host ≠ `server_name` host**, or **`server_name` in `homeserver.yaml` ≠ MXID domain in Postgres**. Align **`server_name`**, **`public_baseurl`**, DB user IDs, and Supabase OAuth redirect URIs; then `docker compose restart synapse`. See **`scripts/patch-synapse-public-baseurl.sh`** and **`scripts/migrate-synapse-domain-minimal.sql`**.

### “500 on Matrix” — which service is failing?

The browser often shows **`https://matrix…/_synapse/client/oidc/callback`** with **500** even when the root cause is **not** Synapse: Synapse proxies the OAuth code exchange and surfaces failures as an error page on that URL.

**Use DevTools → Network (Preserve log)** and find the failing request:

| Failed request | Meaning | What to fix |
|----------------|---------|-------------|
| **`POST …supabase.co/auth/v1/oauth/token` → 500** | **Supabase GoTrue** failed during code→token exchange | **Dashboard → Logs → Auth** (same timestamp). Check **`jwt_issuer`**, **OAuth App** redirect URI + **client_id** = Synapse, **[auth.oauth_server]** / consent if enabled, **Auth hooks** (custom token / before-user hooks) throwing. |
| **`GET …matrix…/oidc/callback` → 500** and **no** failed `oauth/token` row | **Synapse** crashed or errored after receiving tokens | **Synapse logs** on the VM: Python **traceback**, **MappingException**, DB errors (often **user_mapping_provider** / missing **email** in userinfo). |
| **`POST …/oauth/token` → 400** | Bad `redirect_uri`, PKCE, `client_id`, or expired code | Synapse logs usually say **invalid_grant** / **redirect_uri**; align OAuth App + **`public_baseurl`**. |

Repo helper (no secrets): **`./scripts/diagnose-matrix-sso.sh`** — compares **`jwt_issuer`** to live discovery and smoke-tests the token URL.

## 3. Element Web (Docker / static host)

- Deploy **`configs/element-config.castalia.example.json`** as **`config.json`** for the Element container (path depends on image; this repo’s compose mounts `./element-config.json`).
- **`server_name`** in that file must match Synapse’s **`server_name`**.
- **`sso_redirect_options`:** With **`embedded_pages.welcome_url`** (Castalia landing in Element), set **`on_welcome_page`** and **`on_login_page`** to **`true`**. If they are **`false`**, users can get stuck on **“Completing sign-in…”** after OIDC because Element does not run the SSO return / `loginToken` handoff in the welcome context ([Element config example](https://github.com/element-hq/element-web/blob/develop/docs/config.md)). Redeploy Element after changing `config.json`.

## 4. Caddy / TLS

- **`matrix.castalia.institute`** → Synapse (`reverse_proxy` to Synapse HTTP port).
- **`element.castalia.institute`** → Element static UI (`reverse_proxy` to Element :8080).

## 5. Optional: password + OIDC

Keeping **local password** login alongside OIDC requires leaving **`password_config`** enabled in Synapse and **not** relying only on `enable_registration: false` without reviewing policy. The configure script only adds **OIDC**; tighten registration in Synapse explicitly if needed.

## 6. Third Room (Hydrogen) — native Supabase OIDC

Third Room uses **native OIDC** (not Synapse `m.login.sso` / web redirect). It reads **`org.matrix.msc2965.authentication`** from **`/.well-known/matrix/client`** on the homeserver base URL (e.g. `https://matrix.castalia.institute/.well-known/matrix/client`) and expects an **`issuer`** that matches Supabase’s OIDC discovery (`jwt_issuer` in **`supabase/config.toml`**).

### 6a — Synapse: advertise the issuer

Merge **`configs/synapse-extra-well-known-msc2965.castalia.yaml`** into **`homeserver.yaml`** on the Matrix host, then restart Synapse. Verify:

```bash
curl -sS https://matrix.castalia.institute/.well-known/matrix/client | jq .
```

You should see **`org.matrix.msc2965.authentication.issuer`** alongside **`m.homeserver`**.

### 6b — Supabase OAuth App: Third Room redirect URIs (required for `/oauth/authorize`)

**Pushing `additional_redirect_urls` in `supabase/config.toml` is not enough** for Third Room. The authorize endpoint validates `redirect_uri` against **Authentication → OAuth Apps → your public client → Redirect URIs** (see §1a). If Third Room’s origin is missing there, **`GET …/auth/v1/oauth/authorize` returns HTTP 400** (`validation_failed` / `invalid redirect_uri`).

1. Open **Supabase Dashboard** → your project → **Authentication** → **OAuth Apps** (under *Manage*).
2. Select the **public** client whose **Client ID** equals **`VITE_SUPABASE_OIDC_CLIENT_ID`** / Synapse **`oidc_providers.client_id`** (UUID, not the anon JWT).
3. Under **Redirect URIs**, add **every** URL Third Room will send — **exact** string match (scheme, host, path, trailing slash):

   - `https://thirdroom.castalia.institute/`
   - `https://inquiryinstitute.github.io/thirdroom/` (GitHub Pages default URL, if used)
   - `http://localhost:3000/`
   - `http://127.0.0.1:3000/`

4. Keep Synapse’s callback on the **same** client if you reuse one app:  
   `https://matrix.castalia.institute/_synapse/client/oidc/callback`

Third Room builds `redirect_uri` as **`${window.location.origin}/`** (always a **trailing slash**). Do not register only `https://thirdroom.castalia.institute` without `/` unless you change the app.

### 6c — Third Room client env

In the Third Room fork (**InquiryInstitute/thirdroom**, **`castalia`** branch), set:

- **`VITE_SUPABASE_OIDC_CLIENT_ID`** — OAuth App client UUID (same as Matrix/Synapse OIDC unless you use a separate app).
- Optional **`VITE_SUPABASE_OIDC_ISSUER`** — only if it must differ from **`jwt_issuer`** in **`supabase/config.toml`**.

Copy **`.env.example`** to **`.env.local`** for `yarn dev`. Restart Vite after changing env vars.
