#!/bin/bash
# Verify Matrix server setup and configuration

set -e

MATRIX_DIR="${HOME}/GitHub/matrix"
HOMESERVER_CONFIG="${MATRIX_DIR}/matrix-data/homeserver.yaml"
SUPABASE_PROJECT_REF="xougqdomkoisrxdnagcj"

echo "🔍 Verifying Matrix Server Setup"
echo "================================"
echo ""

# Check 1: Repository exists
echo "📁 Check 1: Matrix repository"
if [ -d "${MATRIX_DIR}" ]; then
    echo "   ✅ Repository exists at ${MATRIX_DIR}"
else
    echo "   ❌ Repository not found at ${MATRIX_DIR}"
    echo "   → Run: cd ~/GitHub && git clone https://github.com/InquiryInstitute/matrix.git"
    exit 1
fi

# Check 2: Docker Compose file
echo ""
echo "🐳 Check 2: Docker Compose configuration"
if [ -f "${MATRIX_DIR}/docker-compose.yml" ]; then
    echo "   ✅ docker-compose.yml exists"
else
    echo "   ❌ docker-compose.yml not found"
    echo "   → Copy from: ~/GitHub/Inquiry.Institute/docker-compose.matrix.yml"
fi

# Check 3: Homeserver configuration
echo ""
echo "⚙️  Check 3: Synapse configuration"
if [ -f "${HOMESERVER_CONFIG}" ]; then
    echo "   ✅ homeserver.yaml exists"
    
    # Check for OIDC configuration
    if grep -q "oidc_providers:" "${HOMESERVER_CONFIG}"; then
        echo "   ✅ OIDC configuration found"
        
        # Check for Supabase OIDC
        if grep -q "supabase" "${HOMESERVER_CONFIG}"; then
            echo "   ✅ Supabase OIDC configured"
        else
            echo "   ⚠️  OIDC configured but Supabase not detected"
        fi
        
        # Check for client_id
        if grep -q "client_id:" "${HOMESERVER_CONFIG}"; then
            CLIENT_ID=$(grep "client_id:" "${HOMESERVER_CONFIG}" | head -1 | sed 's/.*client_id: *"\([^"]*\)".*/\1/')
            if [ -n "${CLIENT_ID}" ] && [ "${CLIENT_ID}" != "YOUR_SUPABASE_ANON_KEY" ]; then
                echo "   ✅ Client ID is configured"
            else
                echo "   ⚠️  Client ID needs to be set (Supabase anon key)"
            fi
        else
            echo "   ⚠️  Client ID not found in configuration"
        fi
    else
        echo "   ⚠️  OIDC not configured"
        echo "   → Run: ./scripts/configure-matrix-oidc.sh"
    fi
else
    echo "   ❌ homeserver.yaml not found"
    echo "   → Generate with: docker run -it --rm -v ${MATRIX_DIR}/matrix-data:/data -e SYNAPSE_SERVER_NAME=matrix.inquiry.institute matrixdotorg/synapse:latest generate"
fi

# Check 4: Environment file
echo ""
echo "🔐 Check 4: Environment configuration"
if [ -f "${MATRIX_DIR}/.env" ]; then
    echo "   ✅ .env file exists"
    
    # Check for required variables
    if grep -q "POSTGRES_PASSWORD=" "${MATRIX_DIR}/.env"; then
        POSTGRES_PASS=$(grep "POSTGRES_PASSWORD=" "${MATRIX_DIR}/.env" | cut -d'=' -f2)
        if [ -n "${POSTGRES_PASS}" ] && [ "${POSTGRES_PASS}" != "change_me" ]; then
            echo "   ✅ PostgreSQL password is set"
        else
            echo "   ⚠️  PostgreSQL password needs to be changed"
        fi
    else
        echo "   ⚠️  POSTGRES_PASSWORD not found in .env"
    fi
    
    if grep -q "REDIS_PASSWORD=" "${MATRIX_DIR}/.env"; then
        echo "   ✅ Redis password is set"
    else
        echo "   ⚠️  REDIS_PASSWORD not found in .env"
    fi
else
    echo "   ⚠️  .env file not found"
    echo "   → Create .env file with required variables"
fi

# Check 5: Element config
echo ""
echo "🎨 Check 5: Element Web configuration"
if [ -f "${MATRIX_DIR}/element-config.json" ]; then
    echo "   ✅ element-config.json exists"
else
    echo "   ⚠️  element-config.json not found"
    echo "   → Copy from: ~/GitHub/Inquiry.Institute/element-config.json"
fi

# Check 6: Docker containers
echo ""
echo "🐋 Check 6: Docker containers"
if docker ps | grep -q "matrix-synapse"; then
    echo "   ✅ Synapse container is running"
else
    echo "   ⚠️  Synapse container is not running"
    echo "   → Start with: cd ${MATRIX_DIR} && docker-compose up -d"
fi

if docker ps | grep -q "matrix-postgres"; then
    echo "   ✅ PostgreSQL container is running"
else
    echo "   ⚠️  PostgreSQL container is not running"
fi

if docker ps | grep -q "matrix-redis"; then
    echo "   ✅ Redis container is running"
else
    echo "   ⚠️  Redis container is not running"
fi

if docker ps | grep -q "matrix-element"; then
    echo "   ✅ Element Web container is running"
else
    echo "   ⚠️  Element Web container is not running"
fi

# Check 7: Network connectivity
echo ""
echo "🌐 Check 7: Network connectivity"
if curl -s -f http://localhost:8008/health > /dev/null 2>&1; then
    echo "   ✅ Matrix server is accessible (http://localhost:8008)"
else
    echo "   ⚠️  Matrix server is not accessible"
    echo "   → Check if containers are running and ports are not blocked"
fi

if curl -s -f http://localhost:8080 > /dev/null 2>&1; then
    echo "   ✅ Element Web is accessible (http://localhost:8080)"
else
    echo "   ⚠️  Element Web is not accessible"
fi

# Check 8: Supabase OIDC endpoints
echo ""
echo "🔐 Check 8: Supabase OIDC endpoints"
DISCOVERY_URL="https://${SUPABASE_PROJECT_REF}.supabase.co/auth/v1/.well-known/openid-configuration"
if curl -s -f "${DISCOVERY_URL}" > /dev/null 2>&1; then
    echo "   ✅ Supabase OIDC discovery endpoint is accessible"
    echo "   → URL: ${DISCOVERY_URL}"
else
    echo "   ⚠️  Supabase OIDC discovery endpoint is not accessible"
    echo "   → Check Supabase project status: https://supabase.com/dashboard/project/${SUPABASE_PROJECT_REF}"
fi

JWKS_URL="https://${SUPABASE_PROJECT_REF}.supabase.co/auth/v1/.well-known/jwks.json"
if curl -s -f "${JWKS_URL}" > /dev/null 2>&1; then
    echo "   ✅ Supabase JWKS endpoint is accessible"
else
    echo "   ⚠️  Supabase JWKS endpoint is not accessible"
fi

# Check 9: Supabase redirect URI
echo ""
echo "🔗 Check 9: Supabase redirect URI"
echo "   ℹ️  Manual check required:"
echo "   → Go to: https://supabase.com/dashboard/project/${SUPABASE_PROJECT_REF}/auth/url-configuration"
echo "   → Verify redirect URI is added:"
echo "      http://localhost:8008/_synapse/client/oidc/callback"
echo "   → For production also add:"
echo "      https://matrix.inquiry.institute/_synapse/client/oidc/callback"

# Summary
echo ""
echo "================================"
echo "📊 Verification Summary"
echo "================================"
echo ""

# Count checks
PASSED=0
WARNINGS=0
FAILED=0

if [ -d "${MATRIX_DIR}" ]; then ((PASSED++)); else ((FAILED++)); fi
if [ -f "${MATRIX_DIR}/docker-compose.yml" ]; then ((PASSED++)); else ((WARNINGS++)); fi
if [ -f "${HOMESERVER_CONFIG}" ]; then ((PASSED++)); else ((WARNINGS++)); fi
if [ -f "${MATRIX_DIR}/.env" ]; then ((PASSED++)); else ((WARNINGS++)); fi
if docker ps | grep -q "matrix-synapse"; then ((PASSED++)); else ((WARNINGS++)); fi

echo "✅ Passed: ${PASSED} checks"
echo "⚠️  Warnings: ${WARNINGS} checks"
echo "❌ Failed: ${FAILED} checks"
echo ""

if [ ${FAILED} -eq 0 ] && [ ${WARNINGS} -eq 0 ]; then
    echo "🎉 All checks passed! Matrix server is ready."
elif [ ${FAILED} -eq 0 ]; then
    echo "⚠️  Setup is mostly complete, but some optional items need attention."
else
    echo "❌ Some critical items are missing. Please complete the setup."
fi

echo ""
echo "📚 Next Steps:"
echo "  1. Complete any missing configuration (see warnings above)"
echo "  2. Start services: cd ${MATRIX_DIR} && docker-compose up -d"
echo "  3. Test OIDC login: http://localhost:8080"
echo "  4. See MATRIX_IMPLEMENTATION_CHECKLIST.md for complete checklist"
