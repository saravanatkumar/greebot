# AWS EC2 Deployment - Amazon Linux 2023
## Quick Setup Guide for Green Dot Ball Bot

---

## 🐧 Amazon Linux 2023 - Free & AWS-Optimized

**AMI**: Amazon Linux 2023 (Free Tier Eligible)
**Region**: ap-south-1 (Mumbai)
**Instance**: t3.small Spot ($0.0062/hr) or t2.micro (Free Tier)

---

## Phase 1: Launch & Setup EC2 Instance

### Step 1.1: Launch Instance

**AWS Console:**
1. Go to EC2 → Launch Instance
2. Name: `greendotball-bot-base`
3. **AMI**: Amazon Linux 2023 AMI (Free Tier eligible)
4. **Instance type**: t3.small (or t2.micro for Free Tier)
5. **Key pair**: Create/select your key pair
6. **Network**: Default VPC
7. **Storage**: 8 GB gp3
8. **Security Group**: Allow SSH (22) from your IP
9. Launch instance

**AWS CLI:**
```bash
aws ec2 run-instances \
  --image-id ami-0c2af51e265bd5e0e \
  --instance-type t3.small \
  --key-name your-key-pair \
  --security-group-ids sg-xxxxx \
  --subnet-id subnet-xxxxx \
  --block-device-mappings '[{"DeviceName":"/dev/xvda","Ebs":{"VolumeSize":8,"VolumeType":"gp3"}}]' \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=greendotball-bot-base}]' \
  --region ap-south-1
```

### Step 1.2: Connect to Instance

```bash
# SSH into instance
ssh -i your-key.pem ec2-user@<instance-public-ip>

# Note: Amazon Linux uses 'ec2-user' instead of 'ubuntu'
```

### Step 1.3: Update System & Install Dependencies

```bash
# Update system
sudo dnf update -y

# Install Node.js 18.x
sudo dnf install -y nodejs npm

# Verify Node.js installation
node --version  # Should show v18.x or higher
npm --version

# Install Chrome/Chromium dependencies
sudo dnf install -y \
  chromium \
  liberation-fonts \
  nss \
  atk \
  cups-libs \
  gtk3 \
  libXcomposite \
  libXcursor \
  libXdamage \
  libXext \
  libXi \
  libXrandr \
  libXScrnSaver \
  libXtst \
  pango \
  xdg-utils \
  alsa-lib

# Install Git (if needed)
sudo dnf install -y git

# AWS CLI is pre-installed on Amazon Linux 2023
aws --version
```

### Step 1.4: Install Chromium Browser

```bash
# Install Chromium
sudo dnf install -y chromium

# Verify installation
chromium-browser --version

# Set environment variable for Puppeteer
echo 'export PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true' >> ~/.bashrc
echo 'export PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium-browser' >> ~/.bashrc
source ~/.bashrc
```

### Step 1.5: Create Application Directory

```bash
# Create app directory
sudo mkdir -p /opt/greendotball-bot
sudo chown ec2-user:ec2-user /opt/greendotball-bot
cd /opt/greendotball-bot
```

### Step 1.6: Deploy Bot Code

**Option 1: Upload via SCP (from your local machine)**

```bash
# Run this from your local machine
scp -i your-key.pem -r /Users/apple/CascadeProjects/windsurf-project-2/* \
  ec2-user@<instance-ip>:/opt/greendotball-bot/
```

**Option 2: Clone from Git**

```bash
# On EC2 instance
cd /opt/greendotball-bot
git clone <your-repo-url> .
```

**Option 3: Manual file transfer**

```bash
# Create package.json, src/, config/, etc.
# Copy files one by one
```

### Step 1.7: Install Node.js Dependencies

```bash
cd /opt/greendotball-bot

# Install dependencies
npm install --production

# Set Puppeteer environment variables
export PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true
export PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium-browser
```

### Step 1.8: Configure AWS Credentials (for S3)

**Option 1: IAM Role (Recommended)**

```bash
# Attach IAM role to EC2 instance via AWS Console
# Role should have S3 read/write permissions
# No need to configure credentials manually
```

**Option 2: AWS Configure**

```bash
aws configure
# AWS Access Key ID: <your-key>
# AWS Secret Access Key: <your-secret>
# Default region: ap-south-1
# Default output format: json
```

### Step 1.9: Setup S3 Bucket & Upload Data

```bash
# Create S3 bucket (one-time)
aws s3 mb s3://greendotball-bot-data --region ap-south-1

# Upload images from local machine (run from local)
aws s3 sync /Users/apple/CascadeProjects/windsurf-project-2/data/sample-images/ \
  s3://greendotball-bot-data/images/

# Upload config
aws s3 cp /Users/apple/CascadeProjects/windsurf-project-2/config/config.json \
  s3://greendotball-bot-data/config/config.json

# On EC2: Download images and config
cd /opt/greendotball-bot
aws s3 sync s3://greendotball-bot-data/images/ ./data/sample-images/
aws s3 cp s3://greendotball-bot-data/config/config.json ./config/config.json
```

### Step 1.10: Update Config for Headless Mode

```bash
cd /opt/greendotball-bot

# Edit config
nano config/config.json

# Change:
# "headless": false  →  "headless": true
# Save and exit (Ctrl+X, Y, Enter)
```

### Step 1.11: Test Bot Manually

```bash
cd /opt/greendotball-bot

# Set environment variables
export PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true
export PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium-browser

# Run bot
npm run batch

# Verify it completes 10 submissions successfully
```

---

## Phase 2: Create Auto-Start Script

### Step 2.1: Create Bot Runner Script

```bash
sudo nano /opt/greendotball-bot/run-bot.sh
```

**Script Content:**

```bash
#!/bin/bash

# Bot Runner Script for Amazon Linux 2023
# Auto-runs on instance startup

# Set environment variables
export PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true
export PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium-browser
export HOME=/home/ec2-user
export NODE_ENV=production

# Logging
LOG_DIR="/var/log/greendotball-bot"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="$LOG_DIR/bot_$TIMESTAMP.log"

# Create log directory
sudo mkdir -p $LOG_DIR
sudo chown ec2-user:ec2-user $LOG_DIR

# Log startup
echo "========================================" | tee -a $LOG_FILE
echo "Bot started at $(date)" | tee -a $LOG_FILE
echo "Instance ID: $(ec2-metadata --instance-id | cut -d ' ' -f 2)" | tee -a $LOG_FILE
echo "Instance Type: $(ec2-metadata --instance-type | cut -d ' ' -f 2)" | tee -a $LOG_FILE
echo "Availability Zone: $(ec2-metadata --availability-zone | cut -d ' ' -f 2)" | tee -a $LOG_FILE
echo "========================================" | tee -a $LOG_FILE

# Navigate to bot directory
cd /opt/greendotball-bot

# Download latest images and config from S3
echo "Syncing data from S3..." | tee -a $LOG_FILE
aws s3 sync s3://greendotball-bot-data/images/ ./data/sample-images/ 2>&1 | tee -a $LOG_FILE
aws s3 cp s3://greendotball-bot-data/config/config.json ./config/config.json 2>&1 | tee -a $LOG_FILE

# Wait for network to be fully ready
sleep 5

# Run the bot
echo "Starting bot execution..." | tee -a $LOG_FILE
npm run batch 2>&1 | tee -a $LOG_FILE

# Capture exit code
EXIT_CODE=$?
echo "Bot finished with exit code: $EXIT_CODE" | tee -a $LOG_FILE

# Upload logs to S3
echo "Uploading logs to S3..." | tee -a $LOG_FILE
INSTANCE_ID=$(ec2-metadata --instance-id | cut -d ' ' -f 2)
aws s3 cp $LOG_FILE "s3://greendotball-bot-data/logs/$INSTANCE_ID/$TIMESTAMP.log" 2>&1 | tee -a $LOG_FILE
aws s3 cp /opt/greendotball-bot/logs/ "s3://greendotball-bot-data/logs/$INSTANCE_ID/" --recursive 2>&1 | tee -a $LOG_FILE

# Optional: Auto-shutdown after completion
# Uncomment the following lines to enable auto-shutdown
# echo "Shutting down instance in 60 seconds..." | tee -a $LOG_FILE
# sleep 60
# sudo shutdown -h now

echo "Script completed at $(date)" | tee -a $LOG_FILE
```

```bash
# Make executable
sudo chmod +x /opt/greendotball-bot/run-bot.sh

# Test the script
/opt/greendotball-bot/run-bot.sh
```

### Step 2.2: Create Systemd Service

```bash
sudo nano /etc/systemd/system/greendotball-bot.service
```

**Service Content:**

```ini
[Unit]
Description=Green Dot Ball Bot Auto-Runner
After=network-online.target cloud-final.service
Wants=network-online.target

[Service]
Type=oneshot
User=ec2-user
WorkingDirectory=/opt/greendotball-bot
Environment="PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true"
Environment="PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium-browser"
Environment="HOME=/home/ec2-user"
ExecStart=/opt/greendotball-bot/run-bot.sh
StandardOutput=journal
StandardError=journal
RemainAfterExit=no

[Install]
WantedBy=multi-user.target
```

```bash
# Reload systemd
sudo systemctl daemon-reload

# Enable service to run on boot
sudo systemctl enable greendotball-bot.service

# Test the service
sudo systemctl start greendotball-bot.service

# Check status
sudo systemctl status greendotball-bot.service

# View logs
sudo journalctl -u greendotball-bot.service -f
```

### Step 2.3: Test Auto-Start on Reboot

```bash
# Reboot instance
sudo reboot

# Wait 2-3 minutes, then SSH back in
ssh -i your-key.pem ec2-user@<instance-ip>

# Check if bot ran automatically
sudo systemctl status greendotball-bot.service
sudo journalctl -u greendotball-bot.service -n 100

# Check logs
ls -la /var/log/greendotball-bot/
cat /var/log/greendotball-bot/bot_*.log
```

---

## Phase 3: Create Custom AMI

### Step 3.1: Clean Up Instance

```bash
# Clear bash history
history -c
cat /dev/null > ~/.bash_history

# Clear logs
sudo rm -rf /var/log/greendotball-bot/*
sudo rm -rf /opt/greendotball-bot/logs/*

# Clear cache
sudo dnf clean all
sudo rm -rf /tmp/*
sudo rm -rf /var/tmp/*

# Clear cloud-init logs (optional)
sudo rm -rf /var/lib/cloud/instances/*
```

### Step 3.2: Stop Instance

```bash
# From AWS Console: Stop the instance
# Or via CLI:
aws ec2 stop-instances --instance-ids i-xxxxx --region ap-south-1
```

### Step 3.3: Create AMI

**AWS Console:**
1. Go to EC2 → Instances
2. Select `greendotball-bot-base` instance
3. Actions → Image and templates → Create image
4. Image name: `greendotball-bot-amazon-linux-v1`
5. Description: `Green Dot Ball Bot on Amazon Linux 2023 with auto-start - v1.0`
6. No reboot: ✅ (already stopped)
7. Create image

**AWS CLI:**
```bash
aws ec2 create-image \
  --instance-id i-xxxxx \
  --name "greendotball-bot-amazon-linux-v1" \
  --description "Green Dot Ball Bot on Amazon Linux 2023 with auto-start - v1.0" \
  --region ap-south-1
```

Wait 5-10 minutes for AMI creation to complete.

---

## Phase 4: Create Launch Template

### Step 4.1: Create IAM Role for S3 Access

**AWS Console:**
1. Go to IAM → Roles → Create role
2. Trusted entity: AWS service → EC2
3. Permissions: AmazonS3FullAccess (or custom policy)
4. Role name: `EC2-GreenDotBall-S3-Access`
5. Create role

**Custom S3 Policy (Recommended):**
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::greendotball-bot-data",
        "arn:aws:s3:::greendotball-bot-data/*"
      ]
    }
  ]
}
```

### Step 4.2: Create Launch Template

**AWS CLI:**
```bash
# Get your AMI ID
AMI_ID=$(aws ec2 describe-images \
  --filters "Name=name,Values=greendotball-bot-amazon-linux-v1" \
  --query 'Images[0].ImageId' \
  --output text \
  --region ap-south-1)

echo "AMI ID: $AMI_ID"

# Create launch template
aws ec2 create-launch-template \
  --launch-template-name greendotball-bot-template \
  --version-description "v1.0 - Amazon Linux 2023" \
  --launch-template-data "{
    \"ImageId\": \"$AMI_ID\",
    \"InstanceType\": \"t3.small\",
    \"IamInstanceProfile\": {
      \"Name\": \"EC2-GreenDotBall-S3-Access\"
    },
    \"InstanceMarketOptions\": {
      \"MarketType\": \"spot\",
      \"SpotOptions\": {
        \"SpotInstanceType\": \"one-time\",
        \"InstanceInterruptionBehavior\": \"terminate\"
      }
    },
    \"TagSpecifications\": [{
      \"ResourceType\": \"instance\",
      \"Tags\": [
        {\"Key\": \"Name\", \"Value\": \"greendotball-bot-worker\"},
        {\"Key\": \"Project\", \"Value\": \"greendotball\"},
        {\"Key\": \"OS\", \"Value\": \"AmazonLinux2023\"}
      ]
    }]
  }" \
  --region ap-south-1
```

---

## Phase 5: Launch Instances

### Launch 1 Instance (10 submissions)

```bash
aws ec2 run-instances \
  --launch-template LaunchTemplateName=greendotball-bot-template \
  --count 1 \
  --region ap-south-1
```

### Launch 10 Instances (100 submissions)

```bash
aws ec2 run-instances \
  --launch-template LaunchTemplateName=greendotball-bot-template \
  --count 10 \
  --region ap-south-1
```

### Launch 100 Instances (1000 submissions)

```bash
aws ec2 run-instances \
  --launch-template LaunchTemplateName=greendotball-bot-template \
  --count 100 \
  --region ap-south-1
```

---

## Monitoring & Management

### Check Running Instances

```bash
aws ec2 describe-instances \
  --filters "Name=tag:Project,Values=greendotball" "Name=instance-state-name,Values=running" \
  --query 'Reservations[*].Instances[*].[InstanceId,InstanceType,State.Name,LaunchTime]' \
  --output table \
  --region ap-south-1
```

### Download Logs from S3

```bash
# List all logs
aws s3 ls s3://greendotball-bot-data/logs/ --recursive

# Download all logs
aws s3 sync s3://greendotball-bot-data/logs/ ./local-logs/

# View specific log
aws s3 cp s3://greendotball-bot-data/logs/i-xxxxx/20260114_223000.log - | less
```

### Terminate Instances

```bash
# Terminate specific instance
aws ec2 terminate-instances --instance-ids i-xxxxx --region ap-south-1

# Terminate all bot instances
aws ec2 describe-instances \
  --filters "Name=tag:Project,Values=greendotball" "Name=instance-state-name,Values=running" \
  --query 'Reservations[*].Instances[*].InstanceId' \
  --output text \
  --region ap-south-1 | xargs aws ec2 terminate-instances --instance-ids
```

---

## Cost Summary (Amazon Linux 2023)

### Free Tier (First 12 Months)
- **t2.micro**: 750 hours/month FREE
- **Storage**: 30 GB EBS FREE
- **Data Transfer**: 15 GB/month FREE

### After Free Tier / Using t3.small Spot

| Scenario | Instances | Runtime | Cost/Run | Monthly (30x) |
|----------|-----------|---------|----------|---------------|
| 10 submissions | 1 | 4 min | $0.0004 | $0.012 |
| 100 submissions | 10 | 4 min | $0.004 | $0.12 |
| 1000 submissions | 100 | 4 min | $0.041 | $1.23 |

**Total Monthly Cost (1000 submissions/day)**: ~$1.65 (~₹138)

---

## Quick Reference Commands

```bash
# SSH to instance
ssh -i your-key.pem ec2-user@<instance-ip>

# Check bot service status
sudo systemctl status greendotball-bot.service

# View bot logs
sudo journalctl -u greendotball-bot.service -f

# Manually run bot
cd /opt/greendotball-bot && npm run batch

# Check instance metadata
ec2-metadata --all

# Sync images from S3
aws s3 sync s3://greendotball-bot-data/images/ /opt/greendotball-bot/data/sample-images/

# Upload logs to S3
aws s3 cp /var/log/greendotball-bot/ s3://greendotball-bot-data/logs/$(ec2-metadata --instance-id | cut -d ' ' -f 2)/ --recursive
```

---

## Troubleshooting

### Bot doesn't start on boot
```bash
# Check service status
sudo systemctl status greendotball-bot.service

# Check logs
sudo journalctl -u greendotball-bot.service -n 100

# Manually run script
/opt/greendotball-bot/run-bot.sh

# Check if service is enabled
sudo systemctl is-enabled greendotball-bot.service
```

### Chromium not found
```bash
# Verify Chromium installation
which chromium-browser
chromium-browser --version

# Reinstall if needed
sudo dnf reinstall -y chromium

# Set environment variable
export PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium-browser
```

### S3 access denied
```bash
# Check IAM role attached to instance
aws sts get-caller-identity

# Test S3 access
aws s3 ls s3://greendotball-bot-data/

# If using credentials, reconfigure
aws configure
```

### Out of memory
```bash
# Add swap space
sudo dd if=/dev/zero of=/swapfile bs=1M count=2048
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile

# Make permanent
echo '/swapfile swap swap defaults 0 0' | sudo tee -a /etc/fstab
```

---

## Summary

✅ **Amazon Linux 2023** - Free, AWS-optimized
✅ **Auto-start on boot** - No manual intervention
✅ **Spot instances** - 70% cost savings
✅ **Easy scaling** - Launch 1-100+ instances
✅ **S3 integration** - Centralized data & logs
✅ **Total cost** - $1.65/month for 1000 submissions/day

**You're all set!** Follow the phases above to deploy your bot on Amazon Linux 2023.
