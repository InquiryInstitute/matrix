#!/usr/bin/env python3
"""
Matrix bot: in every room the bot has joined, react to faculty members and fetch replies from a
Supabase Edge function that implements OpenAI-style chat (e.g. ask-faculty: model = faculty id).

Typical setup (Inquiry Institute ask-faculty):
  POST {SUPABASE_URL}/functions/v1/ask-faculty
  Authorization: Bearer {SUPABASE_ANON_KEY}
  apikey: {SUPABASE_ANON_KEY}
  Body: {"model": "a.plato", "messages": [{"role":"user","content":"..."}]}

  LLM backend is configured on the Edge function: GCP_API_KEY + optional DEFAULT_LLM_MODEL
  (ask-faculty defaults to Gemma 4 26B on Google AI API when GCP_API_KEY is set; override e.g.
  gemini-2.5-flash). Pass X-LLM-Model from clients if needed.

Required environment:
  MATRIX_SERVER           — https://matrix.example.com
  MATRIX_DOMAIN           — matrix.example.com
  SUPABASE_URL            — https://xxxx.supabase.co
  SUPABASE_ANON_KEY       — public anon key (invokes edge function)
  Either:
    MATRIX_USER (full @local:domain) + MATRIX_ACCESS_TOKEN
  Or:
    MATRIX_USER + MATRIX_PASSWORD

Optional:
  ASK_FACULTY_URL         — full URL to the edge function (overrides SUPABASE_URL + path)
  ASK_FACULTY_PATH      — path under SUPABASE_URL, default functions/v1/ask-faculty
  ASK_FACULTY_CONTEXT   — X-Context header (e.g. dialogue, office_hours) — server-specific
  ASK_FACULTY_LLM_MODEL — X-LLM-Model header (underlying LLM; server interprets)
  FACULTY_REPLY_MODE    — mention (default) | always | question
  FACULTY_LOCALPART_REGEX — override default faculty MXID pattern (Python regex, one group or full match)
  FACULTY_NAMES_JSON    — path to JSON map {"a.plato": "Plato"} for logging only
  configs/faculty_assistant.json — prepend_room_name, extra_request_fields merged into JSON body

Room metadata (keeps the bot dumb; prompt logic lives in room state + ask-faculty):
  Custom state event org.castalia.institute.room_ai_context (override: ROOM_AI_EVENT_TYPE).
  See configs/room_ai_context.example.json and scripts/set-room-ai-metadata.py.
  Fields: prompt_prepend, prompt_append, context, extra_request_fields, header_overrides.
  Merged into the ask-faculty request (room overrides file/env for headers/body extras).
"""

from __future__ import annotations

import asyncio
import json
import logging
import os
import re
import sys
import time
from pathlib import Path
from typing import Any

try:
    import aiohttp
except ImportError:
    aiohttp = None  # type: ignore

try:
    from nio import (
        AsyncClient,
        LoginResponse,
        MatrixRoom,
        RoomMessageText,
        RoomGetStateEventResponse,
        RoomGetStateEventError,
    )
except ImportError:
    print("matrix-nio required: pip install matrix-nio", file=sys.stderr)
    sys.exit(1)

log = logging.getLogger("faculty-assistant")

MATRIX_SERVER = os.environ.get("MATRIX_SERVER", "").rstrip("/")
MATRIX_DOMAIN = os.environ.get("MATRIX_DOMAIN", "").strip()
MATRIX_USER = os.environ.get("MATRIX_USER", "").strip()
MATRIX_PASSWORD = os.environ.get("MATRIX_PASSWORD", "").strip()
MATRIX_ACCESS_TOKEN = os.environ.get("MATRIX_ACCESS_TOKEN", "").strip()

SUPABASE_URL = os.environ.get("SUPABASE_URL", "").strip().rstrip("/")
SUPABASE_ANON_KEY = os.environ.get("SUPABASE_ANON_KEY", "").strip()
ASK_FACULTY_URL = os.environ.get("ASK_FACULTY_URL", "").strip().rstrip("/")
ASK_FACULTY_PATH = os.environ.get("ASK_FACULTY_PATH", "functions/v1/ask-faculty").strip().strip("/")
ASK_FACULTY_CONTEXT = os.environ.get("ASK_FACULTY_CONTEXT", "").strip()
ASK_FACULTY_LLM_MODEL = os.environ.get("ASK_FACULTY_LLM_MODEL", "").strip()

FACULTY_REPLY_MODE = os.environ.get("FACULTY_REPLY_MODE", "mention").strip().lower()
FACULTY_LOCALPART_REGEX = os.environ.get("FACULTY_LOCALPART_REGEX", "").strip()

CONFIG_PATH = Path(__file__).resolve().parent.parent / "configs" / "faculty_assistant.json"
FACULTY_NAMES_PATH = os.environ.get("FACULTY_NAMES_JSON", "").strip()

ROOM_AI_EVENT_TYPE = os.environ.get(
    "ROOM_AI_EVENT_TYPE", "org.castalia.institute.room_ai_context"
).strip()
ROOM_AI_CACHE_TTL = float(os.environ.get("ROOM_AI_CACHE_TTL", "120"))

# Default: faculty MXIDs like @a.plato:domain (not @aDirector.*)
_DEFAULT_FACULTY = re.compile(r"^a\.[a-zA-Z][a-zA-Z0-9._-]*$")
_faculty_pattern: re.Pattern[str] | None = None

client: AsyncClient | None = None
_bot_local: str | None = None
_config: dict[str, Any] = {}
_name_map: dict[str, str] = {}
_room_ai_cache: dict[str, tuple[float, dict[str, Any]]] = {}


def _faculty_re() -> re.Pattern[str]:
    global _faculty_pattern
    if _faculty_pattern is not None:
        return _faculty_pattern
    if FACULTY_LOCALPART_REGEX:
        _faculty_pattern = re.compile(FACULTY_LOCALPART_REGEX)
    else:
        _faculty_pattern = _DEFAULT_FACULTY
    return _faculty_pattern


def _load_json(path: Path) -> dict[str, Any]:
    if not path.is_file():
        return {}
    with path.open() as f:
        return json.load(f)


def _parse_mxid(mxid: str) -> tuple[str, str] | None:
    if not mxid.startswith("@"):
        return None
    rest = mxid[1:]
    if ":" not in rest:
        return None
    local, domain = rest.split(":", 1)
    return local, domain


def is_faculty_sender(sender_mxid: str) -> bool:
    parsed = _parse_mxid(sender_mxid)
    if not parsed:
        return False
    local, domain = parsed
    if domain != MATRIX_DOMAIN:
        return False
    return bool(_faculty_re().match(local))


def display_name_for(faculty_local: str) -> str:
    return _name_map.get(faculty_local, faculty_local)


def should_trigger(body: str, _mention_local: str) -> bool:
    b = body.strip()
    if not b:
        return False
    if FACULTY_REPLY_MODE == "always":
        return True
    if FACULTY_REPLY_MODE == "question":
        return "?" in b
    if _bot_local and f"@{_bot_local}" in body:
        return True
    full_mxid = f"@{_bot_local}:{MATRIX_DOMAIN}" if _bot_local else ""
    if full_mxid and full_mxid in body:
        return True
    return False


def _ask_faculty_endpoint() -> str:
    if ASK_FACULTY_URL:
        return ASK_FACULTY_URL
    if not SUPABASE_URL:
        return ""
    return f"{SUPABASE_URL}/{ASK_FACULTY_PATH}"


def _build_user_content(room: MatrixRoom, raw_message: str) -> str:
    room_name = room.display_name or room.room_id
    if _config.get("prepend_room_name", True):
        return f"[Room: {room_name}]\n\n{raw_message}"
    return raw_message


def _apply_room_prompt_wrappers(base: str, meta: dict[str, Any]) -> str:
    """Apply prompt_prepend / prompt_append from room state."""
    out = base
    pre = (meta.get("prompt_prepend") or "").strip()
    if pre:
        out = f"{pre}\n\n{out}"
    app = (meta.get("prompt_append") or "").strip()
    if app:
        out = f"{out}\n\n--- Room context ---\n{app}"
    return out


async def get_room_ai_metadata(room_id: str) -> dict[str, Any]:
    """Fetch custom room state; short TTL cache."""
    global client, _room_ai_cache
    assert client is not None
    now = time.time()
    hit = _room_ai_cache.get(room_id)
    if hit and (now - hit[0]) < ROOM_AI_CACHE_TTL:
        return hit[1]

    res = await client.room_get_state_event(room_id, ROOM_AI_EVENT_TYPE, "")
    if isinstance(res, RoomGetStateEventResponse) and res.content:
        data = dict(res.content)
        _room_ai_cache[room_id] = (now, data)
        return data
    if isinstance(res, RoomGetStateEventError):
        log.debug("no %s in %s", ROOM_AI_EVENT_TYPE, room_id)

    _room_ai_cache[room_id] = (now, {})
    return {}


async def generate_reply(
    *,
    faculty_local: str,
    room: MatrixRoom,
    message: str,
) -> str:
    url = _ask_faculty_endpoint()
    if not url or not SUPABASE_ANON_KEY:
        return (
            "[faculty-assistant] Set SUPABASE_URL, SUPABASE_ANON_KEY "
            "(or ASK_FACULTY_URL + SUPABASE_ANON_KEY) to call ask-faculty."
        )

    if aiohttp is None:
        return "[faculty-assistant] pip install aiohttp"

    meta = await get_room_ai_metadata(room.room_id)
    user_text = _apply_room_prompt_wrappers(_build_user_content(room, message), meta)

    # Edge function: model field is faculty id (e.g. a.plato)
    body: dict[str, Any] = {
        "model": faculty_local,
        "messages": [{"role": "user", "content": user_text}],
        "temperature": float(os.environ.get("ASK_FACULTY_TEMPERATURE", "0.7")),
    }
    extra = _config.get("extra_request_fields") or {}
    if isinstance(extra, dict):
        body.update(extra)
    room_extra = meta.get("extra_request_fields")
    if isinstance(room_extra, dict):
        body.update(room_extra)

    ctx = meta.get("context")
    if ctx and isinstance(ctx, str) and ctx.strip():
        body["context"] = ctx.strip()

    headers = {
        "Authorization": f"Bearer {SUPABASE_ANON_KEY}",
        "apikey": SUPABASE_ANON_KEY,
        "Content-Type": "application/json",
    }
    if ASK_FACULTY_CONTEXT:
        headers["X-Context"] = ASK_FACULTY_CONTEXT
    if ASK_FACULTY_LLM_MODEL:
        headers["X-LLM-Model"] = ASK_FACULTY_LLM_MODEL

    ho = meta.get("header_overrides")
    if isinstance(ho, dict):
        for k, v in ho.items():
            if isinstance(k, str) and k.strip() and v is not None:
                headers[k] = str(v)

    referer = MATRIX_SERVER or "https://localhost"
    headers.setdefault("Referer", referer)

    try:
        async with aiohttp.ClientSession() as session:
            async with session.post(
                url,
                headers=headers,
                json=body,
                timeout=aiohttp.ClientTimeout(total=180),
            ) as resp:
                text = await resp.text()
                if resp.status != 200:
                    log.warning("ask-faculty HTTP %s: %s", resp.status, text[:800])
                    try:
                        err = json.loads(text)
                        detail = err.get("details") or err.get("error") or text
                    except json.JSONDecodeError:
                        detail = text[:500]
                    return f"[faculty-assistant] ask-faculty error ({resp.status}): {detail}"

                data = json.loads(text)
                choice = (data.get("choices") or [{}])[0]
                msg = (choice.get("message") or {}).get("content") or ""
                out = (msg or "").strip()
                return out or "[faculty-assistant] (empty reply from ask-faculty)"
    except Exception as exc:
        log.exception("ask-faculty request failed")
        return f"[faculty-assistant] {exc}"


async def on_room_message(room: MatrixRoom, event: RoomMessageText) -> None:
    global client
    assert client is not None
    if event.sender == client.user_id:
        return
    if not isinstance(event, RoomMessageText):
        return
    if not is_faculty_sender(event.sender):
        return

    parsed = _parse_mxid(event.sender)
    assert parsed is not None
    faculty_local, _ = parsed

    body = (event.body or "").strip()
    if not should_trigger(body, faculty_local):
        return

    log.info("Replying to %s in %s mode=%s", event.sender, room.room_id, FACULTY_REPLY_MODE)
    reply = await generate_reply(faculty_local=faculty_local, room=room, message=body)
    await client.room_send(
        room_id=room.room_id,
        message_type="m.room.message",
        content={"msgtype": "m.text", "body": reply},
    )


async def main() -> None:
    global client, _bot_local, _config, _name_map

    logging.basicConfig(
        level=os.environ.get("LOG_LEVEL", "INFO").upper(),
        format="%(asctime)s [%(name)s] %(levelname)s: %(message)s",
    )

    if not MATRIX_SERVER:
        log.error("MATRIX_SERVER is required")
        sys.exit(1)
    if not MATRIX_DOMAIN:
        log.error("MATRIX_DOMAIN is required")
        sys.exit(1)
    if not MATRIX_USER or ":" not in MATRIX_USER or not MATRIX_USER.startswith("@"):
        log.error("MATRIX_USER must be a full MXID")
        sys.exit(1)

    bl = _parse_mxid(MATRIX_USER)
    if not bl:
        log.error("Invalid MATRIX_USER")
        sys.exit(1)
    _bot_local, dom = bl
    if dom != MATRIX_DOMAIN:
        log.error("MATRIX_USER server part must match MATRIX_DOMAIN")
        sys.exit(1)

    if not MATRIX_ACCESS_TOKEN and not MATRIX_PASSWORD:
        log.error("Set MATRIX_ACCESS_TOKEN or MATRIX_PASSWORD")
        sys.exit(1)

    if not ASK_FACULTY_URL and not SUPABASE_URL:
        log.error("Set SUPABASE_URL (or ASK_FACULTY_URL) and SUPABASE_ANON_KEY")
        sys.exit(1)
    if not SUPABASE_ANON_KEY:
        log.error("SUPABASE_ANON_KEY is required to invoke the edge function")
        sys.exit(1)

    _config = _load_json(CONFIG_PATH)
    if FACULTY_NAMES_PATH:
        p = Path(FACULTY_NAMES_PATH)
        if p.is_file():
            raw = _load_json(p)
            _name_map = raw if isinstance(raw, dict) else {}

    client = AsyncClient(MATRIX_SERVER, MATRIX_USER)

    if MATRIX_ACCESS_TOKEN:
        client.access_token = MATRIX_ACCESS_TOKEN
        client.user_id = MATRIX_USER
        log.info("Using existing access token for %s", MATRIX_USER)
    else:
        resp = await client.login(MATRIX_PASSWORD)
        if not isinstance(resp, LoginResponse):
            log.error("Login failed: %s", resp)
            sys.exit(1)
        log.info("Logged in as %s", resp.user_id)

    client.add_event_callback(on_room_message, RoomMessageText)

    log.info(
        "Faculty assistant online as %s; ask-faculty=%s; reply_mode=%s",
        MATRIX_USER,
        _ask_faculty_endpoint(),
        FACULTY_REPLY_MODE,
    )
    await client.sync_forever(timeout=30000, full_state=True)


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        log.info("Stopped")
