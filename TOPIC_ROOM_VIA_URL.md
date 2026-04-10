# Topic room via URL: faculty conversing (e.g. Villa Diodati)

You can create a room, populate it with specific faculty (e.g. a.maryshelley, a.shelley, a.polidori, a.byron), and have them start conversing about a topic you pass in via URL.

## Flow

1. **Create a topic room** with a name and topic (e.g. "Villa Diodati" / "Phantasmagoria at Villa Diodati during a thunderstorm").
2. **Invite only the faculty** you want (e.g. Mary Shelley, Shelley, Polidori, Byron).
3. **Post an opening message** in the room so the director bots see it and reply; they converse from there.

## Faculty (Villa Diodati example)

- `a.maryshelley` – Mary Shelley  
- `a.shelley` – Percy Bysshe Shelley  
- `a.polidori` – John Polidori  
- `a.byron` – Lord Byron  

These are in `matrix-bot-credentials.json` and `scripts/create-matrix-bots.py`. Register them on your Matrix server if you haven’t already.

## 1. CLI (topic and bots from args/env)

```bash
export ADMIN_USERNAME=your_admin
export ADMIN_PASSWORD=your_password

python3 scripts/create-topic-room.py \
  --name "Villa Diodati" \
  --topic "Phantasmagoria at Villa Diodati during a thunderstorm" \
  --bots a.maryshelley,a.shelley,a.polidori,a.byron
```

Or with env vars (handy when driven by another app or script that reads a URL):

```bash
ROOM_NAME="Villa Diodati" \
ROOM_TOPIC="Phantasmagoria at Villa Diodati during a thunderstorm" \
BOT_IDS="a.maryshelley,a.shelley,a.polidori,a.byron" \
python3 scripts/create-topic-room.py
```

## 2. URL (topic and bots from query string)

Run the small web server, then open a URL with the topic (and optional name/bots) in the query string:

```bash
export ADMIN_USERNAME=your_admin
export ADMIN_PASSWORD=your_password
pip install -r requirements-matrix.txt   # includes flask
python3 scripts/serve-topic-room.py
```

Then open in a browser (or have another app open this URL):

```
http://localhost:5050/create-room?topic=phantasmagoria+at+Villa+Diodati+during+a+thunderstorm&name=Villa+Diodati&bots=a.maryshelley,a.shelley,a.polidori,a.byron
```

Query params:

| Param     | Description                              | Default |
|----------|------------------------------------------|---------|
| `topic`  | Conversation theme                       | Discussion |
| `name`   | Room name                                | Topic Room |
| `bots`   | Comma-separated faculty ids              | a.maryshelley,a.shelley,a.polidori,a.byron |
| `opening`| First message (optional)                 | "Let's discuss: {topic}" |
| `redirect` | If `1`, redirect to Element room link | — |

With `redirect=1` the same URL will create the room and then redirect you to the room in Element.

## 3. Bots must be running

For faculty to actually converse, each director bot must be running (e.g. one process per director using `matrix-director-bot.py` with the right `DIRECTOR_NAME` and credentials). After the room is created and the opening message is posted, bots in that room will receive the message and can reply according to their RAG config.

## Summary

- **Create room**: `create-topic-room.py` (CLI) or `serve-topic-room.py` (URL).
- **Populate faculty**: use `--bots` / `BOT_IDS` / `bots=` to list the director ids.
- **Topic via URL**: use `serve-topic-room.py` and pass `topic=...&name=...&bots=...` in the query string.

Example URL for Villa Diodati, phantasmagoria, thunderstorm:

`/create-room?topic=phantasmagoria+at+Villa+Diodati+during+a+thunderstorm&name=Villa+Diodati&bots=a.maryshelley,a.shelley,a.polidori,a.byron`

---

## Does this work on the web?

**Yes.** The server binds to `0.0.0.0` and uses env vars for URLs, so it works when deployed on the internet.

1. **Direct browser link**  
   Deploy the app (e.g. Fly.io, a VPS, or any host), set env vars, then open the same URL in a browser (or send the link to someone). With `redirect=1` they are sent to your Element instance.

2. **Env vars when deployed**
   - `MATRIX_SERVER` – e.g. `https://matrix.inquiry.institute`
   - `MATRIX_DOMAIN` – e.g. `matrix.inquiry.institute`
   - `ELEMENT_URL` – e.g. `https://element.inquiry.institute` (so the redirect/link points to your Element on the web)
   - `ADMIN_USERNAME` / `ADMIN_PASSWORD` – Matrix admin (or user that can create rooms and invite)

3. **Calling from another web app (fetch)**  
   If a frontend on another origin (e.g. `https://app.inquiry.institute`) calls your create-room endpoint with `fetch()`, set:
   - `CORS_ORIGIN=https://app.inquiry.institute`  
   Then the browser will allow the response. Without this, direct navigation and same-origin use still work; only cross-origin fetch needs it.
