#!/usr/bin/env bash
# Append Synapse oidc_providers for Supabase Auth (OpenID Connect).
# Element Web signs in via the homeserver: user chooses SSO → Synapse → Supabase → callback.
#
# Environment (optional; load from repo .env via load-dotenv.sh):
#   SUPABASE_PROJECT_REF   — e.g. xougqdomkoisrxdnagcj (required)
#   SUPABASE_OIDC_CLIENT_ID — OAuth App client ID from Supabase (Authentication → OAuth Apps).
#                             Required when the project uses OAuth 2.1 as IdP (recommended).
#   SUPABASE_ANON_KEY       — Legacy: anon JWT was used as client_id; often INVALID with OAuth 2.1.
#   SYNAPSE_PUBLIC_BASEURL — public Synapse URL, e.g. https://matrix.castalia.institute
#   MATRIX_DIR             — repo root with matrix-data/ (default: parent of scripts/)
#   OIDC_IDP_NAME          — button label, default "Castalia"
#   OIDC_IDP_BRAND         — idp_brand field, default "castalia.institute"
#   OIDC_NON_INTERACTIVE   — if 1, do not prompt (fail if anon key missing)
#
# Supabase (OAuth 2.1): Authentication → OAuth Apps → register a *public* client with redirect URI
#   ${SYNAPSE_PUBLIC_BASEURL}/_synapse/client/oidc/callback
# (exact string; not the same as general "Redirect URLs" for magic links).
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/load-dotenv.sh"

REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
MATRIX_DIR="${MATRIX_DIR:-$REPO_ROOT}"
HOMESERVER_CONFIG="${MATRIX_DIR}/matrix-data/homeserver.yaml"

SUPABASE_PROJECT_REF="${SUPABASE_PROJECT_REF:-}"
SUPABASE_OIDC_CLIENT_ID="${SUPABASE_OIDC_CLIENT_ID:-}"
SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY:-}"
# Do not inherit MATRIX_SERVER_URL here — old values often point at matrix.castalia.institute and break OIDC vs Supabase.
# Use the same host as server_name until Synapse is migrated; split host breaks OIDC callback (400).
SYNAPSE_PUBLIC_BASEURL="${SYNAPSE_PUBLIC_BASEURL:-https://matrix.inquiry.institute}"
SYNAPSE_PUBLIC_BASEURL="${SYNAPSE_PUBLIC_BASEURL%/}"

OIDC_IDP_NAME="${OIDC_IDP_NAME:-Castalia}"
OIDC_IDP_BRAND="${OIDC_IDP_BRAND:-castalia.institute}"

echo "🔷 Configure Synapse OIDC (Supabase Auth)"
echo "   homeserver.yaml: ${HOMESERVER_CONFIG}"
echo "   Public base URL (redirects): ${SYNAPSE_PUBLIC_BASEURL}"
echo ""

if [[ ! -f "${HOMESERVER_CONFIG}" ]]; then
  echo "❌ homeserver.yaml not found: ${HOMESERVER_CONFIG}" >&2
  echo "   Set MATRIX_DIR or generate Synapse config first." >&2
  exit 1
fi

if [[ -z "${SUPABASE_PROJECT_REF}" ]]; then
  read -r -p "Supabase project ref (from project URL): " SUPABASE_PROJECT_REF
fi
if [[ -z "${SUPABASE_PROJECT_REF}" ]]; then
  echo "❌ SUPABASE_PROJECT_REF is required" >&2
  exit 1
fi

SUPABASE_DISCOVERY_URL="https://${SUPABASE_PROJECT_REF}.supabase.co/auth/v1/.well-known/openid-configuration"
# Issuer must match Supabase OIDC discovery document (typically .../auth/v1)
ISSUER="https://${SUPABASE_PROJECT_REF}.supabase.co/auth/v1"

if [[ -z "${SUPABASE_OIDC_CLIENT_ID}" && -z "${SUPABASE_ANON_KEY}" ]]; then
  if [[ "${OIDC_NON_INTERACTIVE:-}" == "1" ]]; then
    echo "❌ Set SUPABASE_OIDC_CLIENT_ID (OAuth Apps client ID) or legacy SUPABASE_ANON_KEY." >&2
    exit 1
  fi
  echo "Prefer SUPABASE_OIDC_CLIENT_ID: Supabase → Authentication → OAuth Apps → your Matrix client → Client ID (UUID)."
  echo "Legacy fallback: anon JWT from Project Settings → API (may return 400 if OAuth 2.1 is enabled)."
  read -r -p "OAuth client ID (or paste anon key for legacy): " SUPABASE_OIDC_CLIENT_ID
fi

OIDC_CLIENT_ID="${SUPABASE_OIDC_CLIENT_ID:-${SUPABASE_ANON_KEY:-}}"
if [[ -z "${OIDC_CLIENT_ID}" ]]; then
  echo "❌ No client id: set SUPABASE_OIDC_CLIENT_ID or SUPABASE_ANON_KEY" >&2
  exit 1
fi

if [[ "${OIDC_CLIENT_ID}" == eyJ* ]]; then
  echo "⚠️  client_id looks like a JWT (legacy anon key). If https://.../auth/v1/oauth/authorize returns 400, register an OAuth App (public) and set SUPABASE_OIDC_CLIENT_ID to that client UUID." >&2
fi

echo ""
echo "🔍 Checking OIDC discovery..."
if curl -fsS -m 15 "${SUPABASE_DISCOVERY_URL}" -o /dev/null; then
  echo "   ✅ ${SUPABASE_DISCOVERY_URL}"
else
  echo "   ⚠️  Could not fetch discovery (offline or wrong project ref). Continuing." >&2
fi

CALLBACK_PATH="/_synapse/client/oidc/callback"
REDIRECT_URI="${SYNAPSE_PUBLIC_BASEURL}${CALLBACK_PATH}"

echo ""
echo "💾 Backup homeserver.yaml..."
cp "${HOMESERVER_CONFIG}" "${HOMESERVER_CONFIG}.backup.$(date +%Y%m%d_%H%M%S)"

if grep -q "^oidc_providers:" "${HOMESERVER_CONFIG}"; then
  echo ""
  echo "⚠️  oidc_providers already present in ${HOMESERVER_CONFIG}"
  if [[ "${OIDC_NON_INTERACTIVE:-}" == "1" ]]; then
    echo "❌ Refusing to duplicate OIDC in non-interactive mode" >&2
    exit 1
  fi
  read -r -p "Remove previous # Supabase OIDC block and replace? (y/N): " REPLACE
  if [[ "${REPLACE}" == "y" || "${REPLACE}" == "Y" ]]; then
    # Remove block between our markers if present; else warn
    if grep -q "# --- Supabase OIDC (matrix repo) ---" "${HOMESERVER_CONFIG}"; then
      sed -i.bak '/# --- Supabase OIDC (matrix repo) ---/,/# --- end Supabase OIDC ---/d' "${HOMESERVER_CONFIG}"
    else
      echo "❌ No marked block to remove. Edit homeserver.yaml manually, then re-run." >&2
      exit 1
    fi
  else
    exit 0
  fi
fi

echo ""
echo "⚙️  Appending oidc_providers..."

{
  cat <<EOF

# --- Supabase OIDC (matrix repo) ---
oidc_providers:
  - idp_id: supabase
    idp_name: "${OIDC_IDP_NAME}"
    idp_brand: "${OIDC_IDP_BRAND}"
    discover: true
    issuer: "${ISSUER}"
    client_id: "${OIDC_CLIENT_ID}"
    client_auth_method: none
    pkce_method: always
    scopes: ["openid", "profile", "email"]
    user_mapping_provider:
      config:
        subject_claim: "sub"
        localpart_template: "{{ user.email.split('@')[0]|lower|replace('.', '_') }}"
        display_name_template: "{{ user.name|default(user.email) }}"
        email_template: "{{ user.email }}"
    allow_existing_users: true
# --- end Supabase OIDC ---
EOF
} >> "${HOMESERVER_CONFIG}"

echo "✅ Appended OIDC provider (issuer: ${ISSUER})"
echo ""
echo "🔗 Register this redirect on an OAuth App (Authentication → OAuth Apps → Public client):"
echo "   ${REDIRECT_URI}"
echo "   General Auth redirect URLs (supabase/config.toml additional_redirect_urls) are separate; both may be needed."
echo "   CLI: ./scripts/supabase-config-push.sh"
echo ""
echo "🚀 Restart Synapse, then open Element → sign in → SSO (${OIDC_IDP_NAME})."
echo "   MATRIX_DIR=${MATRIX_DIR}"
echo "   Example: cd \"${MATRIX_DIR}\" && docker compose restart synapse"
echo ""
echo "📚 Castalia + Element: see CASTALIA_ELEMENT_SUPABASE.md and configs/element-config.castalia.example.json"
echo ""
echo "🛠  If GET ${SYNAPSE_PUBLIC_BASEURL}${CALLBACK_PATH}?code=... returns 400:"
echo "   1) Supabase → Authentication → OAuth Apps (your public client): redirect URI must be EXACTLY:"
echo "      ${REDIRECT_URI}"
echo "   2) Synapse homeserver.yaml: public_baseurl must match that host (https, no trailing slash on path)."
echo "   3) User must start SSO from Element (Sign in with SSO), not by opening the callback URL alone —"
echo "      Synapse needs the OIDC session cookie set at flow start."
echo "   4) Check Synapse logs: docker compose logs synapse --tail=80  (token exchange / redirect_uri errors)."
echo "   5) client_id in oidc_providers must be the OAuth App Client ID (UUID), not the anon JWT."
