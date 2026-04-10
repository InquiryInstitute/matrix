#!/bin/bash
# Complete Board of Directors setup
# This script runs all setup steps in sequence

set -e

echo "🔷 Complete Board of Directors Setup"
echo "====================================="
echo ""
echo "This script will:"
echo "  1. Ensure Matrix server is running"
echo "  2. Install Python dependencies"
echo "  3. Create all bot accounts (13 bots)"
echo "  4. Create the Board of Directors room"
echo "  5. Invite all bots to the room"
echo "  6. Validate the setup"
echo ""
read -p "Continue? (y/N): " CONTINUE

if [ "${CONTINUE}" != "y" ] && [ "${CONTINUE}" != "Y" ]; then
    echo "Setup cancelled"
    exit 0
fi

echo ""
echo "================================="
echo "Step 1: Ensure Matrix is Running"
echo "================================="
./scripts/ensure-matrix-running.sh

echo ""
echo "================================="
echo "Step 2: Install Python Dependencies"
echo "================================="
if python3 -c "import nio" 2>/dev/null; then
    echo "✅ matrix-nio already installed"
else
    echo "📦 Installing matrix-nio..."
    pip3 install -r requirements-matrix.txt
fi

echo ""
echo "================================="
echo "Step 3: Create Bot Accounts"
echo "================================="
if [ -f "matrix-bot-credentials.json" ]; then
    echo "⚠️  Bot credentials file already exists"
    read -p "Recreate bots? This may fail if bots already exist (y/N): " RECREATE
    if [ "${RECREATE}" = "y" ] || [ "${RECREATE}" = "Y" ]; then
        python3 scripts/create-matrix-bots.py
    else
        echo "Skipping bot creation"
    fi
else
    python3 scripts/create-matrix-bots.py
fi

echo ""
echo "================================="
echo "Step 4: Create Board Room"
echo "================================="
echo ""
echo "To create the board room, we need admin credentials."
echo ""

# Check if credentials are in environment
if [ -z "${ADMIN_USERNAME}" ] || [ -z "${ADMIN_PASSWORD}" ]; then
    read -p "Admin username: " ADMIN_USERNAME
    read -s -p "Admin password: " ADMIN_PASSWORD
    echo ""
    export ADMIN_USERNAME
    export ADMIN_PASSWORD
fi

echo ""
echo "Creating room and inviting bots..."
python3 scripts/create-board-room.py

echo ""
echo "================================="
echo "Step 5: Validate Setup"
echo "================================="
./scripts/validate-board-setup.sh

echo ""
echo "================================="
echo "✅ Setup Complete!"
echo "================================="
echo ""
echo "📚 Next Steps:"
echo ""
echo "1. Open Element Web: http://localhost:8080"
echo "   - You should see the 'Board of Directors' room"
echo "   - All 13 bots should be invited"
echo ""
echo "2. Start the custodian bot:"
echo "   ./scripts/start-custodian-bot.sh"
echo ""
echo "3. Start a director bot (in another terminal):"
echo "   export DIRECTOR_NAME=aetica"
echo "   export MATRIX_PASSWORD=<password_from_credentials>"
echo "   python3 scripts/matrix-director-bot.py"
echo ""
echo "4. Test communication in Element Web"
echo "   - Send a message in the board room"
echo "   - Mention a bot: @aCustodian.custodian"
echo "   - Verify bots respond"
echo ""
echo "5. (Optional) Install autostart:"
echo "   ./scripts/install-autostart.sh"
echo ""
echo "📖 Documentation:"
echo "   - SETUP_COMPLETE.md - Overview and quick start"
echo "   - MATRIX_ALWAYS_ON.md - Always-running configuration"
echo "   - CREATE_ROOM_GUIDE.md - Room creation details"
echo "   - QUICK_REFERENCE.md - Command reference"
echo ""
echo "✅ Your Board of Directors is ready!"
