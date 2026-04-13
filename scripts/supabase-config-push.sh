#!/usr/bin/env bash
# Push supabase/config.toml to your hosted Supabase project (Auth redirect URLs, etc.).
#
# Prereqs:
#   brew install supabase/tap/supabase   # https://supabase.com/docs/guides/cli
#   supabase login                       # one-time browser auth
#
# Env (e.g. in .env — see load-dotenv.sh):
#   SUPABASE_PROJECT_REF  — project ref from the Supabase dashboard URL
#
# Usage:
#   ./scripts/supabase-config-push.sh
#   SUPABASE_PROJECT_REF=abcd ./scripts/supabase-config-push.sh
#
# This updates remote settings from ./supabase/config.toml, including [auth].additional_redirect_urls
# for Matrix OIDC (Synapse callback URLs). Review the file before pushing.
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/load-dotenv.sh"

ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${ROOT}"

if ! command -v supabase >/dev/null 2>&1; then
  echo "Install Supabase CLI: https://supabase.com/docs/guides/cli/getting-started" >&2
  exit 1
fi

if [[ ! -f supabase/config.toml ]]; then
  echo "Missing supabase/config.toml — run: supabase init" >&2
  exit 1
fi

REF="${SUPABASE_PROJECT_REF:-}"
if [[ -z "${REF}" ]]; then
  echo "Set SUPABASE_PROJECT_REF in .env (or export it)." >&2
  exit 1
fi

echo "Linking project ${REF} (idempotent if already linked)..."
supabase link --project-ref "${REF}" --yes

echo "Pushing config to Supabase (auth URLs, etc.)..."
supabase config push --project-ref "${REF}" --yes

echo "OK. Matrix OIDC redirect URLs should match supabase/config.toml [auth].additional_redirect_urls"
