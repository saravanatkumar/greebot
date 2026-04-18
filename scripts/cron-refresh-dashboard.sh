#!/bin/bash
# cron-refresh-dashboard.sh
# Refreshes dashboard data every 15 minutes via cron
#
# SETUP on server (EC2):
#   1. Copy this project to server (or git pull)
#   2. Add to crontab:  crontab -e
#      */15 * * * * /home/ec2-user/greebot/scripts/cron-refresh-dashboard.sh >> /home/ec2-user/greebot/logs/cron-dashboard.log 2>&1
#
# Manual run:
#   bash scripts/cron-refresh-dashboard.sh

set -e

# ── Config ──────────────────────────────────────────────────────────────────
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_FILE="$PROJECT_DIR/logs/cron-dashboard.log"
LOCK_FILE="/tmp/greebot-dashboard-refresh.lock"
BUCKET_DATA="greendotball-bot-data"
BUCKET_DASH="myortho"
REGION_DASH="us-east-2"

# ── Lock (prevent overlapping runs) ─────────────────────────────────────────
if [ -f "$LOCK_FILE" ]; then
  LOCK_PID=$(cat "$LOCK_FILE")
  if ps -p "$LOCK_PID" > /dev/null 2>&1; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ⚠️  Already running (PID $LOCK_PID). Skipping." | tee -a "$LOG_FILE"
    exit 0
  else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Stale lock found (PID $LOCK_PID dead). Removing." | tee -a "$LOG_FILE"
    rm -f "$LOCK_FILE"
  fi
fi
echo $$ > "$LOCK_FILE"
trap 'rm -f "$LOCK_FILE"' EXIT

# ── Ensure log dir ───────────────────────────────────────────────────────────
mkdir -p "$PROJECT_DIR/logs"

echo "" | tee -a "$LOG_FILE"
echo "========================================" | tee -a "$LOG_FILE"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] 🔄 Dashboard refresh started" | tee -a "$LOG_FILE"
echo "========================================" | tee -a "$LOG_FILE"

cd "$PROJECT_DIR"

# ── Step 1: Sync S3 campaign data → local ───────────────────────────────────
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [1/2] Syncing campaign data from S3..." | tee -a "$LOG_FILE"
if node scripts/sync-dashboard-data.js >> "$LOG_FILE" 2>&1; then
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✅ Sync complete" | tee -a "$LOG_FILE"
else
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] ❌ Sync failed" | tee -a "$LOG_FILE"
  exit 1
fi

# ── Step 2: Upload dashboard-data.json to myortho bucket ────────────────────
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [2/2] Uploading dashboard-data.json to S3..." | tee -a "$LOG_FILE"
if aws s3 cp dashboards/data/dashboard-data.json \
    "s3://${BUCKET_DASH}/logs/data/dashboard-data.json" \
    --region "$REGION_DASH" \
    --content-type "application/json" \
    --cache-control "no-cache, no-store, must-revalidate" >> "$LOG_FILE" 2>&1; then
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✅ Upload complete" | tee -a "$LOG_FILE"
else
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] ❌ Upload failed" | tee -a "$LOG_FILE"
  exit 1
fi

echo "[$(date '+%Y-%m-%d %H:%M:%S')] 🎉 Dashboard refreshed successfully" | tee -a "$LOG_FILE"
echo "========================================" | tee -a "$LOG_FILE"

# ── Trim log to last 5000 lines (prevent runaway growth) ────────────────────
if [ -f "$LOG_FILE" ]; then
  tail -5000 "$LOG_FILE" > "${LOG_FILE}.tmp" && mv "${LOG_FILE}.tmp" "$LOG_FILE"
fi
