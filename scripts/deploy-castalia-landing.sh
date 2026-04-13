#!/usr/bin/env bash
# Deploy web/castalia-institute to the Matrix VM and add Caddy site login.castalia.institute (static + iframe CSP).
# Requires: gcloud auth, DNS A record login.castalia.institute → same VM as Matrix (scripts/route53-castalia-login-a.sh).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VM="${GCP_VM_NAME:-matrix-synapse}"
ZONE="${GCP_ZONE:-us-central1-b}"
PROJECT="${GCP_PROJECT:-institute-481516}"
REMOTE_DIR="/opt/matrix/web/castalia-institute"

echo "📤 Syncing landing page → ${VM}:${REMOTE_DIR}"
gcloud compute ssh "${VM}" --zone="${ZONE}" --project="${PROJECT}" --command="sudo mkdir -p ${REMOTE_DIR} && sudo chown \$USER ${REMOTE_DIR} || sudo chown root ${REMOTE_DIR}"

gcloud compute scp --recurse "${ROOT}/web/castalia-institute/index.html" "${VM}:${REMOTE_DIR}/" --zone="${ZONE}" --project="${PROJECT}"
gcloud compute scp "${ROOT}/configs/caddy-login.castalia.institute.caddy" "${VM}:/tmp/caddy-login.castalia.caddy" --zone="${ZONE}" --project="${PROJECT}"

gcloud compute ssh "${VM}" --zone="${ZONE}" --project="${PROJECT}" --command='set -e
# CORS: Element fetches welcome_url (EmbeddedPage.tsx); iframe CSP alone is not enough.
sudo python3 <<'"'"'PY'"'"'
path = "/opt/matrix/Caddyfile"
with open("/tmp/caddy-login.castalia.caddy") as f:
    new_block = f.read().strip()
key = "login.castalia.institute {"
with open(path) as f:
    text = f.read()
if key not in text:
    with open(path, "a") as f:
        f.write("\n\n" + new_block + "\n\n")
else:
    i = text.index(key)
    depth = 0
    j = i
    while j < len(text):
        if text[j] == "{":
            depth += 1
        elif text[j] == "}":
            depth -= 1
            if depth == 0:
                j += 1
                break
        j += 1
    text = text[:i] + new_block + "\n\n" + text[j:]
    with open(path, "w") as f:
        f.write(text)
PY
# Older configs used host path; Caddy runs in Docker and only has /srv/castalia.
sudo sed -i "s|root \* /opt/matrix/web/castalia-institute|root * /srv/castalia|g" /opt/matrix/Caddyfile
'

gcloud compute ssh "${VM}" --zone="${ZONE}" --project="${PROJECT}" --command='set -e
# Element requests /config.<hostname>.json — mount same JSON twice (see docker-compose.yml).
if ! sudo grep -q "config.element.castalia.institute.json" /opt/matrix/docker-compose.yml 2>/dev/null; then
  sudo sed -i "/element-config.json:\/app\/config.json:ro$/a\\      - ./element-config.json:/app/config.element.castalia.institute.json:ro" /opt/matrix/docker-compose.yml
  echo "Added hostname-specific Element config volume"
else
  echo "docker-compose already has config.element.castalia.institute volume"
fi
'

gcloud compute ssh "${VM}" --zone="${ZONE}" --project="${PROJECT}" --command='set -e
if ! sudo grep -q "^sso:" /opt/matrix/matrix-data/homeserver.yaml; then
  sudo tee -a /opt/matrix/matrix-data/homeserver.yaml >/dev/null <<YAML

sso:
  client_whitelist:
    - "https://element.castalia.institute/"
    - "https://castalia.institute/"
    - "https://login.castalia.institute/"
YAML
  echo "Appended sso.client_whitelist"
else
  echo "homeserver.yaml already has sso: — merge client_whitelist manually if login fails"
fi
'

echo "📋 Updating Element config + reload"
gcloud compute scp "${ROOT}/configs/element-config.castalia.example.json" "${VM}:/tmp/element-config.castalia.json" --zone="${ZONE}" --project="${PROJECT}"
gcloud compute ssh "${VM}" --zone="${ZONE}" --project="${PROJECT}" --command='set -e
sudo cp /tmp/element-config.castalia.json /opt/matrix/element-config.json
# Caddy must see static files: host dir is mounted at /srv/castalia in the container (see scripts/gcp-vm-install.sh).
if ! sudo docker inspect caddy --format "{{range .Mounts}}{{.Destination}} {{end}}" 2>/dev/null | grep -q "/srv/castalia"; then
  echo "Recreating caddy with /opt/matrix/web/castalia-institute → /srv/castalia mount"
  sudo docker stop caddy && sudo docker rm caddy
  sudo docker run -d --name caddy --restart always --network host \
    -v /opt/matrix/Caddyfile:/etc/caddy/Caddyfile:ro \
    -v /opt/matrix/web/castalia-institute:/srv/castalia:ro \
    caddy:2-alpine
else
  sudo docker restart caddy
fi
cd /opt/matrix && sudo docker compose up -d element-web synapse
'

echo "OK. Landing: https://login.castalia.institute/ — Element embeds it via welcome_url. DNS: scripts/route53-castalia-login-a.sh"
