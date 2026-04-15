#!/bin/bash
# force-terminate-all.sh
# Force terminate all greendotball instances except test instance
# Safe to run from cron - no interactive prompts

# ========================================
# CONFIGURATION
# ========================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

EXCLUDE_INSTANCE="i-0539a3d2739c04880"
REGION="ap-south-1"
STATE_FILE="${PROJECT_DIR}/logs/wave-state.log"

# ========================================
# MAIN PROCESS
# ========================================
echo "[$(date)] ========================================"
echo "[$(date)] Force Terminate - Starting"
echo "[$(date)] ========================================"

# Fetch running instances
echo "[$(date)] Fetching running instances..."
INSTANCES=$(aws ec2 describe-instances \
  --region $REGION \
  --filters "Name=tag:Project,Values=greendotball" "Name=instance-state-name,Values=running" \
  --query 'Reservations[].Instances[].InstanceId' \
  --output text 2>&1)

if [ $? -ne 0 ]; then
  echo "[$(date)] ERROR: Failed to fetch instances"
  echo "[$(date)] $INSTANCES"
  exit 1
fi

# Filter out the test instance
TO_TERMINATE=""
EXCLUDED_COUNT=0
for instance in $INSTANCES; do
  if [ "$instance" = "$EXCLUDE_INSTANCE" ]; then
    echo "[$(date)] Excluding test instance: $instance"
    EXCLUDED_COUNT=$((EXCLUDED_COUNT + 1))
  else
    TO_TERMINATE="$TO_TERMINATE $instance"
  fi
done

# Count instances to terminate
TERMINATE_COUNT=$(echo $TO_TERMINATE | wc -w | tr -d ' ')

echo "[$(date)] Found $TERMINATE_COUNT instances to terminate"
echo "[$(date)] Excluded $EXCLUDED_COUNT test instance(s)"

if [ -z "$TO_TERMINATE" ] || [ "$TERMINATE_COUNT" -eq 0 ]; then
  echo "[$(date)] No instances to terminate"
  echo "[$(date)] ========================================"
  exit 0
fi

# Terminate instances
echo "[$(date)] Terminating $TERMINATE_COUNT instances..."
RESULT=$(aws ec2 terminate-instances \
  --region $REGION \
  --instance-ids $TO_TERMINATE 2>&1)

if [ $? -eq 0 ]; then
  echo "[$(date)] ✓ Successfully initiated termination of $TERMINATE_COUNT instances"
  
  # Clear state file
  > "$STATE_FILE"
  echo "[$(date)] ✓ State file cleared"
else
  echo "[$(date)] ✗ Termination failed"
  echo "[$(date)] $RESULT"
  exit 1
fi

echo "[$(date)] ========================================"
echo "[$(date)] Force Terminate - Complete"
echo "[$(date)] ========================================"
echo ""
