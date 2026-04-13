#!/bin/bash
# Validate remote Matrix server (Fly.io)
# This script checks the remote Matrix server instead of local Docker

set -e

# Load environment variables
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
fi

MATRIX_SERVER="${MATRIX_SERVER_URL:-https://matrix.castalia.institute}"
MATRIX_DOMAIN="${MATRIX_DOMAIN:-matrix.castalia.institute}"

echo "🔷 Remote Matrix Server Validation"
echo "===================================="
echo ""
echo "Server: ${MATRIX_SERVER}"
echo "Domain: ${MATRIX_DOMAIN}"
echo ""

# Check 1: Server accessibility
echo "🌐 Check 1: Server Accessibility"
if curl -s -f "${MATRIX_SERVER}/_matrix/client/versions" > /dev/null 2>&1; then
    echo "   ✅ Matrix server is accessible"
    VERSION_INFO=$(curl -s "${MATRIX_SERVER}/_matrix/client/versions" | jq -r '.versions[-1]' 2>/dev/null || echo "unknown")
    echo "   Latest API version: ${VERSION_INFO}"
else
    echo "   ❌ Matrix server is not accessible"
    echo "   → Check: ${MATRIX_SERVER}"
    exit 1
fi

# Check 2: Well-known configuration
echo ""
echo "🔍 Check 2: Well-Known Configuration"
if curl -s -f "https://${MATRIX_DOMAIN}/.well-known/matrix/client" > /dev/null 2>&1; then
    echo "   ✅ Well-known client configuration found"
    HOMESERVER=$(curl -s "https://${MATRIX_DOMAIN}/.well-known/matrix/client" | jq -r '.["m.homeserver"].base_url' 2>/dev/null || echo "unknown")
    echo "   Homeserver: ${HOMESERVER}"
else
    echo "   ⚠️  Well-known configuration not found (may be optional)"
fi

# Check 3: Bot credentials
echo ""
echo "📋 Check 3: Bot Credentials"
if [ -f "matrix-bot-credentials.json" ]; then
    echo "   ✅ Bot credentials file exists"
    
    BOT_COUNT=$(jq '. | length' matrix-bot-credentials.json 2>/dev/null || echo "0")
    echo "   Total bots: ${BOT_COUNT}"
    
    # Check for special bots
    echo ""
    echo "   Special Bots:"
    for bot in custodian parliamentarian hypatia; do
        if jq -e ".[] | select(.username | contains(\"${bot}\"))" matrix-bot-credentials.json > /dev/null 2>&1; then
            USERNAME=$(jq -r ".[] | select(.username | contains(\"${bot}\")) | .username" matrix-bot-credentials.json)
            MATRIX_ID=$(jq -r ".[] | select(.username | contains(\"${bot}\")) | .matrix_id" matrix-bot-credentials.json)
            echo "   ✅ ${bot}"
            echo "      Username: ${USERNAME}"
            echo "      Matrix ID: ${MATRIX_ID}"
        else
            echo "   ❌ ${bot}: Not found"
        fi
    done
    
    # Count director-role bots (naming convention: "Director" in username)
    echo ""
    DIRECTOR_COUNT=$(jq '[.[] | select(.username | contains("Director"))] | length' matrix-bot-credentials.json 2>/dev/null || echo "0")
    echo "   Director bots (aDirector.* in credentials): ${DIRECTOR_COUNT}"
    if [ "${DIRECTOR_COUNT}" -ge 1 ]; then
        echo "   ✅ At least one director bot present (see matrix-bot-credentials.json for full list)"
    else
        echo "   ⚠️  No director bots found — add bots or regenerate credentials"
    fi
else
    echo "   ❌ Bot credentials file not found"
    echo "   → Run: python3 scripts/create-matrix-bots.py"
fi

# Check 4: Python dependencies
echo ""
echo "🐍 Check 4: Python Dependencies"
if python3 -c "import nio" 2>/dev/null; then
    echo "   ✅ matrix-nio is installed"
    PYTHON_VERSION=$(python3 -c "import nio; print(nio.__version__)" 2>/dev/null || echo "unknown")
    echo "   Version: ${PYTHON_VERSION}"
else
    echo "   ❌ matrix-nio is not installed"
    echo "   → Install: pip3 install -r requirements-matrix.txt"
fi

# Check 5: Element Web (if configured)
echo ""
echo "🎨 Check 5: Element Web Client"
ELEMENT_URL="https://element.castalia.institute"
if curl -s -f "${ELEMENT_URL}" > /dev/null 2>&1; then
    echo "   ✅ Element Web is accessible"
    echo "   URL: ${ELEMENT_URL}"
else
    echo "   ⚠️  Element Web not accessible at ${ELEMENT_URL}"
    echo "   You can use: https://app.element.io"
fi

# Check 6: Registration capability
echo ""
echo "🔐 Check 6: User Registration"
REG_INFO=$(curl -s "${MATRIX_SERVER}/_matrix/client/r0/register" | jq -r '.flows[0].stages[0]' 2>/dev/null || echo "unknown")
if [ "${REG_INFO}" != "unknown" ]; then
    echo "   ✅ Registration endpoint accessible"
    echo "   Flow: ${REG_INFO}"
else
    echo "   ⚠️  Registration info not available"
fi

# Summary
echo ""
echo "===================================="
echo "📊 Validation Summary"
echo "===================================="
echo ""

if curl -s -f "${MATRIX_SERVER}/_matrix/client/versions" > /dev/null 2>&1; then
    echo "✅ Remote Matrix server is operational"
    echo ""
    echo "📚 Next Steps:"
    echo ""
    
    if [ ! -f "matrix-bot-credentials.json" ]; then
        echo "1. Create bot accounts:"
        echo "   python3 scripts/create-matrix-bots.py"
        echo ""
    fi
    
    echo "2. Create board room:"
    echo "   python3 scripts/create-board-room.py"
    echo ""
    
    echo "3. Test bot communication (custodian smoke test; avoids login rate limits):"
    echo "   python3 scripts/validate-board-communication.py"
    echo "   # Full matrix: VALIDATE_BOARD_MODE=all VALIDATE_LOGIN_DELAY_SEC=5 python3 scripts/validate-board-communication.py"
    echo ""
    
    echo "4. Access Element Web:"
    echo "   https://app.element.io"
    echo "   Or: ${ELEMENT_URL}"
    echo ""
    
    echo "5. Start bots:"
    echo "   ./scripts/start-custodian-bot.sh"
else
    echo "❌ Remote Matrix server is not accessible"
    echo ""
    echo "Troubleshooting:"
    echo "1. Check Fly.io app status: fly status"
    echo "2. Check Fly.io logs: fly logs"
    echo "3. Verify DNS: dig matrix.castalia.institute"
fi

echo ""
echo "✅ Validation complete!"
