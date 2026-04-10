#!/usr/bin/env bash
# Point matrix.castalia.institute at the same host as Matrix on GCP (A record in castalia.institute zone).
# Prereq: AWS CLI; profile with Route 53 rights on castalia.institute.
set -euo pipefail

PROFILE="${AWS_PROFILE:-custodian}"
# Hosted zone for castalia.institute (same zone as cal.castalia.institute)
HOSTED_ZONE_ID="${CASTALIA_ROUTE53_ZONE_ID:-Z088198297W8TWOSZTA9}"
NAME="matrix.castalia.institute."
IP="${1:?usage: $0 <gcp_matrix_static_ipv4 e.g. 34.172.124.225>}"

if ! [[ "$IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "error: need IPv4" >&2
  exit 1
fi

TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

cat >"$TMP" <<JSON
{
  "Comment": "matrix.castalia.institute → GCP Matrix VM (same as matrix.inquiry / cal)",
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

echo "OK: ${NAME} → A ${IP}. Wait for DNS TTL, then curl https://matrix.castalia.institute/_matrix/client/versions"
