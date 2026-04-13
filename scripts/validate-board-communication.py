#!/usr/bin/env python3
"""
Validate Board of Directors communication setup.
Checks login, board room membership, and optional send (custodian by default).

Remote homeservers rate-limit logins. Default mode is smoke (custodian only).
Use VALIDATE_BOARD_MODE=all to check every bot — requires VALIDATE_LOGIN_DELAY_SEC
between logins (default 4s).

Environment:
  MATRIX_SERVER or MATRIX_SERVER_URL — homeserver base URL (default http://localhost:8008)
  MATRIX_DOMAIN — server name (default matrix.castalia.institute)
  CUSTODIAN_PASSWORD — if set (e.g. in .env), overrides custodian password from matrix-bot-credentials.json
  VALIDATE_BOARD_MODE — smoke | all (default smoke)
  VALIDATE_LOGIN_DELAY_SEC — seconds between bots when mode=all (default 4)
  BOARD_ROOM_ID — if set, treat this room id as the board room when already joined
"""

from __future__ import annotations

import asyncio
import logging
import os
import sys
import json
from pathlib import Path
from typing import List, Dict, Optional, Union

try:
    from dotenv import load_dotenv

    load_dotenv()
except ImportError:
    pass

# Quiet matrix-nio schema warnings for events Synapse sends that omit optional fields.
logging.getLogger("nio").setLevel(logging.ERROR)

try:
    from nio import AsyncClient, LoginResponse, LoginError
except ImportError:
    print("❌ matrix-nio not installed. Install with: pip install matrix-nio")
    sys.exit(1)

MATRIX_SERVER = (
    os.getenv("MATRIX_SERVER")
    or os.getenv("MATRIX_SERVER_URL")
    or "http://localhost:8008"
).rstrip("/")
MATRIX_SERVER_NAME = os.getenv("MATRIX_DOMAIN", "matrix.castalia.institute")
BOARD_ROOM_ID_ENV = os.getenv("BOARD_ROOM_ID", "").strip()

VALIDATE_BOARD_MODE = os.getenv("VALIDATE_BOARD_MODE", "smoke").strip().lower()
VALIDATE_LOGIN_DELAY_SEC = float(os.getenv("VALIDATE_LOGIN_DELAY_SEC", "4"))

CREDENTIALS_FILE = Path("matrix-bot-credentials.json")


def password_for_bot(bot_info: Dict) -> str:
    """Custodian: CUSTODIAN_PASSWORD env overrides JSON when set."""
    u = (bot_info.get("username") or "").lower()
    env_pw = os.getenv("CUSTODIAN_PASSWORD", "").strip()
    if env_pw and "custodian" in u:
        return env_pw
    return bot_info["password"]


async def load_credentials() -> List[Dict]:
    if CREDENTIALS_FILE.exists():
        with open(CREDENTIALS_FILE, "r") as f:
            return json.load(f)
    return []


async def login_with_retry(client: AsyncClient, password: str) -> Union[LoginResponse, LoginError]:
    """Login once; on M_LIMIT_EXCEEDED wait (capped) and retry once."""
    response = await client.login(password)
    if isinstance(response, LoginResponse):
        return response
    if isinstance(response, LoginError) and response.status_code == "M_LIMIT_EXCEEDED":
        wait_ms = response.retry_after_ms or 60_000
        wait_s = min(wait_ms / 1000.0, 120.0) + 0.5
        print(f"   ⏳ Rate limited ({response.status_code}); waiting {wait_s:.0f}s then retry once…")
        await asyncio.sleep(wait_s)
        return await client.login(password)
    return response


async def find_board_room(client: AsyncClient) -> Optional[str]:
    """Resolve board room after sync: env BOARD_ROOM_ID, then name heuristic."""
    await client.sync(timeout=30_000, full_state=True)

    if BOARD_ROOM_ID_ENV and BOARD_ROOM_ID_ENV in client.rooms:
        return BOARD_ROOM_ID_ENV

    for room_id, room in client.rooms.items():
        name = (room.display_name or "") or ""
        if "board" in name.lower() or "director" in name.lower():
            return room_id
    return None


async def send_test_message(client: AsyncClient, room_id: str, message: str) -> bool:
    try:
        await client.room_send(
            room_id=room_id,
            message_type="m.room.message",
            content={"msgtype": "m.text", "body": message},
        )
        return True
    except Exception as e:
        print(f"   ❌ Failed to send message: {e}")
        return False


async def validate_bot(bot_info: Dict) -> Dict:
    username = bot_info["username"]
    password = password_for_bot(bot_info)
    matrix_id = bot_info["matrix_id"]

    print(f"\n🔍 Validating {username}...")

    result = {
        "username": username,
        "matrix_id": matrix_id,
        "login_success": False,
        "in_board_room": False,
        "can_send_message": False,
    }

    client = AsyncClient(MATRIX_SERVER, matrix_id)
    try:
        print("   🔐 Testing login...")
        response = await login_with_retry(client, password)
        if isinstance(response, LoginError):
            print(f"   ❌ Login failed: {response}")
            return result
        if not isinstance(response, LoginResponse):
            print(f"   ❌ Login failed: {response}")
            return result

        result["login_success"] = True
        print("   ✅ Login successful")

        print("   🔍 Looking for board room (syncing)...")
        board_room_id = await find_board_room(client)

        if board_room_id:
            result["in_board_room"] = True
            print(f"   ✅ Found board room: {board_room_id}")
            print("   📤 Testing message send...")
            test_msg = f"[Validation Test] {username} checking in!"
            if await send_test_message(client, board_room_id, test_msg):
                result["can_send_message"] = True
                print("   ✅ Message sent successfully")
            else:
                print("   ❌ Failed to send message")
        else:
            print("   ⚠️  No board/director room in joined rooms (set BOARD_ROOM_ID if needed)")
    except Exception as e:
        print(f"   ❌ Error: {e}")
    finally:
        await client.close()

    return result


async def validate_custodian_only() -> List[Dict]:
    credentials = await load_credentials()
    custodian = next(
        (b for b in credentials if "custodian" in b["username"].lower()),
        None,
    )
    if not custodian:
        print("❌ Custodian bot not found in credentials")
        return []

    print("\n" + "=" * 60)
    print("🔍 Smoke test: custodian only (set VALIDATE_BOARD_MODE=all for every bot)")
    print("=" * 60)

    r = await validate_bot(custodian)
    print("\n" + "=" * 60)
    print("📊 Custodian summary")
    print("=" * 60)
    print(f"Login: {'✅' if r['login_success'] else '❌'}")
    print(f"In board room: {'✅' if r['in_board_room'] else '❌'}")
    print(f"Can send: {'✅' if r['can_send_message'] else '❌'}")
    return [r]


async def validate_all_bots_staggered() -> List[Dict]:
    credentials = await load_credentials()
    if not credentials:
        print("❌ No bot credentials found")
        print("   Run: python3 scripts/create-matrix-bots.py")
        return []

    print("\n" + "=" * 60)
    print("🔍 Validating all bots (staggered logins)")
    print(f"   Delay between bots: {VALIDATE_LOGIN_DELAY_SEC}s")
    print("=" * 60)

    results: List[Dict] = []
    for i, bot in enumerate(credentials):
        if i:
            await asyncio.sleep(VALIDATE_LOGIN_DELAY_SEC)
        results.append(await validate_bot(bot))
    return results


async def print_summary(results: List[Dict]) -> None:
    if not results:
        return
    print("\n" + "=" * 60)
    print("📊 Validation Summary")
    print("=" * 60)

    total = len(results)
    login_success = sum(1 for r in results if r["login_success"])
    in_board = sum(1 for r in results if r["in_board_room"])
    can_message = sum(1 for r in results if r["can_send_message"])

    print(f"\nTotal bots: {total}")
    print(f"✅ Can login: {login_success}/{total}")
    print(f"✅ In board room: {in_board}/{total}")
    print(f"✅ Can send messages: {can_message}/{total}")

    if can_message == total and total > 0:
        print("\n🎉 All checked bots can post in the board room.")
    elif login_success == total:
        print("\n⚠️  All checked bots can login; some are not in the board room or cannot send.")
        print("   → Create/invite: python3 scripts/create-board-room.py or invite-missing-bots.py")
    else:
        print("\n❌ Some bots could not login — check credentials or wait out rate limits.")


async def main() -> None:
    print("🔷 Board of Directors Communication Validation")
    print("=" * 60)
    print(f"Matrix Server: {MATRIX_SERVER}")
    print(f"Server name: {MATRIX_SERVER_NAME}")
    print(f"Mode: {VALIDATE_BOARD_MODE}")
    print("")

    if not CREDENTIALS_FILE.exists():
        print("❌ Bot credentials file not found")
        print(f"   Expected: {CREDENTIALS_FILE}")
        print("   Run: python3 scripts/create-matrix-bots.py")
        sys.exit(1)

    if VALIDATE_BOARD_MODE in ("all", "full", "every"):
        results = await validate_all_bots_staggered()
    else:
        results = await validate_custodian_only()

    if not results:
        print("\n❌ Nothing to validate.")
        sys.exit(1)

    if VALIDATE_BOARD_MODE in ("all", "full", "every"):
        await print_summary(results)
        ok = all(r["login_success"] for r in results)
    else:
        ok = bool(results[0].get("login_success")) and bool(results[0].get("can_send_message"))

    print("\n📚 Next steps:")
    if VALIDATE_BOARD_MODE not in ("all", "full", "every") and not results[0].get("in_board_room"):
        print("1. Ensure board room exists and custodian is invited.")
        print("2. Or set BOARD_ROOM_ID if the room id is known.")
        print("3. Re-run this script.")
    elif VALIDATE_BOARD_MODE not in ("all", "full", "every") and results[0].get("can_send_message"):
        print(
            "✅ Smoke test passed. Every-bot checks:\n"
            "   VALIDATE_BOARD_MODE=all VALIDATE_LOGIN_DELAY_SEC=5 "
            "python3 scripts/validate-board-communication.py"
        )
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("\n\n👋 Validation interrupted")
        sys.exit(130)
