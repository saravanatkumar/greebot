#!/bin/bash
# setup-wave-cron.sh
# Helper script to setup cron job for instance terminator

SCRIPT_DIR="/Users/apple/CascadeProjects/windsurf-project-2"
TERMINATOR_SCRIPT="$SCRIPT_DIR/scripts/terminate-instances.sh"
LOG_FILE="$SCRIPT_DIR/logs/terminator.log"

echo "========================================"
echo "  Wave Orchestration - Cron Setup"
echo "========================================"
echo ""

# Check if terminator script exists
if [[ ! -f "$TERMINATOR_SCRIPT" ]]; then
  echo "ERROR: Terminator script not found at:"
  echo "  $TERMINATOR_SCRIPT"
  exit 1
fi

# Make sure it's executable
chmod +x "$TERMINATOR_SCRIPT"

# Create cron job line
CRON_LINE="*/5 * * * * $TERMINATOR_SCRIPT >> $LOG_FILE 2>&1"

echo "This will add the following cron job:"
echo ""
echo "  $CRON_LINE"
echo ""
echo "This runs the terminator script every 5 minutes."
echo ""

# Check if cron job already exists
if crontab -l 2>/dev/null | grep -q "terminate-instances.sh"; then
  echo "⚠️  Cron job already exists!"
  echo ""
  echo "Current crontab:"
  crontab -l | grep "terminate-instances.sh"
  echo ""
  read -p "Do you want to replace it? (yes/no): " replace
  
  if [[ "$replace" != "yes" ]]; then
    echo "Aborted."
    exit 0
  fi
  
  # Remove old cron job
  crontab -l | grep -v "terminate-instances.sh" | crontab -
  echo "Old cron job removed."
fi

# Add new cron job
(crontab -l 2>/dev/null; echo "$CRON_LINE") | crontab -

echo ""
echo "✓ Cron job added successfully!"
echo ""
echo "Verify with:"
echo "  crontab -l"
echo ""
echo "Check logs with:"
echo "  tail -f $LOG_FILE"
echo ""
echo "You're ready to run:"
echo "  ./scripts/launch-campaign-waves.sh"
echo ""
