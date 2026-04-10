#!/usr/bin/env bash
# Create matrix-synapse VM with reserved regional IP and tag matrix-server.
#
# Region / zone (override any of these):
#   GCP_REGION=us-central1 GCP_ZONE=us-central1-a   # default — aligns with "central"
#   GCP_REGION=us-west1  GCP_ZONE=us-west1-a       # same region as lms-moodle
#   GCP_REGION=us-east1  GCP_ZONE=us-east1-b         # existing matrix-ip 34.148.23.74 is here
#
# Static IP must exist in the SAME region as the VM. Create first:
#   ./scripts/gcp-matrix-static-ip.sh
# Or: gcloud compute addresses create matrix-ip --region=$GCP_REGION
#
# Default MACHINE_TYPE is e2-micro (1 GiB) — fine for idle/light use; tight for Postgres+Redis+Synapse in one compose.
# Bump with MACHINE_TYPE=e2-small or e2-medium if you hit OOM or add load.
#
# If you see ZONE_RESOURCE_POOL_EXHAUSTED, try another zone in the same region (-b, -c) or later.
#
# Quota: needs CPUS headroom for MACHINE_TYPE (e2-micro ≈ 1 CPU toward quota, e2-small = 2).
set -euo pipefail

PROJECT="${GCP_PROJECT:-institute-481516}"
REGION="${GCP_REGION:-us-central1}"
ZONE="${GCP_ZONE:-us-central1-a}"
NAME="${VM_NAME:-matrix-synapse}"
MACHINE="${MACHINE_TYPE:-e2-micro}"
ADDRESS_NAME="${STATIC_IP_NAME:-matrix-ip}"

if gcloud compute instances describe "$NAME" --zone="$ZONE" --project="$PROJECT" &>/dev/null; then
  echo "Instance $NAME already exists in $ZONE."
  exit 1
fi

if ! gcloud compute addresses describe "$ADDRESS_NAME" --region="$REGION" --project="$PROJECT" &>/dev/null; then
  echo "No static IP '$ADDRESS_NAME' in region $REGION." >&2
  echo "Create it (same region as GCP_REGION / zone), then re-run:" >&2
  echo "  GCP_REGION=$REGION ./scripts/gcp-matrix-static-ip.sh" >&2
  echo "Or pick STATIC_IP_NAME if you use a different address resource name." >&2
  exit 1
fi

ADDR_URL="projects/${PROJECT}/regions/${REGION}/addresses/${ADDRESS_NAME}"

gcloud compute instances create "$NAME" \
  --project="$PROJECT" \
  --zone="$ZONE" \
  --machine-type="$MACHINE" \
  --network-interface="network-tier=PREMIUM,subnet=projects/${PROJECT}/regions/${REGION}/subnetworks/default,address=${ADDR_URL}" \
  --tags=matrix-server \
  --image-family=ubuntu-2204-lts \
  --image-project=ubuntu-os-cloud \
  --boot-disk-size=50GB \
  --boot-disk-type=pd-balanced

echo "OK: $NAME created with external IP from $ADDRESS_NAME."
echo "Next: SSH in, install Docker, clone this repo, configure .env and matrix-data, docker compose up -d, TLS on :443."
