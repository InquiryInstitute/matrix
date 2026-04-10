#!/usr/bin/env bash
# Create a blank pd-balanced disk and attach it to matrix-synapse (same zone).
# After this, SSH to the VM and run: ./scripts/matrix-vm-setup-opt-data-dir.sh
set -euo pipefail

PROJECT="${GCP_PROJECT:-institute-481516}"
ZONE="${GCP_ZONE:?Set GCP_ZONE}"
VM="${VM_NAME:-matrix-synapse}"
SIZE_GB="${DATA_DISK_GB:-200}"
DISK_NAME="${DATA_DISK_NAME:-matrix-data}"

if gcloud compute disks describe "$DISK_NAME" --zone="$ZONE" --project="$PROJECT" &>/dev/null; then
  echo "Disk $DISK_NAME already exists in $ZONE."
else
  echo "Creating disk $DISK_NAME (${SIZE_GB}GB)..."
  gcloud compute disks create "$DISK_NAME" \
    --project="$PROJECT" \
    --zone="$ZONE" \
    --size="${SIZE_GB}" \
    --type=pd-balanced
fi

if gcloud compute instances describe "$VM" --zone="$ZONE" --project="$PROJECT" \
  --format='get(disks[].deviceName)' | grep -q "$DISK_NAME"; then
  echo "Disk already attached to $VM."
else
  echo "Attaching $DISK_NAME to $VM..."
  gcloud compute instances attach-disk "$VM" \
    --disk="$DISK_NAME" \
    --zone="$ZONE" \
    --project="$PROJECT"
fi

echo ""
echo "Next (on the VM):"
echo "  gcloud compute ssh $VM --zone=$ZONE --project=$PROJECT"
echo "  # then copy scripts/matrix-vm-setup-opt-data-dir.sh and run with sudo, or follow comments inside it."
