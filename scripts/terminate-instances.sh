#!/bin/bash
# terminate-instances.sh
# Instance Terminator - Runs every 5 minutes via cron
# Checks state file and terminates instances that have run for 55+ minutes
# Automatically rotates state file when all instances are terminated

# ========================================
# CONFIGURATION
# ========================================
STATE_FILE="logs/wave-state.log"
TEMP_FILE="logs/wave-state.tmp"
TIMEOUT=3300  # 55 minutes in seconds
REGION="ap-south-1"

# ========================================
# MAIN PROCESS
# ========================================
echo "[$(date)] ========================================"
echo "[$(date)] Instance Terminator - Starting check"
echo "[$(date)] ========================================"

# Check if state file exists
if [[ ! -f "$STATE_FILE" ]]; then
  echo "[$(date)] No state file found. Nothing to do."
  exit 0
fi

# Check if state file is empty
if [[ ! -s "$STATE_FILE" ]]; then
  echo "[$(date)] State file is empty. Nothing to do."
  exit 0
fi

# Get current time
CURRENT_TIME=$(date +%s)

# Initialize counters
RUNNING_COUNT=0
TOTAL_COUNT=0
TERMINATED_COUNT=0

# Clear temp file
> "$TEMP_FILE"

# Read state file line by line
echo "[$(date)] Reading state file..."
while IFS='|' read -r wave_id batch_id job_id instance_id start_time status; do
  
  # Skip empty lines
  if [[ -z "$wave_id" ]]; then
    continue
  fi
  
  TOTAL_COUNT=$((TOTAL_COUNT + 1))
  
  # Check if instance is running
  if [[ "$status" == "running" ]]; then
    RUNNING_COUNT=$((RUNNING_COUNT + 1))
    
    # Calculate elapsed time
    ELAPSED=$((CURRENT_TIME - start_time))
    ELAPSED_MIN=$((ELAPSED / 60))
    
    # Check if timeout reached (55 minutes)
    if [[ $ELAPSED -ge $TIMEOUT ]]; then
      echo "[$(date)] Terminating: $instance_id (Wave $wave_id, Batch $batch_id, Job $job_id)"
      echo "[$(date)]   Elapsed time: ${ELAPSED_MIN} minutes"
      
      # Terminate instance via AWS CLI
      aws ec2 terminate-instances \
        --region "$REGION" \
        --instance-ids "$instance_id" \
        --output text >> logs/terminator.log 2>&1
      
      if [[ $? -eq 0 ]]; then
        echo "[$(date)]   ✓ Terminated successfully"
        # Update status to terminated
        echo "${wave_id}|${batch_id}|${job_id}|${instance_id}|${start_time}|terminated" >> "$TEMP_FILE"
        TERMINATED_COUNT=$((TERMINATED_COUNT + 1))
      else
        echo "[$(date)]   ✗ Termination failed (keeping as running)"
        # Keep as running if termination failed
        echo "${wave_id}|${batch_id}|${job_id}|${instance_id}|${start_time}|running" >> "$TEMP_FILE"
      fi
    else
      # Not yet time to terminate - keep as running
      REMAINING=$((TIMEOUT - ELAPSED))
      REMAINING_MIN=$((REMAINING / 60))
      echo "[$(date)] Running: $instance_id (Wave $wave_id, Batch $batch_id) - ${REMAINING_MIN} min remaining"
      echo "${wave_id}|${batch_id}|${job_id}|${instance_id}|${start_time}|running" >> "$TEMP_FILE"
    fi
  else
    # Already terminated - keep as is
    echo "${wave_id}|${batch_id}|${job_id}|${instance_id}|${start_time}|${status}" >> "$TEMP_FILE"
  fi
  
done < "$STATE_FILE"

# Replace state file with updated version
mv "$TEMP_FILE" "$STATE_FILE"

# Calculate final running count (after terminations)
FINAL_RUNNING=$((RUNNING_COUNT - TERMINATED_COUNT))

echo "[$(date)] ========================================"
echo "[$(date)] Summary:"
echo "[$(date)]   Total instances: $TOTAL_COUNT"
echo "[$(date)]   Running (before): $RUNNING_COUNT"
echo "[$(date)]   Terminated (this run): $TERMINATED_COUNT"
echo "[$(date)]   Running (after): $FINAL_RUNNING"
echo "[$(date)] ========================================"

# ========================================
# LOG ROTATION
# ========================================
# If all instances are terminated, rotate the state file
if [[ $FINAL_RUNNING -eq 0 ]] && [[ $TOTAL_COUNT -gt 0 ]]; then
  echo "[$(date)] All instances terminated!"
  echo "[$(date)] Rotating state file..."
  
  # Create archive filename with timestamp
  TIMESTAMP=$(date +%Y%m%d-%H%M%S)
  ARCHIVE_FILE="logs/wave-state-${TIMESTAMP}.log"
  
  # Move state file to archive
  mv "$STATE_FILE" "$ARCHIVE_FILE"
  echo "[$(date)] State file archived to: $ARCHIVE_FILE"
  
  # Create empty state file for next wave
  touch "$STATE_FILE"
  echo "[$(date)] Created empty state file for next wave"
  echo "[$(date)] Ready for next wave execution!"
fi

echo "[$(date)] Termination check complete"
echo ""
