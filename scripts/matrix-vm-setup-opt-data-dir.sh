#!/usr/bin/env bash
# Run ON THE MATRIX VM (as root) after gcp-matrix-attach-data-disk.sh.
# Prepares /opt/matrix for Docker data: optional format+mount of attached disk, creates directories.
set -euo pipefail

MOUNT="/opt/matrix"
DISK_LABEL="matrix-data"
# Non-boot data disk on GCP is often /dev/sdb (verify with: lsblk)
DEVICE="${MATRIX_DATA_DEVICE:-/dev/sdb}"

if [[ ! -b "$DEVICE" ]]; then
  echo "Block device $DEVICE not found. Set MATRIX_DATA_DEVICE (e.g. /dev/sdb). lsblk:" >&2
  lsblk || true
  exit 1
fi

if ! blkid "$DEVICE" &>/dev/null; then
  echo "Formatting $DEVICE (ext4) — destructive if wrong disk!"
  mkfs.ext4 -L "$DISK_LABEL" "$DEVICE"
fi

mkdir -p "$MOUNT"
if ! mountpoint -q "$MOUNT"; then
  mount "$DEVICE" "$MOUNT"
fi

if ! grep -q "$MOUNT" /etc/fstab; then
  UUID="$(blkid -s UUID -o value "$DEVICE")"
  echo "UUID=$UUID $MOUNT ext4 defaults,nofail 0 2" >> /etc/fstab
fi

mkdir -p "$MOUNT/postgres-data" "$MOUNT/redis-data" "$MOUNT/matrix-data"
chown -R root:root "$MOUNT"

echo "OK: $MOUNT ready. To use bind mounts with Docker Compose, set on the host:"
echo "  export MATRIX_HOST_DATA_DIR=$MOUNT"
echo "Then use a compose override that maps:"
echo "  postgres -> $MOUNT/postgres-data:/var/lib/postgresql/data"
echo "  redis    -> $MOUNT/redis-data:/data"
echo "  synapse  -> $MOUNT/matrix-data:/data"
echo "(Duplicate those volume lines in a second compose file used only on this server, or switch volumes manually.)"
