#!/bin/bash
# Start the custodian bot
# This is a convenience wrapper around matrix-director-bot.py
# Password: CUSTODIAN_PASSWORD from .env if set, else matrix-bot-credentials.json

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/load-dotenv.sh"

CREDENTIALS_FILE="matrix-bot-credentials.json"

echo "🤖 Starting Custodian Bot"
echo "========================="
echo ""

# Check if credentials file exists
if [ ! -f "${CREDENTIALS_FILE}" ]; then
    echo "❌ Bot credentials file not found: ${CREDENTIALS_FILE}"
    echo "   Run: python3 scripts/create-matrix-bots.py"
    exit 1
fi

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo "⚠️  jq not installed, using manual configuration"
    echo ""
    echo "Please set environment variables manually:"
    echo "  export MATRIX_PASSWORD=<custodian_password>"
    echo "  or CUSTODIAN_PASSWORD in .env"
    echo "  export DIRECTOR_NAME=custodian"
    echo ""

    if [ -z "${MATRIX_PASSWORD}" ] && [ -z "${CUSTODIAN_PASSWORD:-}" ]; then
        echo "❌ MATRIX_PASSWORD or CUSTODIAN_PASSWORD not set"
        exit 1
    fi

    export DIRECTOR_NAME=custodian
    export MATRIX_PASSWORD="${MATRIX_PASSWORD:-${CUSTODIAN_PASSWORD}}"
else
    # Extract custodian credentials
    CUSTODIAN_USERNAME=$(jq -r '.[] | select(.username | contains("custodian")) | .username' "${CREDENTIALS_FILE}")
    CUSTODIAN_PASSWORD_JSON=$(jq -r '.[] | select(.username | contains("custodian")) | .password' "${CREDENTIALS_FILE}")
    CUSTODIAN_ID=$(jq -r '.[] | select(.username | contains("custodian")) | .matrix_id' "${CREDENTIALS_FILE}")

    if [ -z "${CUSTODIAN_USERNAME}" ]; then
        echo "❌ Custodian not found in credentials file"
        echo "   Run: python3 scripts/create-matrix-bots.py"
        exit 1
    fi

    PW_FROM_ENV="${CUSTODIAN_PASSWORD:-}"
    if [ -n "${PW_FROM_ENV}" ]; then
        CUSTODIAN_PASSWORD="${PW_FROM_ENV}"
    else
        CUSTODIAN_PASSWORD="${CUSTODIAN_PASSWORD_JSON}"
    fi

    echo "📋 Custodian Configuration:"
    echo "   Username: ${CUSTODIAN_USERNAME}"
    echo "   Matrix ID: ${CUSTODIAN_ID}"
    if [ -n "${PW_FROM_ENV}" ]; then
        echo "   Password: from .env CUSTODIAN_PASSWORD (${#CUSTODIAN_PASSWORD} chars)"
    else
        echo "   Password: ${CUSTODIAN_PASSWORD:0:10}... (from ${CREDENTIALS_FILE})"
    fi
    echo ""

    # Set environment variables
    export DIRECTOR_NAME=custodian
    export MATRIX_PASSWORD="${CUSTODIAN_PASSWORD}"
fi

# Check if Matrix server is running
echo "🔍 Checking Matrix server..."
if curl -s -f http://localhost:8008/health > /dev/null 2>&1; then
    echo "   ✅ Matrix server is running"
else
    echo "   ❌ Matrix server is not responding"
    echo "   → Start with: docker-compose up -d"
    exit 1
fi

# Check Python dependencies
echo ""
echo "🐍 Checking Python dependencies..."
if python3 -c "import nio" 2>/dev/null; then
    echo "   ✅ matrix-nio is installed"
else
    echo "   ❌ matrix-nio is not installed"
    echo "   → Install with: pip3 install -r requirements-matrix.txt"
    exit 1
fi

# Start the bot
echo ""
echo "🚀 Starting custodian bot..."
echo "   Press Ctrl+C to stop"
echo ""

python3 scripts/matrix-director-bot.py
