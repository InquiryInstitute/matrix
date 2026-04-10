# How to Create the Board of Directors Room

## Prerequisites

Matrix server should already be running. If not, start it:

```bash
# Check if running
./scripts/ensure-matrix-running.sh

# Or start manually
docker-compose up -d
```

## Option 1: Manual Creation (Recommended)

### Step 1: Verify Matrix Server is Running

### Step 1: Verify Matrix Server is Running

```bash
# Quick check
curl http://localhost:8008/health

# Or use the helper script
./scripts/ensure-matrix-running.sh
```

If not running, the script will start it automatically.

### Step 2: Open Element Web

1. Open your browser to: http://localhost:8080
2. You should see the Element login page

### Step 3: Create or Login with Admin Account

If you don't have an account yet:

```bash
# In terminal, create an admin user
docker-compose exec synapse register_new_matrix_user \
  -c /data/homeserver.yaml \
  http://localhost:8008 \
  -u admin \
  -p <your_password> \
  --admin
```

Then login to Element Web with:
- Username: `admin`
- Password: `<your_password>`
- Homeserver: `http://localhost:8008` (or use the default)

### Step 4: Create the Room

In Element Web:

1. Click the **"+"** button or **"Create Room"** in the left sidebar
2. Fill in the room details:
   - **Name:** `Inquiry Institute Board of Directors`
   - **Topic:** `Board of Directors meeting room for strategic discussions`
   - **Room visibility:** Choose "Private" (recommended) or "Public"
   - **Enable end-to-end encryption:** Optional (your choice)
3. Click **"Create Room"**

### Step 5: Get the Room ID

In the room:
1. Click the room name at the top
2. Click **"Settings"** → **"Advanced"**
3. Copy the **Room ID** (looks like `!abc123:matrix.inquiry.institute`)

### Step 6: Invite the Bots

You have two options:

#### Option A: Manual Invites (if bots aren't created yet)

In the room, click **"Invite"** and add these Matrix IDs:

**Directors (10):**
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

**Special Bots (3):**
- `@aCustodian.custodian:matrix.inquiry.institute`
- `@aParliamentarian.parliamentarian:matrix.inquiry.institute`
- `@aAssistant.hypatia:matrix.inquiry.institute`

#### Option B: Automated Invites (after creating bots)

```bash
# First create the bots
python3 scripts/create-matrix-bots.py

# Then use the automated room creation script
export ADMIN_USERNAME=admin
export ADMIN_PASSWORD=<your_password>
python3 scripts/create-board-room.py
```

---

## Option 2: Automated Creation (After Server is Running)

If the Matrix server is already running and you have bot credentials:

```bash
# Set your admin credentials
export ADMIN_USERNAME=admin
export ADMIN_PASSWORD=<your_password>

# Run the room creation script
python3 scripts/create-board-room.py
```

This will:
- Create the "Board of Directors" room
- Invite all 13 bots automatically
- Send a welcome message
- Give you the room ID and alias

---

## Troubleshooting

### "I don't see Element Web"

Check if the container is running:
```bash
docker ps | grep element
```

If not running:
```bash
docker-compose up -d element-web
```

### "I can't connect to the homeserver"

1. Check Matrix server is running:
   ```bash
   curl http://localhost:8008/health
   ```

2. Check logs:
   ```bash
   docker-compose logs synapse
   ```

3. Restart if needed:
   ```bash
   docker-compose restart synapse
   ```

### "Bot invitations fail"

The bots need to be registered first:
```bash
python3 scripts/create-matrix-bots.py
```

### "I created the room but can't find it"

1. Check your room list in Element Web (left sidebar)
2. Look for "Inquiry Institute Board of Directors"
3. If you can't see it, try refreshing the page
4. Check if you're logged in with the correct account

---

## Quick Start Checklist

- [ ] Docker Desktop/daemon is running
- [ ] Matrix server started: `docker-compose up -d`
- [ ] Element Web accessible: http://localhost:8080
- [ ] Admin account created
- [ ] Logged into Element Web
- [ ] Board room created
- [ ] Bots created: `python3 scripts/create-matrix-bots.py`
- [ ] Bots invited to room (manual or automated)
- [ ] Room visible in Element Web

---

## What You Should See

After completing these steps, in Element Web you should see:

1. **Left sidebar:** "Inquiry Institute Board of Directors" room
2. **Room members:** 14 total (you + 13 bots)
3. **Room topic:** Board of Directors meeting room description
4. **Pending invitations:** Bots will show as "invited" until they accept

To get bots to accept invitations, you need to start them:
```bash
./scripts/start-custodian-bot.sh
# Or start individual director bots
```

---

## Need Help?

Run the validation script to check your setup:
```bash
./scripts/validate-board-setup.sh
```

Or check the full guide:
```bash
cat BOARD_VALIDATION_GUIDE.md
```
