#!/usr/bin/env bash
# Stop Matrix VM, change machine type, start. Use when you need more CPU/RAM on the same disk/IP.
# Prereq: snapshot disks first (./scripts/gcp-matrix-disk-snapshot.sh).
set -euo pipefail

PROJECT="${GCP_PROJECT:-institute-481516}"
ZONE="${GCP_ZONE:?Set GCP_ZONE (e.g. us-central1-b)}"
NAME="${VM_NAME:-matrix-synapse}"
MACHINE="${MACHINE_TYPE:?Set MACHINE_TYPE (e.g. e2-medium)}"

echo "Stopping $NAME in $ZONE..."
gcloud compute instances stop "$NAME" --zone="$ZONE" --project="$PROJECT" --quiet

echo "Setting machine type to $MACHINE..."
gcloud compute instances set-machine-type "$NAME" --zone="$ZONE" --project="$PROJECT" \
  --machine-type="$MACHINE"

echo "Starting $NAME..."
gcloud compute instances start "$NAME" --zone="$ZONE" --project="$PROJECT" --quiet

gcloud compute instances describe "$NAME" --zone="$ZONE" --project="$PROJECT" \
  --format="table(name,zone,machineType.basename(),status)"

echo "OK. SSH in and: cd /path/to/matrix && docker compose up -d"
