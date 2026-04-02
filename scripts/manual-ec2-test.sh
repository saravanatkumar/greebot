#!/bin/bash
# manual-ec2-test.sh
# Run this ON the EC2 instance (via SSH) to test bot_new.js manually
# before baking into an AMI.
#
# Prerequisites on the EC2 instance:
#   - Node.js, npm, git, AWS CLI installed
#   - IAM role with S3 access attached (EC2-GreenDotBall-S3-Access)
#   - Google Chrome installed (/usr/bin/google-chrome)
#
# Usage:
#   1. SSH into EC2:  ssh -i greendotball-bot-key-v2.pem ec2-user@<EC2-IP>
#   2. Copy your CAMPAIGN_ID and JOB_IDS from create-test-campaign.sh output
#   3. Run:  bash manual-ec2-test.sh <CAMPAIGN_ID> <JOB_IDS>
#
# Example:
#   bash manual-ec2-test.sh "test-apr-02-2026-manual-091530" "job-001,job-002"

set -e

CAMPAIGN_ID="${1}"
JOB_IDS="${2}"

if [ -z "$CAMPAIGN_ID" ] || [ -z "$JOB_IDS" ]; then
  echo "Usage: bash manual-ec2-test.sh <CAMPAIGN_ID> <JOB_IDS>"
  echo "Example: bash manual-ec2-test.sh test-apr-02-2026-manual-091530 job-001,job-002"
  exit 1
fi

BOT_DIR="/opt/greendotball-bot"
LOG_DIR="/var/log/greendotball-bot"
S3_BUCKET="greendotball-bot-data"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="${LOG_DIR}/manual-test-${TIMESTAMP}.log"
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id 2>/dev/null || echo "local-test")

echo "=================================================="
echo "  GREENDOTBALL BOT — MANUAL EC2 TEST"
echo "=================================================="
echo "  Campaign ID : $CAMPAIGN_ID"
echo "  Job IDs     : $JOB_IDS"
echo "  Instance ID : $INSTANCE_ID"
echo "  Log File    : $LOG_FILE"
echo "=================================================="
echo ""

# ── 1. Setup ──────────────────────────────────────────────────────────────────
sudo mkdir -p "$LOG_DIR"
sudo chown ec2-user:ec2-user "$LOG_DIR"
mkdir -p "$BOT_DIR"

# ── 2. Checkout design-rethink branch ────────────────────────────────────────
echo "[1/5] Checking out latest code from design-rethink branch..."
if [ ! -d "$BOT_DIR/.git" ]; then
  echo "      Cloning repo..."
  sudo git clone https://github.com/saravanatkumar/greebot.git "$BOT_DIR"
  sudo chown -R ec2-user:ec2-user "$BOT_DIR"
fi

cd "$BOT_DIR"
git fetch origin
git checkout design-rethink
git reset --hard origin/design-rethink
echo "      ✅ On branch: $(git branch --show-current) @ $(git log -1 --format='%h %s')"

# ── 3. Install dependencies ───────────────────────────────────────────────────
echo ""
echo "[2/5] Installing Node.js dependencies..."
npm install --production 2>&1 | tail -5
echo "      ✅ npm install done"

# ── 4. Verify Chrome ──────────────────────────────────────────────────────────
echo ""
echo "[3/5] Checking Chrome..."
if ! command -v google-chrome &>/dev/null; then
  echo "      ⚠️  google-chrome not found. Installing..."
  sudo rpm -i https://dl.google.com/linux/direct/google-chrome-stable_current_x86_64.rpm || true
fi
CHROME_VER=$(google-chrome --version 2>/dev/null || echo "NOT FOUND")
echo "      Chrome: $CHROME_VER"

# ── 5. Run bot_new.js ─────────────────────────────────────────────────────────
echo ""
echo "[4/5] Running bot_new.js..."
echo "      CAMPAIGN_ID=$CAMPAIGN_ID"
echo "      JOB_IDS=$JOB_IDS"
echo ""

export CAMPAIGN_ID="$CAMPAIGN_ID"
export JOB_IDS="$JOB_IDS"
export PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true
export PUPPETEER_EXECUTABLE_PATH=/usr/bin/google-chrome
export HOME=/home/ec2-user
export NODE_ENV=production

node src/bot_new.js 2>&1 | tee "$LOG_FILE"
BOT_EXIT=${PIPESTATUS[0]}

echo ""
if [ $BOT_EXIT -eq 0 ]; then
  echo "      ✅ bot_new.js finished successfully (exit code 0)"
else
  echo "      ⚠️  bot_new.js exited with code $BOT_EXIT — check log above"
fi

# ── 6. Upload logs to S3 ──────────────────────────────────────────────────────
echo ""
echo "[5/5] Uploading logs to S3..."
aws s3 cp "$LOG_FILE" \
  "s3://${S3_BUCKET}/campaigns/${CAMPAIGN_ID}/logs/${INSTANCE_ID}-manual-${TIMESTAMP}.log" \
  --region ap-south-1 2>/dev/null && echo "      ✅ Log uploaded" || echo "      ⚠️  Log upload failed (check IAM role)"

# ── 7. Verify S3 results ──────────────────────────────────────────────────────
echo ""
echo "=================================================="
echo "  VERIFICATION — Check S3 for results"
echo "=================================================="
echo ""
echo "  Results:"
aws s3 ls "s3://${S3_BUCKET}/campaigns/${CAMPAIGN_ID}/results/" --region ap-south-1 2>/dev/null \
  || echo "  (no results yet or S3 access issue)"
echo ""
echo "  Logs:"
aws s3 ls "s3://${S3_BUCKET}/campaigns/${CAMPAIGN_ID}/logs/" --region ap-south-1 2>/dev/null \
  || echo "  (no logs yet)"
echo ""
echo "=================================================="
echo "  TEST COMPLETE"
echo "  If results appear above → bot is working ✅"
echo "  Next step: Create AMI from this instance"
echo "=================================================="
