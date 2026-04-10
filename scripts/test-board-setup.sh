#!/bin/bash
# Test the board setup
# This script waits for Docker and then runs all validation tests

set -e

echo "🧪 Testing Board of Directors Setup"
echo "===================================="
echo ""

# Wait for Docker to be ready
echo "⏳ Waiting for Docker to be ready..."
MAX_WAIT=60
WAITED=0

while [ $WAITED -lt $MAX_WAIT ]; do
    if docker info > /dev/null 2>&1; then
        echo "✅ Docker is ready"
        break
    fi
    echo "   Waiting... (${WAITED}s)"
    sleep 5
    WAITED=$((WAITED + 5))
done

if [ $WAITED -ge $MAX_WAIT ]; then
    echo "❌ Docker did not start within ${MAX_WAIT} seconds"
    echo ""
    echo "Please start Docker manually:"
    echo "  - Mac: Open Docker Desktop"
    echo "  - Linux: sudo systemctl start docker"
    exit 1
fi

echo ""
echo "================================="
echo "Test 1: Matrix Server Status"
echo "================================="
./scripts/ensure-matrix-running.sh

echo ""
echo "================================="
echo "Test 2: Configuration Validation"
echo "================================="
./scripts/validate-board-setup.sh

echo ""
echo "================================="
echo "Test 3: Bot Credentials Check"
echo "================================="
if [ -f "matrix-bot-credentials.json" ]; then
    echo "✅ Bot credentials file exists"
    
    BOT_COUNT=$(jq '. | length' matrix-bot-credentials.json 2>/dev/null || echo "0")
    echo "   Total bots: ${BOT_COUNT}"
    
    # Check for special bots
    echo ""
    echo "   Special Bots:"
    for bot in custodian parliamentarian hypatia; do
        if jq -e ".[] | select(.username | contains(\"${bot}\"))" matrix-bot-credentials.json > /dev/null 2>&1; then
            USERNAME=$(jq -r ".[] | select(.username | contains(\"${bot}\")) | .username" matrix-bot-credentials.json)
            echo "   ✅ ${bot}: ${USERNAME}"
        else
            echo "   ❌ ${bot}: Not found"
        fi
    done
    
    # Count directors
    echo ""
    DIRECTOR_COUNT=$(jq '[.[] | select(.username | contains("Director"))] | length' matrix-bot-credentials.json 2>/dev/null || echo "0")
    echo "   Director bots: ${DIRECTOR_COUNT}/10"
else
    echo "⚠️  Bot credentials file not found"
    echo "   Run: python3 scripts/create-matrix-bots.py"
fi

echo ""
echo "================================="
echo "Test 4: Python Dependencies"
echo "================================="
if python3 -c "import nio" 2>/dev/null; then
    echo "✅ matrix-nio is installed"
    PYTHON_VERSION=$(python3 -c "import nio; print(nio.__version__)" 2>/dev/null || echo "unknown")
    echo "   Version: ${PYTHON_VERSION}"
else
    echo "❌ matrix-nio is not installed"
    echo "   Install: pip3 install -r requirements-matrix.txt"
fi

echo ""
echo "================================="
echo "Test 5: Docker Compose Configuration"
echo "================================="
if [ -f "docker-compose.yml" ]; then
    echo "✅ docker-compose.yml exists"
    
    # Check restart policy
    if grep -q "restart: always" docker-compose.yml; then
        echo "✅ Restart policy set to 'always'"
    else
        echo "⚠️  Restart policy not set to 'always'"
    fi
    
    # Check services
    echo ""
    echo "   Services configured:"
    grep "^  [a-z]" docker-compose.yml | grep -v "^  #" | sed 's/:$//' | while read -r service; do
        echo "   - ${service}"
    done
else
    echo "❌ docker-compose.yml not found"
fi

echo ""
echo "================================="
echo "Test 6: Scripts Executable"
echo "================================="
SCRIPTS=(
    "ensure-matrix-running.sh"
    "validate-board-setup.sh"
    "create-matrix-bots.py"
    "create-board-room.py"
    "validate-board-communication.py"
    "start-custodian-bot.sh"
    "install-autostart.sh"
    "setup-board-complete.sh"
)

for script in "${SCRIPTS[@]}"; do
    if [ -x "scripts/${script}" ]; then
        echo "   ✅ ${script}"
    else
        echo "   ❌ ${script} (not executable)"
    fi
done

echo ""
echo "================================="
echo "Test 7: Documentation Files"
echo "================================="
DOCS=(
    "README.md"
    "SETUP_COMPLETE.md"
    "MATRIX_ALWAYS_ON.md"
    "CREATE_ROOM_GUIDE.md"
    "BOARD_VALIDATION_GUIDE.md"
    "QUICK_REFERENCE.md"
)

for doc in "${DOCS[@]}"; do
    if [ -f "${doc}" ]; then
        echo "   ✅ ${doc}"
    else
        echo "   ❌ ${doc}"
    fi
done

echo ""
echo "================================="
echo "📊 Test Summary"
echo "================================="
echo ""

# Count checks
TOTAL_TESTS=7
PASSED_TESTS=0

docker info > /dev/null 2>&1 && ((PASSED_TESTS++))
[ -f "docker-compose.yml" ] && ((PASSED_TESTS++))
[ -f "README.md" ] && ((PASSED_TESTS++))
[ -x "scripts/ensure-matrix-running.sh" ] && ((PASSED_TESTS++))

echo "Tests completed: ${PASSED_TESTS}/${TOTAL_TESTS} major checks passed"
echo ""

if docker ps | grep -q "matrix-synapse"; then
    echo "✅ Matrix server is running"
    echo "   Access: http://localhost:8080"
else
    echo "⚠️  Matrix server is not running yet"
    echo "   Start: docker-compose up -d"
fi

echo ""
echo "📚 Next Steps:"
echo ""

if [ ! -f "matrix-bot-credentials.json" ]; then
    echo "1. Create bot accounts:"
    echo "   python3 scripts/create-matrix-bots.py"
    echo ""
fi

if ! docker ps | grep -q "matrix-synapse"; then
    echo "2. Start Matrix server:"
    echo "   docker-compose up -d"
    echo ""
fi

echo "3. Create board room:"
echo "   python3 scripts/create-board-room.py"
echo ""

echo "4. Test communication:"
echo "   python3 scripts/validate-board-communication.py"
echo ""

echo "✅ Testing complete!"
