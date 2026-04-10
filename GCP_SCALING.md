# Matrix on GCP — scaling as usage grows

Use this as a **growth ladder**. You can stop at any phase that fits traffic and cost.

## Principles

1. **Static IP stays put** — Resizing the VM or attaching disks does not change the regional address (e.g. `matrix-ip-central`) unless you rebuild in another region.
2. **Backup before structural changes** — Run disk snapshots (`./scripts/gcp-matrix-disk-snapshot.sh`) or `pg_dump` before resize, disk moves, or DB migration.
3. **Vertical first** — Bigger machine type (`e2-small` → `e2-medium` → `e2-standard-4`) is the simplest step.
4. **Then managed data** — Move Postgres to **Cloud SQL** and Redis to **Memorystore** when you need HA, easier backups, or the VM is CPU-bound with DB I/O.

## Phase 0 — Idle / light (current pattern)

- One **Compute Engine** VM, **Docker Compose** on the boot disk (or boot + optional data disk).
- Synapse + Postgres + Redis as in `docker-compose.yml`.

## Phase 1 — More CPU / RAM (same VM)

When latency grows or OOMs appear:

```bash
GCP_ZONE=us-central1-b MACHINE_TYPE=e2-medium ./scripts/gcp-matrix-resize-vm.sh
```

Typical path: **`e2-micro`** → **`e2-small`** → **`e2-medium`** → **`e2-standard-4`** (same zone/region).

**Before:** `docker compose stop` (SSH) and snapshot disks (script below). **After:** `docker compose up -d`, check `/_matrix/client/versions` and `/health`.

## Phase 2 — More disk or cleaner data separation

**Option A — Expand boot disk** (simplest if everything lives on `/`)

```bash
# Example: 50 GB → 100 GB (then grow partition inside the VM — see GCP docs)
gcloud compute disks resize matrix-synapse --size=100 --zone=YOUR_ZONE --project=institute-481516
```

**Option B — Separate persistent disk** for Docker data (easier to snapshot/move later than mixing with OS):

```bash
DATA_DISK_GB=200 GCP_ZONE=us-central1-b ./scripts/gcp-matrix-attach-data-disk.sh
# Then SSH and run (once): ./scripts/matrix-vm-setup-opt-data-dir.sh
```

Point Compose bind mounts at `/opt/matrix/...` (see comments in `matrix-vm-setup-opt-data-dir.sh`) or keep using Docker volumes on the mounted disk path.

## Phase 3 — Managed Postgres / Redis

When the VM is stable but you want **automated backups**, **patching**, or **read replicas**:

1. Create **Cloud SQL for PostgreSQL** (matching Synapse’s Postgres version expectations).
2. **Dump/restore:** `pg_dump` from the VM → restore to Cloud SQL; or use Database Migration Service for larger moves.
3. Update Synapse `homeserver.yaml` / env to the Cloud SQL **private IP** (VPC) or **SSL** connection string; restrict with **IAM / authorized networks** as needed.
4. Optionally add **Memorystore (Redis)** and point `redis` host in Synapse config; remove the Redis container from Compose on the VM.

Synapse still runs on the VM (or move to a second pool later); only the DB tier becomes managed.

## Phase 4 — Beyond a single VM

- Multiple app VMs behind a load balancer (sticky sessions / IP affinity for Synapse need care).
- Federation and media offloads — follow current Synapse docs for your version.

Most teams stay on **Phase 1–3** for a long time.

## Quick reference

| Action | Script / command |
|--------|------------------|
| Snapshot boot (+ optional data) disk | `./scripts/gcp-matrix-disk-snapshot.sh` |
| Resize machine type | `./scripts/gcp-matrix-resize-vm.sh` |
| Create + attach data disk | `./scripts/gcp-matrix-attach-data-disk.sh` |
| On VM: dirs + optional mount | `./scripts/matrix-vm-setup-opt-data-dir.sh` |

Environment variables are documented at the top of each script (`GCP_ZONE`, `VM_NAME`, `PROJECT`, etc.).

## Quota

Larger machine types need headroom in **`CPUS_ALL_REGIONS`** and per-region **`CPUS`**. Check:

```bash
gcloud compute project-info describe --project=institute-481516 \
  --format=json | jq '.quotas[] | select(.metric=="CPUS_ALL_REGIONS")'
```

Request increases in Cloud Console if you hit limits.
