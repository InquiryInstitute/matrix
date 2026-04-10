#!/usr/bin/env bash
# Point matrix.inquiry.institute at GCP: remove Fly CNAME, add A record to reserved Matrix IP.
# Prereq: AWS CLI; profile with Route 53 change rights on inquiry.institute zone.
set -euo pipefail

PROFILE="${AWS_PROFILE:-custodian}"
# Hosted zone for inquiry.institute (not castalia)
HOSTED_ZONE_ID="${ROUTE53_HOSTED_ZONE_ID:-Z0160339H8UNP018AYAN}"
NAME="matrix.inquiry.institute."
IP="${1:?usage: $0 <gcp_matrix_static_ipv4>}"

if ! [[ "$IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "error: need IPv4 (e.g. 34.148.23.74)" >&2
  exit 1
fi

TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

cat >"$TMP" <<JSON
{
  "Comment": "Matrix on GCP: drop Fly CNAME, add A",
  "Changes": [
    {
      "Action": "DELETE",
      "ResourceRecordSet": {
        "Name": "${NAME}",
        "Type": "CNAME",
        "TTL": 300,
        "ResourceRecords": [{ "Value": "inquiry-matrix.fly.dev" }]
      }
    },
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

echo "OK: ${NAME} → A ${IP} (removed Fly CNAME). Wait for DNS propagation before scaling down Fly."
