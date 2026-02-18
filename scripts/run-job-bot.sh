#!/bin/bash
export PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true
export PUPPETEER_EXECUTABLE_PATH=/usr/bin/google-chrome
export HOME=/home/ec2-user
export NODE_ENV=production

# Get instance metadata
INSTANCE_ID=$(ec2-metadata --instance-id | cut -d ' ' -f 2)

# Extract JOB_ID from user-data
JOB_ID=$(curl -s http://169.254.169.254/latest/user-data | grep JOB_ID | cut -d'=' -f2)

if [ -z "$JOB_ID" ]; then
  echo "ERROR: No Job ID provided in user-data. Exiting."
  exit 1
fi

LOG_DIR="/var/log/greendotball-bot"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="$LOG_DIR/job-${JOB_ID}_$TIMESTAMP.log"

mkdir -p $LOG_DIR
chown ec2-user:ec2-user $LOG_DIR

echo "========================================" | tee -a $LOG_FILE
echo "Job Bot started at $(date)" | tee -a $LOG_FILE
echo "Instance ID: $INSTANCE_ID" | tee -a $LOG_FILE
echo "Job ID: $JOB_ID" | tee -a $LOG_FILE
echo "========================================" | tee -a $LOG_FILE

cd /opt/greendotball-bot

echo "Syncing data from S3..." | tee -a $LOG_FILE
aws s3 sync s3://greendotball-bot-data/jobs/ ./data/jobs/ 2>&1 | tee -a $LOG_FILE
aws s3 sync s3://greendotball-bot-data/images/ ./data/images/ 2>&1 | tee -a $LOG_FILE
aws s3 cp s3://greendotball-bot-data/config/config.json ./config/config.json 2>&1 | tee -a $LOG_FILE

sleep 5

echo "Starting job bot execution for Job ID: $JOB_ID..." | tee -a $LOG_FILE
node src/bot_new.js --job-id $JOB_ID 2>&1 | tee -a $LOG_FILE

EXIT_CODE=$?
echo "Bot finished with exit code: $EXIT_CODE" | tee -a $LOG_FILE

echo "Uploading logs to S3..." | tee -a $LOG_FILE
aws s3 cp $LOG_FILE "s3://greendotball-bot-data/logs/job-${JOB_ID}/${INSTANCE_ID}_${TIMESTAMP}.log" 2>&1 | tee -a $LOG_FILE

echo "Script completed at $(date)" | tee -a $LOG_FILE

# Auto-shutdown instance after completion
echo "Shutting down instance in 60 seconds..." | tee -a $LOG_FILE
sleep 60
shutdown -h now
