# Matrix on Google Cloud

Production Matrix (Synapse) runs on **Google Cloud Platform** — typically a **Compute Engine VM** with Docker Compose (see `scripts/gcp-create-matrix-vm.sh`, `scripts/gcp-matrix-static-ip.sh`). It is **not** hosted on Fly.io.

## Homeserver

- Set `MATRIX_SERVER_URL` / homeserver URL to your public Matrix HTTPS endpoint (e.g. `https://matrix.castalia.institute` or your domain).
- Validate: `curl -sS https://<your-homeserver>/_matrix/client/versions`

## Operations (GCP)

**Default gcloud project:** `institute-481516` (set once with `gcloud config set project institute-481516`). Castalia Matrix deploy: `bash scripts/deploy-castalia-landing.sh` (uses `GCP_VM_NAME=matrix-synapse`, `GCP_ZONE=us-central1-b` by default).

**Inquiry.Institute keys + Supabase CLI:** From the matrix repo, run `./scripts/setup-castalia-from-inquiry.sh` (reads `../Inquiry.Institute/.env` and `.env.local`, sets `gcloud` project from `GCP_PROJECT_ID`, pushes `supabase/config.toml` via Supabase CLI). Use `--dry-run` to print steps only.


| Task | How |
|------|-----|
| **SSH to the VM** | `gcloud compute ssh matrix-synapse --zone=us-central1-b` |
| **Logs** | On the VM: `docker compose logs -f synapse` (or your stack) |
| **Deploy / restart** | Pull repo on VM, adjust `.env`, `docker compose up -d` |
| **Static IP & DNS** | Reserve IP in the correct region; Route 53 **A** record to that IP. See [GCP_FLY_MIGRATION.md](GCP_FLY_MIGRATION.md) for migration-era notes. |

## Registering bots

Use Element Web against your homeserver, the Synapse admin API, or run `register_new_matrix_user` **on the Matrix VM** (via `gcloud compute ssh`), not via Fly.

## Topic rooms (`/create-room`)

The Flask helper in `scripts/serve-topic-room.py` is **not tied to Fly**. Run it on the same host as Synapse (or behind nginx) and proxy `https://<homeserver>/create-room` to it. See [TOPIC_ROOM_VIA_URL.md](TOPIC_ROOM_VIA_URL.md).

## Scaling & backups

See [GCP_SCALING.md](GCP_SCALING.md).

## Historical note

Matrix was previously on Fly.io; migration steps and DNS cutover are documented in [GCP_FLY_MIGRATION.md](GCP_FLY_MIGRATION.md).
