#!/bin/bash
# monitor-wave-progress.sh
# Real-time monitoring of wave execution
# Shows current status by reading the state file

STATE_FILE="logs/wave-state.log"

# Clear screen and show header
clear
echo "========================================"
echo "  WAVE PROGRESS MONITOR"
echo "========================================"
echo "Press Ctrl+C to exit"
echo ""

# Continuous monitoring loop
while true; do
  # Check if state file exists
  if [[ ! -f "$STATE_FILE" ]]; then
    echo "[$(date +%H:%M:%S)] No state file found. Waiting for wave to start..."
    sleep 5
    continue
  fi
  
  # Check if state file is empty
  if [[ ! -s "$STATE_FILE" ]]; then
    echo "[$(date +%H:%M:%S)] State file is empty. No active wave."
    sleep 5
    continue
  fi
  
  # Get current time
  CURRENT_TIME=$(date +%s)
  
  # Clear screen for fresh display
  clear
  echo "========================================"
  echo "  WAVE PROGRESS MONITOR"
  echo "========================================"
  echo "Last update: $(date)"
  echo ""
  
  # Count instances by wave
  for wave in 1 2 3 4; do
    TOTAL=$(grep "^${wave}|" "$STATE_FILE" 2>/dev/null | wc -l | tr -d ' ')
    RUNNING=$(grep "^${wave}|" "$STATE_FILE" 2>/dev/null | grep "|running$" | wc -l | tr -d ' ')
    TERMINATED=$((TOTAL - RUNNING))
    
    if [[ $TOTAL -gt 0 ]]; then
      echo "Wave $wave: $TOTAL total | $RUNNING running | $TERMINATED terminated"
      
      # Show batch details for this wave
      for batch in $(seq -f "%02g" 1 19); do
        BATCH_TOTAL=$(grep "^${wave}|${batch}|" "$STATE_FILE" 2>/dev/null | wc -l | tr -d ' ')
        BATCH_RUNNING=$(grep "^${wave}|${batch}|" "$STATE_FILE" 2>/dev/null | grep "|running$" | wc -l | tr -d ' ')
        
        if [[ $BATCH_TOTAL -gt 0 ]]; then
          if [[ $BATCH_RUNNING -gt 0 ]]; then
            # Calculate time remaining for this batch
            BATCH_START=$(grep "^${wave}|${batch}|" "$STATE_FILE" 2>/dev/null | head -1 | cut -d'|' -f5)
            ELAPSED=$((CURRENT_TIME - BATCH_START))
            REMAINING=$((3300 - ELAPSED))
            REMAINING_MIN=$((REMAINING / 60))
            
            if [[ $REMAINING -gt 0 ]]; then
              echo "  Batch $batch: $BATCH_RUNNING running (terminate in ${REMAINING_MIN} min)"
            else
              echo "  Batch $batch: $BATCH_RUNNING running (ready to terminate)"
            fi
          else
            echo "  Batch $batch: all terminated ✓"
          fi
        fi
      done
      echo ""
    fi
  done
  
  # Overall summary
  TOTAL_ALL=$(wc -l < "$STATE_FILE" | tr -d ' ')
  RUNNING_ALL=$(grep "|running$" "$STATE_FILE" 2>/dev/null | wc -l | tr -d ' ')
  TERMINATED_ALL=$((TOTAL_ALL - RUNNING_ALL))
  
  echo "========================================"
  echo "OVERALL: $TOTAL_ALL total | $RUNNING_ALL running | $TERMINATED_ALL terminated"
  echo "========================================"
  
  # Wait before next update
  sleep 10
done
