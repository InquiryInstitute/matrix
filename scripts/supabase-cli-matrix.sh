#!/usr/bin/env bash
# Supabase CLI workflow for Castalia + Matrix OIDC (hosted project).
#
# Prereqs:  brew install supabase/tap/supabase && supabase login
#
# Uses SUPABASE_PROJECT_REF from .env (default: supabase/.temp/project-ref if present).
#
# Commands:
#   ./scripts/supabase-cli-matrix.sh link          # link repo to hosted project
#   ./scripts/supabase-cli-matrix.sh push-config   # push supabase/config.toml ([auth] URLs, etc.)
#   ./scripts/supabase-cli-matrix.sh doctor        # OIDC discovery + suggest next steps
#   ./scripts/supabase-cli-matrix.sh auth-logs     # hosted Auth logs (SUPABASE_ACCESS_TOKEN in Inquiry .env)
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/load-dotenv.sh"

# If matrix/.env has no SUPABASE_PROJECT_REF, try sibling Inquiry.Institute (.env.local).
if [[ -z "${SUPABASE_PROJECT_REF:-}" && -f "${SCRIPT_DIR}/load-inquiry-institute-env.sh" ]]; then
  # shellcheck disable=SC1091
  source "${SCRIPT_DIR}/load-inquiry-institute-env.sh" || true
fi

ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${ROOT}"

if ! command -v supabase >/dev/null 2>&1; then
  echo "Install: brew install supabase/tap/supabase" >&2
  exit 1
fi

REF="${SUPABASE_PROJECT_REF:-}"
if [[ -z "${REF}" && -f supabase/.temp/project-ref ]]; then
  REF="$(tr -d '[:space:]' < supabase/.temp/project-ref)"
fi
if [[ -z "${REF}" ]]; then
  echo "Set SUPABASE_PROJECT_REF in .env" >&2
  exit 1
fi

cmd="${1:-help}"

case "${cmd}" in
  link)
    supabase link --project-ref "${REF}" --yes
    echo "Linked: ${REF}"
    ;;
  push-config)
    supabase link --project-ref "${REF}" --yes
    # config push prompts to confirm [auth] diffs; feed affirmative replies
    set +o pipefail
    yes | supabase config push --project-ref "${REF}"
    set -o pipefail
    echo "OK: remote Auth settings updated from supabase/config.toml (additional_redirect_urls, site_url, …)"
    ;;
  auth-logs)
    exec "${ROOT}/scripts/supabase-review-logs.sh"
    ;;
  doctor)
    echo "Project ref: ${REF}"
    echo ""
    echo "OIDC discovery (should return JSON):"
    curl -fsS "https://${REF}.supabase.co/auth/v1/.well-known/openid-configuration" | head -c 400 || echo "(curl failed)"
    echo ""
    echo ""
    echo "JWKS:"
    curl -fsS "https://${REF}.supabase.co/auth/v1/.well-known/jwks.json" | head -c 200 || echo "(curl failed)"
    echo ""
    echo ""
    echo "Synapse callback must be registered in TWO places:"
    echo "  1) Dashboard → Authentication → OAuth Apps (public client) — redirect URI for code/PKCE"
    echo "  2) supabase/config.toml [auth].additional_redirect_urls — run: $0 push-config"
    echo ""
    echo "If login still fails with 500 on /oauth/token, check Dashboard → Logs (Auth) — CLI cannot stream hosted Auth logs yet."
    echo "With a PAT in Inquiry .env: $0 auth-logs  (see scripts/supabase-review-logs.sh)"
    ;;
  help|*)
    echo "Usage: $0 link | push-config | doctor | auth-logs"
    exit 0
    ;;
esac
