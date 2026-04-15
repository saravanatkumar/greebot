#!/bin/bash
# emergency-stop-waves.sh
# Emergency stop - terminates all running instances immediately

STATE_FILE="logs/wave-state.log"
REGION="ap-south-1"

echo "========================================"
echo "  EMERGENCY STOP"
echo "========================================"
echo ""

# Check if state file exists
if [[ ! -f "$STATE_FILE" ]]; then
  echo "No state file found. No instances to stop."
  exit 0
fi

# Count running instances
RUNNING_COUNT=$(grep "|running$" "$STATE_FILE" 2>/dev/null | wc -l | tr -d ' ')

if [[ $RUNNING_COUNT -eq 0 ]]; then
  echo "No running instances found."
  exit 0
fi

echo "Found $RUNNING_COUNT running instances."
echo ""
read -p "Are you sure you want to terminate ALL running instances? (yes/no): " confirm

if [[ "$confirm" != "yes" ]]; then
  echo "Aborted."
  exit 0
fi

echo ""
echo "Terminating all running instances..."
echo ""

# Terminate each running instance
TERMINATED=0
while IFS='|' read -r wave_id batch_id job_id instance_id start_time status; do
  if [[ "$status" == "running" ]]; then
    echo "Terminating: $instance_id (Wave $wave_id, Batch $batch_id, Job $job_id)"
    
    aws ec2 terminate-instances \
      --region "$REGION" \
      --instance-ids "$instance_id" \
      --output text >> logs/emergency-stop.log 2>&1
    
    if [[ $? -eq 0 ]]; then
      echo "  ✓ Terminated"
      TERMINATED=$((TERMINATED + 1))
    else
      echo "  ✗ Failed"
    fi
  fi
done < "$STATE_FILE"

echo ""
echo "========================================"
echo "Emergency stop complete"
echo "Terminated: $TERMINATED instances"
echo "========================================"
echo ""
echo "Note: Run terminate-instances.sh to update state file"
echo ""
