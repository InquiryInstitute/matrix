#!/bin/bash
# Fetch directors from Supabase and update the bot creation scripts

set -e

echo "🔷 Update Directors from Supabase"
echo "================================="
echo ""

# Supabase configuration
SUPABASE_URL="${SUPABASE_URL:-https://xougqdomkoisrxdnagcj.supabase.co}"
SUPABASE_KEY="${SUPABASE_ANON_KEY}"

if [ -z "${SUPABASE_KEY}" ]; then
    echo "❌ SUPABASE_ANON_KEY not set"
    echo ""
    echo "Please set it:"
    echo "  export SUPABASE_ANON_KEY=your_anon_key"
    echo ""
    echo "Get it from:"
    echo "  https://supabase.com/dashboard/project/xougqdomkoisrxdnagcj/settings/api"
    exit 1
fi

echo "📡 Fetching directors from Supabase..."
echo "   URL: ${SUPABASE_URL}"
echo ""

# Try different possible table names
TABLES=("ttl" "directors" "board_members" "board_of_directors" "profiles")

for TABLE in "${TABLES[@]}"; do
    echo "🔍 Trying table: ${TABLE}"
    
    RESPONSE=$(curl -s "${SUPABASE_URL}/rest/v1/${TABLE}?select=*" \
        -H "apikey: ${SUPABASE_KEY}" \
        -H "Authorization: Bearer ${SUPABASE_KEY}" \
        -H "Content-Type: application/json")
    
    # Check if response is valid JSON and not empty
    if echo "${RESPONSE}" | jq -e '. | length > 0' > /dev/null 2>&1; then
        echo "   ✅ Found data in ${TABLE}"
        echo ""
        echo "📋 Directors found:"
        echo "${RESPONSE}" | jq -r '.[] | "\(.id // .name // .username // .email)"' 2>/dev/null || echo "${RESPONSE}" | jq '.'
        echo ""
        
        # Save to file
        echo "${RESPONSE}" | jq '.' > supabase-directors.json
        echo "💾 Saved to: supabase-directors.json"
        echo ""
        
        echo "📚 Next steps:"
        echo "1. Review supabase-directors.json"
        echo "2. Identify the director names/IDs"
        echo "3. Update scripts/create-matrix-bots.py with the correct DIRECTORS list"
        echo "4. Regenerate bot credentials: python3 scripts/create-matrix-bots.py"
        
        exit 0
    else
        echo "   ⚠️  No data or table not found"
    fi
done

echo ""
echo "❌ Could not find directors in any common table"
echo ""
echo "Please provide:"
echo "1. The correct table name"
echo "2. Run: curl -s \"${SUPABASE_URL}/rest/v1/YOUR_TABLE?select=*\" \\"
echo "        -H \"apikey: \${SUPABASE_ANON_KEY}\" \\"
echo "        -H \"Authorization: Bearer \${SUPABASE_ANON_KEY}\""
