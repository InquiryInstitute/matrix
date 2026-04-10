# Matrix on GCP (migrating off Fly.io)

## Current state

| Item | Detail |
|------|--------|
| **Fly.io** | `matrix.inquiry.institute` → CNAME → `inquiry-matrix.fly.dev` (live today). |
| **GCP static IP (east1, legacy doc)** | `matrix-ip` = **34.148.23.74** (`us-east1`), **RESERVED** — only attach to a VM in **`us-east1`**. |
| **GCP VM** | `matrix-synapse` was removed; **recreate** before or right after DNS cutover. |
| **DNS (Route 53)** | Zone `inquiry.institute` — `matrix.inquiry.institute` is a **CNAME** to Fly. For GCP, use an **A** record to your Matrix VM’s **regional** static IP (see below). |
| **Firewall** | Rules `matrix-http`, `matrix-https`, `matrix-federation` apply to instances tagged **`matrix-server`** (ports **80**, **443**, **8448**). Put **Synapse behind TLS** on 443 (nginx/Caddy); federation stays on **8448**. |

## Region: central, west, or east

**Regional static IPs are tied to one region.** You cannot move `34.148.23.74` (us-east1) to a VM in **us-central1** or **us-west1**.

**Address names** (`matrix-ip`, etc.) must be **unique in the project**. If `matrix-ip` already exists in **us-east1**, create a **new** name for another region, e.g. `STATIC_IP_NAME=matrix-ip-central`.

| Goal | What to do |
|------|------------|
| **Run Matrix in us-central1** (default in `gcp-create-matrix-vm.sh`) | `GCP_REGION=us-central1 STATIC_IP_NAME=matrix-ip-central ./scripts/gcp-matrix-static-ip.sh` then `GCP_REGION=us-central1 GCP_ZONE=us-central1-a STATIC_IP_NAME=matrix-ip-central ./scripts/gcp-create-matrix-vm.sh`. Point Route 53 **A** at the **new** IPv4. |
| **Run in us-west1** (same region as `lms-moodle`) | `GCP_REGION=us-west1 GCP_ZONE=us-west1-a` and a static IP in **us-west1** (e.g. `STATIC_IP_NAME=matrix-ip-west`), deploy VM, DNS **A** to that IP. |
| **Keep using the existing east1 address** | Deploy in **`us-east1`** only: `GCP_REGION=us-east1 GCP_ZONE=us-east1-b`, `STATIC_IP_NAME=matrix-ip`, then DNS → **34.148.23.74**. |

If **`ZONE_RESOURCE_POOL_EXHAUSTED`** appears, try another zone in the same region (`us-central1-b`, `us-central1-c`, etc.) or retry later.

## Instance size: micro vs small

| Type | RAM | Notes |
|------|-----|--------|
| **e2-micro** | 1 GiB | **Default** in `gcp-create-matrix-vm.sh` — OK for **idle/light** use; **tight** for full **docker-compose** (Postgres + Redis + Synapse + Element). Shrink stack or raise `MACHINE_TYPE` if OOM. |
| **e2-small** | 2 GiB | Closer to Fly’s 2 GB Matrix machine; safer for Postgres compose unchanged. |
| **e2-medium** | 4 GiB | Comfortable if many users or heavy media. |

Override (larger): `MACHINE_TYPE=e2-small ./scripts/gcp-create-matrix-vm.sh`

**Always Free:** Only one **e2-micro** per billing account/month in qualifying regions; having multiple e2-micro VMs may still incur charges on the extras.

## Quota

`CPUS_ALL_REGIONS` must allow headroom for the chosen `MACHINE_TYPE`. Check:

```bash
gcloud compute project-info describe --project=institute-481516 \
  --format=json | jq '.quotas[] | select(.metric=="CPUS_ALL_REGIONS")'
```

## Order of operations

1. **Data (if Fly is canonical)** — Export Synapse/Postgres from Fly and restore on GCP, *or* accept starting from GCP backup only. Plan this before cutover if users rely on Fly history.
2. **Static IP in target region** — `./scripts/gcp-matrix-static-ip.sh` (set `GCP_REGION` / `STATIC_IP_NAME` as needed).
3. **Create VM** — `GCP_REGION=… GCP_ZONE=… MACHINE_TYPE=… ./scripts/gcp-create-matrix-vm.sh`. Deploy repo: `docker compose up -d`, sync `matrix-data/`, TLS on **443**, `public_baseurl` / federation for `https://matrix.inquiry.institute`.
4. **Validate** — `curl -sS https://matrix.inquiry.institute/_matrix/client/versions` and federation checks.
5. **DNS cutover** — `./scripts/route53-matrix-gcp.sh <matrix_static_ipv4>` (replaces Fly CNAME with **A** to that IP). Use the IP shown for the address in **your chosen region**. `_matrix._tcp` SRV can stay if it still points at `matrix.inquiry.institute:8448`.
6. **Fly** — Scale `inquiry-matrix` to **0** or remove the app after TTL and validation.

## Rollback

Point `matrix.inquiry.institute` CNAME back to `inquiry-matrix.fly.dev` in Route 53.

## Scaling as usage grows

See **[GCP_SCALING.md](GCP_SCALING.md)** — vertical resize, disk snapshots, optional separate data disk, and paths to **Cloud SQL** / **Memorystore**.
