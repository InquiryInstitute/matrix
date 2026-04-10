#!/usr/bin/env bash
# Scale every Fly.io app in your account to 0 machines (stops compute billing for those apps).
# Requires: flyctl authenticated (`fly auth login`).
# Usage: ./scripts/fly-scale-all-zero.sh
#
# Notes:
# - Postgres/Fly-managed DB apps may need different handling; this runs `fly scale count 0` per app.
# - Apps with multiple process groups may need manual `fly scale count 0 --process <name>`.
set -euo pipefail

if ! command -v fly &>/dev/null && ! command -v flyctl &>/dev/null; then
  echo "Install flyctl: https://fly.io/docs/hands-on/install-flyctl/" >&2
  exit 1
fi
FLY="${FLY:-fly}"

if ! "$FLY" auth whoami &>/dev/null; then
  echo "Not logged in. Run: fly auth login" >&2
  exit 1
fi

echo "Listing apps..."
# Prefer JSON names: `fly apps list -q` can pad with tabs and break `-a` URLs.
APPS=()
while IFS= read -r line; do
  [[ -n "$line" ]] && APPS+=("$line")
done < <("$FLY" apps list -j 2>/dev/null | jq -r '.[].Name' 2>/dev/null || true)
if [[ ${#APPS[@]} -eq 0 ]]; then
  while IFS= read -r line; do
    [[ -n "$line" ]] && APPS+=("$line")
  done < <("$FLY" apps list -q 2>/dev/null | tr -d '\t' | awk '{print $1}' || true)
fi

if [[ ${#APPS[@]} -eq 0 ]]; then
  echo "No apps found."
  exit 0
fi

echo "Scaling ${#APPS[@]} app(s) to 0..."
for app in "${APPS[@]}"; do
  echo "--- $app ---"
  if "$FLY" scale count 0 -a "$app" --yes 2>&1; then
    echo "OK: $app"
  else
    echo "WARN: scale failed for $app (try: fly machine list -a $app && fly machine stop <id> -a $app)" >&2
  fi
done

echo "Done. Check: fly apps list"
