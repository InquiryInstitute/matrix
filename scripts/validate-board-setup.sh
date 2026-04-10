#!/bin/bash
# Validate Board of Directors setup
# Checks configuration, Docker containers, and bot accounts

set -e

MATRIX_DIR="$(pwd)"
CREDENTIALS_FILE="matrix-bot-credentials.json"

echo "🔷 Board of Directors Setup Validation"
echo "========================================"
echo ""

# Check 1: Docker containers
echo "🐳 Check 1: Docker Containers"
if docker ps | grep -q "matrix-synapse"; then
    echo "   ✅ Synapse container is running"
    SYNAPSE_RUNNING=true
else
    echo "   ❌ Synapse container is not running"
    echo "   → Start with: docker-compose up -d"
    SYNAPSE_RUNNING=false
fi

if docker ps | grep -q "matrix-postgres"; then
    echo "   ✅ PostgreSQL container is running"
else
    echo "   ⚠️  PostgreSQL container is not running"
fi

if docker ps | grep -q "matrix-element"; then
    echo "   ✅ Element Web container is running"
else
    echo "   ⚠️  Element Web container is not running"
fi

# Check 2: Matrix server health
echo ""
echo "🏥 Check 2: Matrix Server Health"
if curl -s -f http://localhost:8008/health > /dev/null 2>&1; then
    echo "   ✅ Matrix server is healthy"
    SERVER_HEALTHY=true
else
    echo "   ❌ Matrix server is not responding"
    echo "   → Check: docker-compose logs synapse"
    SERVER_HEALTHY=false
fi

# Check 3: Bot credentials file
echo ""
echo "📋 Check 3: Bot Credentials"
if [ -f "${CREDENTIALS_FILE}" ]; then
    echo "   ✅ Bot credentials file exists"
    
    # Count bots
    BOT_COUNT=$(jq '. | length' "${CREDENTIALS_FILE}" 2>/dev/null || echo "0")
    echo "   📊 Total bots configured: ${BOT_COUNT}"
    
    # Check for custodian
    if jq -e '.[] | select(.username | contains("custodian"))' "${CREDENTIALS_FILE}" > /dev/null 2>&1; then
        echo "   ✅ Custodian bot is configured"
        CUSTODIAN_USERNAME=$(jq -r '.[] | select(.username | contains("custodian")) | .username' "${CREDENTIALS_FILE}")
        CUSTODIAN_ID=$(jq -r '.[] | select(.username | contains("custodian")) | .matrix_id' "${CREDENTIALS_FILE}")
        echo "      Username: ${CUSTODIAN_USERNAME}"
        echo "      Matrix ID: ${CUSTODIAN_ID}"
    else
        echo "   ⚠️  Custodian bot not found in credentials"
        echo "   → Run: python3 scripts/create-matrix-bots.py"
    fi
    
    # List all director bots
    echo ""
    echo "   👥 Director Bots:"
    jq -r '.[] | select(.username | contains("Director")) | "      - \(.username) (\(.matrix_id))"' "${CREDENTIALS_FILE}" 2>/dev/null || echo "      None found"
    
else
    echo "   ❌ Bot credentials file not found"
    echo "   → Run: python3 scripts/create-matrix-bots.py"
    BOT_COUNT=0
fi

# Check 4: Verify bot accounts exist (if server is running)
echo ""
echo "🤖 Check 4: Bot Account Registration"
if [ "${SYNAPSE_RUNNING}" = true ] && [ -f "${CREDENTIALS_FILE}" ]; then
    echo "   🔍 Checking bot accounts in Synapse..."
    
    # Check custodian
    if [ -n "${CUSTODIAN_USERNAME}" ]; then
        if docker-compose exec -T synapse sqlite3 /data/homeserver.db "SELECT name FROM users WHERE name LIKE '%${CUSTODIAN_USERNAME}%';" 2>/dev/null | grep -q "${CUSTODIAN_USERNAME}"; then
            echo "   ✅ Custodian account exists in database"
        else
            echo "   ⚠️  Custodian account not found in database"
            echo "   → Register with: docker-compose exec synapse register_new_matrix_user -c /data/homeserver.yaml http://localhost:8008 -u ${CUSTODIAN_USERNAME} -p <password>"
        fi
    fi
    
    # Count registered director bots
    REGISTERED_COUNT=$(docker-compose exec -T synapse sqlite3 /data/homeserver.db "SELECT COUNT(*) FROM users WHERE name LIKE '%Director%';" 2>/dev/null || echo "0")
    echo "   📊 Registered director bots: ${REGISTERED_COUNT}"
    
else
    echo "   ⏭️  Skipping (server not running or no credentials)"
fi

# Check 5: Python dependencies
echo ""
echo "🐍 Check 5: Python Dependencies"
if python3 -c "import nio" 2>/dev/null; then
    echo "   ✅ matrix-nio is installed"
else
    echo "   ⚠️  matrix-nio is not installed"
    echo "   → Install with: pip3 install matrix-nio"
fi

if [ -f "requirements-matrix.txt" ]; then
    echo "   ✅ requirements-matrix.txt exists"
    echo "   → Install all: pip3 install -r requirements-matrix.txt"
else
    echo "   ⚠️  requirements-matrix.txt not found"
fi

# Check 6: Board room (manual check)
echo ""
echo "🏛️  Check 6: Board of Directors Room"
echo "   ℹ️  Manual verification required:"
echo "   1. Open Element Web: http://localhost:8080"
echo "   2. Log in with admin account"
echo "   3. Check if 'Board of Directors' room exists"
echo "   4. Verify all bots are invited/joined:"
if [ -f "${CREDENTIALS_FILE}" ]; then
    jq -r '.[] | .matrix_id' "${CREDENTIALS_FILE}" 2>/dev/null | while read -r matrix_id; do
        echo "      - ${matrix_id}"
    done
fi

# Summary
echo ""
echo "========================================"
echo "📊 Validation Summary"
echo "========================================"
echo ""

CHECKS_PASSED=0
CHECKS_TOTAL=6

[ "${SYNAPSE_RUNNING}" = true ] && ((CHECKS_PASSED++))
[ "${SERVER_HEALTHY}" = true ] && ((CHECKS_PASSED++))
[ -f "${CREDENTIALS_FILE}" ] && ((CHECKS_PASSED++))
[ "${BOT_COUNT}" -gt 0 ] && ((CHECKS_PASSED++))

echo "✅ Checks Passed: ${CHECKS_PASSED}/${CHECKS_TOTAL}"
echo ""

if [ "${CHECKS_PASSED}" -eq "${CHECKS_TOTAL}" ]; then
    echo "🎉 Setup looks good!"
elif [ "${CHECKS_PASSED}" -ge 3 ]; then
    echo "⚠️  Setup is partially complete"
else
    echo "❌ Setup needs attention"
fi

echo ""
echo "📚 Next Steps:"
echo ""

if [ "${SYNAPSE_RUNNING}" != true ]; then
    echo "1. Start Matrix server:"
    echo "   docker-compose up -d"
    echo ""
fi

if [ ! -f "${CREDENTIALS_FILE}" ] || [ "${BOT_COUNT}" -eq 0 ]; then
    echo "2. Create bot accounts:"
    echo "   python3 scripts/create-matrix-bots.py"
    echo ""
fi

echo "3. Create Board of Directors room:"
echo "   - Open http://localhost:8080"
echo "   - Create room: 'Inquiry Institute Board of Directors'"
echo "   - Invite all bots (see list above)"
echo ""

echo "4. Test bot communication:"
echo "   python3 scripts/validate-board-communication.py"
echo ""

echo "5. Start a director bot:"
echo "   export DIRECTOR_NAME=aetica"
echo "   export MATRIX_PASSWORD=<bot_password>"
echo "   python3 scripts/matrix-director-bot.py"
echo ""

echo "✅ Validation complete!"
