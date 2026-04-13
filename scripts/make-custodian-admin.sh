#!/bin/bash
# Make custodian a server admin using Synapse Admin API
# Loads ADMIN_ACCESS_TOKEN from .env (repo root) if present.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/load-dotenv.sh"

MATRIX_SERVER="https://matrix.castalia.institute"
CUSTODIAN_USER="@custodian:matrix.castalia.institute"

echo "🔷 Make Custodian Server Admin"
echo "==============================="
echo ""

if [ -z "${ADMIN_ACCESS_TOKEN}" ]; then
    echo "❌ ADMIN_ACCESS_TOKEN not set"
    echo ""
    echo "Add to .env in the repo root (or export for one session):"
    echo "  ADMIN_ACCESS_TOKEN=syt_..."
    echo ""
    echo "Get the token: Element Web (server admin) → Settings → Help & About → Access token"
    echo ""
    echo "Then run:"
    echo "  ./scripts/make-custodian-admin.sh"
    exit 1
fi

echo "✅ Admin access token found"
echo ""
echo "🔄 Making ${CUSTODIAN_USER} a server admin..."

RESPONSE=$(curl -s -X PUT \
    "${MATRIX_SERVER}/_synapse/admin/v2/users/${CUSTODIAN_USER}" \
    -H "Authorization: Bearer ${ADMIN_ACCESS_TOKEN}" \
    -H "Content-Type: application/json" \
    -d '{
        "admin": true
    }')

# Check for error
if echo "${RESPONSE}" | jq -e '.errcode' > /dev/null 2>&1; then
    ERROR=$(echo "${RESPONSE}" | jq -r '.error')
    ERRCODE=$(echo "${RESPONSE}" | jq -r '.errcode')
    echo "❌ Failed: ${ERRCODE} - ${ERROR}"
    echo ""
    echo "Response: ${RESPONSE}"
    exit 1
fi

# Check if successful
if echo "${RESPONSE}" | jq -e '.admin' > /dev/null 2>&1; then
    IS_ADMIN=$(echo "${RESPONSE}" | jq -r '.admin')
    if [ "${IS_ADMIN}" = "true" ]; then
        echo "✅ Custodian is now a server admin!"
        echo ""
        echo "User details:"
        echo "${RESPONSE}" | jq '.'
        echo ""
        echo "📚 Next steps:"
        echo "1. Custodian can now invite bots to rooms"
        echo "2. Run: ./scripts/auto-invite-bots.sh"
    else
        echo "⚠️  Admin status not confirmed"
        echo "Response: ${RESPONSE}"
    fi
else
    echo "⚠️  Unexpected response"
    echo "${RESPONSE}"
fi
