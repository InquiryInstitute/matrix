#!/usr/bin/env python3
"""Compare board room membership to matrix-bot-credentials.json (no invites)."""

import asyncio
import json
import os
import sys
from pathlib import Path

try:
    from nio import (
        AsyncClient,
        LoginResponse,
        RoomResolveAliasResponse,
    )
except ImportError:
    print("pip install matrix-nio")
    sys.exit(1)

MATRIX_SERVER = os.getenv("MATRIX_SERVER", "https://matrix.castalia.institute").rstrip("/")
MATRIX_SERVER_NAME = os.getenv("MATRIX_DOMAIN", "matrix.castalia.institute")
BOARD_ROOM_ID = os.getenv("BOARD_ROOM_ID", "").strip()
BOARD_ROOM_ALIAS = os.getenv("BOARD_ROOM_ALIAS", "board-of-directors").strip()
ADMIN_USERNAME = os.getenv("ADMIN_USERNAME")
ADMIN_PASSWORD = os.getenv("ADMIN_PASSWORD")

ROOT = Path(__file__).resolve().parent.parent
CRED = ROOT / "matrix-bot-credentials.json"


async def main() -> None:
    if not ADMIN_USERNAME or not ADMIN_PASSWORD:
        print("Set ADMIN_USERNAME and ADMIN_PASSWORD")
        sys.exit(1)
    with open(CRED) as f:
        bots = json.load(f)
    expected = {b["matrix_id"] for b in bots}

    admin_id = (
        ADMIN_USERNAME
        if ADMIN_USERNAME.startswith("@")
        else f"@{ADMIN_USERNAME}:{MATRIX_SERVER_NAME}"
    )
    client = AsyncClient(MATRIX_SERVER, admin_id)
    try:
        lg = await client.login(ADMIN_PASSWORD)
        if not isinstance(lg, LoginResponse):
            print("Login failed:", lg)
            sys.exit(1)

        if BOARD_ROOM_ID:
            room_id = BOARD_ROOM_ID
        else:
            res = await client.room_resolve_alias(f"#{BOARD_ROOM_ALIAS}:{MATRIX_SERVER_NAME}")
            if not isinstance(res, RoomResolveAliasResponse):
                print("Could not resolve room alias. Create room or set BOARD_ROOM_ID.")
                sys.exit(1)
            room_id = res.room_id

        print(f"Room: {room_id}")
        try:
            await client.join(room_id)
        except Exception as e:
            print(f"join note: {e}")

        await client.sync(timeout=30000, full_state=True)
        room = client.rooms.get(room_id)
        if not room:
            print("Room not in client state after sync.")
            sys.exit(1)

        members = set(room.users.keys())
        missing = expected - members
        extra = members - expected

        print(f"\nExpected (from credentials): {len(expected)}")
        print(f"Joined members seen:       {len(members)}")
        print(f"Missing expected:          {len(missing)}")
        for m in sorted(missing):
            print(f"  - {m}")
        if extra:
            print(f"Other members (not in credentials file): {len(extra)}")
            for m in sorted(extra)[:20]:
                print(f"  + {m}")
            if len(extra) > 20:
                print("  ...")
        sys.exit(0 if not missing else 2)
    finally:
        await client.close()


if __name__ == "__main__":
    asyncio.run(main())
