#!/usr/bin/env python3
"""
Minimal web server so you can create a topic room by passing parameters via URL.

Usage:
  export ADMIN_USERNAME=your_admin  ADMIN_PASSWORD=your_password
  python3 scripts/serve-topic-room.py

Then open in browser (or link from another app):
  http://localhost:5050/create-room?topic=phantasmagoria+at+Villa+Diodati+during+a+thunderstorm&name=Villa+Diodati&bots=a.maryshelley,a.shelley,a.polidori,a.byron

Query params:
  topic   - Conversation theme (e.g. phantasmagoria at Villa Diodati during a thunderstorm)
  name    - Room name (default: Topic Room)
  bots    - Comma-separated faculty ids (default: a.maryshelley,a.shelley,a.polidori,a.byron)
  opening - Optional first message (default: "Let's discuss: {topic}")
  redirect - If 1, redirect to Element room link; otherwise return JSON
"""

import asyncio
import importlib.util
import os
import sys
from pathlib import Path
from urllib.parse import unquote_plus

# Load create-topic-room (module name has hyphen)
_script_dir = Path(__file__).resolve().parent
_spec = importlib.util.spec_from_file_location(
    "create_topic_room",
    _script_dir / "create-topic-room.py",
)
_create_topic_room = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_create_topic_room)

try:
    from flask import Flask, request, redirect, jsonify
except ImportError:
    print("Install Flask: pip install flask")
    sys.exit(1)

app = Flask(__name__)
PORT = int(os.getenv("PORT", "5050"))
ELEMENT_URL = os.getenv("ELEMENT_URL", "http://localhost:8080")
# Optional: set CORS_ORIGIN (e.g. https://app.inquiry.institute) so web apps on that origin can call /create-room via fetch()
CORS_ORIGIN = os.getenv("CORS_ORIGIN", "").strip()


@app.after_request
def _cors(resp):
    if CORS_ORIGIN:
        resp.headers["Access-Control-Allow-Origin"] = CORS_ORIGIN
        resp.headers["Access-Control-Allow-Methods"] = "GET, OPTIONS"
        resp.headers["Access-Control-Allow-Headers"] = "Content-Type"
    return resp


@app.route("/create-room", methods=["GET", "OPTIONS"])
def create_room():
    if request.method == "OPTIONS":
        return "", 204
    topic = unquote_plus(request.args.get("topic", "Discussion")).strip()
    name = unquote_plus(request.args.get("name", "Topic Room")).strip()
    bots_str = request.args.get("bots", "a.maryshelley,a.shelley,a.polidori,a.byron").strip()
    opening = unquote_plus(request.args.get("opening", "")).strip()
    do_redirect = request.args.get("redirect", "").strip() == "1"

    bot_ids = [x.strip() for x in bots_str.split(",") if x.strip()]
    if not opening and topic:
        opening = f"Let's discuss: {topic}"

    try:
        room_id = asyncio.run(
            _create_topic_room.main(
                room_name=name,
                room_topic=topic,
                bot_ids=bot_ids,
                opening_message=opening or None,
                alias_name=None,
            )
        )
    except Exception as e:
        return jsonify({"ok": False, "error": str(e)}), 500

    if not room_id:
        return jsonify({"ok": False, "error": "Room creation failed"}), 500

    element_link = f"{ELEMENT_URL}/#/room/{room_id}"
    if do_redirect:
        return redirect(element_link)
    return jsonify({"ok": True, "room_id": room_id, "element_url": element_link})


@app.route("/")
def index():
    return """
    <h1>Topic room from URL</h1>
    <p>Create a room and invite faculty by opening a URL like:</p>
    <pre>
/create-room?topic=phantasmagoria+at+Villa+Diodati+during+a+thunderstorm&amp;name=Villa+Diodati&amp;bots=a.maryshelley,a.shelley,a.polidori,a.byron
    </pre>
    <p>Params: <code>topic</code>, <code>name</code>, <code>bots</code> (comma-separated), <code>opening</code> (optional), <code>redirect=1</code> to open Element.</p>
    """


if __name__ == "__main__":
    if not os.getenv("ADMIN_USERNAME") or not os.getenv("ADMIN_PASSWORD"):
        print("Set ADMIN_USERNAME and ADMIN_PASSWORD")
        sys.exit(1)
    app.run(host="0.0.0.0", port=PORT, debug=False)
