#!/bin/bash
# setup-systemd.sh
# Run ONCE on the EC2 instance before creating the AMI.
# Installs greendotball-bot.service so the bot starts automatically on every boot.
#
# Usage (on EC2, from repo root):
#   sudo bash scripts/setup-systemd.sh

set -e

BOT_DIR="/opt/greendotball-bot"
SERVICE_NAME="greendotball-bot"
SERVICE_FILE="$BOT_DIR/scripts/greendotball-bot.service"
SYSTEMD_DIR="/etc/systemd/system"

echo ""
echo "=================================================="
echo "  GREENDOTBALL BOT — SYSTEMD SETUP"
echo "=================================================="
echo ""

# Validate
if [ ! -f "$SERVICE_FILE" ]; then
  echo "❌ ERROR: Service file not found: $SERVICE_FILE"
  echo "   Make sure you are in the repo root and have pulled latest code."
  exit 1
fi

if [ ! -f "$BOT_DIR/scripts/run-job-bot.sh" ]; then
  echo "❌ ERROR: run-job-bot.sh not found at $BOT_DIR/scripts/run-job-bot.sh"
  exit 1
fi

# Make run-job-bot.sh executable
chmod +x "$BOT_DIR/scripts/run-job-bot.sh"
echo "  ✅ run-job-bot.sh is executable"

# Copy service file to systemd
cp "$SERVICE_FILE" "$SYSTEMD_DIR/${SERVICE_NAME}.service"
echo "  ✅ Service file copied to $SYSTEMD_DIR/${SERVICE_NAME}.service"

# Reload systemd and enable service
systemctl daemon-reload
systemctl enable "$SERVICE_NAME"
echo "  ✅ Service enabled (will start on next boot)"

# Verify
systemctl is-enabled "$SERVICE_NAME" && echo "  ✅ Confirmed: $SERVICE_NAME is enabled"

echo ""
echo "=================================================="
echo "  ✅ SETUP COMPLETE"
echo "=================================================="
echo ""
echo "  The bot will auto-start on next EC2 boot."
echo "  It reads CAMPAIGN_ID + JOB_IDS from USER_DATA."
echo ""
echo "  To check service status after reboot:"
echo "    sudo systemctl status $SERVICE_NAME"
echo ""
echo "  To view logs:"
echo "    sudo journalctl -u $SERVICE_NAME -f"
echo "    cat /var/log/greendotball-bot/bot_*.log"
echo ""
echo "  Next step: Stop this instance and create a new AMI."
echo ""
