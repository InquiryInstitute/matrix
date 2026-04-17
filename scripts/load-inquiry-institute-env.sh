#!/usr/bin/env bash
# Source Inquiry.Institute .env files and export vars expected by matrix + Supabase scripts.
#
# Default directory: sibling of this repo — ../Inquiry.Institute (override with INQUIRY_INSTITUTE_DIR).
# Load order: .env then .env.local (later overrides).
#
# Mappings:
#   NEXT_PUBLIC_SUPABASE_PROJECT_REF → SUPABASE_PROJECT_REF (if unset)
#   GCP_PROJECT_ID → GCP_PROJECT (if unset) for gcloud
#
# Usage (from matrix repo):
#   source scripts/load-inquiry-institute-env.sh
#
_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_MATRIX_ROOT="$(cd "${_SCRIPT_DIR}/.." && pwd)"

# Resolve Inquiry.Institute path (try exact name, then lowercase variant)
if [[ -n "${INQUIRY_INSTITUTE_DIR:-}" ]]; then
  _II_DIR="$(cd "${INQUIRY_INSTITUTE_DIR}" && pwd)"
else
  _II_DIR=""
  for _cand in "${_MATRIX_ROOT}/../Inquiry.Institute" "${_MATRIX_ROOT}/../inquiry.institute"; do
    if [[ -d "${_cand}" ]]; then
      _II_DIR="$(cd "${_cand}" && pwd)"
      break
    fi
  done
fi

if [[ -z "${_II_DIR}" ]] || [[ ! -d "${_II_DIR}" ]]; then
  echo "Inquiry.Institute repo not found. Clone it next to matrix or set INQUIRY_INSTITUTE_DIR." >&2
  if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    exit 1
  fi
  return 1
fi

set -a
if [[ -f "${_II_DIR}/.env" ]]; then
  # shellcheck disable=SC1091
  source "${_II_DIR}/.env"
fi
if [[ -f "${_II_DIR}/.env.local" ]]; then
  # shellcheck disable=SC1091
  source "${_II_DIR}/.env.local"
fi
set +a

# Supabase (hosted Auth config push / link)
if [[ -z "${SUPABASE_PROJECT_REF:-}" && -n "${NEXT_PUBLIC_SUPABASE_PROJECT_REF:-}" ]]; then
  export SUPABASE_PROJECT_REF="${NEXT_PUBLIC_SUPABASE_PROJECT_REF}"
fi

# Google Cloud (Synapse VM lives in a GCP project)
if [[ -z "${GCP_PROJECT:-}" ]]; then
  if [[ -n "${GCP_PROJECT_ID:-}" ]]; then
    export GCP_PROJECT="${GCP_PROJECT_ID}"
  elif [[ -n "${GOOGLE_CLOUD_PROJECT:-}" ]]; then
    export GCP_PROJECT="${GOOGLE_CLOUD_PROJECT}"
  else
    export GCP_PROJECT="${GCP_PROJECT:-institute-481516}"
  fi
fi

export INQUIRY_INSTITUTE_DIR="${_II_DIR}"
