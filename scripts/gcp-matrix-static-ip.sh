#!/usr/bin/env bash
# Create (or show) a regional static IP for Matrix. Run once per target region.
# Global addresses cannot be shared across regions — pick the region where the VM will live.
set -euo pipefail

PROJECT="${GCP_PROJECT:-institute-481516}"
REGION="${GCP_REGION:-us-central1}"
# If matrix-ip already exists in another region, use a new name, e.g. STATIC_IP_NAME=matrix-ip-central
NAME="${STATIC_IP_NAME:-matrix-ip}"

if gcloud compute addresses describe "$NAME" --region="$REGION" --project="$PROJECT" &>/dev/null; then
  echo "Address '$NAME' already exists in $REGION:"
  gcloud compute addresses describe "$NAME" --region="$REGION" --project="$PROJECT" \
    --format='value(address)'
  exit 0
fi

gcloud compute addresses create "$NAME" --region="$REGION" --project="$PROJECT"
echo "Created '$NAME' in $REGION:"
gcloud compute addresses describe "$NAME" --region="$REGION" --project="$PROJECT" \
  --format='value(address)'
