#!/usr/bin/env python3
"""
Create a topic room, invite selected faculty (bots), and post an opening message
so they can converse about a topic. Supports topic and bots from CLI, env, or URL query.

Example:
  python3 scripts/create-topic-room.py \\
    --name "Villa Diodati" \\
    --topic "Phantasmagoria at Villa Diodati during a thunderstorm" \\
    --bots a.maryshelley,a.shelley,a.polidori,a.byron

  # Or via env (e.g. from a web handler that receives URL params):
  ROOM_NAME="Villa Diodati" ROOM_TOPIC="Phantasmagoria..." BOT_IDS="a.maryshelley,a.shelley,..." \\
    python3 scripts/create-topic-room.py
"""

import argparse
import asyncio
import json
import os
import sys
from pathlib import Path
from typing import List, Dict, Optional

try:
    from nio import AsyncClient, LoginResponse, RoomCreateResponse, RoomInviteResponse
except ImportError:
    print("❌ matrix-nio not installed. Install with: pip install matrix-nio")
    sys.exit(1)

MATRIX_SERVER = os.getenv("MATRIX_SERVER", "http://localhost:8008")
MATRIX_SERVER_NAME = os.getenv("MATRIX_DOMAIN", "matrix.inquiry.institute")
ELEMENT_URL = os.getenv("ELEMENT_URL", "http://localhost:8080")
CREDENTIALS_FILE = Path(__file__).parent.parent / "matrix-bot-credentials.json"


def load_bot_credentials() -> List[Dict]:
    """Load bot credentials from file."""
    if CREDENTIALS_FILE.exists():
        with open(CREDENTIALS_FILE, "r") as f:
            return json.load(f)
    return []


def bots_for_ids(all_bots: List[Dict], bot_ids: List[str]) -> List[Dict]:
    """Return bots whose username ends with one of the given ids (e.g. a.maryshelley)."""
    ids_set = {s.strip().lower() for s in bot_ids if s.strip()}
    out = []
    for bot in all_bots:
        username = bot.get("username", "")
        if not username.startswith("aDirector."):
            continue
        suffix = username.replace("aDirector.", "").lower()
        if suffix in ids_set:
            out.append(bot)
            continue
        # Also match a.shelley -> aDirector.a.shelley
        for i in ids_set:
            if suffix == i or suffix.endswith("." + i):
                out.append(bot)
                break
    return out


async def create_room(
    client: AsyncClient,
    room_name: str,
    room_topic: str,
    alias_name: Optional[str] = None,
) -> Optional[str]:
    """Create a room with the given name and topic."""
    safe_alias = (alias_name or room_name.lower().replace(" ", "-").replace("'", "")).replace(" ", "-")
    room_config = {
        "name": room_name,
        "topic": room_topic,
        "preset": "private_chat",
        "visibility": "private",
        "initial_state": [
            {"type": "m.room.guest_access", "state_key": "", "content": {"guest_access": "can_join"}},
            {"type": "m.room.history_visibility", "state_key": "", "content": {"history_visibility": "shared"}},
        ],
        "power_level_content_override": {
            "users_default": 0,
            "events_default": 0,
            "state_default": 50,
            "invite": 0,
        },
    }
    if safe_alias:
        room_config["room_alias_name"] = safe_alias[:50]
    try:
        response = await client.room_create(**room_config)
        if isinstance(response, RoomCreateResponse):
            return response.room_id
    except Exception as e:
        print(f"   ❌ Error creating room: {e}")
    return None


async def invite_bots(client: AsyncClient, room_id: str, bots: List[Dict]) -> Dict:
    """Invite listed bots to the room."""
    results = {"invited": [], "failed": []}
    for bot in bots:
        matrix_id = bot["matrix_id"]
        username = bot["username"]
        try:
            response = await client.room_invite(room_id, matrix_id)
            if isinstance(response, RoomInviteResponse):
                results["invited"].append(username)
                print(f"      ✅ {username}")
            else:
                results["failed"].append(username)
                print(f"      ❌ {username}: {response}")
        except Exception as e:
            results["failed"].append(username)
            print(f"      ❌ {username}: {e}")
    return results


async def send_message(client: AsyncClient, room_id: str, body: str) -> bool:
    """Send a text message to the room."""
    try:
        await client.room_send(
            room_id=room_id,
            message_type="m.room.message",
            content={"msgtype": "m.text", "body": body},
        )
        return True
    except Exception as e:
        print(f"   ⚠️  Could not send message: {e}")
        return False


async def main(
    room_name: str,
    room_topic: str,
    bot_ids: List[str],
    opening_message: Optional[str] = None,
    alias_name: Optional[str] = None,
) -> Optional[str]:
    """Create topic room, invite selected bots, post opening message. Returns room_id or None."""
    admin_user = os.getenv("ADMIN_USERNAME")
    admin_pass = os.getenv("ADMIN_PASSWORD")
    if not admin_user or not admin_pass:
        print("❌ Set ADMIN_USERNAME and ADMIN_PASSWORD (or pass interactively)")
        admin_user = input("Admin username: ").strip()
        admin_pass = input("Admin password: ").strip()
        if not admin_user or not admin_pass:
            return None

    all_bots = load_bot_credentials()
    if not all_bots:
        print("❌ No bots in matrix-bot-credentials.json")
        return None

    bots = bots_for_ids(all_bots, bot_ids)
    if not bots:
        print(f"❌ No matching bots for ids: {bot_ids}")
        print("   Available director suffixes: a.maryshelley, a.shelley, a.polidori, a.byron, etc.")
        return None

    client = AsyncClient(MATRIX_SERVER, f"@{admin_user}:{MATRIX_SERVER_NAME}")
    try:
        login = await client.login(admin_pass)
        if not isinstance(login, LoginResponse):
            print(f"❌ Login failed: {login}")
            return None

        print(f"\n🏛️  Creating room: {room_name}")
        print(f"   Topic: {room_topic}")
        room_id = await create_room(client, room_name, room_topic, alias_name=alias_name)
        if not room_id:
            return None
        print(f"   ✅ Room ID: {room_id}")

        print(f"\n👥 Inviting {len(bots)} bots...")
        await invite_bots(client, room_id, bots)

        if opening_message:
            print("\n📨 Posting opening message...")
            await send_message(client, room_id, opening_message)

        return room_id
    finally:
        await client.close()


def run_from_url_query(query: Dict) -> Dict:
    """
    Run room creation from a URL-style query (e.g. from a web app).
    query can have: topic, name, bots (comma-separated), opening (optional).
    """
    topic = (query.get("topic") or "").strip() or "Discussion"
    name = (query.get("name") or query.get("room") or "Topic Room").strip()
    bots_str = (query.get("bots") or query.get("faculty") or "a.maryshelley,a.shelley,a.polidori,a.byron").strip()
    opening = (query.get("opening") or query.get("message") or "").strip()
    if not opening and topic:
        opening = f"Let's discuss: {topic}"

    bot_ids = [x.strip() for x in bots_str.split(",") if x.strip()]
    loop = asyncio.get_event_loop()
    room_id = loop.run_until_complete(main(name, topic, bot_ids, opening_message=opening or None))
    if room_id:
        return {"ok": True, "room_id": room_id, "element_url": f"{ELEMENT_URL}/#/room/{room_id}"}
    return {"ok": False, "error": "Room creation failed"}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Create a topic room and invite selected faculty bots")
    parser.add_argument("--name", default=os.getenv("ROOM_NAME", "Topic Room"), help="Room name")
    parser.add_argument("--topic", default=os.getenv("ROOM_TOPIC", "Discussion"), help="Room topic / conversation theme")
    parser.add_argument("--bots", default=os.getenv("BOT_IDS", "a.maryshelley,a.shelley,a.polidori,a.byron"), help="Comma-separated bot ids")
    parser.add_argument("--opening", default=os.getenv("OPENING_MESSAGE"), help="First message to post (default: topic)")
    parser.add_argument("--alias", default=os.getenv("ROOM_ALIAS"), help="Room alias name (optional)")
    args = parser.parse_args()

    bot_ids = [x.strip() for x in args.bots.split(",") if x.strip()]
    opening = args.opening or f"Let's discuss: {args.topic}"

    room_id = asyncio.run(main(args.name, args.topic, bot_ids, opening_message=opening, alias_name=args.alias or None))
    if room_id:
        print("\n" + "=" * 60)
        print("✅ Room created. Faculty can now converse in the room.")
        print(f"   Room ID: {room_id}")
        print(f"   Open in Element: {ELEMENT_URL}/#/room/{room_id}")
        print("=" * 60)
    else:
        sys.exit(1)
