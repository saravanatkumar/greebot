#!/bin/bash
# launch-campaign-waves.sh
# Wave Launcher - Launches 20 batches in 4 waves sequentially
# Each wave has 5 batches, each batch has ~42 jobs
# Logs all instances to shared state file for terminator script

set -e

# ========================================
# CONFIGURATION
# ========================================
# USER CONFIGURABLE - Change these values as needed
TOTAL_BATCHES_INPUT=1      # Total number of batches to process
BATCHES_PER_WAVE=4          # Number of batches per wave

# Other settings
BATCH_STAGGER_INTERVAL=600  # 10 minutes between batches
COOLDOWN_PERIOD=300         # 5 minutes between waves
STATE_FILE="logs/wave-state.log"
EXECUTION_LOG="logs/wave-execution.log"
REGION="ap-south-1"

# ========================================
# WAVE CONFIGURATION (AUTO-GENERATED)
# ========================================
# Dynamically build WAVE_BATCHES array based on configuration

# Calculate number of waves needed
TOTAL_WAVES=$(( (TOTAL_BATCHES_INPUT + BATCHES_PER_WAVE - 1) / BATCHES_PER_WAVE ))

# Build wave batches array
WAVE_BATCHES=()
batch_num=1

for wave in $(seq 1 $TOTAL_WAVES); do
  wave_batch_list=""
  
  # Add batches to this wave
  for i in $(seq 1 $BATCHES_PER_WAVE); do
    if [[ $batch_num -le $TOTAL_BATCHES_INPUT ]]; then
      wave_batch_list="$wave_batch_list $batch_num"
      batch_num=$((batch_num + 1))
    fi
  done
  
  # Add to array (trim leading space)
  WAVE_BATCHES+=("${wave_batch_list# }")
done

# Final count
TOTAL_BATCHES=$TOTAL_BATCHES_INPUT

# ========================================
# SETUP
# ========================================
echo "========================================"
echo "  WAVE ORCHESTRATOR - GreenDotBall"
echo "========================================"
echo "Start time: $(date)"
echo "Total batches: $TOTAL_BATCHES"
echo "Total waves: $TOTAL_WAVES"
echo "Batches per wave: $BATCHES_PER_WAVE"
echo ""
echo "Wave Configuration:"
for i in $(seq 0 $((TOTAL_WAVES - 1))); do
  wave_num=$((i + 1))
  batches="${WAVE_BATCHES[$i]}"
  batch_count=$(echo $batches | wc -w | tr -d ' ')
  echo "  Wave $wave_num: Batches $batches ($batch_count batches)"
done
echo "========================================"
echo ""

# Create logs directory if it doesn't exist
mkdir -p logs

# Create empty state file if it doesn't exist
if [[ ! -f "$STATE_FILE" ]]; then
  touch "$STATE_FILE"
  echo "Created state file: $STATE_FILE"
fi

# ========================================
# HELPER FUNCTIONS
# ========================================

# Check if all instances in a wave are terminated
check_wave_complete() {
  local wave_id=$1
  
  # Count running instances for this wave
  local running_count=$(grep "^${wave_id}|" "$STATE_FILE" 2>/dev/null | grep "|running$" | wc -l | tr -d ' ')
  
  if [[ $running_count -eq 0 ]]; then
    return 0  # Wave complete
  else
    return 1  # Still running
  fi
}

# Process a single batch
process_batch() {
  local wave_id=$1
  local batch_num=$2
  
  echo ""
  echo "========================================"
  echo "[Wave $wave_id] Processing Batch $batch_num"
  echo "========================================"
  echo "Start time: $(date)"
  
  # Record start time
  local start_time=$(date +%s)
  
  # Step 1: Copy batch phones to phones.txt
  echo "[Step 1/5] Copying phone_batch_${batch_num}.txt to phones.txt..."
  cp "data/phone_batch_${batch_num}.txt" "data/phones.txt"
  echo "  ✓ Phones copied"
  
  # Step 2: Create campaign
  echo "[Step 2/5] Creating campaign for batch-${batch_num}..."
  local campaign_output=$(./scripts/create-campaign-pool-20img.sh "batch-${batch_num}" 2>&1)
  
  # Step 3 & 4: Parse CAMPAIGN_ID and JOB_IDS from output
  echo "[Step 3/5] Parsing campaign details..."
  export CAMPAIGN_ID=$(echo "$campaign_output" | grep 'export CAMPAIGN_ID=' | cut -d'"' -f2)
  export JOB_IDS=$(echo "$campaign_output" | grep 'export JOB_IDS=' | cut -d'"' -f2)
  
  if [[ -z "$CAMPAIGN_ID" ]]; then
    echo "  ✗ ERROR: Could not parse CAMPAIGN_ID"
    return 1
  fi
  
  echo "  ✓ Campaign ID: $CAMPAIGN_ID"
  echo "  ✓ Job IDs: $JOB_IDS"
  
  # Step 5: Launch EC2 instances
  echo "[Step 4/5] Launching EC2 instances..."
  local instance_output=$(./scripts/launch-campaign-instances.sh 2>&1)
  
  # Step 6: Extract instance IDs and log to state file
  echo "[Step 5/5] Logging instances to state file..."
  
  # Parse instance IDs from output
  local instance_count=0
  while read -r line; do
    # Look for lines with instance IDs (format: i-xxxxxxxxxxxxxxxxx)
    if [[ $line =~ (i-[a-f0-9]{17}) ]]; then
      local instance_id="${BASH_REMATCH[1]}"
      
      # Determine job ID (job-001, job-002, etc.)
      # We'll use a counter since we don't have exact job-to-instance mapping
      instance_count=$((instance_count + 1))
      local job_id=$(printf "job-%03d" $instance_count)
      
      # Append to state file: wave_id|batch_num|job_id|instance_id|start_time|status
      echo "${wave_id}|${batch_num}|${job_id}|${instance_id}|${start_time}|running" >> "$STATE_FILE"
    fi
  done <<< "$instance_output"
  
  echo "  ✓ Logged $instance_count instances to state file"
  echo ""
  echo "[Wave $wave_id] Batch $batch_num complete!"
  echo "  Campaign: $CAMPAIGN_ID"
  echo "  Instances: $instance_count"
  echo "  Start time: $(date -r $start_time)"
  echo "  Terminate at: $(date -r $((start_time + 3300)))"
  echo ""
}

# ========================================
# MAIN EXECUTION
# ========================================

# Process each wave
for wave_num in $(seq 1 $TOTAL_WAVES); do
  echo ""
  echo "========================================"
  echo "WAVE $wave_num OF $TOTAL_WAVES"
  echo "========================================"
  echo "Start time: $(date)"
  echo ""
  
  # Get batches for this wave
  wave_batches=(${WAVE_BATCHES[$((wave_num - 1))]})
  
  # Process each batch in the wave sequentially
  for batch_num in "${wave_batches[@]}"; do
    process_batch $wave_num $batch_num
    
    # Wait between batches (except after last batch in wave)
    if [[ $batch_num != ${wave_batches[-1]} ]]; then
      echo "Waiting $((BATCH_STAGGER_INTERVAL / 60)) minutes before next batch..."
      sleep $BATCH_STAGGER_INTERVAL
    fi
  done
  
  echo ""
  echo "========================================"
  echo "[Wave $wave_num] All batches launched"
  echo "========================================"
  echo "Waiting for all instances to be terminated..."
  echo ""
  
  # Wait for all instances in this wave to be terminated
  while ! check_wave_complete $wave_num; do
    local running=$(grep "^${wave_num}|" "$STATE_FILE" 2>/dev/null | grep "|running$" | wc -l | tr -d ' ')
    echo "[$(date)] Wave $wave_num: $running instances still running..."
    sleep 60  # Check every minute
  done
  
  echo ""
  echo "[Wave $wave_num] Complete! All instances terminated."
  echo ""
  
  # Cooldown between waves (except after last wave)
  if [[ $wave_num -lt $TOTAL_WAVES ]]; then
    echo "Cooldown period: $((COOLDOWN_PERIOD / 60)) minutes before next wave..."
    sleep $COOLDOWN_PERIOD
  fi
done

# ========================================
# COMPLETION
# ========================================
echo ""
echo "========================================"
echo "  ALL WAVES COMPLETE!"
echo "========================================"
echo "End time: $(date)"
echo "Total batches processed: $TOTAL_BATCHES"
echo "Total waves: $TOTAL_WAVES"
echo ""
echo "Check results:"
echo "  aws s3 ls s3://greendotball-bot-data/campaigns/ --recursive"
echo ""
echo "View archived state files:"
echo "  ls -lh logs/wave-state-*.log"
echo ""
