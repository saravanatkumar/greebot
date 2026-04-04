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

# Get instance metadata (IMDSv2)
IMDS_TOKEN=$(curl -sf -X PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 60" 2>/dev/null || echo "")
if [ -n "$IMDS_TOKEN" ]; then
  INSTANCE_ID=$(curl -sf -H "X-aws-ec2-metadata-token: $IMDS_TOKEN" \
    http://169.254.169.254/latest/meta-data/instance-id 2>/dev/null || echo "unknown")
else
  INSTANCE_ID=$(curl -sf http://169.254.169.254/latest/meta-data/instance-id 2>/dev/null || echo "unknown")
fi
log "Instance ID : $INSTANCE_ID"

# ─── Read campaign env vars from /etc/greendotball-env (written by EC2 USER_DATA) ─
ENV_FILE="/etc/greendotball-env"

if [ -f "$ENV_FILE" ]; then
  log "Loading env from $ENV_FILE"
  # shellcheck source=/dev/null
  source "$ENV_FILE"
else
  log "ERROR: $ENV_FILE not found — USER_DATA may not have run yet"
  log "Expected: CAMPAIGN_ID and JOB_IDS in $ENV_FILE"
  exit 1
fi

if [ -z "${CAMPAIGN_ID:-}" ]; then
  log "ERROR: CAMPAIGN_ID not set in $ENV_FILE"
  log "File contents: $(cat $ENV_FILE 2>/dev/null || echo '(empty)')"
  exit 1
fi

if [ -z "${JOB_IDS:-}" ]; then
  log "ERROR: JOB_IDS not set in $ENV_FILE"
  log "File contents: $(cat $ENV_FILE 2>/dev/null || echo '(empty)')"
  exit 1
fi

log "Campaign ID : $CAMPAIGN_ID"
log "Job IDs     : $JOB_IDS"

export CAMPAIGN_ID
export JOB_IDS

# ─── Git pull latest code ─────────────────────────────────────────────────────
log "Pulling latest code..."
cd "$BOT_DIR"
git fetch origin design-rethink 2>&1 | tee -a "$LOG_FILE"
git reset --hard origin/design-rethink 2>&1 | tee -a "$LOG_FILE"
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
