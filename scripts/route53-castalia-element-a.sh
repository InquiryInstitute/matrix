#!/usr/bin/env bash
# Point element.castalia.institute at the same GCP VM that serves Matrix + Element Web (Caddy → :8080).
# Prereq: AWS CLI; profile with Route 53 rights on castalia.institute.
set -euo pipefail

PROFILE="${AWS_PROFILE:-custodian}"
HOSTED_ZONE_ID="${CASTALIA_ROUTE53_ZONE_ID:-Z088198297W8TWOSZTA9}"
NAME="element.castalia.institute."
IP="${1:?usage: $0 <gcp_matrix_static_ipv4 e.g. 34.172.124.225>}"

if ! [[ "$IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "error: need IPv4" >&2
  exit 1
fi

TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

cat >"$TMP" <<JSON
{
  "Comment": "element.castalia.institute → GCP VM (Element Web behind Caddy)",
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

echo "OK: ${NAME} → A ${IP}. On the VM: Caddy site → reverse_proxy 127.0.0.1:8080 and docker compose up -d element-web"
