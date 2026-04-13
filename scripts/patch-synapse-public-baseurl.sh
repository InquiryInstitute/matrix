#!/usr/bin/env bash
# Set Synapse public_baseurl (drives OIDC redirect_uri). Run on the Matrix host after pull.
#
#   SYNAPSE_PUBLIC_BASEURL=https://matrix.castalia.institute \
#     ./scripts/patch-synapse-public-baseurl.sh
#
# Then: docker compose restart synapse
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
MATRIX_DIR="${MATRIX_DIR:-$REPO_ROOT}"
HOMESERVER_YAML="${1:-${MATRIX_DIR}/matrix-data/homeserver.yaml}"
URL="${SYNAPSE_PUBLIC_BASEURL:-https://matrix.castalia.institute}"
URL="${URL%/}"

if [[ ! -f "${HOMESERVER_YAML}" ]]; then
  echo "❌ Not found: ${HOMESERVER_YAML}" >&2
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "❌ python3 required" >&2
  exit 1
fi

export PATCH_YAML="${HOMESERVER_YAML}"
export PATCH_URL="${URL}"

python3 <<'PY'
import os
import sys

try:
    import yaml
except ImportError:
    print("❌ Install PyYAML: apt-get install -y python3-yaml  (or pip install pyyaml)", file=sys.stderr)
    sys.exit(1)

path = os.environ["PATCH_YAML"]
url = os.environ["PATCH_URL"]

with open(path) as f:
    data = yaml.safe_load(f)

if not isinstance(data, dict):
    print("❌ Unexpected YAML root", file=sys.stderr)
    sys.exit(1)

old = data.get("public_baseurl")
data["public_baseurl"] = url

with open(path, "w") as f:
    yaml.safe_dump(data, f, default_flow_style=False, sort_keys=False, allow_unicode=True)

print(f"✅ public_baseurl: {old!r} → {url!r}")
print(f"   File: {path}")
print("   Restart Synapse:  docker compose restart synapse")
PY
