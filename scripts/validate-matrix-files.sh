#!/bin/bash
# Validate Matrix setup files are present and correctly configured

set -e

INQUIRY_DIR="${HOME}/GitHub/Inquiry.Institute"
ERRORS=0
WARNINGS=0

echo "🔍 Validating Matrix Setup Files"
echo "================================"
echo ""

# Check required configuration files
echo "📝 Checking configuration files..."

REQUIRED_FILES=(
    "docker-compose.matrix.yml"
    "element-config.json"
    "matrix-homeserver-oidc.yaml.template"
)

for file in "${REQUIRED_FILES[@]}"; do
    if [ -f "${INQUIRY_DIR}/${file}" ]; then
        echo "   ✅ ${file}"
        
        # Basic validation
        case "${file}" in
            "docker-compose.matrix.yml")
                if grep -q "matrixdotorg/synapse" "${INQUIRY_DIR}/${file}"; then
                    echo "      ✅ Contains Synapse service"
                else
                    echo "      ⚠️  May be missing Synapse configuration"
                    ((WARNINGS++))
                fi
                ;;
            "element-config.json")
                if grep -q "matrix.inquiry.institute" "${INQUIRY_DIR}/${file}"; then
                    echo "      ✅ Contains Matrix domain"
                else
                    echo "      ⚠️  Domain may not be configured"
                    ((WARNINGS++))
                fi
                ;;
            "matrix-homeserver-oidc.yaml.template")
                if grep -q "oidc_providers" "${INQUIRY_DIR}/${file}"; then
                    echo "      ✅ Contains OIDC configuration"
                else
                    echo "      ⚠️  May be missing OIDC configuration"
                    ((WARNINGS++))
                fi
                ;;
        esac
    else
        echo "   ❌ ${file} - NOT FOUND"
        ((ERRORS++))
    fi
done

# Check setup scripts
echo ""
echo "🔧 Checking setup scripts..."

SETUP_SCRIPTS=(
    "scripts/setup-matrix.sh"
    "scripts/setup-matrix-complete.sh"
    "scripts/configure-matrix-oidc.sh"
    "scripts/verify-matrix-setup.sh"
)

for script in "${SETUP_SCRIPTS[@]}"; do
    if [ -f "${INQUIRY_DIR}/${script}" ]; then
        if [ -x "${INQUIRY_DIR}/${script}" ]; then
            echo "   ✅ ${script} (executable)"
        else
            echo "   ⚠️  ${script} (not executable)"
            ((WARNINGS++))
        fi
        
        # Check for shebang
        if head -1 "${INQUIRY_DIR}/${script}" | grep -q "^#!/bin/bash\|^#!/usr/bin/env bash"; then
            echo "      ✅ Has valid shebang"
        else
            echo "      ⚠️  Missing or invalid shebang"
            ((WARNINGS++))
        fi
    else
        echo "   ❌ ${script} - NOT FOUND"
        ((ERRORS++))
    fi
done

# Check bot scripts
echo ""
echo "🤖 Checking bot integration scripts..."

BOT_SCRIPTS=(
    "scripts/create-matrix-bots.py"
    "scripts/matrix-director-bot.py"
    "requirements-matrix.txt"
)

for script in "${BOT_SCRIPTS[@]}"; do
    if [ -f "${INQUIRY_DIR}/${script}" ]; then
        echo "   ✅ ${script}"
        
        if [[ "${script}" == *.py ]]; then
            if head -1 "${INQUIRY_DIR}/${script}" | grep -q "^#!/usr/bin/env python3\|^#!/usr/bin/python3"; then
                echo "      ✅ Has valid shebang"
            else
                echo "      ⚠️  Missing or invalid shebang"
                ((WARNINGS++))
            fi
        fi
    else
        echo "   ❌ ${script} - NOT FOUND"
        ((ERRORS++))
    fi
done

# Check documentation files
echo ""
echo "📚 Checking documentation files..."

DOC_FILES=(
    "MATRIX_SETUP.md"
    "MATRIX_SUPABASE_OIDC_SETUP.md"
    "MATRIX_QUICK_START.md"
    "MATRIX_OIDC_QUICK_START.md"
    "MATRIX_OIDC_INTEGRATION_SUMMARY.md"
    "MATRIX_IMPLEMENTATION_CHECKLIST.md"
    "NEXT_STEPS_MATRIX.md"
    "MATRIX_IMPLEMENTATION_SUMMARY.md"
    "MATRIX_SETUP_COMPLETE.md"
)

for doc in "${DOC_FILES[@]}"; do
    if [ -f "${INQUIRY_DIR}/${doc}" ]; then
        # Check file size (should have content)
        if [ -s "${INQUIRY_DIR}/${doc}" ]; then
            echo "   ✅ ${doc}"
        else
            echo "   ⚠️  ${doc} - Empty file"
            ((WARNINGS++))
        fi
    else
        echo "   ❌ ${doc} - NOT FOUND"
        ((ERRORS++))
    fi
done

# Check docker-compose syntax (if yq or docker-compose is available)
echo ""
echo "🐳 Validating docker-compose.matrix.yml..."

if command -v docker-compose &> /dev/null || docker compose version &> /dev/null; then
    cd "${INQUIRY_DIR}"
    if docker-compose -f docker-compose.matrix.yml config > /dev/null 2>&1 || docker compose -f docker-compose.matrix.yml config > /dev/null 2>&1; then
        echo "   ✅ docker-compose.matrix.yml syntax is valid"
    else
        echo "   ⚠️  docker-compose.matrix.yml may have syntax errors"
        echo "      Run: docker-compose -f docker-compose.matrix.yml config"
        ((WARNINGS++))
    fi
else
    echo "   ⏭️  Skipping docker-compose validation (docker-compose not available)"
fi

# Check JSON syntax for element-config.json
echo ""
echo "📋 Validating element-config.json..."

if command -v python3 &> /dev/null; then
    if python3 -m json.tool "${INQUIRY_DIR}/element-config.json" > /dev/null 2>&1; then
        echo "   ✅ element-config.json syntax is valid"
    else
        echo "   ⚠️  element-config.json may have syntax errors"
        echo "      Run: python3 -m json.tool element-config.json"
        ((WARNINGS++))
    fi
else
    echo "   ⏭️  Skipping JSON validation (python3 not available)"
fi

# Check YAML template (basic check)
echo ""
echo "⚙️  Validating matrix-homeserver-oidc.yaml.template..."

if command -v python3 &> /dev/null; then
    # Try to import yaml module
    if python3 -c "import yaml" 2>/dev/null; then
        if python3 -c "import yaml; yaml.safe_load(open('${INQUIRY_DIR}/matrix-homeserver-oidc.yaml.template'))" 2>/dev/null; then
            echo "   ✅ matrix-homeserver-oidc.yaml.template syntax is valid"
        else
            echo "   ⚠️  matrix-homeserver-oidc.yaml.template may have syntax errors (template placeholders may cause this)"
            ((WARNINGS++))
        fi
    else
        echo "   ⏭️  Skipping YAML validation (PyYAML not installed)"
    fi
else
    echo "   ⏭️  Skipping YAML validation (python3 not available)"
fi

# Check for Supabase OIDC endpoints accessibility
echo ""
echo "🔐 Checking Supabase OIDC endpoints..."

SUPABASE_PROJECT_REF="xougqdomkoisrxdnagcj"
DISCOVERY_URL="https://${SUPABASE_PROJECT_REF}.supabase.co/auth/v1/.well-known/openid-configuration"

if command -v curl &> /dev/null; then
    if curl -s -f "${DISCOVERY_URL}" > /dev/null 2>&1; then
        echo "   ✅ Supabase OIDC discovery endpoint is accessible"
    else
        echo "   ⚠️  Supabase OIDC discovery endpoint is not accessible"
        echo "      URL: ${DISCOVERY_URL}"
        echo "      This may be normal if Supabase project is paused or network is unavailable"
        ((WARNINGS++))
    fi
else
    echo "   ⏭️  Skipping endpoint check (curl not available)"
fi

# Summary
echo ""
echo "================================"
echo "📊 Validation Summary"
echo "================================"
echo ""
echo "✅ Errors: ${ERRORS}"
echo "⚠️  Warnings: ${WARNINGS}"
echo ""

if [ ${ERRORS} -eq 0 ] && [ ${WARNINGS} -eq 0 ]; then
    echo "🎉 All files validated successfully!"
    echo ""
    echo "✅ Ready to proceed with Matrix server setup:"
    echo "   ./scripts/setup-matrix-complete.sh"
    exit 0
elif [ ${ERRORS} -eq 0 ]; then
    echo "⚠️  Validation complete with warnings"
    echo ""
    echo "✅ Setup files are present, but some warnings should be reviewed"
    echo "   You can proceed with setup, but check warnings above"
    exit 0
else
    echo "❌ Validation failed with errors"
    echo ""
    echo "⚠️  Some required files are missing"
    echo "   Please check the errors above before proceeding"
    exit 1
fi
