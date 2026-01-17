#!/bin/bash
set -e

export PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true
export PUPPETEER_EXECUTABLE_PATH=/usr/bin/google-chrome
export HOME=/home/ec2-user
export NODE_ENV=production

LOG_DIR="/var/log/greendotball-bot"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="$LOG_DIR/bot_$TIMESTAMP.log"

sudo mkdir -p $LOG_DIR
sudo chown ec2-user:ec2-user $LOG_DIR

# Start 45-minute failsafe timer in background
# If script doesn't complete in 45 minutes, force shutdown
(
  sleep 2700  # 45 minutes = 2700 seconds
  echo "⚠️  FAILSAFE: 45-minute timeout reached - forcing shutdown" | tee -a $LOG_FILE
  sudo shutdown -h now
) &
FAILSAFE_PID=$!

echo "========================================" | tee -a $LOG_FILE
echo "Bot started at $(date)" | tee -a $LOG_FILE
INSTANCE_ID=$(ec2-metadata --instance-id | cut -d ' ' -f 2)
echo "Instance ID: $INSTANCE_ID" | tee -a $LOG_FILE
echo "Failsafe timer: Will auto-terminate in 45 minutes" | tee -a $LOG_FILE

# Get MOBILE_INDEX from EC2 user-data
echo "Fetching mobile index from user-data..." | tee -a $LOG_FILE
MOBILE_INDEX=$(ec2-metadata --user-data | grep -oP 'MOBILE_INDEX=\K\d+' || echo "")

if [ -z "$MOBILE_INDEX" ]; then
  echo "ERROR: MOBILE_INDEX not found in user-data" | tee -a $LOG_FILE
  echo "Falling back to legacy mode (config.json)" | tee -a $LOG_FILE
  MOBILE_INDEX=""
else
  echo "Assigned Mobile Index: $MOBILE_INDEX" | tee -a $LOG_FILE
fi

echo "========================================" | tee -a $LOG_FILE

cd /opt/greendotball-bot

# Create data directories
mkdir -p ./data/image-batches

if [ -n "$MOBILE_INDEX" ]; then
  # Dynamic assignment mode
  echo "🎯 DYNAMIC ASSIGNMENT MODE" | tee -a $LOG_FILE
  echo "Mobile Index: $MOBILE_INDEX" | tee -a $LOG_FILE
  
  # Download mobile numbers list
  echo "Downloading mobile numbers..." | tee -a $LOG_FILE
  aws s3 cp s3://greendotball-bot-data/config/mobile-numbers.txt ./data/mobile-numbers.txt 2>&1 | tee -a $LOG_FILE
  
  # Download ALL images (same for all instances)
  echo "Downloading all images..." | tee -a $LOG_FILE
  mkdir -p ./data/images
  aws s3 sync s3://greendotball-bot-data/images/ ./data/images/ 2>&1 | tee -a $LOG_FILE
  
  # Rename images to random names for anonymity
  echo "Renaming images to random names..." | tee -a $LOG_FILE
  cd ./data/images/
  for file in *; do
    if [ -f "$file" ]; then
      # Get file extension
      ext="${file##*.}"
      # Generate random name (12 characters)
      random_name=$(cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 12 | head -n 1)
      # Rename file
      mv "$file" "${random_name}.${ext}"
      echo "  Renamed: $file -> ${random_name}.${ext}" | tee -a $LOG_FILE
    fi
  done
  cd /opt/greendotball-bot
  
  IMAGE_COUNT=$(ls ./data/images/ 2>/dev/null | wc -l)
  echo "Downloaded and renamed $IMAGE_COUNT images" | tee -a $LOG_FILE
  
  if [ "$IMAGE_COUNT" -eq 0 ]; then
    echo "ERROR: No images found" | tee -a $LOG_FILE
    exit 1
  fi
  
  echo "This instance will process: 1 mobile × $IMAGE_COUNT images = $IMAGE_COUNT submissions" | tee -a $LOG_FILE
else
  # Legacy mode - download all images and use config.json
  echo "📋 LEGACY MODE - Using config.json" | tee -a $LOG_FILE
  echo "Syncing data from S3..." | tee -a $LOG_FILE
  aws s3 sync s3://greendotball-bot-data/images/ ./data/sample-images/ 2>&1 | tee -a $LOG_FILE
  aws s3 cp s3://greendotball-bot-data/config/config.json ./config/config.json 2>&1 | tee -a $LOG_FILE
fi

sleep 5

# Run bot with or without mobile index
echo "Starting bot execution..." | tee -a $LOG_FILE

if [ -n "$MOBILE_INDEX" ]; then
  echo "Command: node src/bot.js --batch --mobile-index $MOBILE_INDEX" | tee -a $LOG_FILE
  node src/bot.js --batch --mobile-index $MOBILE_INDEX 2>&1 | tee -a $LOG_FILE
else
  echo "Command: node src/bot.js --batch" | tee -a $LOG_FILE
  node src/bot.js --batch 2>&1 | tee -a $LOG_FILE
fi

EXIT_CODE=$?
echo "Bot finished with exit code: $EXIT_CODE" | tee -a $LOG_FILE

# Cancel failsafe timer since bot completed
kill $FAILSAFE_PID 2>/dev/null || true
echo "✓ Failsafe timer cancelled - bot completed successfully" | tee -a $LOG_FILE

# Upload logs to S3
echo "Uploading logs to S3..." | tee -a $LOG_FILE
aws s3 cp $LOG_FILE "s3://greendotball-bot-data/logs/$INSTANCE_ID/$TIMESTAMP.log" 2>&1 | tee -a $LOG_FILE
aws s3 cp /opt/greendotball-bot/logs/ "s3://greendotball-bot-data/logs/$INSTANCE_ID/" --recursive 2>&1 | tee -a $LOG_FILE

echo "Script completed at $(date)" | tee -a $LOG_FILE

# Auto-shutdown
echo "Shutting down instance in 60 seconds..." | tee -a $LOG_FILE
sleep 60
sudo shutdown -h now
