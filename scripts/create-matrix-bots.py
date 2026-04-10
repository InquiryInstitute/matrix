#!/usr/bin/env python3
"""
Create Matrix bot accounts for Inquiry Institute directors.
Each director will have a Matrix bot account that can participate in rooms.
"""

import os
import sys
import subprocess
import json
from pathlib import Path

# Director names (from Supabase board_of_directors table)
DIRECTORS = [
    "a.alkhwarizmi",    # Math - Algebra, formal abstraction
    "a.avicenna",       # Heal - Medicine, physiology
    "a.daVinci",        # Craf - Engineering, invention
    "a.darwin",         # Elag - Biology, evolution
    "a.diogenes",       # Heretic - Challenges conventions
    "a.katsushikaoi",   # Arts - Visual arts, perception
    "a.maryshelley",    # Humn - Literature, myth
    "a.newton",         # Natp - Physics, mathematics
    "a.plato",          # Meta - Philosophy, ethics
    "a.turing",         # Ains - Computer science, AI
    "a.shelley",        # Percy Bysshe Shelley - Poetry, radical thought
    "a.polidori",       # John Polidori - Vampires, gothic
    "a.byron",          # Lord Byron - Poetry, drama, travel
]

# Special bots
SPECIAL_BOTS = [
    "custodian",      # The custodian bot that manages the board
    "parliamentarian", # Ensures board follows proper procedures
    "hypatia"         # Custodian assistant
]

MATRIX_SERVER_URL = os.getenv("MATRIX_SERVER_URL", "https://matrix.inquiry.institute")
MATRIX_SERVER_NAME = os.getenv("MATRIX_DOMAIN", "matrix.inquiry.institute")
HOMESERVER_CONFIG = os.getenv(
    "HOMESERVER_CONFIG",
    os.path.expanduser("~/GitHub/matrix/matrix-data/homeserver.yaml")
)

def run_command(cmd, description):
    """Run a shell command and return the result."""
    print(f"🔄 {description}...")
    try:
        result = subprocess.run(
            cmd,
            shell=True,
            check=True,
            capture_output=True,
            text=True
        )
        print(f"✅ {description} - Success")
        return result.stdout
    except subprocess.CalledProcessError as e:
        print(f"❌ {description} - Failed")
        print(f"Error: {e.stderr}")
        return None

def register_matrix_user(username, password, admin=False):
    """Register a new Matrix user."""
    admin_flag = "-a" if admin else ""
    cmd = (
        f"docker-compose exec -T synapse register_new_matrix_user "
        f"-c /data/homeserver.yaml "
        f"{MATRIX_SERVER_URL} "
        f"{admin_flag} "
        f"-u {username} "
        f"-p {password} "
        f"--no-admin" if not admin else ""
    )
    
    # Alternative if not using docker-compose
    if not Path("docker-compose.yml").exists():
        cmd = (
            f"register_new_matrix_user "
            f"-c {HOMESERVER_CONFIG} "
            f"{MATRIX_SERVER_URL} "
            f"{admin_flag} "
            f"-u {username} "
            f"-p {password}"
        )
    
    # For interactive registration, we need to handle password input
    # This is a simplified version - in production, use Matrix Client-Server API
    print(f"⚠️  Manual registration required for {username}")
    print(f"   Run: register_new_matrix_user -c {HOMESERVER_CONFIG} {MATRIX_SERVER_URL} -u {username} -p <password>")
    return None

def create_bot_account(director_name):
    """Create a Matrix bot account for a director."""
    username = f"aDirector.{director_name}"
    password = f"bot_{director_name}_password_change_me"
    
    print(f"\n🤖 Creating bot account for {username}...")
    print(f"   Matrix server is on Fly.io - manual registration required")
    print(f"   Or use Matrix Admin API if you have admin access")
    
    return {
        "username": username,
        "password": password,
        "matrix_id": f"@{username}:{MATRIX_SERVER_NAME}",
        "status": "pending_registration"
    }

def create_special_bot_account(bot_name):
    """Create a Matrix bot account for special bots (like custodian)."""
    # Determine username prefix based on bot type
    if bot_name == "custodian":
        username = f"aCustodian.{bot_name}"
    elif bot_name == "parliamentarian":
        username = f"aParliamentarian.{bot_name}"
    elif bot_name == "hypatia":
        username = f"aAssistant.{bot_name}"
    else:
        username = f"aBot.{bot_name}"
    
    password = f"bot_{bot_name}_password_change_me"
    
    print(f"\n🤖 Creating special bot account for {username}...")
    print(f"   Matrix server is on Fly.io - manual registration required")
    print(f"   Or use Matrix Admin API if you have admin access")
    
    return {
        "username": username,
        "password": password,
        "matrix_id": f"@{username}:{MATRIX_SERVER_NAME}",
        "bot_type": bot_name,
        "status": "pending_registration"
    }

def create_board_room(bots):
    """Create a Board of Directors room and invite all bots."""
    print("\n🏛️  Board of Directors room setup")
    print("   This must be done via Matrix client (Element Web)")
    print("   Steps:")
    print("   1. Log in to Element Web: http://localhost:8080")
    print("   2. Create a new room: 'Inquiry Institute Board of Directors'")
    print("   3. Make it public or private as needed")
    print("   4. Invite all director bots:")
    for bot in bots:
        print(f"      - {bot['matrix_id']}")
    
    return None

def main():
    """Main function to create all director bots."""
    print("🔷 Creating Matrix bot accounts for Inquiry Institute Directors")
    print(f"Matrix Server: {MATRIX_SERVER_URL}")
    print(f"Server Name: {MATRIX_SERVER_NAME}")
    print("")
    
    bots = []
    
    # Create director bots
    print("👥 Creating Director Bots:")
    for director in DIRECTORS:
        bot_info = create_bot_account(director)
        if bot_info:
            bots.append(bot_info)
    
    # Create special bots
    print("\n🤖 Creating Special Bots:")
    for special_bot in SPECIAL_BOTS:
        bot_info = create_special_bot_account(special_bot)
        if bot_info:
            bots.append(bot_info)
    
    print("\n" + "="*60)
    print("✅ Bot Account Creation Summary")
    print("="*60)
    
    for bot in bots:
        print(f"\n{bot['username']}:")
        print(f"  Matrix ID: {bot['matrix_id']}")
        print(f"  Password: {bot['password']}")
        print(f"  Status: {bot['status']}")
    
    # Save bot credentials to file
    credentials_file = Path("matrix-bot-credentials.json")
    with open(credentials_file, "w") as f:
        json.dump(bots, f, indent=2)
    
    print(f"\n💾 Bot credentials saved to: {credentials_file}")
    print("⚠️  IMPORTANT: Change all bot passwords after first login!")
    
    create_board_room(bots)
    
    print("\n📚 Next steps:")
    print("1. Register bots on Fly.io Matrix server:")
    print("   Option A: Use Matrix Admin API (if you have admin token)")
    print("   Option B: Use Fly.io SSH:")
    print("      fly ssh console -a <your-matrix-app-name>")
    print("      register_new_matrix_user -c /data/homeserver.yaml https://matrix.inquiry.institute")
    print("")
    print("2. Update passwords in matrix-bot-credentials.json")
    print("3. Create Board of Directors room")
    print("4. Invite all director bots to the room")
    print("5. Configure bot webhooks/API integration")
    print("6. Test bot responses")

if __name__ == "__main__":
    main()
