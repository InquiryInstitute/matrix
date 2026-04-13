# Board of Directors Room — Expected Members

Canonical list is **`matrix-bot-credentials.json`** (16 bot accounts). Scripts invite everyone in that file.

## Room

- **Alias:** `#board-of-directors:matrix.castalia.institute` (override with `BOARD_ROOM_ALIAS`)
- **Room ID:** set after creation, or use `BOARD_ROOM_ID` env for tools. Older docs referenced `!aEqllYpAjknuXJTPGD:matrix.castalia.institute` — resolve the alias to confirm the live id.

## Members (16)

### Special (3)

| Role | Matrix ID |
|------|-----------|
| Custodian | `@aCustodian.custodian:matrix.castalia.institute` |
| Parliamentarian | `@aParliamentarian.parliamentarian:matrix.castalia.institute` |
| Hypatia | `@aAssistant.hypatia:matrix.castalia.institute` |

### Directors (13)

Director bots use the `aDirector.*` localpart convention (literary / college names in-repo):

`@aDirector.a.alkhwarizmi`, `@aDirector.a.avicenna`, `@aDirector.a.daVinci`, `@aDirector.a.darwin`, `@aDirector.a.diogenes`, `@aDirector.a.katsushikaoi`, `@aDirector.a.maryshelley`, `@aDirector.a.shelley`, `@aDirector.a.polidori`, `@aDirector.a.byron`, `@aDirector.a.newton`, `@aDirector.a.plato`, `@aDirector.a.turing` — all on `matrix.castalia.institute`.

> **Note:** An older naming scheme used `@aDirector.aetica`, `@aDirector.scholia`, etc. Those are **not** the IDs in `matrix-bot-credentials.json`; use the file as source of truth.

## Commands

```bash
export MATRIX_SERVER=https://matrix.castalia.institute
export MATRIX_DOMAIN=matrix.castalia.institute
export ADMIN_USERNAME=...
export ADMIN_PASSWORD=...

# Create room (or reuse alias) and invite all bots from credentials
python3 scripts/create-board-room.py

# Invite only missing members (resolves #board-of-directors by default)
python3 scripts/invite-missing-bots.py

# Check coverage (exit 2 if someone missing)
python3 scripts/validate-board-room.py
```

Bots must **exist on the homeserver** (registered) for invites to succeed. Use your admin registration flow if accounts are still `pending_registration`.
