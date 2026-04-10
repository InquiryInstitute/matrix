# Board of Directors Validation Guide

This guide helps you validate that the Board of Directors setup works correctly, including ensuring the custodian bot can communicate with the board.

## Prerequisites

1. Docker and Docker Compose installed
2. Python 3.7+ installed
3. Matrix server configured and running

## Quick Validation

Run the validation script to check your setup:

```bash
./scripts/validate-board-setup.sh
```

This will check:
- Docker containers are running
- Matrix server is healthy
- Bot credentials are configured
- Custodian bot is included
- Python dependencies are installed

## Step-by-Step Validation

### 1. Start Matrix Server

```bash
# Make sure you're in the matrix directory
cd ~/GitHub/matrix

# Start all services
docker-compose up -d

# Check logs
docker-compose logs -f synapse
```

Wait for the message: "Synapse now listening on TCP port 8008"

### 2. Install Python Dependencies

```bash
pip3 install -r requirements-matrix.txt
```

Or install manually:
```bash
pip3 install matrix-nio
```

### 3. Create Bot Accounts

The custodian bot has been added to the bot creation script:

```bash
python3 scripts/create-matrix-bots.py
```

This will create:
- 10 director bots (aDirector.aetica, aDirector.scholia, etc.)
- 1 custodian bot (aCustodian.custodian)

Bot credentials will be saved to `matrix-bot-credentials.json`.

**Important:** Change the default passwords after creation!

### 4. Create Board of Directors Room

1. Open Element Web: http://localhost:8080
2. Log in with your admin account (or create one)
3. Click "Create Room" or "+"
4. Room settings:
   - Name: "Inquiry Institute Board of Directors"
   - Topic: "Board of Directors meeting room"
   - Visibility: Private (or Public if preferred)
   - Enable encryption: Optional
5. Click "Create Room"

### 5. Invite All Bots to Board Room

In the board room:

1. Click the room name → "Invite"
2. Invite each bot by their Matrix ID:
   - @aCustodian.custodian:matrix.inquiry.institute
   - @aDirector.aetica:matrix.inquiry.institute
   - @aDirector.scholia:matrix.inquiry.institute
   - @aDirector.pedagogia:matrix.inquiry.institute
   - @aDirector.machina:matrix.inquiry.institute
   - @aDirector.terra:matrix.inquiry.institute
   - @aDirector.cultura:matrix.inquiry.institute
   - @aDirector.aureus:matrix.inquiry.institute
   - @aDirector.fabrica:matrix.inquiry.institute
   - @aDirector.civitas:matrix.inquiry.institute
   - @aDirector.lex:matrix.inquiry.institute

Or use the script to get the list:
```bash
jq -r '.[] | .matrix_id' matrix-bot-credentials.json
```

### 6. Test Bot Communication

Run the automated validation:

```bash
python3 scripts/validate-board-communication.py
```

This will:
- Test login for each bot
- Verify bots are in the board room
- Send test messages from each bot
- Validate custodian can communicate

### 7. Start a Director Bot

Test a single director bot:

```bash
# Set environment variables
export DIRECTOR_NAME=aetica
export MATRIX_PASSWORD=bot_aetica_password_change_me
export MATRIX_SERVER=http://localhost:8008
export MATRIX_DOMAIN=matrix.inquiry.institute

# Start the bot
python3 scripts/matrix-director-bot.py
```

The bot will:
- Log in to Matrix
- Listen for messages in the board room
- Respond to messages mentioning it

### 8. Test Custodian Communication

Start the custodian bot (similar to director bot):

```bash
# Set environment variables
export DIRECTOR_NAME=custodian
export MATRIX_PASSWORD=bot_custodian_password_change_me
export MATRIX_SERVER=http://localhost:8008
export MATRIX_DOMAIN=matrix.inquiry.institute

# Start the bot (using the director bot script)
python3 scripts/matrix-director-bot.py
```

Or create a dedicated custodian bot script if needed.

### 9. Send Test Messages

In Element Web, in the board room:

1. Send a message: "Hello @aCustodian.custodian:matrix.inquiry.institute"
2. Send a message: "Hello @aDirector.aetica:matrix.inquiry.institute"
3. Verify bots respond

## Validation Checklist

- [ ] Docker containers running (synapse, postgres, redis, element)
- [ ] Matrix server accessible at http://localhost:8008
- [ ] Element Web accessible at http://localhost:8080
- [ ] Bot credentials file exists (matrix-bot-credentials.json)
- [ ] Custodian bot in credentials file
- [ ] All 10 director bots in credentials file
- [ ] Board of Directors room created
- [ ] All bots invited to board room
- [ ] Bots can log in successfully
- [ ] Bots can send messages in board room
- [ ] Custodian can communicate with directors
- [ ] Directors can communicate with custodian

## Troubleshooting

### Docker containers not starting

```bash
# Check logs
docker-compose logs synapse
docker-compose logs postgres

# Restart services
docker-compose restart
```

### Bot login fails

1. Check bot password in credentials file
2. Verify bot account exists:
   ```bash
   docker-compose exec synapse sqlite3 /data/homeserver.db "SELECT name FROM users;"
   ```
3. Re-register bot if needed:
   ```bash
   docker-compose exec synapse register_new_matrix_user \
     -c /data/homeserver.yaml \
     http://localhost:8008 \
     -u aCustodian.custodian \
     -p <new_password>
   ```

### Bot not in board room

1. Check room invitations in Element Web
2. Manually invite bot using Matrix ID
3. Verify bot accepted invitation (check bot logs)

### Bot not responding to messages

1. Check bot is running (see process logs)
2. Verify bot is listening to correct room
3. Check message format (mention bot with @)
4. Review bot logs for errors

## Manual Testing

### Test Custodian → Director Communication

1. Start custodian bot in one terminal
2. Start a director bot (e.g., aetica) in another terminal
3. In Element Web, send message as custodian: "Hello directors!"
4. Verify director bot receives and responds

### Test Director → Custodian Communication

1. Ensure both bots are running
2. Send message as director: "@aCustodian.custodian please review this"
3. Verify custodian bot receives and responds

### Test Multi-Director Communication

1. Start multiple director bots
2. Send message mentioning multiple directors
3. Verify all mentioned directors respond

## Next Steps

After validation:

1. Configure director RAG configs in `configs/directors/`
2. Integrate with OpenRouter or Ollama for LLM responses
3. Set up automated bot startup (systemd, supervisor, etc.)
4. Configure webhooks for external integrations
5. Add logging and monitoring
6. Implement board meeting workflows

## Scripts Reference

- `scripts/create-matrix-bots.py` - Create all bot accounts
- `scripts/matrix-director-bot.py` - Run a director bot
- `scripts/validate-board-setup.sh` - Validate setup configuration
- `scripts/validate-board-communication.py` - Test bot communication
- `scripts/verify-matrix-setup.sh` - Verify Matrix server setup

## Support

For issues:
1. Check logs: `docker-compose logs -f synapse`
2. Review Matrix documentation: https://matrix.org/docs/
3. Check Synapse admin API: http://localhost:8008/_synapse/admin/v1/
4. Review bot logs for errors

## Security Notes

- Change all default bot passwords immediately
- Use strong passwords for production
- Enable encryption for sensitive rooms
- Restrict room access appropriately
- Keep credentials file secure (add to .gitignore)
- Use environment variables for passwords in production
