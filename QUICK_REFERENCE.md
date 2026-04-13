# Board of Directors - Quick Reference

## Quick Commands

### Setup
```bash
# Start Matrix server
docker-compose up -d

# Install dependencies
pip3 install -r requirements-matrix.txt

# Create all bots (including custodian)
python3 scripts/create-matrix-bots.py
```

### Validation
```bash
# Quick setup check
./scripts/validate-board-setup.sh

# Full communication test
python3 scripts/validate-board-communication.py
```

### Start Bots
```bash
# Start custodian bot
./scripts/start-custodian-bot.sh

# Start a specific director bot
export DIRECTOR_NAME=aetica
export MATRIX_PASSWORD=<password>
python3 scripts/matrix-director-bot.py
```

## Bot Accounts

### Special Bots (3 total)
1. **Custodian** - `@aCustodian.custodian:matrix.castalia.institute`
   - Role: Manages board operations
2. **Parliamentarian** - `@aParliamentarian.parliamentarian:matrix.castalia.institute`
   - Role: Ensures proper procedures
3. **Hypatia** - `@aAssistant.hypatia:matrix.castalia.institute`
   - Role: Custodian assistant

### Directors (10 total)
1. `@aDirector.aetica:matrix.castalia.institute` - Ethics & Values
2. `@aDirector.scholia:matrix.castalia.institute` - Education & Learning
3. `@aDirector.pedagogia:matrix.castalia.institute` - Teaching Methods
4. `@aDirector.machina:matrix.castalia.institute` - Technology & AI
5. `@aDirector.terra:matrix.castalia.institute` - Environment & Sustainability
6. `@aDirector.cultura:matrix.castalia.institute` - Culture & Society
7. `@aDirector.aureus:matrix.castalia.institute` - Finance & Resources
8. `@aDirector.fabrica:matrix.castalia.institute` - Operations & Production
9. `@aDirector.civitas:matrix.castalia.institute` - Community & Governance
10. `@aDirector.lex:matrix.castalia.institute` - Legal & Compliance

**Total Board Members: 13 bots**

## URLs

- Matrix Server: http://localhost:8008
- Element Web: http://localhost:8080
- Health Check: http://localhost:8008/health

## File Locations

- Bot Credentials: `matrix-bot-credentials.json`
- Homeserver Config: `matrix-data/homeserver.yaml`
- Environment: `.env`
- Docker Compose: `docker-compose.yml`

## Common Tasks

### Check if server is running
```bash
docker ps | grep matrix
curl http://localhost:8008/health
```

### View logs
```bash
docker-compose logs -f synapse
docker-compose logs -f postgres
```

### Restart services
```bash
docker-compose restart
docker-compose restart synapse
```

### List registered users
```bash
docker-compose exec synapse sqlite3 /data/homeserver.db "SELECT name FROM users;"
```

### Register a bot manually
```bash
docker-compose exec synapse register_new_matrix_user \
  -c /data/homeserver.yaml \
  http://localhost:8008 \
  -u aCustodian.custodian \
  -p <password>
```

## Validation Checklist

Quick checklist for board validation:

```bash
# 1. Docker running?
docker ps | grep matrix-synapse

# 2. Server healthy?
curl http://localhost:8008/health

# 3. Bots created?
ls -la matrix-bot-credentials.json

# 4. Custodian in credentials?
jq '.[] | select(.username | contains("custodian"))' matrix-bot-credentials.json

# 5. Python deps installed?
python3 -c "import nio" && echo "✅ OK" || echo "❌ Install matrix-nio"

# 6. Run full validation
./scripts/validate-board-setup.sh
```

## Troubleshooting

### Docker not running
```bash
# Mac: Start Docker Desktop
# Linux: sudo systemctl start docker
```

### Server not responding
```bash
docker-compose logs synapse
docker-compose restart synapse
```

### Bot can't login
```bash
# Check credentials
cat matrix-bot-credentials.json

# Verify bot exists
docker-compose exec synapse sqlite3 /data/homeserver.db \
  "SELECT name FROM users WHERE name LIKE '%custodian%';"

# Re-register if needed
docker-compose exec synapse register_new_matrix_user \
  -c /data/homeserver.yaml http://localhost:8008 \
  -u aCustodian.custodian -p <new_password>
```

### Bot not in room
1. Open Element Web: http://localhost:8080
2. Go to board room
3. Click room name → Invite
4. Enter bot Matrix ID
5. Bot should auto-accept (if running)

## Testing Communication

### Test custodian → directors
1. Start custodian bot: `./scripts/start-custodian-bot.sh`
2. Start director bot in another terminal
3. In Element Web, send message in board room
4. Verify both bots respond

### Test director → custodian
1. Ensure both bots running
2. Send: "@aCustodian.custodian please review"
3. Verify custodian responds

### Automated test
```bash
python3 scripts/validate-board-communication.py
```

## Scripts Reference

| Script | Purpose |
|--------|---------|
| `create-matrix-bots.py` | Create all bot accounts |
| `matrix-director-bot.py` | Run a director/custodian bot |
| `validate-board-setup.sh` | Check configuration |
| `validate-board-communication.py` | Test bot communication |
| `start-custodian-bot.sh` | Quick start custodian |
| `verify-matrix-setup.sh` | Verify Matrix server |

## Documentation

- Setup Guide: `BOARD_VALIDATION_GUIDE.md`
- Summary: `VALIDATION_SUMMARY.md`
- This Reference: `QUICK_REFERENCE.md`

## Next Steps After Validation

1. Configure director RAG configs
2. Integrate LLM (OpenRouter/Ollama)
3. Set up automated bot startup
4. Configure webhooks
5. Add logging/monitoring
6. Implement board workflows
