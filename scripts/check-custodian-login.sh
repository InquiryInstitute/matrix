#!/usr/bin/env bash
# Test custodian login against Matrix. Password: CUSTODIAN_PASSWORD from .env if set, else matrix-bot-credentials.json (not printed).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/load-dotenv.sh"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT"

CRED="${MATRIX_BOT_CREDENTIALS:-matrix-bot-credentials.json}"
MATRIX_SERVER="${MATRIX_SERVER_URL:-https://matrix.castalia.institute}"
MATRIX_SERVER="${MATRIX_SERVER%/}"

if [[ ! -f "$CRED" ]]; then
  echo "Missing $CRED"
  exit 1
fi

USER=$(jq -r '.[] | select(.username | test("custodian"; "i")) | .username' "$CRED" | head -1)
if [[ -z "$USER" || "$USER" == "null" ]]; then
  echo "No custodian entry in $CRED"
  exit 1
fi

PW_JSON=$(jq -r '.[] | select(.username | test("custodian"; "i")) | .password' "$CRED" | head -1)
if [[ -n "${CUSTODIAN_PASSWORD:-}" ]]; then
  PASS="$CUSTODIAN_PASSWORD"
else
  PASS="$PW_JSON"
fi

BODY=$(jq -n \
  --arg u "$USER" \
  --arg p "$PASS" \
  '{type: "m.login.password", identifier: {type: "m.id.user", user: $u}, password: $p}')

RESP=$(curl -sS -m 30 -X POST "${MATRIX_SERVER}/_matrix/client/v3/login" \
  -H "Content-Type: application/json" \
  -d "$BODY")

echo "$RESP" | jq '{errcode, error, user_id, retry_after_ms}'

if echo "$RESP" | jq -e '.user_id != null' >/dev/null 2>&1; then
  echo "OK: custodian password matches server."
  exit 0
fi

echo "Login failed (wrong password, rate limit, or server issue). Reset: scripts/reset-custodian-password.sh" >&2
exit 1
