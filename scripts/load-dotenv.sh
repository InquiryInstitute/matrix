#!/usr/bin/env bash
# Source repository-root .env so ADMIN_ACCESS_TOKEN and other vars are available.
# Usage (from another script):  source "$(cd "$(dirname "$0")" && pwd)/load-dotenv.sh"
_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ -f "${_root}/.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "${_root}/.env"
  set +a
fi
