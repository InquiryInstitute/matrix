#!/bin/bash
# Configure Matrix Synapse with Supabase OIDC authentication

set -e

MATRIX_DIR="${HOME}/GitHub/matrix"
HOMESERVER_CONFIG="${MATRIX_DIR}/matrix-data/homeserver.yaml"
TEMPLATE_FILE="${HOME}/GitHub/Inquiry.Institute/matrix-homeserver-oidc.yaml.template"

SUPABASE_PROJECT_REF="xougqdomkoisrxdnagcj"
SUPABASE_DISCOVERY_URL="https://${SUPABASE_PROJECT_REF}.supabase.co/auth/v1/.well-known/openid-configuration"

echo "🔷 Configuring Matrix Synapse with Supabase OIDC"
echo ""

# Check if homeserver.yaml exists
if [ ! -f "${HOMESERVER_CONFIG}" ]; then
    echo "❌ homeserver.yaml not found at ${HOMESERVER_CONFIG}"
    echo "   Run setup-matrix.sh first to generate configuration"
    exit 1
fi

# Check if template exists
if [ ! -f "${TEMPLATE_FILE}" ]; then
    echo "⚠️  Template file not found at ${TEMPLATE_FILE}"
    echo "   Using inline configuration instead"
fi

# Get Supabase anon key
echo "📋 Step 1: Get Supabase Anon Key (Client ID)"
echo "   Go to: https://supabase.com/dashboard/project/${SUPABASE_PROJECT_REF}/settings/api"
echo "   Copy the 'anon (public) key'"
echo ""
read -p "Enter Supabase anon key: " SUPABASE_ANON_KEY

if [ -z "${SUPABASE_ANON_KEY}" ]; then
    echo "❌ Supabase anon key is required"
    exit 1
fi

# Verify OIDC endpoints
echo ""
echo "🔍 Step 2: Verifying Supabase OIDC endpoints..."
if curl -s "${SUPABASE_DISCOVERY_URL}" > /dev/null; then
    echo "✅ Discovery endpoint is accessible"
else
    echo "⚠️  Could not reach discovery endpoint"
    echo "   URL: ${SUPABASE_DISCOVERY_URL}"
    echo "   Continuing anyway..."
fi

# Create backup
echo ""
echo "💾 Step 3: Creating backup of homeserver.yaml..."
cp "${HOMESERVER_CONFIG}" "${HOMESERVER_CONFIG}.backup.$(date +%Y%m%d_%H%M%S)"
echo "✅ Backup created"

# Generate OIDC configuration
echo ""
echo "⚙️  Step 4: Generating OIDC configuration..."

OIDC_CONFIG=$(cat <<EOF
# Supabase OIDC Provider Configuration (Auto-generated)
oidc_providers:
  - idp_id: supabase
    idp_name: "Inquiry Institute"
    idp_brand: "inquiry.institute"
    
    # Supabase OIDC Discovery Endpoint
    discover: true
    issuer: "https://${SUPABASE_PROJECT_REF}.supabase.co"
    
    # Client ID (Supabase anon key)
    client_id: "${SUPABASE_ANON_KEY}"
    
    # Supabase uses public client flow (no client secret needed)
    client_secret: null
    
    # Scopes to request
    scopes: ["openid", "profile", "email"]
    
    # User attribute mapping
    user_mapping_provider:
      config:
        localpart_template: "{{user.preferred_username}}"
        display_name_template: "{{user.name}}"
        email_template: "{{user.email}}"
        extra_attributes:
          picture: "{{user.picture}}"
    
    # Allow linking existing accounts
    allow_existing_users: true

# Disable open registration, use OIDC only
enable_registration: false
EOF
)

# Check if OIDC config already exists
if grep -q "oidc_providers:" "${HOMESERVER_CONFIG}"; then
    echo "⚠️  OIDC configuration already exists in homeserver.yaml"
    read -p "Replace existing OIDC config? (y/N): " REPLACE
    if [ "${REPLACE}" = "y" ] || [ "${REPLACE}" = "Y" ]; then
        # Remove old OIDC config
        sed -i.bak '/^# Supabase OIDC/,/^enable_registration: false/d' "${HOMESERVER_CONFIG}"
        echo "✅ Removed old OIDC configuration"
    else
        echo "ℹ️  Keeping existing configuration"
        echo ""
        echo "📝 Current OIDC configuration:"
        grep -A 20 "oidc_providers:" "${HOMESERVER_CONFIG}" || echo "   (not found)"
        exit 0
    fi
fi

# Append OIDC config to homeserver.yaml
echo "${OIDC_CONFIG}" >> "${HOMESERVER_CONFIG}"
echo "✅ OIDC configuration added to homeserver.yaml"

# Configure redirect URI
echo ""
echo "🔗 Step 5: Configure Redirect URI in Supabase"
echo "   Go to: https://supabase.com/dashboard/project/${SUPABASE_PROJECT_REF}/auth/url-configuration"
echo ""
echo "   Add this redirect URI:"
if [ "${MATRIX_DOMAIN:-}" = "matrix.inquiry.institute" ]; then
    echo "   https://matrix.inquiry.institute/_synapse/client/oidc/callback"
else
    echo "   http://localhost:8008/_synapse/client/oidc/callback"
    echo ""
    echo "   For production, also add:"
    echo "   https://matrix.inquiry.institute/_synapse/client/oidc/callback"
fi
echo ""
read -p "Have you added the redirect URI in Supabase? (y/N): " REDIRECT_ADDED

if [ "${REDIRECT_ADDED}" != "y" ] && [ "${REDIRECT_ADDED}" != "Y" ]; then
    echo "⚠️  Please add the redirect URI before testing OIDC login"
fi

# Summary
echo ""
echo "✅ OIDC Configuration Complete!"
echo ""
echo "📋 Configuration Summary:"
echo "   OIDC Provider: Supabase (Inquiry Institute)"
echo "   Discovery URL: ${SUPABASE_DISCOVERY_URL}"
echo "   Client ID: ${SUPABASE_ANON_KEY:0:20}... (truncated)"
echo "   Config file: ${HOMESERVER_CONFIG}"
echo "   Backup: ${HOMESERVER_CONFIG}.backup.*"
echo ""
echo "🚀 Next Steps:"
echo "1. Verify redirect URI is added in Supabase (see above)"
echo "2. Restart Synapse: cd ${MATRIX_DIR} && docker-compose restart synapse"
echo "3. Test OIDC login in Element Web: http://localhost:8080"
echo "4. Look for 'Sign in with Inquiry Institute' button"
echo ""
echo "📚 For detailed documentation, see:"
echo "   ${HOME}/GitHub/Inquiry.Institute/MATRIX_SUPABASE_OIDC_SETUP.md"
