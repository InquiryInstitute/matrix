#!/bin/bash
# Make custodian a server admin using Synapse Admin API

MATRIX_SERVER="https://matrix.inquiry.institute"
CUSTODIAN_USER="@custodian:matrix.inquiry.institute"

echo "🔷 Make Custodian Server Admin"
echo "==============================="
echo ""

if [ -z "${ADMIN_ACCESS_TOKEN}" ]; then
    echo "❌ ADMIN_ACCESS_TOKEN not set"
    echo ""
    echo "You need an existing server admin's access token."
    echo ""
    echo "To get it:"
    echo "1. Login to Element Web as a server admin"
    echo "2. Go to Settings → Help & About"
    echo "3. Reveal and copy the Access Token"
    echo ""
    echo "Then run:"
    echo "  export ADMIN_ACCESS_TOKEN=your_admin_token"
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
