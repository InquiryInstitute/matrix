#!/usr/bin/env python3
"""
Set room-level AI metadata (custom Matrix state) read by matrix-faculty-assistant-bot.

Event type: org.inquiry.institute.room_ai_context (empty state_key)
Content: see configs/room_ai_context.example.json

Usage:
  export MATRIX_SERVER=https://matrix.example.com
  export MATRIX_DOMAIN=matrix.example.com
  export ADMIN_USERNAME=...
  export ADMIN_PASSWORD=...

  python3 scripts/set-room-ai-metadata.py '!room:domain' -f configs/room_ai_context.example.json
  python3 scripts/set-room-ai-metadata.py '!room:domain' -j '{"prompt_append":"Keep answers short."}'
"""

from __future__ import annotations

import argparse
import asyncio
import json
import os
import sys
from pathlib import Path

try:
    from nio import AsyncClient, LoginResponse, RoomPutStateResponse
except ImportError:
    print("pip install matrix-nio", file=sys.stderr)
    sys.exit(1)

MATRIX_SERVER = os.environ.get("MATRIX_SERVER", "https://matrix.inquiry.institute").rstrip("/")
MATRIX_DOMAIN = os.environ.get("MATRIX_DOMAIN", "matrix.inquiry.institute")
ADMIN_USERNAME = os.environ.get("ADMIN_USERNAME")
ADMIN_PASSWORD = os.environ.get("ADMIN_PASSWORD")

EVENT_TYPE = os.environ.get("ROOM_AI_EVENT_TYPE", "org.inquiry.institute.room_ai_context")


async def main() -> None:
    ap = argparse.ArgumentParser(description="Put room AI metadata state event")
    ap.add_argument("room_id", help="Room id e.g. !xxx:domain")
    g = ap.add_mutually_exclusive_group(required=True)
    g.add_argument("--file", "-f", type=Path, dest="json_file", help="JSON file with event content")
    g.add_argument("--json", "-j", dest="inline_json", help="JSON string for event content")
    args = ap.parse_args()

    if not ADMIN_USERNAME or not ADMIN_PASSWORD:
        print("Set ADMIN_USERNAME and ADMIN_PASSWORD", file=sys.stderr)
        sys.exit(1)

    if args.json_file is not None:
        content = json.loads(args.json_file.read_text())
    else:
        content = json.loads(args.inline_json or "{}")

    if not isinstance(content, dict):
        print("Content must be a JSON object", file=sys.stderr)
        sys.exit(1)

    admin_id = (
        ADMIN_USERNAME
        if ADMIN_USERNAME.startswith("@")
        else f"@{ADMIN_USERNAME}:{MATRIX_DOMAIN}"
    )
    client = AsyncClient(MATRIX_SERVER, admin_id)
    try:
        lg = await client.login(ADMIN_PASSWORD)
        if not isinstance(lg, LoginResponse):
            print("Login failed:", lg)
            sys.exit(1)

        res = await client.room_put_state(args.room_id, EVENT_TYPE, content, state_key="")
        if isinstance(res, RoomPutStateResponse):
            print(f"OK: {EVENT_TYPE} set on {args.room_id}")
        else:
            print("Failed:", res)
            sys.exit(1)
    finally:
        await client.close()


if __name__ == "__main__":
    asyncio.run(main())
