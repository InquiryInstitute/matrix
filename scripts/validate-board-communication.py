#!/usr/bin/env python3
"""
Validate Board of Directors communication setup.
This script checks that:
1. All director bots are registered
2. Custodian bot is registered
3. Board room exists
4. All bots can communicate in the board room
"""

import asyncio
import os
import sys
import json
from pathlib import Path
from typing import List, Dict, Optional

try:
    from nio import AsyncClient, MatrixRoom, RoomMessageText, LoginResponse, JoinedRoomsResponse
except ImportError:
    print("❌ matrix-nio not installed. Install with: pip install matrix-nio")
    sys.exit(1)

# Configuration
MATRIX_SERVER = os.getenv("MATRIX_SERVER", "http://localhost:8008")
MATRIX_SERVER_NAME = os.getenv("MATRIX_DOMAIN", "matrix.inquiry.institute")
ADMIN_USERNAME = os.getenv("ADMIN_USERNAME", "admin")
ADMIN_PASSWORD = os.getenv("ADMIN_PASSWORD")

# Expected bots (from Supabase board_of_directors table)
DIRECTORS = [
    "a.alkhwarizmi", "a.avicenna", "a.daVinci", "a.darwin", "a.diogenes",
    "a.katsushikaoi", "a.maryshelley", "a.newton", "a.plato", "a.turing"
]
SPECIAL_BOTS = ["custodian"]

# Load bot credentials
CREDENTIALS_FILE = Path("matrix-bot-credentials.json")


async def load_credentials() -> List[Dict]:
    """Load bot credentials from file."""
    if CREDENTIALS_FILE.exists():
        with open(CREDENTIALS_FILE, "r") as f:
            return json.load(f)
    return []


async def test_bot_login(username: str, password: str) -> bool:
    """Test if a bot can login successfully."""
    client = AsyncClient(MATRIX_SERVER, f"@{username}:{MATRIX_SERVER_NAME}")
    
    try:
        response = await client.login(password)
        if isinstance(response, LoginResponse):
            await client.close()
            return True
        else:
            await client.close()
            return False
    except Exception as e:
        print(f"   ❌ Login failed: {e}")
        return False


async def find_board_room(client: AsyncClient) -> Optional[str]:
    """Find the Board of Directors room."""
    response = await client.joined_rooms()
    
    if isinstance(response, JoinedRoomsResponse):
        for room_id in response.rooms:
            # Get room details
            room = client.rooms.get(room_id)
            if room:
                room_name = room.display_name or ""
                if "board" in room_name.lower() or "director" in room_name.lower():
                    return room_id
    
    return None


async def send_test_message(client: AsyncClient, room_id: str, message: str) -> bool:
    """Send a test message to a room."""
    try:
        await client.room_send(
            room_id=room_id,
            message_type="m.room.message",
            content={
                "msgtype": "m.text",
                "body": message
            }
        )
        return True
    except Exception as e:
        print(f"   ❌ Failed to send message: {e}")
        return False


async def validate_bot(bot_info: Dict) -> Dict:
    """Validate a single bot."""
    username = bot_info["username"]
    password = bot_info["password"]
    matrix_id = bot_info["matrix_id"]
    
    print(f"\n🔍 Validating {username}...")
    
    result = {
        "username": username,
        "matrix_id": matrix_id,
        "login_success": False,
        "in_board_room": False,
        "can_send_message": False
    }
    
    # Test login
    print(f"   🔐 Testing login...")
    client = AsyncClient(MATRIX_SERVER, matrix_id)
    
    try:
        response = await client.login(password)
        if isinstance(response, LoginResponse):
            result["login_success"] = True
            print(f"   ✅ Login successful")
            
            # Find board room
            print(f"   🔍 Looking for board room...")
            board_room_id = await find_board_room(client)
            
            if board_room_id:
                result["in_board_room"] = True
                print(f"   ✅ Found board room: {board_room_id}")
                
                # Test sending message
                print(f"   📤 Testing message send...")
                test_msg = f"[Validation Test] {username} checking in!"
                if await send_test_message(client, board_room_id, test_msg):
                    result["can_send_message"] = True
                    print(f"   ✅ Message sent successfully")
                else:
                    print(f"   ❌ Failed to send message")
            else:
                print(f"   ⚠️  Not in any board room")
        else:
            print(f"   ❌ Login failed: {response}")
    except Exception as e:
        print(f"   ❌ Error: {e}")
    finally:
        await client.close()
    
    return result


async def validate_custodian_communication() -> Dict:
    """Validate that custodian can communicate with the board."""
    print("\n" + "="*60)
    print("🔍 Validating Custodian Communication")
    print("="*60)
    
    credentials = await load_credentials()
    
    # Find custodian
    custodian = None
    for bot in credentials:
        if "custodian" in bot["username"].lower():
            custodian = bot
            break
    
    if not custodian:
        print("❌ Custodian bot not found in credentials")
        return {"status": "not_found"}
    
    result = await validate_bot(custodian)
    
    print("\n" + "="*60)
    print("📊 Custodian Validation Summary")
    print("="*60)
    print(f"Login: {'✅' if result['login_success'] else '❌'}")
    print(f"In Board Room: {'✅' if result['in_board_room'] else '❌'}")
    print(f"Can Send Messages: {'✅' if result['can_send_message'] else '❌'}")
    
    return result


async def validate_all_bots() -> List[Dict]:
    """Validate all bots."""
    print("\n" + "="*60)
    print("🔍 Validating All Board Members")
    print("="*60)
    
    credentials = await load_credentials()
    
    if not credentials:
        print("❌ No bot credentials found")
        print(f"   Run: python3 scripts/create-matrix-bots.py")
        return []
    
    results = []
    for bot in credentials:
        result = await validate_bot(bot)
        results.append(result)
    
    return results


async def print_summary(results: List[Dict]):
    """Print validation summary."""
    print("\n" + "="*60)
    print("📊 Validation Summary")
    print("="*60)
    
    total = len(results)
    login_success = sum(1 for r in results if r["login_success"])
    in_board = sum(1 for r in results if r["in_board_room"])
    can_message = sum(1 for r in results if r["can_send_message"])
    
    print(f"\nTotal Bots: {total}")
    print(f"✅ Can Login: {login_success}/{total}")
    print(f"✅ In Board Room: {in_board}/{total}")
    print(f"✅ Can Send Messages: {can_message}/{total}")
    
    if can_message == total and total > 0:
        print("\n🎉 All bots are working correctly!")
    elif login_success == total:
        print("\n⚠️  All bots can login, but some are not in the board room")
        print("   → Create a board room and invite all bots")
    else:
        print("\n❌ Some bots cannot login")
        print("   → Check bot credentials and passwords")


async def main():
    """Main validation function."""
    print("🔷 Board of Directors Communication Validation")
    print("=" * 60)
    print(f"Matrix Server: {MATRIX_SERVER}")
    print(f"Server Name: {MATRIX_SERVER_NAME}")
    print("")
    
    # Check if credentials file exists
    if not CREDENTIALS_FILE.exists():
        print("❌ Bot credentials file not found")
        print(f"   Expected: {CREDENTIALS_FILE}")
        print(f"   Run: python3 scripts/create-matrix-bots.py")
        sys.exit(1)
    
    # Validate custodian first
    custodian_result = await validate_custodian_communication()
    
    # Validate all bots
    all_results = await validate_all_bots()
    
    # Print summary
    await print_summary(all_results)
    
    print("\n📚 Next Steps:")
    if not all_results:
        print("1. Create bot accounts: python3 scripts/create-matrix-bots.py")
        print("2. Start Matrix server: docker-compose up -d")
        print("3. Run this validation again")
    elif any(not r["in_board_room"] for r in all_results):
        print("1. Log in to Element Web: http://localhost:8080")
        print("2. Create 'Board of Directors' room")
        print("3. Invite all bots:")
        for r in all_results:
            print(f"   - {r['matrix_id']}")
        print("4. Run this validation again")
    else:
        print("✅ All systems operational!")
        print("   Test communication by sending messages in the board room")


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("\n\n👋 Validation interrupted")
    except Exception as e:
        print(f"\n❌ Error: {e}")
        import traceback
        traceback.print_exc()
