# Inquiry Institute - Matrix Board of Directors

Matrix-based communication system for the Inquiry Institute Board of Directors, featuring 10 director bots plus 3 special bots (Custodian, Parliamentarian, and Hypatia).

## Quick Start

```bash
# One-command setup (recommended)
./scripts/setup-board-complete.sh
```

Or step by step:

```bash
# 1. Ensure Matrix is running
./scripts/ensure-matrix-running.sh

# 2. Create all bots
python3 scripts/create-matrix-bots.py

# 3. Create board room
python3 scripts/create-board-room.py

# 4. Validate setup
./scripts/validate-board-setup.sh
```

## Board Members

### Special Bots (3)
- **Custodian** - Manages board operations
- **Parliamentarian** - Ensures proper procedures  
- **Hypatia** - Custodian assistant

### Directors (10)
- aetica (Ethics & Values)
- scholia (Education & Learning)
- pedagogia (Teaching Methods)
- machina (Technology & AI)
- terra (Environment & Sustainability)
- cultura (Culture & Society)
- aureus (Finance & Resources)
- fabrica (Operations & Production)
- civitas (Community & Governance)
- lex (Legal & Compliance)

## Access

- **Matrix Server:** http://localhost:8008
- **Element Web:** http://localhost:8080
- **Health Check:** http://localhost:8008/health

## Key Features

- ✅ Always-running Matrix server (auto-restart)
- ✅ 13 bot accounts (10 directors + 3 special)
- ✅ Automated room creation and bot invitations
- ✅ Comprehensive validation tools
- ✅ Autostart support (macOS/Linux)

## Documentation

| Document | Description |
|----------|-------------|
| [SETUP_COMPLETE.md](SETUP_COMPLETE.md) | Complete setup overview |
| [MATRIX_ALWAYS_ON.md](MATRIX_ALWAYS_ON.md) | Always-running configuration |
| [CREATE_ROOM_GUIDE.md](CREATE_ROOM_GUIDE.md) | Room creation guide |
| [BOARD_VALIDATION_GUIDE.md](BOARD_VALIDATION_GUIDE.md) | Validation guide |
| [QUICK_REFERENCE.md](QUICK_REFERENCE.md) | Command reference |
| [GCP_FLY_MIGRATION.md](GCP_FLY_MIGRATION.md) | Matrix on Google Cloud (Fly migration) |
| [GCP_SCALING.md](GCP_SCALING.md) | Grow on GCP: resize, snapshots, managed DB |

## Scripts

| Script | Purpose |
|--------|---------|
| `setup-board-complete.sh` | Complete automated setup |
| `ensure-matrix-running.sh` | Check/start Matrix |
| `create-matrix-bots.py` | Create bot accounts |
| `create-board-room.py` | Create board room |
| `validate-board-setup.sh` | Validate configuration |
| `validate-board-communication.py` | Test communication |
| `start-custodian-bot.sh` | Start custodian |
| `install-autostart.sh` | Install autostart |

## Requirements

- Docker & Docker Compose
- Python 3.7+
- matrix-nio (`pip install matrix-nio`)

## Configuration

- `docker-compose.yml` - Docker services (restart: always)
- `.env` - Environment variables
- `matrix-data/homeserver.yaml` - Synapse configuration
- `element-config.json` - Element Web configuration
- `matrix-bot-credentials.json` - Bot credentials (generated)

## Troubleshooting

```bash
# Check Matrix status
./scripts/ensure-matrix-running.sh

# Validate setup
./scripts/validate-board-setup.sh

# View logs
docker-compose logs -f synapse

# Restart services
docker-compose restart
```

## Support

See documentation files for detailed guides and troubleshooting.

## License

Inquiry Institute © 2024
