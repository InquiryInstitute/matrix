#!/usr/bin/env python3
"""
Check who is in Matrix rooms.
This script lists rooms and their members.
"""

import asyncio
import os
import sys
from typing import Optional

try:
    from nio import AsyncClient, LoginResponse, JoinedRoomsResponse
except ImportError:
    print("❌ matrix-nio not installed. Install with: pip install matrix-nio")
    sys.exit(1)

# Configuration
MATRIX_SERVER = os.getenv("MATRIX_SERVER", "https://matrix.inquiry.institute")
MATRIX_SERVER_NAME = os.getenv("MATRIX_DOMAIN", "matrix.inquiry.institute")
USERNAME = os.getenv("MATRIX_USERNAME")
PASSWORD = os.getenv("MATRIX_PASSWORD")


async def list_rooms_and_members(client: AsyncClient):
    """List all rooms and their members."""
    print("\n🏛️  Rooms and Members")
    print("=" * 60)
    
    # Get joined rooms
    response = await client.joined_rooms()
    
    if not isinstance(response, JoinedRoomsResponse):
        print(f"❌ Failed to get rooms: {response}")
        return
    
    if not response.rooms:
        print("📭 No rooms found. You haven't joined any rooms yet.")
        return
    
    print(f"\n📊 Found {len(response.rooms)} room(s)\n")
    
    for room_id in response.rooms:
        # Get room details
        room = client.rooms.get(room_id)
        
        if not room:
            print(f"⚠️  Room {room_id}: Unable to get details")
            continue
        
        room_name = room.display_name or room.name or "Unnamed Room"
        room_topic = room.topic or "No topic"
        member_count = len(room.users)
        
        print(f"🏛️  {room_name}")
        print(f"   Room ID: {room_id}")
        print(f"   Topic: {room_topic}")
        print(f"   Members: {member_count}")
        print(f"\n   👥 Member List:")
        
        # List members
        for user_id in sorted(room.users.keys()):
            user = room.users[user_id]
            display_name = user.display_name or user_id
            power_level = user.power_level
            
            # Determine role
            if power_level >= 100:
                role = "👑 Admin"
            elif power_level >= 50:
                role = "⭐ Moderator"
            else:
                role = "👤 Member"
            
            print(f"      {role} {display_name}")
            if display_name != user_id:
                print(f"         ({user_id})")
        
        print()


async def main():
    """Main function."""
    print("🔷 Matrix Room Member Checker")
    print("=" * 60)
    
    # Check for credentials
    if not USERNAME or not PASSWORD:
        print("\n❌ Credentials not provided")
        print("\nPlease set environment variables:")
        print("  export MATRIX_USERNAME=your_username")
        print("  export MATRIX_PASSWORD=your_password")
        print("\nOr run interactively:")
        username_input = input("Username: ").strip()
        password_input = input("Password: ").strip()
        
        if not username_input or not password_input:
            print("❌ Credentials required")
            sys.exit(1)
        
        USERNAME = username_input
        PASSWORD = password_input
    
    # Create Matrix client
    if "@" in USERNAME:
        user_id = USERNAME
    else:
        user_id = f"@{USERNAME}:{MATRIX_SERVER_NAME}"
    
    print(f"\n🔐 Logging in as: {user_id}")
    print(f"   Server: {MATRIX_SERVER}")
    
    client = AsyncClient(MATRIX_SERVER, user_id)
    
    try:
        # Login
        response = await client.login(PASSWORD)
        
        if not isinstance(response, LoginResponse):
            print(f"❌ Login failed: {response}")
            sys.exit(1)
        
        print(f"✅ Logged in successfully")
        
        # Sync to get room data
        print("\n⏳ Syncing with server...")
        await client.sync(timeout=30000, full_state=True)
        
        # List rooms and members
        await list_rooms_and_members(client)
        
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
