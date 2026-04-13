#!/bin/bash
# List which bots should be in the board room
# This is a simple version that doesn't require Python dependencies

ROOM_ID="!aEqllYpAjknuXJTPGD:matrix.castalia.institute"

echo "🔷 Board Room - Expected Members"
echo "================================="
echo ""
echo "Room ID: ${ROOM_ID}"
echo ""

if [ ! -f "matrix-bot-credentials.json" ]; then
    echo "❌ Bot credentials file not found"
    exit 1
fi

echo "📋 Expected Bots in Room:"
echo ""

echo "Special Bots (3):"
jq -r '.[] | select(.bot_type) | "   ✓ \(.username)\n     \(.matrix_id)"' matrix-bot-credentials.json
echo ""

echo "Director Bots (10):"
jq -r '.[] | select(.username | contains("Director")) | "   ✓ \(.username)\n     \(.matrix_id)"' matrix-bot-credentials.json
echo ""

TOTAL=$(jq '. | length' matrix-bot-credentials.json)
echo "Total: ${TOTAL} bots"
echo ""

echo "================================="
echo "📚 To Invite Missing Bots:"
echo "================================="
echo ""
echo "Option 1: Via Element Web (https://app.element.io)"
echo "  1. Join the board room"
echo "  2. Click room name → Invite"
echo "  3. Copy/paste each Matrix ID above"
echo ""
echo "Option 2: Via Python script (requires matrix-nio)"
echo "  python3 scripts/invite-missing-bots.py"
echo ""

echo "================================="
echo "🔍 Check Current Members:"
echo "================================="
echo ""
echo "To see who's currently in the room, you can:"
echo "1. Open Element Web and check the member list"
echo "2. Use the Matrix API (requires access token)"
echo ""

# Show the Matrix IDs in a format easy to copy
echo "================================="
echo "📋 Matrix IDs (for easy copying):"
echo "================================="
echo ""
jq -r '.[].matrix_id' matrix-bot-credentials.json | sort
