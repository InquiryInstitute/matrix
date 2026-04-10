#!/bin/bash
# Make custodian a server admin via Fly.io SSH

echo "🔷 Make Custodian Server Admin (via Fly.io)"
echo "============================================"
echo ""

# Check if fly CLI is installed
if ! command -v fly &> /dev/null; then
    echo "❌ Fly CLI not installed"
    echo ""
    echo "Install it:"
    echo "  brew install flyctl"
    echo "  # or"
    echo "  curl -L https://fly.io/install.sh | sh"
    exit 1
fi

echo "✅ Fly CLI found"
echo ""

# Get app name
read -p "Enter your Fly.io Matrix app name: " APP_NAME

if [ -z "${APP_NAME}" ]; then
    echo "❌ App name required"
    exit 1
fi

echo ""
echo "🔄 Connecting to Fly.io and making custodian admin..."
echo ""

# Run the command via Fly SSH
fly ssh console -a "${APP_NAME}" -C "
echo '🔐 Making custodian a server admin...'
register_new_matrix_user \
  -c /data/homeserver.yaml \
  https://matrix.inquiry.institute \
  -u custodian \
  -p bot_custodian_password_change_me \
  --admin \
  --no-admin=false
echo '✅ Done!'
"

echo ""
echo "=================================="
echo "📚 Next Steps"
echo "=================================="
echo ""
echo "1. Verify custodian is admin (should see success message above)"
echo "2. Now custodian can invite bots to rooms"
echo "3. Run: export MATRIX_ACCESS_TOKEN=syt_Y3VzdG9kaWFu_zRVlGHXPcdbLwgQmuNVD_4bHFgR"
echo "4. Run: ./scripts/auto-invite-bots.sh"
