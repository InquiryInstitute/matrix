#!/usr/bin/env bash
# Run ON the GCP Matrix VM (Ubuntu) as root or with sudo.
# Installs Docker, Caddy, clones repo, generates Synapse + Postgres config, starts stack.
set -euo pipefail

MATRIX_DIR="${MATRIX_DIR:-/opt/matrix}"
MATRIX_DOMAIN="${MATRIX_DOMAIN:-matrix.inquiry.institute}"
# Optional: CalDAV on same host (docker compose publishes 127.0.0.1:18080 — see cal.inquiry.institute repo).
CAL_DOMAIN="${CAL_DOMAIN:-cal.castalia.institute}"
# Optional: extra hostnames for the same Synapse (TLS + proxy). Comma-separated, e.g. matrix.castalia.institute
MATRIX_EXTRA_DOMAINS="${MATRIX_EXTRA_DOMAINS:-}"
REPO_URL="${MATRIX_REPO_URL:-https://github.com/InquiryInstitute/matrix.git}"
export MATRIX_DIR MATRIX_DOMAIN CAL_DOMAIN MATRIX_EXTRA_DOMAINS

export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq docker.io docker-compose-v2 python3-yaml git curl

systemctl enable --now docker

mkdir -p "$MATRIX_DIR"
cd "$MATRIX_DIR"

if [[ ! -f docker-compose.yml ]]; then
  if git clone --depth 1 "$REPO_URL" . 2>/dev/null; then
    :
  else
    echo "No docker-compose.yml and git clone failed (private repo?). Extract a tarball into ${MATRIX_DIR} first, then re-run." >&2
    exit 1
  fi
fi

POSTGRES_PASSWORD="$(openssl rand -base64 32)"
REDIS_PASSWORD="$(openssl rand -base64 32)"
cat > .env <<EOF
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
REDIS_PASSWORD=${REDIS_PASSWORD}
MATRIX_DOMAIN=${MATRIX_DOMAIN}
MATRIX_SERVER_URL=https://${MATRIX_DOMAIN}
SYNAPSE_REPORT_STATS=no
EOF
chmod 600 .env

mkdir -p matrix-data
# Remove bundled secrets/config so generate is clean; ensure Synapse (uid 991) can write.
find matrix-data -mindepth 1 -delete 2>/dev/null || rm -rf matrix-data/*
mkdir -p matrix-data
chown -R 991:991 matrix-data 2>/dev/null || chmod -R 777 matrix-data

# Synapse serves both client and federation on port 8008; Caddy terminates TLS on 443 only.
# Bind published 8008 to localhost so Caddy can use :443 (and optional :8448) on the host.
if grep -q '8008:8008' docker-compose.yml && ! grep -q '127.0.0.1:8008:8008' docker-compose.yml; then
  sed -i 's/- "8008:8008"/- "127.0.0.1:8008:8008"/' docker-compose.yml
fi
# Drop host publish of 8448 if present (federation uses 8008 in generated config).
sed -i '/8448:8448/d' docker-compose.yml || true

docker compose pull postgres redis
docker compose up -d postgres redis
echo "Waiting for Postgres..."
for i in $(seq 1 60); do
  docker compose exec -T postgres pg_isready -U synapse && break
  sleep 2
done

docker pull matrixdotorg/synapse:latest
docker run --rm \
  -v "${MATRIX_DIR}/matrix-data:/data" \
  -e SYNAPSE_SERVER_NAME="${MATRIX_DOMAIN}" \
  -e SYNAPSE_REPORT_STATS=no \
  matrixdotorg/synapse:latest generate

set -a
# shellcheck disable=SC1091
source "${MATRIX_DIR}/.env"
set +a

python3 <<'PATCH'
import os
import yaml

path = os.path.join(os.environ["MATRIX_DIR"], "matrix-data", "homeserver.yaml")
with open(path) as f:
    data = yaml.safe_load(f)

data["public_baseurl"] = f"https://{os.environ['MATRIX_DOMAIN']}"
data["database"] = {
    "name": "psycopg2",
    "args": {
        "user": "synapse",
        "password": os.environ["POSTGRES_PASSWORD"],
        "dbname": "synapse",
        "host": "postgres",
        "port": 5432,
        "cp_min": 1,
        "cp_max": 10,
    },
}
data["enable_registration"] = False

with open(path, "w") as f:
    yaml.safe_dump(data, f, default_flow_style=False, sort_keys=False, allow_unicode=True)
PATCH

docker compose pull synapse
docker compose up -d synapse
echo "Waiting for Synapse health..."
for i in $(seq 1 90); do
  if curl -fsS http://127.0.0.1:8008/health >/dev/null 2>&1; then
    echo "Synapse is up."
    break
  fi
  sleep 2
done

cat > "${MATRIX_DIR}/Caddyfile" <<CADDY
{
  email custodian@inquiry.institute
}
${MATRIX_DOMAIN} {
  reverse_proxy 127.0.0.1:8008
}
${CAL_DOMAIN} {
  reverse_proxy 127.0.0.1:18080
}
CADDY

# Same Synapse on additional Matrix client hostnames (DNS must point here; see scripts/route53-castalia-matrix-a.sh)
if [[ -n "${MATRIX_EXTRA_DOMAINS// }" ]]; then
  _IFS=$IFS
  IFS=','
  for _host in ${MATRIX_EXTRA_DOMAINS}; do
    _host=$(echo "${_host}" | tr -d '[:space:]')
    [[ -z "${_host}" ]] && continue
    printf '%s {\n  reverse_proxy 127.0.0.1:8008\n}\n' "${_host}" >> "${MATRIX_DIR}/Caddyfile"
  done
  IFS=$_IFS
fi

docker rm -f caddy 2>/dev/null || true
docker pull caddy:2-alpine
docker run -d --name caddy --restart always --network host \
  -v "${MATRIX_DIR}/Caddyfile:/etc/caddy/Caddyfile:ro" \
  caddy:2-alpine

curl -fsS "http://127.0.0.1:8008/_matrix/client/versions" | head -c 200 || true
echo ""
echo "OK: Matrix stack running. HTTPS via Caddy. .env and secrets in ${MATRIX_DIR}"
