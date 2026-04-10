#!/bin/bash
# Install Matrix autostart service
# This ensures Matrix server starts automatically when the system boots

set -e

MATRIX_DIR="$(pwd)"
USERNAME=$(whoami)
HOME_DIR="${HOME}"

echo "🔷 Matrix Autostart Installation"
echo "================================="
echo ""
echo "This will configure Matrix to start automatically when your system boots."
echo ""

# Detect OS
if [[ "$OSTYPE" == "darwin"* ]]; then
    OS="macos"
    echo "📱 Detected: macOS"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    OS="linux"
    echo "🐧 Detected: Linux"
else
    echo "❌ Unsupported OS: $OSTYPE"
    exit 1
fi

echo ""

# macOS Installation
if [ "$OS" = "macos" ]; then
    echo "🍎 Installing macOS LaunchAgent..."
    
    # Create logs directory
    mkdir -p "${MATRIX_DIR}/logs"
    
    # Update plist with actual paths
    PLIST_FILE="${HOME_DIR}/Library/LaunchAgents/com.inquiryinstitute.matrix.plist"
    
    # Find docker-compose path
    DOCKER_COMPOSE_PATH=$(which docker-compose || echo "/usr/local/bin/docker-compose")
    
    cat > "${PLIST_FILE}" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.inquiryinstitute.matrix</string>
    
    <key>ProgramArguments</key>
    <array>
        <string>${DOCKER_COMPOSE_PATH}</string>
        <string>-f</string>
        <string>${MATRIX_DIR}/docker-compose.yml</string>
        <string>up</string>
        <string>-d</string>
    </array>
    
    <key>WorkingDirectory</key>
    <string>${MATRIX_DIR}</string>
    
    <key>RunAtLoad</key>
    <true/>
    
    <key>KeepAlive</key>
    <false/>
    
    <key>StandardOutPath</key>
    <string>${MATRIX_DIR}/logs/matrix-autostart.log</string>
    
    <key>StandardErrorPath</key>
    <string>${MATRIX_DIR}/logs/matrix-autostart.error.log</string>
    
    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
    </dict>
</dict>
</plist>
EOF
    
    echo "   ✅ Created LaunchAgent: ${PLIST_FILE}"
    
    # Load the LaunchAgent
    launchctl unload "${PLIST_FILE}" 2>/dev/null || true
    launchctl load "${PLIST_FILE}"
    
    echo "   ✅ LaunchAgent loaded"
    echo ""
    echo "📚 LaunchAgent Commands:"
    echo "   Start:   launchctl start com.inquiryinstitute.matrix"
    echo "   Stop:    launchctl stop com.inquiryinstitute.matrix"
    echo "   Unload:  launchctl unload ${PLIST_FILE}"
    echo "   Logs:    tail -f ${MATRIX_DIR}/logs/matrix-autostart.log"
    
# Linux Installation
elif [ "$OS" = "linux" ]; then
    echo "🐧 Installing systemd service..."
    
    # Find docker-compose path
    DOCKER_COMPOSE_PATH=$(which docker-compose || echo "/usr/bin/docker-compose")
    
    SERVICE_FILE="/etc/systemd/system/matrix-homeserver.service"
    
    # Create service file content
    SERVICE_CONTENT="[Unit]
Description=Matrix Homeserver (Synapse)
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=${MATRIX_DIR}
ExecStart=${DOCKER_COMPOSE_PATH} up -d
ExecStop=${DOCKER_COMPOSE_PATH} down
TimeoutStartSec=0
User=${USERNAME}

[Install]
WantedBy=multi-user.target"
    
    # Write service file (requires sudo)
    echo "${SERVICE_CONTENT}" | sudo tee "${SERVICE_FILE}" > /dev/null
    
    echo "   ✅ Created systemd service: ${SERVICE_FILE}"
    
    # Reload systemd
    sudo systemctl daemon-reload
    
    # Enable service
    sudo systemctl enable matrix-homeserver.service
    
    echo "   ✅ Service enabled"
    echo ""
    echo "📚 Systemd Commands:"
    echo "   Start:   sudo systemctl start matrix-homeserver"
    echo "   Stop:    sudo systemctl stop matrix-homeserver"
    echo "   Status:  sudo systemctl status matrix-homeserver"
    echo "   Disable: sudo systemctl disable matrix-homeserver"
    echo "   Logs:    sudo journalctl -u matrix-homeserver -f"
fi

echo ""
echo "================================="
echo "✅ Autostart Installation Complete"
echo "================================="
echo ""
echo "Matrix will now start automatically when your system boots."
echo ""
echo "To start Matrix now:"
echo "  docker-compose up -d"
echo ""
echo "To verify it's running:"
echo "  ./scripts/ensure-matrix-running.sh"
