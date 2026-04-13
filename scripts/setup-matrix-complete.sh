#!/bin/bash
# Complete Matrix server setup with Supabase OIDC
# This script orchestrates the entire setup process

set -e

INQUIRY_DIR="${HOME}/GitHub/Inquiry.Institute"
MATRIX_DIR="${HOME}/GitHub/matrix"
REPO_URL="https://github.com/InquiryInstitute/matrix.git"
SUPABASE_PROJECT_REF="xougqdomkoisrxdnagcj"

echo "🔷 Complete Matrix Server Setup with Supabase OIDC"
echo "=================================================="
echo ""

# Step 1: Check prerequisites
echo "📋 Step 1: Checking prerequisites..."

# Check Docker
if command -v docker &> /dev/null; then
    echo "   ✅ Docker is installed: $(docker --version)"
else
    echo "   ❌ Docker is not installed"
    echo "   → Install Docker: https://docs.docker.com/get-docker/"
    exit 1
fi

# Check Docker Compose
if command -v docker-compose &> /dev/null || docker compose version &> /dev/null; then
    echo "   ✅ Docker Compose is installed"
else
    echo "   ❌ Docker Compose is not installed"
    echo "   → Install Docker Compose: https://docs.docker.com/compose/install/"
    exit 1
fi

# Check Git
if command -v git &> /dev/null; then
    echo "   ✅ Git is installed: $(git --version | cut -d' ' -f3)"
else
    echo "   ❌ Git is not installed"
    exit 1
fi

# Check Python (for bot scripts)
if command -v python3 &> /dev/null; then
    echo "   ✅ Python 3 is installed: $(python3 --version)"
else
    echo "   ⚠️  Python 3 is not installed (needed for bot scripts)"
fi

# Step 2: Clone or create Matrix directory
echo ""
echo "📁 Step 2: Setting up Matrix directory..."

if [ -d "${MATRIX_DIR}" ]; then
    echo "   ✅ Matrix directory already exists: ${MATRIX_DIR}"
    cd "${MATRIX_DIR}"
    if [ -d ".git" ]; then
        echo "   🔄 Updating repository..."
        git pull || echo "   ⚠️  Could not pull updates"
    fi
else
    echo "   📥 Cloning Matrix repository..."
    mkdir -p "${HOME}/GitHub"
    
    # Try to clone repository
    if git clone "${REPO_URL}" "${MATRIX_DIR}" 2>/dev/null; then
        echo "   ✅ Repository cloned successfully"
    else
        echo "   ⚠️  Could not clone repository (may not exist yet)"
        echo "   📁 Creating directory structure manually..."
        mkdir -p "${MATRIX_DIR}"
        echo "   ✅ Directory created: ${MATRIX_DIR}"
    fi
fi

cd "${MATRIX_DIR}"

# Step 3: Copy configuration files
echo ""
echo "📝 Step 3: Copying configuration files..."

# Docker Compose
if [ -f "${INQUIRY_DIR}/docker-compose.matrix.yml" ]; then
    cp "${INQUIRY_DIR}/docker-compose.matrix.yml" docker-compose.yml
    echo "   ✅ docker-compose.yml copied"
else
    echo "   ⚠️  docker-compose.matrix.yml not found in Inquiry.Institute"
fi

# Element config
if [ -f "${INQUIRY_DIR}/element-config.json" ]; then
    cp "${INQUIRY_DIR}/element-config.json" element-config.json
    echo "   ✅ element-config.json copied"
else
    echo "   ⚠️  element-config.json not found in Inquiry.Institute"
fi

# Setup scripts
if [ -f "${INQUIRY_DIR}/scripts/setup-matrix.sh" ]; then
    cp "${INQUIRY_DIR}/scripts/setup-matrix.sh" setup-matrix.sh
    chmod +x setup-matrix.sh
    echo "   ✅ setup-matrix.sh copied"
fi

if [ -f "${INQUIRY_DIR}/scripts/configure-matrix-oidc.sh" ]; then
    cp "${INQUIRY_DIR}/scripts/configure-matrix-oidc.sh" configure-matrix-oidc.sh
    chmod +x configure-matrix-oidc.sh
    echo "   ✅ configure-matrix-oidc.sh copied"
fi

# Bot scripts
if [ -f "${INQUIRY_DIR}/scripts/create-matrix-bots.py" ]; then
    cp "${INQUIRY_DIR}/scripts/create-matrix-bots.py" create-matrix-bots.py
    chmod +x create-matrix-bots.py
    echo "   ✅ create-matrix-bots.py copied"
fi

if [ -f "${INQUIRY_DIR}/scripts/matrix-director-bot.py" ]; then
    cp "${INQUIRY_DIR}/scripts/matrix-director-bot.py" matrix-director-bot.py
    chmod +x matrix-director-bot.py
    echo "   ✅ matrix-director-bot.py copied"
fi

# Requirements
if [ -f "${INQUIRY_DIR}/requirements-matrix.txt" ]; then
    cp "${INQUIRY_DIR}/requirements-matrix.txt" requirements-matrix.txt
    echo "   ✅ requirements-matrix.txt copied"
fi

# Step 4: Generate Synapse configuration
echo ""
echo "⚙️  Step 4: Generating Synapse configuration..."

if [ ! -f "matrix-data/homeserver.yaml" ]; then
    echo "   📝 Generating homeserver.yaml..."
    mkdir -p matrix-data
    
    docker run -it --rm \
        -v "$(pwd)/matrix-data:/data" \
        -e SYNAPSE_SERVER_NAME=matrix.castalia.institute \
        -e SYNAPSE_REPORT_STATS=no \
        matrixdotorg/synapse:latest generate
    
    if [ -f "matrix-data/homeserver.yaml" ]; then
        echo "   ✅ homeserver.yaml generated"
    else
        echo "   ❌ Failed to generate homeserver.yaml"
        exit 1
    fi
else
    echo "   ✅ homeserver.yaml already exists"
fi

# Step 5: Create environment file
echo ""
echo "🔐 Step 5: Creating environment file..."

if [ ! -f ".env" ]; then
    echo "   📝 Creating .env file with secure passwords..."
    
    # Generate secure passwords
    POSTGRES_PASSWORD=$(openssl rand -base64 32 2>/dev/null || echo "change_me_secure_password_$(date +%s)")
    REDIS_PASSWORD=$(openssl rand -base64 32 2>/dev/null || echo "change_me_redis_password_$(date +%s)")
    
    cat > .env << EOF
# Matrix Server Environment Variables
# Generated: $(date)

MATRIX_DOMAIN=matrix.castalia.institute
MATRIX_SERVER_URL=http://localhost:8008
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
REDIS_PASSWORD=${REDIS_PASSWORD}
SYNAPSE_REPORT_STATS=no
EOF
    
    echo "   ✅ .env file created"
    echo "   💾 Save these passwords securely!"
    echo "   PostgreSQL Password: ${POSTGRES_PASSWORD:0:20}..."
    echo "   Redis Password: ${REDIS_PASSWORD:0:20}..."
else
    echo "   ✅ .env file already exists"
fi

# Step 6: Update database passwords in homeserver.yaml
echo ""
echo "🔧 Step 6: Updating database configuration..."

if [ -f "matrix-data/homeserver.yaml" ] && [ -f ".env" ]; then
    source .env
    
    # Update PostgreSQL password if it's still the default
    if grep -q "password.*synapse_password\|password.*change_me" matrix-data/homeserver.yaml; then
        # This is a simplified update - manual editing may be needed
        echo "   ⚠️  Please manually update database passwords in matrix-data/homeserver.yaml"
        echo "   → Set database password to: ${POSTGRES_PASSWORD:0:20}..."
        echo "   → Set Redis password to: ${REDIS_PASSWORD:0:20}..."
    else
        echo "   ✅ Database passwords appear to be configured"
    fi
fi

# Step 7: Configure Supabase OIDC (optional)
echo ""
echo "🔐 Step 7: Supabase OIDC Configuration"
echo "   ℹ️  OIDC configuration can be done automatically or manually"
read -p "   Configure Supabase OIDC now? (y/N): " CONFIGURE_OIDC

if [ "${CONFIGURE_OIDC}" = "y" ] || [ "${CONFIGURE_OIDC}" = "Y" ]; then
    if [ -f "configure-matrix-oidc.sh" ]; then
        echo "   🔄 Running OIDC configuration script..."
        ./configure-matrix-oidc.sh
    else
        echo "   ⚠️  OIDC configuration script not found"
        echo "   → Run manually: ./scripts/configure-matrix-oidc.sh from Inquiry.Institute directory"
    fi
else
    echo "   ⏭️  Skipping OIDC configuration"
    echo "   → Run later: ./configure-matrix-oidc.sh"
    echo "   → Or see: ${INQUIRY_DIR}/MATRIX_SUPABASE_OIDC_SETUP.md"
fi

# Step 8: Summary and next steps
echo ""
echo "=================================================="
echo "✅ Setup Complete!"
echo "=================================================="
echo ""
echo "📁 Matrix directory: ${MATRIX_DIR}"
echo "📝 Configuration: matrix-data/homeserver.yaml"
echo "🔐 Environment: .env"
echo ""
echo "📚 Documentation:"
echo "   - Setup guide: ${INQUIRY_DIR}/MATRIX_SETUP.md"
echo "   - OIDC setup: ${INQUIRY_DIR}/MATRIX_SUPABASE_OIDC_SETUP.md"
echo "   - Quick start: ${INQUIRY_DIR}/MATRIX_QUICK_START.md"
echo ""
echo "🚀 Next Steps:"
echo ""
echo "1. Review configuration:"
echo "   cd ${MATRIX_DIR}"
echo "   nano matrix-data/homeserver.yaml  # Update database passwords"
echo ""
echo "2. Configure Supabase OIDC (if not done):"
echo "   cd ${MATRIX_DIR}"
echo "   ./configure-matrix-oidc.sh"
echo ""
echo "3. Add redirect URI in Supabase:"
echo "   → Go to: https://supabase.com/dashboard/project/${SUPABASE_PROJECT_REF}/auth/url-configuration"
echo "   → Add: http://localhost:8008/_synapse/client/oidc/callback"
echo ""
echo "4. Start Matrix server:"
echo "   cd ${MATRIX_DIR}"
echo "   docker-compose up -d"
echo ""
echo "5. Verify setup:"
echo "   cd ${INQUIRY_DIR}"
echo "   ./scripts/verify-matrix-setup.sh"
echo ""
echo "6. Test OIDC login:"
echo "   → Open: http://localhost:8080"
echo "   → Click 'Sign in with Inquiry Institute'"
echo ""
echo "✅ Setup complete! Follow the next steps above to start your Matrix server."
