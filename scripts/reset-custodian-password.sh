#!/usr/bin/env bash
# Reset custodian Matrix password via Synapse Admin API and update matrix-bot-credentials.json.
#
# Requires a server admin access token (Element: Settings → Help & About → Access token).
#
# Usage:
#   echo 'ADMIN_ACCESS_TOKEN=syt_...' >> .env   # or export for one session
#   ./scripts/reset-custodian-password.sh              # random password, updates JSON
#   NEW_PASSWORD='your-secure-pass' ./scripts/reset-custodian-password.sh
#
# Optional:
#   MATRIX_SERVER_URL   (default https://matrix.castalia.institute)
#   CUSTODIAN_MXID      (default @aCustodian.custodian:matrix.castalia.institute)
#   MATRIX_BOT_CREDENTIALS  path to credentials file (default matrix-bot-credentials.json)
#
# Admin token: set ADMIN_ACCESS_TOKEN in .env (repo root) or export in the shell.
# On success, also sets CUSTODIAN_PASSWORD in .env (creates .env if missing).
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/load-dotenv.sh"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT"

MATRIX_SERVER="${MATRIX_SERVER_URL:-https://matrix.castalia.institute}"
MATRIX_SERVER="${MATRIX_SERVER%/}"
CRED="${MATRIX_BOT_CREDENTIALS:-matrix-bot-credentials.json}"
MXID="${CUSTODIAN_MXID:-@aCustodian.custodian:matrix.castalia.institute}"

if [[ -z "${ADMIN_ACCESS_TOKEN:-}" ]]; then
  echo "Set ADMIN_ACCESS_TOKEN in .env (repo root) or export it." >&2
  echo "Element Web → Settings → Help & About → Access token (server admin user)." >&2
  exit 1
fi

NEW_PASSWORD="${NEW_PASSWORD:-}"
if [[ -z "$NEW_PASSWORD" ]]; then
  NEW_PASSWORD="$(openssl rand -base64 24 | tr -d '\n' | tr '/+' 'Aa')"
  echo "Generated new password (will be written to $CRED if present)."
fi

ENC_MXID=$(python3 -c "import urllib.parse, sys; print(urllib.parse.quote(sys.argv[1], safe=''))" "$MXID")

PAYLOAD=$(jq -n --arg p "$NEW_PASSWORD" '{password: $p, logout_devices: true}')

HTTP=$(curl -sS -w '\n%{http_code}' -o /tmp/reset-custodian-body.json -X PUT \
  "${MATRIX_SERVER}/_synapse/admin/v2/users/${ENC_MXID}" \
  -H "Authorization: Bearer ${ADMIN_ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD")

CODE=$(echo "$HTTP" | tail -n1)
BODY=$(cat /tmp/reset-custodian-body.json)
rm -f /tmp/reset-custodian-body.json

if [[ "$CODE" != "200" && "$CODE" != "201" ]]; then
  echo "HTTP $CODE" >&2
  echo "$BODY" | jq . 2>/dev/null || echo "$BODY" >&2
  exit 1
fi

echo "OK: password updated on server for $MXID (devices logged out)."

if [[ -f "$CRED" ]]; then
  TMP=$(mktemp)
  jq --arg p "$NEW_PASSWORD" --arg m "$MXID" \
    'map(if (.matrix_id == $m) or (.username | test("custodian"; "i")) then .password = $p else . end)' \
    "$CRED" > "$TMP"
  mv "$TMP" "$CRED"
  echo "Updated password field for custodian in $CRED"
else
  echo "No $CRED — set password in your secrets store manually."
fi

export NEW_PASSWORD_FOR_ENV="$NEW_PASSWORD"
python3 <<'PY'
import os
import shlex
from pathlib import Path

key = "CUSTODIAN_PASSWORD"
val = os.environ["NEW_PASSWORD_FOR_ENV"]
path = Path(".env")
lines = path.read_text().splitlines() if path.exists() else []
out = []
found = False
for line in lines:
    s = line.strip()
    if not s or s.startswith("#") or "=" not in line:
        out.append(line)
        continue
    k = line.split("=", 1)[0].strip()
    if k == key:
        out.append(f"{key}={shlex.quote(val)}")
        found = True
    else:
        out.append(line)
if not found:
    out.append(f"{key}={shlex.quote(val)}")
path.write_text("\n".join(out) + "\n")
print(f"Updated {key} in .env")
PY
chmod 600 .env 2>/dev/null || true

echo ""
echo "Verify:"
echo "  ./scripts/check-custodian-login.sh"
