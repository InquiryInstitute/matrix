#!/usr/bin/env bash
# One-shot: apply Inquiry.Institute keys to Castalia Matrix + Supabase (local workstation).
#
# Prereqs:
#   brew install google-cloud-sdk supabase/tap/supabase
#   gcloud auth login && gcloud auth application-default login   # as needed
#   supabase login   # one-time
#
# Env: reads ../Inquiry.Institute/.env and .env.local (see scripts/load-inquiry-institute-env.sh).
#
# This script:
#   1. Sets gcloud project (GCP_PROJECT from Inquiry or institute-481516).
#   2. Links Supabase CLI and pushes matrix/supabase/config.toml to the hosted project.
#
# Synapse itself runs on the GCP VM — use scripts/gcp-create-matrix-vm.sh + SSH + gcp-vm-install.sh,
# or ./scripts/gcp-matrix-ssh.sh if present. This does not replace on-VM Docker.
#
# Usage (from matrix repo root):
#   ./scripts/setup-castalia-from-inquiry.sh
#   ./scripts/setup-castalia-from-inquiry.sh --dry-run
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${ROOT}"

DRY=0
if [[ "${1:-}" == "--dry-run" ]]; then
  DRY=1
fi

# shellcheck disable=SC1091
source "${SCRIPT_DIR}/load-inquiry-institute-env.sh"

echo "Inquiry.Institute dir: ${INQUIRY_INSTITUTE_DIR}"
echo "GCP project: ${GCP_PROJECT}"
echo "Supabase project ref: ${SUPABASE_PROJECT_REF:-<missing>}"

if [[ -z "${SUPABASE_PROJECT_REF:-}" ]]; then
  echo "Set NEXT_PUBLIC_SUPABASE_PROJECT_REF or SUPABASE_PROJECT_REF in Inquiry .env" >&2
  exit 1
fi

if ! command -v gcloud >/dev/null 2>&1; then
  echo "Install gcloud: https://cloud.google.com/sdk/docs/install" >&2
  exit 1
fi
if ! command -v supabase >/dev/null 2>&1; then
  echo "Install: brew install supabase/tap/supabase" >&2
  exit 1
fi

run() {
  if [[ "$DRY" -eq 1 ]]; then
    echo "[dry-run] $*"
  else
    "$@"
  fi
}

run gcloud config set project "${GCP_PROJECT}"

echo ""
echo "=== Supabase CLI: link + config push (matrix/supabase/config.toml) ==="
run supabase link --project-ref "${SUPABASE_PROJECT_REF}" --yes
if [[ "$DRY" -eq 1 ]]; then
  run supabase config push --project-ref "${SUPABASE_PROJECT_REF}"
else
  set +o pipefail
  yes | supabase config push --project-ref "${SUPABASE_PROJECT_REF}"
  set -o pipefail
fi

echo ""
echo "OK."
echo ""
echo "Next — Synapse on GCP (if not already running):"
echo "  1) Reserve IP / create VM (see scripts/gcp-matrix-static-ip.sh, scripts/gcp-create-matrix-vm.sh)"
echo " 2) gcloud compute ssh matrix-synapse --zone=us-central1-b --project=${GCP_PROJECT}"
echo " 3) On the VM: follow scripts/gcp-vm-install.sh or pull repo to /opt/matrix and docker compose up -d"
echo " 4) OIDC: SUPABASE_OIDC_CLIENT_ID=... ./scripts/configure-matrix-oidc.sh (see CASTALIA_ELEMENT_SUPABASE.md)"
echo ""
