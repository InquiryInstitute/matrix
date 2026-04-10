#!/bin/bash
# Start the custodian bot
# This is a convenience wrapper around matrix-director-bot.py

set -e

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
    echo "  export DIRECTOR_NAME=custodian"
    echo ""
    
    # Check if password is set
    if [ -z "${MATRIX_PASSWORD}" ]; then
        echo "❌ MATRIX_PASSWORD not set"
        exit 1
    fi
    
    export DIRECTOR_NAME=custodian
else
    # Extract custodian credentials
    CUSTODIAN_USERNAME=$(jq -r '.[] | select(.username | contains("custodian")) | .username' "${CREDENTIALS_FILE}")
    CUSTODIAN_PASSWORD=$(jq -r '.[] | select(.username | contains("custodian")) | .password' "${CREDENTIALS_FILE}")
    CUSTODIAN_ID=$(jq -r '.[] | select(.username | contains("custodian")) | .matrix_id' "${CREDENTIALS_FILE}")
    
    if [ -z "${CUSTODIAN_USERNAME}" ]; then
        echo "❌ Custodian not found in credentials file"
        echo "   Run: python3 scripts/create-matrix-bots.py"
        exit 1
    fi
    
    echo "📋 Custodian Configuration:"
    echo "   Username: ${CUSTODIAN_USERNAME}"
    echo "   Matrix ID: ${CUSTODIAN_ID}"
    echo "   Password: ${CUSTODIAN_PASSWORD:0:10}..."
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
