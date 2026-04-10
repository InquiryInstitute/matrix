#!/usr/bin/env python3
"""
Check which bots are missing from the board room and invite them.
"""

import asyncio
import os
import sys
import json
from pathlib import Path
from typing import List, Dict, Set

try:
    from nio import (
        AsyncClient,
        LoginResponse,
        RoomInviteResponse,
        RoomResolveAliasResponse,
        RoomResolveAliasError,
    )
except ImportError:
    print("❌ matrix-nio not installed. Install with: pip install matrix-nio")
    sys.exit(1)

# Configuration
MATRIX_SERVER = os.getenv("MATRIX_SERVER", "https://matrix.inquiry.institute").rstrip("/")
MATRIX_SERVER_NAME = os.getenv("MATRIX_DOMAIN", "matrix.inquiry.institute")
# Prefer BOARD_ROOM_ID; else resolve #BOARD_ROOM_ALIAS:domain after login
BOARD_ROOM_ID = os.getenv("BOARD_ROOM_ID", "").strip()
BOARD_ROOM_ALIAS = os.getenv("BOARD_ROOM_ALIAS", "board-of-directors").strip()

# Credentials
ADMIN_USERNAME = os.getenv("ADMIN_USERNAME")
ADMIN_PASSWORD = os.getenv("ADMIN_PASSWORD")

# Load bot credentials
CREDENTIALS_FILE = Path(__file__).resolve().parent.parent / "matrix-bot-credentials.json"


async def load_bot_credentials() -> List[Dict]:
    """Load bot credentials from file."""
    if CREDENTIALS_FILE.exists():
        with open(CREDENTIALS_FILE, "r") as f:
            return json.load(f)
    return []


async def get_room_members(client: AsyncClient, room_id: str) -> Set[str]:
    """Get all members in a room."""
    members = set()
    
    try:
        # Sync to get room data
        await client.sync(timeout=30000, full_state=True)
        
        # Get room
        room = client.rooms.get(room_id)
        if room:
            members = set(room.users.keys())
            print(f"   Found {len(members)} members in room")
        else:
            print(f"   ⚠️  Room not found in sync data")
    except Exception as e:
        print(f"   ⚠️  Error getting members: {e}")
    
    return members


async def invite_bot(client: AsyncClient, room_id: str, bot_matrix_id: str, bot_username: str) -> bool:
    """Invite a bot to the room."""
    try:
        response = await client.room_invite(room_id, bot_matrix_id)
        
        if isinstance(response, RoomInviteResponse):
            print(f"   ✅ Invited {bot_username}")
            return True
        else:
            print(f"   ❌ Failed to invite {bot_username}: {response}")
            return False
    except Exception as e:
        print(f"   ❌ Error inviting {bot_username}: {e}")
        return False


async def resolve_board_room_id(client: AsyncClient) -> str:
    """Return BOARD_ROOM_ID or resolve canonical alias."""
    if BOARD_ROOM_ID:
        return BOARD_ROOM_ID
    full_alias = f"#{BOARD_ROOM_ALIAS}:{MATRIX_SERVER_NAME}"
    print(f"Resolving {full_alias}...")
    res = await client.room_resolve_alias(full_alias)
    if isinstance(res, RoomResolveAliasResponse):
        print(f"   → {res.room_id}")
        return res.room_id
    print(f"❌ Could not resolve alias: {res}")
    return ""


async def main():
    """Main function."""
    print("🔷 Board Room - Missing Bots Checker & Inviter")
    print("=" * 60)
    print(f"Server: {MATRIX_SERVER}")
    if BOARD_ROOM_ID:
        print(f"Room ID: {BOARD_ROOM_ID}")
    else:
        print(f"Room: #{BOARD_ROOM_ALIAS}:{MATRIX_SERVER_NAME} (resolve after login)")
    print("")
    
    # Load bot credentials
    print("📋 Loading bot credentials...")
    bots = await load_bot_credentials()
    
    if not bots:
        print("❌ No bot credentials found")
        print("   Run: python3 scripts/create-matrix-bots.py")
        sys.exit(1)
    
    print(f"   Found {len(bots)} bots in credentials file")
    
    # Expected bots
    expected_bots = {bot["matrix_id"]: bot["username"] for bot in bots}
    print(f"\n📊 Expected bots in room: {len(expected_bots)}")
    
    # Special bots
    special_bots = [b for b in bots if b.get("bot_type")]
    print(f"   Special bots: {len(special_bots)}")
    for bot in special_bots:
        print(f"      - {bot['username']} ({bot['bot_type']})")
    
    # Director bots
    director_bots = [b for b in bots if "Director" in b["username"]]
    print(f"   Director bots: {len(director_bots)}")
    
    # Check for admin credentials
    if not ADMIN_USERNAME or not ADMIN_PASSWORD:
        print("\n❌ Admin credentials not provided")
        print("\nPlease set environment variables:")
        print("  export ADMIN_USERNAME=your_admin_username")
        print("  export ADMIN_PASSWORD=your_admin_password")
        print("\nOr enter them now:")
        username_input = input("Admin username: ").strip()
        password_input = input("Admin password: ").strip()
        
        if not username_input or not password_input:
            print("❌ Credentials required")
            sys.exit(1)
        
        ADMIN_USERNAME = username_input
        ADMIN_PASSWORD = password_input
    
    # Create Matrix client
    if "@" in ADMIN_USERNAME:
        admin_id = ADMIN_USERNAME
    else:
        admin_id = f"@{ADMIN_USERNAME}:{MATRIX_SERVER_NAME}"
    
    print(f"\n🔐 Logging in as: {admin_id}")
    
    client = AsyncClient(MATRIX_SERVER, admin_id)
    
    try:
        # Login
        response = await client.login(ADMIN_PASSWORD)
        
        if not isinstance(response, LoginResponse):
            print(f"❌ Login failed: {response}")
            sys.exit(1)
        
        print(f"✅ Logged in successfully")

        room_id = await resolve_board_room_id(client)
        if not room_id:
            sys.exit(1)

        # Get current room members
        print(f"\n🔍 Checking room members...")
        current_members = await get_room_members(client, room_id)
        
        if not current_members:
            print("⚠️  Could not get room members. You may not be in the room.")
            print("   Attempting to join room first...")
            try:
                await client.join(room_id)
                print("   ✅ Joined room")
                current_members = await get_room_members(client, room_id)
            except Exception as e:
                print(f"   ❌ Could not join room: {e}")
        
        print(f"\n📊 Current members in room: {len(current_members)}")
        
        # Find missing bots
        missing_bots = []
        present_bots = []
        
        for matrix_id, username in expected_bots.items():
            if matrix_id in current_members:
                present_bots.append((matrix_id, username))
            else:
                missing_bots.append((matrix_id, username))
        
        # Display results
        print(f"\n✅ Present bots: {len(present_bots)}/{len(expected_bots)}")
        if present_bots:
            for matrix_id, username in sorted(present_bots, key=lambda x: x[1]):
                print(f"   ✅ {username}")
        
        print(f"\n❌ Missing bots: {len(missing_bots)}/{len(expected_bots)}")
        if missing_bots:
            for matrix_id, username in sorted(missing_bots, key=lambda x: x[1]):
                print(f"   ❌ {username}")
                print(f"      {matrix_id}")
        
        # Invite missing bots
        if missing_bots:
            print(f"\n📨 Inviting missing bots...")
            
            invited_count = 0
            failed_count = 0
            
            for matrix_id, username in missing_bots:
                if await invite_bot(client, room_id, matrix_id, username):
                    invited_count += 1
                else:
                    failed_count += 1
            
            print(f"\n📊 Invitation Results:")
            print(f"   ✅ Invited: {invited_count}")
            print(f"   ❌ Failed: {failed_count}")
        else:
            print(f"\n🎉 All bots are already in the room!")
        
        # Summary
        print("\n" + "=" * 60)
        print("📊 Final Summary")
        print("=" * 60)
        print(f"Total bots expected: {len(expected_bots)}")
        print(f"Bots in room: {len(present_bots)}")
        print(f"Bots invited: {len(missing_bots)}")
        
        if missing_bots:
            print("\n📚 Next Steps:")
            print("1. Bots need to accept invitations (they must be running)")
            print("2. Start bots to auto-accept:")
            print("   ./scripts/start-custodian-bot.sh")
            print("3. Or manually accept in Element Web")
        
    except Exception as e:
        print(f"\n❌ Error: {e}")
        import traceback
        traceback.print_exc()
    finally:
        await client.close()


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("\n\n👋 Interrupted by user")
    except Exception as e:
        print(f"\n❌ Error: {e}")
        import traceback
        traceback.print_exc()
