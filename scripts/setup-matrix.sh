#!/bin/bash
# Setup script for Matrix chat server (Synapse)
# This script clones the repository and sets up Matrix server

set -e

MATRIX_DIR="${HOME}/GitHub/matrix"
REPO_URL="https://github.com/InquiryInstitute/matrix.git"

echo "🔷 Setting up Matrix chat server"
echo "Repository: ${REPO_URL}"
echo "Directory: ${MATRIX_DIR}"
echo ""

# Step 1: Clone repository if it doesn't exist
if [ ! -d "${MATRIX_DIR}" ]; then
    echo "📥 Step 1: Cloning Matrix repository..."
    mkdir -p "${HOME}/GitHub"
    git clone "${REPO_URL}" "${MATRIX_DIR}"
    echo "✅ Repository cloned"
else
    echo "✅ Repository already exists at ${MATRIX_DIR}"
    cd "${MATRIX_DIR}"
    echo "🔄 Updating repository..."
    git pull || true
fi

cd "${MATRIX_DIR}"

# Step 2: Check if docker-compose exists
if [ ! -f "docker-compose.yml" ]; then
    echo ""
    echo "📝 Step 2: Creating docker-compose.yml..."
    # We'll copy it from the Inquiry.Institute project
    if [ -f "${HOME}/GitHub/Inquiry.Institute/docker-compose.matrix.yml" ]; then
        cp "${HOME}/GitHub/Inquiry.Institute/docker-compose.matrix.yml" docker-compose.yml
    else
        echo "⚠️  docker-compose.yml not found. Creating default configuration..."
    fi
fi

# Step 3: Generate configuration
echo ""
echo "⚙️  Step 3: Generating Matrix server configuration..."

if [ ! -f "matrix-data/homeserver.yaml" ]; then
    echo "Generating homeserver.yaml..."
    mkdir -p "${MATRIX_DIR}/matrix-data"
    docker run -it --rm \
        -v "${MATRIX_DIR}/matrix-data:/data" \
        -e SYNAPSE_SERVER_NAME=matrix.inquiry.institute \
        -e SYNAPSE_REPORT_STATS=no \
        matrixdotorg/synapse:latest generate
    echo "✅ Configuration generated"
else
    echo "✅ Configuration already exists"
fi

# Step 4: Set permissions
echo ""
echo "🔐 Step 4: Setting up permissions..."
mkdir -p "${MATRIX_DIR}/matrix-data"
chmod -R 777 "${MATRIX_DIR}/matrix-data" 2>/dev/null || true

# Step 5: Start services
echo ""
echo "🚀 Step 5: Starting Matrix server..."
echo ""
echo "To start the Matrix server, run:"
echo "  cd ${MATRIX_DIR}"
echo "  docker-compose up -d"
echo ""
echo "To view logs:"
echo "  docker-compose logs -f"
echo ""
echo "To stop the Matrix server:"
echo "  docker-compose down"
echo ""
echo "✅ Setup complete!"
echo ""
echo "Next steps:"
echo "1. Configure Supabase OIDC (recommended):"
echo "   ./scripts/configure-matrix-oidc.sh"
echo ""
echo "2. Or review and configure homeserver.yaml manually"
echo ""
echo "3. Start the server with: docker-compose up -d"
echo ""
echo "4. If not using OIDC, register admin user:"
echo "   docker-compose exec synapse register_new_matrix_user -c /data/homeserver.yaml http://localhost:8008 -a -u admin -p password"
echo ""
echo "5. Access Element web client: http://localhost:8080"
