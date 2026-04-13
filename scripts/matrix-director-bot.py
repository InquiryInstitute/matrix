#!/usr/bin/env python3
"""
Matrix bot for Inquiry Institute directors.
This bot connects to Matrix and responds to messages using director RAG configs.
"""

import asyncio
import os
import json
import sys
from pathlib import Path
from typing import Optional

try:
    from nio import AsyncClient, MatrixRoom, RoomMessageText, LoginResponse
except ImportError:
    print("❌ matrix-nio not installed. Install with: pip install matrix-nio")
    sys.exit(1)

# Director configuration
DIRECTOR_NAME = os.getenv("DIRECTOR_NAME", "aetica")
MATRIX_SERVER = os.getenv("MATRIX_SERVER", "http://localhost:8008")
MATRIX_USERNAME = f"aDirector.{DIRECTOR_NAME}"
MATRIX_PASSWORD = os.getenv("MATRIX_PASSWORD")
MATRIX_SERVER_NAME = os.getenv("MATRIX_DOMAIN", "matrix.castalia.institute")

# Load director RAG config
CONFIG_DIR = Path(__file__).parent.parent / "configs" / "directors"
RAG_CONFIG_FILE = CONFIG_DIR / f"{DIRECTOR_NAME}.rag.json"


async def load_rag_config():
    """Load director's RAG configuration."""
    if RAG_CONFIG_FILE.exists():
        with open(RAG_CONFIG_FILE, "r") as f:
            return json.load(f)
    else:
        print(f"⚠️  RAG config not found: {RAG_CONFIG_FILE}")
        print(f"   Using default configuration")
        return {
            "system_prompt": f"You are aDirector.{DIRECTOR_NAME}, a member of the Inquiry Institute Board of Directors.",
            "temperature": 0.7,
        }


async def get_director_response(message: str, rag_config: dict) -> str:
    """Get response from director using their RAG config."""
    # This would typically call OpenRouter or Ollama
    # For now, return a simple response
    system_prompt = rag_config.get("system_prompt", "")
    
    # In production, this would call your LLM API
    # For example:
    # response = await call_openrouter(message, system_prompt, rag_config)
    
    return f"[{DIRECTOR_NAME}] Received: {message[:50]}... (Response would be generated via LLM)"


async def message_callback(room: MatrixRoom, event: RoomMessageText):
    """Handle incoming messages."""
    # Ignore our own messages
    if event.sender == client.user_id:
        return
    
    # Get the message text
    message_text = event.body.strip()
    
    # Check if we're mentioned or in a board room
    room_name = room.display_name or room.room_id
    is_board_room = "board" in room_name.lower() or "director" in room_name.lower()
    
    if is_board_room or f"@{MATRIX_USERNAME}" in message_text:
        print(f"📨 Message in {room_name} from {event.sender}: {message_text[:50]}")
        
        # Load RAG config
        rag_config = await load_rag_config()
        
        # Get director response
        response = await get_director_response(message_text, rag_config)
        
        # Send response
        await client.room_send(
            room_id=room.room_id,
            message_type="m.room.message",
            content={
                "msgtype": "m.text",
                "body": response
            }
        )
        print(f"✅ Sent response: {response[:50]}...")


async def main():
    """Main bot function."""
    global client
    
    if not MATRIX_PASSWORD:
        print(f"❌ MATRIX_PASSWORD environment variable not set")
        print(f"   Set it with: export MATRIX_PASSWORD=your_password")
        sys.exit(1)
    
    print(f"🔷 Starting Matrix bot for {DIRECTOR_NAME}")
    print(f"   Server: {MATRIX_SERVER}")
    print(f"   Username: {MATRIX_USERNAME}@{MATRIX_SERVER_NAME}")
    print("")
    
    # Create client
    client = AsyncClient(MATRIX_SERVER, f"@{MATRIX_USERNAME}:{MATRIX_SERVER_NAME}")
    
    # Login
    print("🔐 Logging in...")
    login_response = await client.login(MATRIX_PASSWORD)
    
    if isinstance(login_response, LoginResponse):
        print("✅ Logged in successfully")
        print(f"   User ID: {login_response.user_id}")
        print(f"   Device ID: {login_response.device_id}")
    else:
        print(f"❌ Login failed: {login_response}")
        sys.exit(1)
    
    # Set up event callbacks
    client.add_event_callback(message_callback, RoomMessageText)
    
    # Sync forever
    print("\n🔄 Syncing with Matrix server...")
    print("   Bot is now listening for messages.")
    print("   Press Ctrl+C to stop.\n")
    
    try:
        await client.sync_forever(timeout=30000, full_state=True)
    except KeyboardInterrupt:
        print("\n\n👋 Stopping bot...")
        await client.close()
        print("✅ Bot stopped")


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("\n👋 Bot interrupted by user")
    except Exception as e:
        print(f"\n❌ Error: {e}")
        import traceback
        traceback.print_exc()
