#!/usr/bin/env python3
"""
Create the Board of Directors room (or use existing #board-of-directors) and invite all bots
listed in matrix-bot-credentials.json.
"""

import asyncio
import os
import sys
import json
from pathlib import Path
from typing import List, Dict, Optional

try:
    from nio import (
        AsyncClient,
        LoginResponse,
        RoomCreateResponse,
        RoomInviteResponse,
        RoomResolveAliasResponse,
        RoomResolveAliasError,
        RoomPreset,
        RoomVisibility,
    )
except ImportError:
    print("❌ matrix-nio not installed. Install with: pip install matrix-nio")
    sys.exit(1)

MATRIX_SERVER = os.getenv("MATRIX_SERVER", "https://matrix.inquiry.institute").rstrip("/")
MATRIX_SERVER_NAME = os.getenv("MATRIX_DOMAIN", "matrix.inquiry.institute")
ADMIN_USERNAME = os.getenv("ADMIN_USERNAME")
ADMIN_PASSWORD = os.getenv("ADMIN_PASSWORD")

ROOM_NAME = "Inquiry Institute Board of Directors"
ROOM_TOPIC = "Board of Directors meeting room for strategic discussions and governance"
ROOM_ALIAS_LOCAL = os.getenv("BOARD_ROOM_ALIAS", "board-of-directors").strip()

CREDENTIALS_FILE = Path(__file__).resolve().parent.parent / "matrix-bot-credentials.json"


async def load_bot_credentials() -> List[Dict]:
    if CREDENTIALS_FILE.exists():
        with open(CREDENTIALS_FILE, "r") as f:
            return json.load(f)
    print(f"❌ Bot credentials file not found: {CREDENTIALS_FILE}")
    return []


async def resolve_existing_board_room(client: AsyncClient) -> Optional[str]:
    """If #board-of-directors (or BOARD_ROOM_ALIAS) exists, return its room id."""
    full_alias = f"#{ROOM_ALIAS_LOCAL}:{MATRIX_SERVER_NAME}"
    print(f"\n🔍 Checking for existing alias {full_alias}...")
    res = await client.room_resolve_alias(full_alias)
    if isinstance(res, RoomResolveAliasResponse):
        print(f"   ✅ Found existing room: {res.room_id}")
        return res.room_id
    if isinstance(res, RoomResolveAliasError):
        print(f"   ℹ️  No alias yet ({getattr(res, 'message', res)})")
    return None


async def create_room(client: AsyncClient) -> Optional[str]:
    print(f"\n🏛️  Creating room: {ROOM_NAME}")
    try:
        response = await client.room_create(
            visibility=RoomVisibility.private,
            alias=ROOM_ALIAS_LOCAL,
            name=ROOM_NAME,
            topic=ROOM_TOPIC,
            preset=RoomPreset.private_chat,
            initial_state=(
                {
                    "type": "m.room.guest_access",
                    "state_key": "",
                    "content": {"guest_access": "can_join"},
                },
                {
                    "type": "m.room.history_visibility",
                    "state_key": "",
                    "content": {"history_visibility": "shared"},
                },
            ),
        )
        if isinstance(response, RoomCreateResponse):
            print(f"   ✅ Room created — ID: {response.room_id}")
            return response.room_id
        print(f"   ❌ Failed to create room: {response}")
        return None
    except Exception as e:
        print(f"   ❌ Error creating room: {e}")
        return None


async def invite_bots(client: AsyncClient, room_id: str, bots: List[Dict]) -> Dict:
    print(f"\n👥 Inviting bots...")
    results: Dict[str, List[str]] = {"invited": [], "failed": []}
    for bot in bots:
        matrix_id = bot["matrix_id"]
        username = bot["username"]
        print(f"   📨 {username}...")
        try:
            response = await client.room_invite(room_id, matrix_id)
            if isinstance(response, RoomInviteResponse):
                print("      ✅ invited")
                results["invited"].append(matrix_id)
            else:
                print(f"      ❌ {response}")
                results["failed"].append(matrix_id)
        except Exception as e:
            print(f"      ❌ {e}")
            results["failed"].append(matrix_id)
    return results


async def send_welcome_message(client: AsyncClient, room_id: str, bot_count: int) -> None:
    welcome_msg = f"""🏛️ Welcome to the Inquiry Institute Board of Directors!

This room is for strategic discussions, governance, and collaborative decision-making.

**Members ({bot_count} bot accounts):** see `matrix-bot-credentials.json` — directors + Custodian, Parliamentarian, Hypatia.

**Guidelines:**
- Mention bots with @ to get their attention
- Use respectful, professional communication

Let's begin our work together! 🚀"""
    try:
        await client.room_send(
            room_id=room_id,
            message_type="m.room.message",
            content={"msgtype": "m.text", "body": welcome_msg},
        )
        print("\n   ✅ Welcome message sent")
    except Exception as e:
        print(f"\n   ⚠️  Could not send welcome message: {e}")


async def main() -> None:
    print("🔷 Board of Directors — create / reuse & invite")
    print("=" * 60)
    print(f"Matrix: {MATRIX_SERVER}")
    print(f"Domain: {MATRIX_SERVER_NAME}")
    print("")

    if not ADMIN_USERNAME or not ADMIN_PASSWORD:
        print("❌ Set ADMIN_USERNAME and ADMIN_PASSWORD")
        sys.exit(1)

    bots = await load_bot_credentials()
    if not bots:
        sys.exit(1)

    print(f"📋 {len(bots)} accounts in {CREDENTIALS_FILE.name}")

    admin_id = (
        ADMIN_USERNAME
        if ADMIN_USERNAME.startswith("@")
        else f"@{ADMIN_USERNAME}:{MATRIX_SERVER_NAME}"
    )
    client = AsyncClient(MATRIX_SERVER, admin_id)

    try:
        print(f"\n🔐 Logging in as {admin_id}...")
        login = await client.login(ADMIN_PASSWORD)
        if not isinstance(login, LoginResponse):
            print(f"❌ Login failed: {login}")
            sys.exit(1)
        print("   ✅ Logged in")

        room_id = await resolve_existing_board_room(client)
        if not room_id:
            room_id = await create_room(client)
        if not room_id:
            sys.exit(1)

        results = await invite_bots(client, room_id, bots)
        await send_welcome_message(client, room_id, len(bots))

        print("\n" + "=" * 60)
        print("📊 Summary")
        print("=" * 60)
        print(f"Room ID:     {room_id}")
        print(f"Alias:       #{ROOM_ALIAS_LOCAL}:{MATRIX_SERVER_NAME}")
        print(f"Invited OK:  {len(results['invited'])}")
        print(f"Failed:      {len(results['failed'])}")
        if results["failed"]:
            for mid in results["failed"]:
                print(f"   - {mid}")
        print("\nSet BOARD_ROOM_ID for other scripts, e.g.:")
        print(f'  export BOARD_ROOM_ID="{room_id}"')
    finally:
        await client.close()


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("\n👋 Interrupted")
