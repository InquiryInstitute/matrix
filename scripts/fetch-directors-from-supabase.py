#!/usr/bin/env python3
"""
Fetch the actual board of directors from Supabase.
This will query the Supabase database to get the real director list.
"""

import os
import sys

# Supabase configuration
SUPABASE_URL = os.getenv("SUPABASE_URL", "https://xougqdomkoisrxdnagcj.supabase.co")
SUPABASE_KEY = os.getenv("SUPABASE_ANON_KEY")

if not SUPABASE_KEY:
    print("❌ SUPABASE_ANON_KEY environment variable not set")
    print("   Set it with: export SUPABASE_ANON_KEY=your_key")
    sys.exit(1)

try:
    import requests
except ImportError:
    print("❌ requests not installed. Install with: pip install requests")
    sys.exit(1)

def fetch_directors():
    """Fetch directors from Supabase."""
    headers = {
        "apikey": SUPABASE_KEY,
        "Authorization": f"Bearer {SUPABASE_KEY}"
    }
    
    # Query the directors table (adjust table name as needed)
    # Common table names: directors, board_members, board_of_directors
    possible_tables = ["directors", "board_members", "board_of_directors", "ttl"]
    
    for table in possible_tables:
        url = f"{SUPABASE_URL}/rest/v1/{table}"
        print(f"🔍 Checking table: {table}")
        
        try:
            response = requests.get(url, headers=headers)
            
            if response.status_code == 200:
                data = response.json()
                if data:
                    print(f"   ✅ Found {len(data)} records")
                    return table, data
                else:
                    print(f"   ⚠️  Table exists but is empty")
            elif response.status_code == 404:
                print(f"   ❌ Table not found")
            else:
                print(f"   ⚠️  Error: {response.status_code}")
        except Exception as e:
            print(f"   ❌ Error: {e}")
    
    return None, None


def main():
    """Main function."""
    print("🔷 Fetch Board of Directors from Supabase")
    print("=" * 60)
    print(f"Supabase URL: {SUPABASE_URL}")
    print("")
    
    table_name, directors = fetch_directors()
    
    if not directors:
        print("\n❌ Could not find directors in Supabase")
        print("\nPlease provide:")
        print("1. The correct table name")
        print("2. The column names for director information")
        sys.exit(1)
    
    print(f"\n✅ Found directors in table: {table_name}")
    print("\nDirectors:")
    for director in directors:
        print(f"   {director}")
    
    print("\n📝 To update the Matrix bot scripts:")
    print("1. Note the director names/IDs above")
    print("2. Update scripts/create-matrix-bots.py")
    print("3. Regenerate bot credentials")


if __name__ == "__main__":
    main()
