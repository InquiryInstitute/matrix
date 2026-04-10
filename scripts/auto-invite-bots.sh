#!/bin/bash
# Automatically invite all bots to the board room using Matrix API

set -e

ROOM_ID="!aEqllYpAjknuXJTPGD:matrix.inquiry.institute"
MATRIX_SERVER="https://matrix.inquiry.institute"

echo "🔷 Auto-Invite Bots to Board Room"
echo "=================================="
echo ""
echo "Room ID: ${ROOM_ID}"
echo ""

# Check for access token
if [ -z "${MATRIX_ACCESS_TOKEN}" ]; then
    echo "❌ MATRIX_ACCESS_TOKEN not set"
    echo ""
    echo "To get your access token:"
    echo "1. Login to Element Web"
    echo "2. Click your profile → All Settings → Help & About"
    echo "3. Scroll down to 'Access Token' and click to reveal"
    echo "4. Copy the token"
    echo ""
    echo "Then run:"
    echo "  export MATRIX_ACCESS_TOKEN=your_token"
    echo "  ./scripts/auto-invite-bots.sh"
    exit 1
fi

echo "✅ Access token found"
echo ""

# Load bot credentials
if [ ! -f "matrix-bot-credentials.json" ]; then
    echo "❌ Bot credentials file not found"
    exit 1
fi

echo "📋 Loading bot credentials..."
BOT_COUNT=$(jq '. | length' matrix-bot-credentials.json)
echo "   Found ${BOT_COUNT} bots"
echo ""

# Invite each bot
echo "📨 Inviting bots to room..."
echo ""

INVITED=0
FAILED=0

jq -r '.[].matrix_id' matrix-bot-credentials.json | while read -r MATRIX_ID; do
    USERNAME=$(echo "${MATRIX_ID}" | sed 's/@\(.*\):.*/\1/')
    
    echo "   Inviting ${USERNAME}..."
    
    RESPONSE=$(curl -s -X POST \
        "${MATRIX_SERVER}/_matrix/client/v3/rooms/${ROOM_ID}/invite" \
        -H "Authorization: Bearer ${MATRIX_ACCESS_TOKEN}" \
        -H "Content-Type: application/json" \
        -d "{\"user_id\": \"${MATRIX_ID}\"}")
    
    # Check if successful
    if echo "${RESPONSE}" | jq -e '.error' > /dev/null 2>&1; then
        ERROR_MSG=$(echo "${RESPONSE}" | jq -r '.error')
        if [ "${ERROR_MSG}" = "User is already in the room." ]; then
            echo "      ✓ Already in room"
        else
            echo "      ❌ Failed: ${ERROR_MSG}"
            ((FAILED++)) || true
        fi
    else
        echo "      ✅ Invited"
        ((INVITED++)) || true
    fi
done

echo ""
echo "=================================="
echo "📊 Summary"
echo "=================================="
echo "Total bots: ${BOT_COUNT}"
echo "Invited: ${INVITED}"
echo "Failed: ${FAILED}"
echo ""

if [ ${FAILED} -eq 0 ]; then
    echo "🎉 All bots invited successfully!"
else
    echo "⚠️  Some invitations failed. Check the errors above."
fi

echo ""
echo "📚 Next Steps:"
echo "1. Bots need to accept invitations (start them to auto-accept)"
echo "2. Start custodian: ./scripts/start-custodian-bot.sh"
echo "3. Check room members in Element Web"
