#!/usr/bin/env bash
# Point login.castalia.institute at the Matrix VM (Caddy serves SSO landing page).
set -euo pipefail

PROFILE="${AWS_PROFILE:-custodian}"
HOSTED_ZONE_ID="${CASTALIA_ROUTE53_ZONE_ID:-Z088198297W8TWOSZTA9}"
NAME="login.castalia.institute."
IP="${1:?usage: $0 <gcp_matrix_static_ipv4 e.g. 34.172.124.225>}"

if ! [[ "$IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "error: need IPv4" >&2
  exit 1
fi

TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

cat >"$TMP" <<JSON
{
  "Comment": "login.castalia.institute → Castalia Log in landing (Caddy)",
  "Changes": [
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "${NAME}",
        "Type": "A",
        "TTL": 300,
        "ResourceRecords": [{ "Value": "${IP}" }]
      }
    }
  ]
}
JSON

aws route53 change-resource-record-sets \
  --profile "$PROFILE" \
  --hosted-zone-id "$HOSTED_ZONE_ID" \
  --change-batch "file://${TMP}"

echo "OK: ${NAME} → A ${IP}"
