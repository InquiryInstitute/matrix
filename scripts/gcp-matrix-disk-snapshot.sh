#!/usr/bin/env bash
# Snapshot boot disk (and optional attached data disk) for matrix-synapse — run before resize/migration.
set -euo pipefail

PROJECT="${GCP_PROJECT:-institute-481516}"
ZONE="${GCP_ZONE:?Set GCP_ZONE}"
NAME="${VM_NAME:-matrix-synapse}"
TS="$(date +%Y%m%d-%H%M%S)"

DISKS_JSON="$(gcloud compute instances describe "$NAME" --zone="$ZONE" --project="$PROJECT" \
  --format=json)"

BOOT_DISK="$(echo "$DISKS_JSON" | jq -r '.disks[] | select(.boot==true) | .source | split("/") | last')"

echo "Creating snapshot of boot disk: $BOOT_DISK"
gcloud compute disks snapshot "$BOOT_DISK" \
  --zone="$ZONE" \
  --project="$PROJECT" \
  --snapshot-names="${BOOT_DISK}-snap-${TS}" \
  --description="matrix backup ${TS}"

DATA_DISK_NAME="${MATRIX_DATA_DISK_NAME:-}"
if [[ -n "$DATA_DISK_NAME" ]]; then
  echo "Creating snapshot of data disk: $DATA_DISK_NAME"
  gcloud compute disks snapshot "$DATA_DISK_NAME" \
    --zone="$ZONE" \
    --project="$PROJECT" \
    --snapshot-names="${DATA_DISK_NAME}-snap-${TS}" \
    --description="matrix data backup ${TS}"
fi

echo "OK. List: gcloud compute snapshots list --project=$PROJECT --filter='name~snap-${TS}'"
