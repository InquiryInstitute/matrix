# Board of Directors - Fly.io Setup

Your Matrix server is running on Fly.io at `https://matrix.inquiry.institute`.

## Current Status

✅ Matrix server is operational on Fly.io  
✅ Bot credentials file created (13 bots)  
⏳ Bots need to be registered on the server  
⏳ Board room needs to be created  

## Bot Accounts (13 total)

### Special Bots (3)
- `@aCustodian.custodian:matrix.inquiry.institute`
- `@aParliamentarian.parliamentarian:matrix.inquiry.institute`
- `@aAssistant.hypatia:matrix.inquiry.institute`

### Directors (10)
- `@aDirector.aetica:matrix.inquiry.institute`
- `@aDirector.scholia:matrix.inquiry.institute`
- `@aDirector.pedagogia:matrix.inquiry.institute`
- `@aDirector.machina:matrix.inquiry.institute`
- `@aDirector.terra:matrix.inquiry.institute`
- `@aDirector.cultura:matrix.inquiry.institute`
- `@aDirector.aureus:matrix.inquiry.institute`
- `@aDirector.fabrica:matrix.inquiry.institute`
- `@aDirector.civitas:matrix.inquiry.institute`
- `@aDirector.lex:matrix.inquiry.institute`

## Next Steps

### 1. Register Bots on Fly.io

You have several options:

#### Option A: Use Element Web (Easiest)

1. Open https://app.element.io
2. Click "Create Account"
3. Set homeserver to: `matrix.inquiry.institute`
4. Register each bot manually with their credentials from `matrix-bot-credentials.json`

#### Option B: Use Fly.io SSH

```bash
# SSH into your Fly.io Matrix app
fly ssh console -a <your-matrix-app-name>

# Register each bot
register_new_matrix_user \
  -c /data/homeserver.yaml \
  https://matrix.inquiry.institute \
  -u aCustodian.custodian \
  -p <password>
```

#### Option C: Use Matrix Admin API

If you have an admin access token:

```bash
# Get admin token first (from your admin account)
# Then register users via API

curl -X POST "https://matrix.inquiry.institute/_synapse/admin/v1/register" \
  -H "Authorization: Bearer YOUR_ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "aCustodian.custodian",
    "password": "bot_custodian_password_change_me",
    "admin": false
  }'
```

### 2. Create Board Room

Once bots are registered:

```bash
# Set your admin credentials
export ADMIN_USERNAME=your_admin_username
export ADMIN_PASSWORD=your_admin_password

# Create room and invite all bots
python3 scripts/create-board-room.py
```

Or create manually in Element Web:
1. Open https://app.element.io
2. Login with your admin account
3. Create room: "Inquiry Institute Board of Directors"
4. Invite all 13 bots

### 3. Validate Setup

```bash
# Check remote server
./scripts/validate-remote-matrix.sh

# Test bot communication (after bots are registered)
python3 scripts/validate-board-communication.py
```

### 4. Start Bots Locally

Bots run on your local machine and connect to Fly.io:

```bash
# Start custodian
./scripts/start-custodian-bot.sh

# Start a director (in another terminal)
export DIRECTOR_NAME=aetica
export MATRIX_PASSWORD=<password_from_credentials>
python3 scripts/matrix-director-bot.py
```

## Configuration

### Environment Variables (.env)

```bash
MATRIX_DOMAIN=matrix.inquiry.institute
MATRIX_SERVER_URL=https://matrix.inquiry.institute
```

### Bot Credentials

Located in: `matrix-bot-credentials.json`

**Important:** Change default passwords after registration!

## Accessing Element Web

### Option 1: Public Element (Recommended)
https://app.element.io

Set homeserver to: `matrix.inquiry.institute`

### Option 2: Self-hosted Element
If you deploy Element to Fly.io: `https://element.inquiry.institute`

## Fly.io Commands

```bash
# Check app status
fly status -a <your-matrix-app-name>

# View logs
fly logs -a <your-matrix-app-name>

# SSH into app
fly ssh console -a <your-matrix-app-name>

# Scale app
fly scale count 1 -a <your-matrix-app-name>

# Deploy updates
fly deploy -a <your-matrix-app-name>
```

## Architecture

```
┌─────────────────┐
│   Fly.io Cloud  │
│                 │
│  ┌───────────┐  │
│  │  Synapse  │  │ ← Matrix Homeserver
│  │ (Matrix)  │  │
│  └───────────┘  │
│       ↓         │
│  ┌───────────┐  │
│  │ PostgreSQL│  │ ← Database
│  └───────────┘  │
└─────────────────┘
        ↑
        │ HTTPS
        │
┌───────┴─────────┐
│  Local Machine  │
│                 │
│  ┌───────────┐  │
│  │   Bots    │  │ ← Run locally
│  │ (Python)  │  │
│  └───────────┘  │
│                 │
│  ┌───────────┐  │
│  │  Element  │  │ ← Web browser
│  │   Web     │  │
│  └───────────┘  │
└─────────────────┘
```

## Troubleshooting

### Can't connect to Matrix server

```bash
# Test connectivity
curl https://matrix.inquiry.institute/_matrix/client/versions

# Check Fly.io status
fly status -a <your-matrix-app-name>

# View logs
fly logs -a <your-matrix-app-name>
```

### Bot registration fails

1. Check if registration is enabled in homeserver.yaml
2. Verify you're using correct server URL
3. Try registering via Element Web first
4. Check Fly.io logs for errors

### Bot can't login

1. Verify bot is registered: check in Element Web
2. Confirm password is correct
3. Check bot credentials file
4. Test with curl:
   ```bash
   curl -X POST "https://matrix.inquiry.institute/_matrix/client/r0/login" \
     -H "Content-Type: application/json" \
     -d '{
       "type": "m.login.password",
       "user": "aCustodian.custodian",
       "password": "your_password"
     }'
   ```

### Room not visible

1. Refresh Element Web
2. Check you're logged in with correct account
3. Verify room was created
4. Check invitations

## Security Notes

- Matrix server is publicly accessible (HTTPS)
- Use strong passwords for all bot accounts
- Change default passwords immediately
- Consider enabling rate limiting
- Monitor Fly.io logs for suspicious activity
- Keep Synapse updated

## Cost Optimization

Fly.io charges based on:
- VM size and count
- Database storage
- Bandwidth

To optimize:
1. Use smallest VM that meets needs
2. Enable log rotation
3. Clean up old media periodically
4. Monitor usage: `fly dashboard -a <your-matrix-app-name>`

## Support

- Fly.io docs: https://fly.io/docs/
- Matrix docs: https://matrix.org/docs/
- Synapse docs: https://matrix-org.github.io/synapse/

## Quick Commands

```bash
# Validate remote server
./scripts/validate-remote-matrix.sh

# Create bot credentials
python3 scripts/create-matrix-bots.py

# Create board room
python3 scripts/create-board-room.py

# Start custodian
./scripts/start-custodian-bot.sh

# Check Fly.io status
fly status

# View Fly.io logs
fly logs
```
