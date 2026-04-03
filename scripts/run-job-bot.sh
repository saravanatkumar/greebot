#!/bin/bash
# run-job-bot.sh
# Executed on EC2 startup (via systemd or direct call).
# Reads CAMPAIGN_ID + JOB_IDS from USER_DATA, git pulls latest code,
# runs bot_new.js for all assigned jobs, uploads logs to S3, shuts down.

set -uo pipefail

export PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true
export PUPPETEER_EXECUTABLE_PATH=/usr/bin/google-chrome
export HOME=/home/ec2-user
export NODE_ENV=production
export AWS_DEFAULT_REGION=ap-south-1

BOT_DIR="/opt/greendotball-bot"
LOG_DIR="/var/log/greendotball-bot"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="$LOG_DIR/bot_$TIMESTAMP.log"

mkdir -p "$LOG_DIR"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"; }

log "========================================"
log "GreenDotBall Job Bot — EC2 Startup"
log "========================================"

# ─── Hard 50-minute shutdown timer (background) ───────────────────────────────
# Ensures instance ALWAYS terminates within 50 min regardless of bot outcome
( sleep 3000 && log "⏰ 50-min hard limit reached — shutting down" && sudo shutdown -h now ) &
SHUTDOWN_PID=$!
log "Auto-shutdown armed: 50 min (PID $SHUTDOWN_PID)"

# Get instance metadata
INSTANCE_ID=$(curl -sf http://169.254.169.254/latest/meta-data/instance-id 2>/dev/null || echo "unknown")
log "Instance ID : $INSTANCE_ID"

# ─── Read USER_DATA ───────────────────────────────────────────────────────────
USER_DATA=$(curl -sf http://169.254.169.254/latest/user-data 2>/dev/null || echo "")

CAMPAIGN_ID=$(echo "$USER_DATA" | grep "^CAMPAIGN_ID=" | cut -d'=' -f2- | tr -d '[:space:]')
JOB_IDS=$(echo "$USER_DATA"    | grep "^JOB_IDS="     | cut -d'=' -f2- | tr -d '[:space:]')

if [ -z "$CAMPAIGN_ID" ]; then
  log "ERROR: CAMPAIGN_ID not found in USER_DATA"
  log "USER_DATA dump: $USER_DATA"
  exit 1
fi

if [ -z "$JOB_IDS" ]; then
  log "ERROR: JOB_IDS not found in USER_DATA"
  log "USER_DATA dump: $USER_DATA"
  exit 1
fi

log "Campaign ID : $CAMPAIGN_ID"
log "Job IDs     : $JOB_IDS"

export CAMPAIGN_ID
export JOB_IDS

# ─── Git pull latest code ─────────────────────────────────────────────────────
log "Pulling latest code..."
cd "$BOT_DIR"
git fetch origin 2>&1 | tee -a "$LOG_FILE"
git reset --hard origin/main 2>&1 | tee -a "$LOG_FILE"
log "Code updated to: $(git log -1 --format='%h %s')"

# ─── Install dependencies ─────────────────────────────────────────────────────
log "Installing dependencies..."
npm install --production 2>&1 | tee -a "$LOG_FILE"

# ─── Run the bot ──────────────────────────────────────────────────────────────
log "Starting bot..."
log "Command: node src/bot_new.js --campaign-id $CAMPAIGN_ID --job-ids $JOB_IDS"

node src/bot_new.js \
  --campaign-id "$CAMPAIGN_ID" \
  --job-ids "$JOB_IDS" \
  2>&1 | tee -a "$LOG_FILE"

BOT_EXIT=${PIPESTATUS[0]}
log "Bot finished with exit code: $BOT_EXIT"

# ─── Upload logs to S3 ────────────────────────────────────────────────────────
log "Uploading logs to S3..."
aws s3 cp "$LOG_FILE" \
  "s3://greendotball-bot-data/campaigns/$CAMPAIGN_ID/logs/$INSTANCE_ID-$TIMESTAMP.log" \
  2>&1 | tee -a "$LOG_FILE" || true

if [ -d "$BOT_DIR/logs" ]; then
  aws s3 sync "$BOT_DIR/logs/" \
    "s3://greendotball-bot-data/campaigns/$CAMPAIGN_ID/logs/$INSTANCE_ID/" \
    2>&1 | tee -a "$LOG_FILE" || true
fi

log "All done at $(date)"

# ─── Shutdown: cancel background timer and shut down now ─────────────────────
kill "$SHUTDOWN_PID" 2>/dev/null || true
log "Shutting down instance now..."
sleep 10
sudo shutdown -h now
