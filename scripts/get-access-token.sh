#!/bin/bash
# Get Matrix access token by logging in

MATRIX_SERVER="https://matrix.inquiry.institute"

echo "🔐 Get Matrix Access Token"
echo "=========================="
echo ""

read -p "Username: " USERNAME
read -s -p "Password: " PASSWORD
echo ""
echo ""

echo "🔄 Logging in..."

RESPONSE=$(curl -s -X POST "${MATRIX_SERVER}/_matrix/client/v3/login" \
  -H "Content-Type: application/json" \
  -d "{
    \"type\": \"m.login.password\",
    \"user\": \"${USERNAME}\",
    \"password\": \"${PASSWORD}\"
  }")

# Check for error
if echo "${RESPONSE}" | jq -e '.error' > /dev/null 2>&1; then
    ERROR=$(echo "${RESPONSE}" | jq -r '.error')
    echo "❌ Login failed: ${ERROR}"
    exit 1
fi

# Extract access token
ACCESS_TOKEN=$(echo "${RESPONSE}" | jq -r '.access_token')

if [ -n "${ACCESS_TOKEN}" ] && [ "${ACCESS_TOKEN}" != "null" ]; then
    echo "✅ Login successful!"
    echo ""
    echo "Your access token:"
    echo "${ACCESS_TOKEN}"
    echo ""
    echo "To use it:"
    echo "  export MATRIX_ACCESS_TOKEN=${ACCESS_TOKEN}"
    echo "  ./scripts/auto-invite-bots.sh"
    echo ""
    
    # Optionally save to file
    read -p "Save token to .matrix-token file? (y/N): " SAVE
    if [ "${SAVE}" = "y" ] || [ "${SAVE}" = "Y" ]; then
        echo "${ACCESS_TOKEN}" > .matrix-token
        echo "💾 Saved to .matrix-token"
        echo ""
        echo "To use it later:"
        echo "  export MATRIX_ACCESS_TOKEN=\$(cat .matrix-token)"
    fi
else
    echo "❌ Could not get access token"
    echo "Response: ${RESPONSE}"
fi
