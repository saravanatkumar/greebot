# AWS EC2 Deployment Plan - Green Dot Ball Bot
## Minimal Cost Architecture with Auto-Start & Parallel Instances

---

## 🎯 Project Overview

**Objective**: Deploy the Green Dot Ball bot on AWS EC2 with:
- ✅ Auto-start on instance launch (runs 10 submissions automatically)
- ✅ Create custom AMI for easy replication
- ✅ Launch multiple instances in parallel (1-10+ instances)
- ✅ Minimal cost optimization (Spot instances)
- ✅ Auto-shutdown after completion
- ✅ Manual start/stop control

**Use Case**: 
- Start 1 instance → 10 submissions
- Start 10 instances → 100 submissions (in parallel)
- Start 100 instances → 1000 submissions (in parallel)

---

## 💰 Cost Optimization Strategy

### Instance Type Selection

| Instance Type | vCPU | RAM | On-Demand | Spot Price | Recommended |
|--------------|------|-----|-----------|------------|-------------|
| **t3.micro** | 2 | 1 GB | $0.0104/hr | $0.0031/hr | ❌ Too small for Chrome |
| **t3.small** | 2 | 2 GB | $0.0208/hr | $0.0062/hr | ✅ **BEST** |
| **t4g.small** | 2 | 2 GB | $0.0168/hr | $0.0050/hr | ✅ ARM (cheaper) |
| **t3.medium** | 2 | 4 GB | $0.0416/hr | $0.0125/hr | ⚠️ Overkill |

### Cost Calculation (Mumbai Region - ap-south-1)

**Scenario 1: Single Instance Daily**
- Instance: t3.small Spot
- Runtime: 10 submissions × 25 seconds = ~4 minutes
- Cost per run: $0.0062 × (4/60) = **$0.0004**
- Monthly (30 runs): **$0.012** (~₹1)

**Scenario 2: 10 Parallel Instances Daily**
- Instances: 10 × t3.small Spot
- Runtime: 10 submissions × 25 seconds = ~4 minutes
- Cost per run: 10 × $0.0062 × (4/60) = **$0.004**
- Monthly (30 runs): **$0.12** (~₹10)

**Scenario 3: 100 Parallel Instances (1000 submissions)**
- Instances: 100 × t3.small Spot
- Runtime: ~4 minutes
- Cost per run: 100 × $0.0062 × (4/60) = **$0.041**
- Monthly (30 runs): **$1.23** (~₹103)

### Additional AWS Costs

| Service | Usage | Monthly Cost |
|---------|-------|--------------|
| **AMI Storage** | 8 GB snapshot | $0.40 (~₹33) |
| **S3 (Images)** | 100 MB | $0.02 (~₹2) |
| **Data Transfer** | 1 GB out | $0.09 (~₹8) |
| **CloudWatch Logs** | 500 MB | $0.25 (~₹21) |
| **Total Fixed** | - | **$0.76** (~₹64) |

### Total Monthly Cost Estimate

| Scenario | Instances | Cost |
|----------|-----------|------|
| **1 instance/day** | 1 | $0.76 + $0.012 = **$0.77** (~₹65/month) |
| **10 instances/day** | 10 | $0.76 + $0.12 = **$0.88** (~₹74/month) |
| **100 instances/day** | 100 | $0.76 + $1.23 = **$2.00** (~₹167/month) |

---

## 🏗️ Architecture Design

```
┌─────────────────────────────────────────────────────────────────┐
│                    AWS EC2 Architecture                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌────────────────────────────────────────────────────────┐    │
│  │              Custom AMI (Golden Image)                  │    │
│  │  - Ubuntu 22.04                                         │    │
│  │  - Node.js 18.x                                         │    │
│  │  - Chrome/Chromium                                      │    │
│  │  - Bot Code                                             │    │
│  │  - Startup Script (User Data)                           │    │
│  └────────────────────────────────────────────────────────┘    │
│                            │                                     │
│                            │ Launch from AMI                     │
│                            ▼                                     │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │         EC2 Instance (t3.small Spot)                      │  │
│  │  ┌────────────────────────────────────────────────────┐  │  │
│  │  │  1. Instance starts                                 │  │  │
│  │  │  2. User Data script executes                       │  │  │
│  │  │  3. npm run batch (10 submissions)                  │  │  │
│  │  │  4. Upload logs to S3                               │  │  │
│  │  │  5. Auto-shutdown (optional)                        │  │  │
│  │  └────────────────────────────────────────────────────┘  │  │
│  └──────────────────────────────────────────────────────────┘  │
│                            │                                     │
│                            │ Logs & Results                      │
│                            ▼                                     │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │                    S3 Bucket                              │  │
│  │  - Images (input)                                         │  │
│  │  - Phone numbers (input)                                  │  │
│  │  - Logs (output)                                          │  │
│  │  - Results (output)                                       │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │              Launch Multiple Instances                    │  │
│  │  Instance 1 → 10 submissions                              │  │
│  │  Instance 2 → 10 submissions                              │  │
│  │  Instance 3 → 10 submissions                              │  │
│  │  ...                                                      │  │
│  │  Instance N → 10 submissions                              │  │
│  │                                                           │  │
│  │  Total: N × 10 submissions (parallel)                    │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 📋 Implementation Plan

### Phase 1: Prepare Base EC2 Instance (One-time setup)

#### Step 1.1: Launch Initial EC2 Instance

```bash
# Launch t3.small instance in Mumbai region
# AMI: Ubuntu 22.04 LTS (ami-0f58b397bc5c1f2e8)
# Instance Type: t3.small
# Storage: 8 GB gp3
# Security Group: Allow SSH (22) from your IP
```

**AWS Console Steps:**
1. Go to EC2 → Launch Instance
2. Name: `greendotball-bot-base`
3. AMI: Ubuntu Server 22.04 LTS
4. Instance type: t3.small
5. Key pair: Create/select your key pair
6. Network: Default VPC
7. Storage: 8 GB gp3
8. Launch instance

#### Step 1.2: Connect and Install Dependencies

```bash
# SSH into instance
ssh -i your-key.pem ubuntu@<instance-public-ip>

# Update system
sudo apt update && sudo apt upgrade -y

# Install Node.js 18.x
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt install -y nodejs

# Install Chrome dependencies
sudo apt install -y \
  chromium-browser \
  chromium-chromedriver \
  fonts-liberation \
  libasound2 \
  libatk-bridge2.0-0 \
  libatk1.0-0 \
  libatspi2.0-0 \
  libcups2 \
  libdbus-1-3 \
  libdrm2 \
  libgbm1 \
  libgtk-3-0 \
  libnspr4 \
  libnss3 \
  libwayland-client0 \
  libxcomposite1 \
  libxdamage1 \
  libxfixes3 \
  libxkbcommon0 \
  libxrandr2 \
  xdg-utils

# Install AWS CLI
sudo apt install -y awscli

# Verify installations
node --version  # Should show v18.x
chromium-browser --version
aws --version
```

#### Step 1.3: Deploy Bot Code

```bash
# Create app directory
sudo mkdir -p /opt/greendotball-bot
sudo chown ubuntu:ubuntu /opt/greendotball-bot
cd /opt/greendotball-bot

# Clone or copy your bot code
# Option 1: From Git
git clone <your-repo-url> .

# Option 2: Upload via SCP from local machine
# (Run this from your local machine)
scp -i your-key.pem -r /Users/apple/CascadeProjects/windsurf-project-2/* ubuntu@<instance-ip>:/opt/greendotball-bot/

# Install dependencies
cd /opt/greendotball-bot
npm install --production

# Configure Puppeteer to use system Chrome
export PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true
export PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium-browser
```

#### Step 1.4: Configure AWS Credentials (for S3 access)

```bash
# Configure AWS CLI
aws configure
# AWS Access Key ID: <your-key>
# AWS Secret Access Key: <your-secret>
# Default region: ap-south-1
# Default output format: json

# Or use IAM Role (recommended)
# Attach IAM role to EC2 instance with S3 access
```

#### Step 1.5: Download Images and Config from S3

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

#### Step 1.6: Update Config for Headless Mode

```bash
# Edit config to run headless
cd /opt/greendotball-bot
nano config/config.json

# Change:
# "headless": false  →  "headless": true
# "maxSubmissionsPerSession": 10
```

#### Step 1.7: Test Bot Manually

```bash
cd /opt/greendotball-bot
npm run batch

# Verify it runs successfully and completes 10 submissions
```

---

### Phase 2: Create Startup Script

#### Step 2.1: Create Bot Runner Script

```bash
sudo nano /opt/greendotball-bot/run-bot.sh
```

**Script Content:**

```bash
#!/bin/bash

# Bot Runner Script
# This script runs on instance startup

# Set environment variables
export PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true
export PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium-browser
export HOME=/home/ubuntu
export NODE_ENV=production

# Logging
LOG_DIR="/var/log/greendotball-bot"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="$LOG_DIR/bot_$TIMESTAMP.log"

# Create log directory
mkdir -p $LOG_DIR

# Log startup
echo "========================================" | tee -a $LOG_FILE
echo "Bot started at $(date)" | tee -a $LOG_FILE
echo "Instance ID: $(ec2-metadata --instance-id | cut -d ' ' -f 2)" | tee -a $LOG_FILE
echo "========================================" | tee -a $LOG_FILE

# Navigate to bot directory
cd /opt/greendotball-bot

# Download latest images and config from S3 (optional)
echo "Syncing data from S3..." | tee -a $LOG_FILE
aws s3 sync s3://greendotball-bot-data/images/ ./data/sample-images/ 2>&1 | tee -a $LOG_FILE
aws s3 cp s3://greendotball-bot-data/config/config.json ./config/config.json 2>&1 | tee -a $LOG_FILE

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
# Uncomment the following line to enable auto-shutdown
# echo "Shutting down instance..." | tee -a $LOG_FILE
# sudo shutdown -h now

echo "Script completed at $(date)" | tee -a $LOG_FILE
```

```bash
# Make executable
sudo chmod +x /opt/greendotball-bot/run-bot.sh

# Test the script
sudo /opt/greendotball-bot/run-bot.sh
```

#### Step 2.2: Create Systemd Service (Auto-start on boot)

```bash
sudo nano /etc/systemd/system/greendotball-bot.service
```

**Service Content:**

```ini
[Unit]
Description=Green Dot Ball Bot Auto-Runner
After=network.target cloud-final.service

[Service]
Type=oneshot
User=ubuntu
WorkingDirectory=/opt/greendotball-bot
Environment="PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true"
Environment="PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium-browser"
ExecStart=/opt/greendotball-bot/run-bot.sh
StandardOutput=journal
StandardError=journal
RemainAfterExit=no

[Install]
WantedBy=multi-user.target
```

```bash
# Enable the service
sudo systemctl daemon-reload
sudo systemctl enable greendotball-bot.service

# Test the service
sudo systemctl start greendotball-bot.service
sudo systemctl status greendotball-bot.service

# View logs
sudo journalctl -u greendotball-bot.service -f
```

---

### Phase 3: Create Custom AMI

#### Step 3.1: Clean Up Instance

```bash
# Clear bash history
history -c
cat /dev/null > ~/.bash_history

# Clear logs
sudo rm -rf /var/log/greendotball-bot/*
sudo rm -rf /opt/greendotball-bot/logs/*

# Clear cache
sudo apt clean
sudo rm -rf /tmp/*
sudo rm -rf /var/tmp/*

# Stop the instance (from AWS Console or CLI)
```

#### Step 3.2: Create AMI

**AWS Console:**
1. Go to EC2 → Instances
2. Select `greendotball-bot-base` instance
3. Actions → Image and templates → Create image
4. Image name: `greendotball-bot-v1`
5. Description: `Green Dot Ball Bot with auto-start - v1.0`
6. No reboot: ✅ (recommended)
7. Create image

**AWS CLI:**
```bash
aws ec2 create-image \
  --instance-id i-xxxxx \
  --name "greendotball-bot-v1" \
  --description "Green Dot Ball Bot with auto-start - v1.0" \
  --no-reboot \
  --region ap-south-1
```

Wait 5-10 minutes for AMI creation to complete.

---

### Phase 4: Launch Instances from AMI

#### Option 1: Launch Single Instance (AWS Console)

1. Go to EC2 → AMIs
2. Select `greendotball-bot-v1`
3. Actions → Launch instance from AMI
4. Instance type: t3.small
5. **Request Spot instances**: ✅ (for cost savings)
6. Storage: 8 GB gp3
7. IAM role: Select role with S3 access
8. Advanced details → User data (optional - for dynamic config):

```bash
#!/bin/bash
# Optional: Override config dynamically
echo "Instance started at $(date)" >> /var/log/startup.log
```

9. Launch instance

**The bot will automatically start running 10 submissions on boot!**

#### Option 2: Launch Multiple Instances (AWS CLI)

```bash
# Launch 10 instances in parallel
aws ec2 run-instances \
  --image-id ami-xxxxx \
  --instance-type t3.small \
  --count 10 \
  --instance-market-options '{"MarketType":"spot","SpotOptions":{"SpotInstanceType":"one-time","InstanceInterruptionBehavior":"terminate"}}' \
  --iam-instance-profile Name=EC2-S3-Access-Role \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=greendotball-bot-worker},{Key=Batch,Value=batch-001}]' \
  --region ap-south-1
```

**Result**: 10 instances launch → Each runs 10 submissions → Total 100 submissions in parallel!

#### Option 3: Launch Template (Recommended for Scaling)

**Create Launch Template:**

```bash
aws ec2 create-launch-template \
  --launch-template-name greendotball-bot-template \
  --version-description "v1.0" \
  --launch-template-data '{
    "ImageId": "ami-xxxxx",
    "InstanceType": "t3.small",
    "IamInstanceProfile": {
      "Name": "EC2-S3-Access-Role"
    },
    "InstanceMarketOptions": {
      "MarketType": "spot",
      "SpotOptions": {
        "SpotInstanceType": "one-time",
        "InstanceInterruptionBehavior": "terminate"
      }
    },
    "TagSpecifications": [{
      "ResourceType": "instance",
      "Tags": [
        {"Key": "Name", "Value": "greendotball-bot-worker"},
        {"Key": "Project", "Value": "greendotball"}
      ]
    }]
  }' \
  --region ap-south-1
```

**Launch from Template:**

```bash
# Launch 1 instance
aws ec2 run-instances \
  --launch-template LaunchTemplateName=greendotball-bot-template \
  --count 1 \
  --region ap-south-1

# Launch 10 instances
aws ec2 run-instances \
  --launch-template LaunchTemplateName=greendotball-bot-template \
  --count 10 \
  --region ap-south-1

# Launch 100 instances
aws ec2 run-instances \
  --launch-template LaunchTemplateName=greendotball-bot-template \
  --count 100 \
  --region ap-south-1
```

---

### Phase 5: Monitoring & Management

#### Monitor Running Instances

```bash
# List running instances
aws ec2 describe-instances \
  --filters "Name=tag:Project,Values=greendotball" "Name=instance-state-name,Values=running" \
  --query 'Reservations[*].Instances[*].[InstanceId,State.Name,LaunchTime]' \
  --output table \
  --region ap-south-1

# Check logs in S3
aws s3 ls s3://greendotball-bot-data/logs/ --recursive
```

#### Download Logs

```bash
# Download all logs
aws s3 sync s3://greendotball-bot-data/logs/ ./local-logs/

# View specific instance log
aws s3 cp s3://greendotball-bot-data/logs/i-xxxxx/20260114_223000.log -
```

#### Terminate Instances

```bash
# Terminate specific instance
aws ec2 terminate-instances --instance-ids i-xxxxx

# Terminate all bot instances
aws ec2 describe-instances \
  --filters "Name=tag:Project,Values=greendotball" "Name=instance-state-name,Values=running" \
  --query 'Reservations[*].Instances[*].InstanceId' \
  --output text | xargs aws ec2 terminate-instances --instance-ids
```

---

## 🚀 Quick Start Guide

### Scenario 1: Run 10 Submissions (1 Instance)

```bash
# Launch 1 instance from template
aws ec2 run-instances \
  --launch-template LaunchTemplateName=greendotball-bot-template \
  --count 1 \
  --region ap-south-1

# Wait 5-10 minutes
# Bot runs automatically
# Check logs in S3
```

**Cost**: ~$0.0004 per run

### Scenario 2: Run 100 Submissions (10 Instances)

```bash
# Launch 10 instances
aws ec2 run-instances \
  --launch-template LaunchTemplateName=greendotball-bot-template \
  --count 10 \
  --region ap-south-1

# Wait 5-10 minutes
# All 10 bots run in parallel
# Check logs in S3
```

**Cost**: ~$0.004 per run

### Scenario 3: Run 1000 Submissions (100 Instances)

```bash
# Launch 100 instances
aws ec2 run-instances \
  --launch-template LaunchTemplateName=greendotball-bot-template \
  --count 100 \
  --region ap-south-1

# Wait 5-10 minutes
# All 100 bots run in parallel
# Check logs in S3
```

**Cost**: ~$0.041 per run

---

## 📊 Cost Breakdown Summary

### One-Time Setup Costs
- AMI Storage: $0.40/month
- S3 Storage: $0.02/month
- **Total**: $0.42/month (~₹35/month)

### Per-Run Costs (Spot Instances)

| Submissions | Instances | Runtime | Cost/Run | Daily (1x) | Monthly (30x) |
|-------------|-----------|---------|----------|------------|---------------|
| 10 | 1 | 4 min | $0.0004 | $0.0004 | $0.012 |
| 100 | 10 | 4 min | $0.004 | $0.004 | $0.12 |
| 1000 | 100 | 4 min | $0.041 | $0.041 | $1.23 |

### Total Monthly Cost

| Daily Submissions | Monthly Cost (USD) | Monthly Cost (INR) |
|-------------------|--------------------|--------------------|
| 10 | $0.43 | ₹36 |
| 100 | $0.54 | ₹45 |
| 1000 | $1.65 | ₹138 |

---

## 🔧 Advanced Features

### Auto-Shutdown After Completion

Enable in `/opt/greendotball-bot/run-bot.sh`:

```bash
# Uncomment this line at the end of the script
sudo shutdown -h now
```

**Benefit**: Instances terminate automatically after bot completes, saving costs!

### Dynamic Configuration via User Data

Pass custom config when launching:

```bash
aws ec2 run-instances \
  --launch-template LaunchTemplateName=greendotball-bot-template \
  --count 1 \
  --user-data '#!/bin/bash
echo "{\"maxSubmissionsPerSession\": 20}" > /opt/greendotball-bot/config/override.json
' \
  --region ap-south-1
```

### Scheduled Launches with EventBridge

Create EventBridge rule to launch instances automatically:

```bash
# Create rule to launch 10 instances daily at 6 AM IST
aws events put-rule \
  --name greendotball-daily-launch \
  --schedule-expression "cron(30 0 * * ? *)" \
  --state ENABLED \
  --region ap-south-1

# Add target (Lambda function to launch EC2 instances)
# Lambda code would call ec2.run_instances()
```

---

## 📝 Deployment Checklist

### Initial Setup (One-time)
- [ ] Launch base EC2 instance (t3.small)
- [ ] Install Node.js, Chrome, AWS CLI
- [ ] Deploy bot code to `/opt/greendotball-bot`
- [ ] Create S3 bucket and upload images/config
- [ ] Test bot manually (`npm run batch`)
- [ ] Create startup script (`run-bot.sh`)
- [ ] Create systemd service
- [ ] Test auto-start (reboot instance)
- [ ] Create custom AMI
- [ ] Create IAM role for S3 access
- [ ] Create launch template

### Daily Operations
- [ ] Launch N instances from template
- [ ] Wait 5-10 minutes for completion
- [ ] Download logs from S3
- [ ] Verify submissions
- [ ] Terminate instances (if not auto-shutdown)

---

## 🎯 Implementation Timeline

| Phase | Duration | Tasks |
|-------|----------|-------|
| **Phase 1** | 1-2 hours | Setup base instance, install dependencies, deploy code |
| **Phase 2** | 30 minutes | Create startup scripts and systemd service |
| **Phase 3** | 30 minutes | Create and test AMI |
| **Phase 4** | 15 minutes | Create launch template |
| **Phase 5** | 15 minutes | Test parallel launches |
| **Total** | **3-4 hours** | Complete setup |

---

## 🔒 Security Best Practices

1. **IAM Role**: Use IAM role instead of hardcoded credentials
2. **Security Group**: Restrict SSH to your IP only
3. **S3 Bucket**: Enable encryption and versioning
4. **Secrets**: Store sensitive data in AWS Secrets Manager
5. **VPC**: Launch instances in private subnet (optional)

---

## 🆘 Troubleshooting

### Bot doesn't start on boot
```bash
# Check service status
sudo systemctl status greendotball-bot.service

# Check logs
sudo journalctl -u greendotball-bot.service -n 50

# Manually run script
sudo /opt/greendotball-bot/run-bot.sh
```

### Chrome crashes
```bash
# Increase memory (use t3.medium instead of t3.small)
# Or add swap space
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
```

### Spot instance terminated
```bash
# Check spot interruption logs
aws ec2 describe-spot-instance-requests --region ap-south-1

# Use on-demand instances for critical runs
# Remove --instance-market-options from launch command
```

---

## 📞 Support & Next Steps

**Ready to Deploy?**

1. Follow Phase 1-3 to create your AMI
2. Create launch template
3. Test with 1 instance
4. Scale to 10, 100, or more instances as needed!

**Need Help?**
- AWS Documentation: https://docs.aws.amazon.com/ec2/
- Puppeteer on EC2: https://github.com/puppeteer/puppeteer/blob/main/docs/troubleshooting.md

**Cost Monitoring:**
- Set up AWS Budgets alert for $5/month
- Monitor with AWS Cost Explorer
- Use Spot instances for 70% cost savings!

---

## 🎉 Summary

**What You Get:**
- ✅ Fully automated EC2 instances that run bot on startup
- ✅ Easy scaling: 1 instance = 10 submissions, 100 instances = 1000 submissions
- ✅ Minimal cost: ~$0.0004 per 10 submissions
- ✅ Logs automatically uploaded to S3
- ✅ Optional auto-shutdown to save costs
- ✅ Launch template for easy replication

**Total Monthly Cost for 1000 submissions/day:**
- **$1.65/month (~₹138/month)** 🎯

This is the most cost-effective solution for your use case!
