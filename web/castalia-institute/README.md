# Castalia institute landing (`castalia.institute`)

Static **Log in** page that starts Matrix SSO and returns users to Element with a `loginToken`.

- **Button target:**  
  `https://matrix.castalia.institute/_matrix/client/v3/login/sso/redirect?redirectUrl=https%3A%2F%2Felement.castalia.institute%2F`

**DNS:** Point **`castalia.institute`** (apex) **A** record at the same host that runs Caddy for Matrix/Element (or deploy this folder elsewhere and update URLs).

**Caddy:** See `scripts/gcp-vm-install.sh` / server docs for serving this directory at `castalia.institute`.

**Synapse:** `sso.client_whitelist` should include `https://element.castalia.institute/` (trailing slash). Deploy script adds it.

**Framing + CORS:** Element loads `welcome_url` via **`fetch()`** (`EmbeddedPage`), not only an iframe. Caddy must send **`Access-Control-Allow-Origin: https://element.castalia.institute`** (and OPTIONS for preflight) in addition to **`Content-Security-Policy: frame-ancestors …`**. See `configs/caddy-login.castalia.institute.caddy` and `scripts/deploy-castalia-landing.sh`.

**Element config 404:** Element requests `config.<hostname>.json` (e.g. `config.element.castalia.institute.json`). Mount the same `element-config.json` at that path in Docker (see `docker-compose.yml`).
