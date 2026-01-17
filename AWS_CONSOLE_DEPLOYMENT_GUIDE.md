# AWS Console Deployment Guide - Green Dot Ball Bot
## Step-by-Step Manual Setup (No CLI Required)

---

## 🎯 Overview

This guide shows you how to deploy the bot using **only the AWS Console** (web interface).
No command-line experience needed - just follow the screenshots and steps!

**What you'll create:**
- EC2 instance with auto-start bot
- Custom AMI (image) for easy replication
- Launch template to scale to 1-100+ instances
- S3 bucket for images and logs

**Total time:** 2-3 hours
**Monthly cost:** $1-2 for 1000 submissions/day

---

## 📋 Prerequisites

- AWS Account (Free Tier eligible)
- SSH client (PuTTY for Windows, Terminal for Mac/Linux)
- Bot code on your local machine
- Images and phone numbers ready

---

## Phase 1: Setup S3 Bucket (10 minutes)

### Step 1.1: Create S3 Bucket

1. **Login to AWS Console**: https://console.aws.amazon.com
2. **Search for "S3"** in the top search bar
3. Click **"S3"** service
4. Click **"Create bucket"** button (orange)

**Bucket Settings:**
- **Bucket name**: `greendotball-bot-data` (must be globally unique)
- **AWS Region**: `Asia Pacific (Mumbai) ap-south-1`
- **Block Public Access**: Keep all boxes CHECKED ✅
- **Bucket Versioning**: Disabled (optional)
- **Encryption**: Enable (default)
- Click **"Create bucket"** at the bottom

### Step 1.2: Create Folder Structure

1. Click on your bucket name: `greendotball-bot-data`
2. Click **"Create folder"** button
3. Create these folders:
   - Folder name: `images` → Create folder
   - Folder name: `config` → Create folder
   - Folder name: `logs` → Create folder

### Step 1.3: Upload Images

1. Click on the **`images`** folder
2. Click **"Upload"** button
3. Click **"Add files"**
4. Select all your images (img-1.png, img-2.png, etc.)
5. Click **"Upload"** at the bottom
6. Wait for upload to complete
7. Click **"Close"**

### Step 1.4: Upload Config File

1. Go back to bucket (click `greendotball-bot-data` at top)
2. Click on the **`config`** folder
3. Click **"Upload"**
4. Click **"Add files"**
5. Select your `config.json` file
6. Click **"Upload"**
7. Click **"Close"**

✅ **S3 Setup Complete!**

---

## Phase 2: Create IAM Role (5 minutes)

### Step 2.1: Create IAM Role for EC2

1. **Search for "IAM"** in the top search bar
2. Click **"IAM"** service
3. Click **"Roles"** in the left sidebar
4. Click **"Create role"** button (orange)

**Step 1 - Select trusted entity:**
- **Trusted entity type**: AWS service
- **Use case**: EC2
- Click **"Next"**

**Step 2 - Add permissions:**
- In the search box, type: `AmazonS3FullAccess`
- Check the box next to **"AmazonS3FullAccess"**
- Click **"Next"**

**Step 3 - Name and create:**
- **Role name**: `EC2-GreenDotBall-S3-Access`
- **Description**: `Allows EC2 instances to access S3 for bot data`
- Click **"Create role"**

✅ **IAM Role Created!**

---

## Phase 3: Launch EC2 Instance (15 minutes)

### Step 3.1: Launch Instance

1. **Search for "EC2"** in the top search bar
2. Click **"EC2"** service
3. Click **"Launch instance"** button (orange)

### Step 3.2: Configure Instance

**Name and tags:**
- **Name**: `greendotball-bot-base`

**Application and OS Images (AMI):**
- Click **"Quick Start"** tab
- Select **"Amazon Linux"**
- Choose **"Amazon Linux 2023 AMI"** (Free tier eligible)
- Keep default (64-bit x86)

**Instance type:**
- Select **"t3.small"** (2 vCPU, 2 GB RAM)
- Note: t2.micro is free tier but too small for Chrome

**Key pair (login):**
- If you have a key pair: Select it from dropdown
- If you don't have one:
  - Click **"Create new key pair"**
  - Key pair name: `greendotball-bot-key`
  - Key pair type: RSA
  - Private key file format: `.pem` (Mac/Linux) or `.ppk` (Windows/PuTTY)
  - Click **"Create key pair"**
  - **IMPORTANT**: Save the downloaded file safely!

**Network settings:**
- Click **"Edit"** button
- **VPC**: Keep default
- **Subnet**: Keep default (or choose any)
- **Auto-assign public IP**: Enable
- **Firewall (security groups)**: Create security group
  - Security group name: `greendotball-bot-sg`
  - Description: `SSH access for bot management`
  - **Rule 1**: SSH, Port 22, Source: My IP (automatically detects your IP)

**Configure storage:**
- **Size**: 8 GiB
- **Volume type**: gp3
- **Delete on termination**: Yes ✅

**Advanced details:**
- Scroll down to **"IAM instance profile"**
- Select: `EC2-GreenDotBall-S3-Access` (the role you created)
- Leave everything else as default

**Summary:**
- Review your settings
- Click **"Launch instance"** (orange button)

### Step 3.3: Wait for Instance to Start

1. Click **"View all instances"**
2. Wait for **Instance state** to show: `Running` (green)
3. Wait for **Status check** to show: `2/2 checks passed` (green)
4. This takes 2-3 minutes

✅ **EC2 Instance Running!**

---

## Phase 4: Connect and Setup Instance (45 minutes)

### Step 4.1: Get Instance IP Address

1. In EC2 Instances page, select your instance: `greendotball-bot-base`
2. Look at the **Details** tab below
3. Copy the **Public IPv4 address** (e.g., 13.127.45.123)

### Step 4.2: Connect via SSH

**For Mac/Linux:**
```bash
# Open Terminal
cd ~/Downloads  # or wherever you saved the key
chmod 400 greendotball-bot-key.pem
ssh -i greendotball-bot-key.pem ec2-user@13.127.45.123
# Replace with your actual IP address
```

**For Windows (using PuTTY):**
1. Download PuTTY: https://www.putty.org/
2. Open PuTTY
3. Host Name: `ec2-user@13.127.45.123` (your IP)
4. Port: 22
5. Connection → SSH → Auth → Browse → Select your .ppk key file
6. Click "Open"

**First time connection:**
- Type `yes` when asked about fingerprint
- You should see: `[ec2-user@ip-xxx-xxx-xxx-xxx ~]$`

### Step 4.3: Install Dependencies

Copy and paste these commands one by one:

```bash
# Update system
sudo dnf update -y

# Install Node.js
sudo dnf install -y nodejs npm

# Verify Node.js
node --version
npm --version

# Install Chromium and dependencies
sudo dnf install -y chromium liberation-fonts nss atk cups-libs gtk3 \
  libXcomposite libXcursor libXdamage libXext libXi libXrandr \
  libXScrnSaver libXtst pango xdg-utils alsa-lib

# Verify Chrome
google-chrome --version

# Install Git
sudo dnf install -y git

# Set environment variables
echo 'export PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true' >> ~/.bashrc
echo 'export PUPPETEER_EXECUTABLE_PATH=/usr/bin/google-chrome' >> ~/.bashrc
source ~/.bashrc
```

### Step 4.4: Create Application Directory

```bash
# Create directory
sudo mkdir -p /opt/greendotball-bot
sudo chown ec2-user:ec2-user /opt/greendotball-bot
cd /opt/greendotball-bot
```

### Step 4.5: Upload Bot Code

**Option 1: Using SCP (from your local machine)**

Open a NEW terminal/command prompt on your LOCAL machine (not SSH):

```bash
# Mac/Linux
cd /Users/apple/CascadeProjects/windsurf-project-2
scp -i ~/Downloads/greendotball-bot-key.pem -r ./* ec2-user@13.127.45.123:/opt/greendotball-bot/

# Windows (using WinSCP or pscp)
# Download WinSCP: https://winscp.net/
# Use GUI to drag and drop files
```

**Option 2: Using Git (if you have a repo)**

Back in the SSH session:
```bash
cd /opt/greendotball-bot
git clone https://github.com/yourusername/your-repo.git .
```

### Step 4.6: Install Node Dependencies

```bash
cd /opt/greendotball-bot
npm install --production
```

### Step 4.7: Download Data from S3

```bash
# Download images
aws s3 sync s3://greendotball-bot-data/images/ ./data/sample-images/

# Download config
aws s3 cp s3://greendotball-bot-data/config/config.json ./config/config.json

# Verify files
ls -la data/sample-images/
cat config/config.json
```

### Step 4.8: Update Config for Headless Mode

```bash
# Edit config
nano config/config.json

# Find this line:
#   "headless": false,
# Change to:
#   "headless": true,

# Save and exit:
# Press Ctrl+X
# Press Y
# Press Enter
```

### Step 4.9: Test Bot Manually

```bash
cd /opt/greendotball-bot
export PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true
export PUPPETEER_EXECUTABLE_PATH=/usr/bin/google-chrome
npm run batch
```

**Expected output:**
- Bot should run 10 submissions
- You'll see success messages
- Takes about 4-5 minutes

✅ **Bot Works!**

---

## Phase 5: Create Auto-Start Script (20 minutes)

### Step 5.1: Create Runner Script

```bash
sudo nano /opt/greendotball-bot/run-bot.sh
```

**Paste this content:**

```bash
#!/bin/bash
export PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true
export PUPPETEER_EXECUTABLE_PATH=/usr/bin/google-chrome
export HOME=/home/ec2-user
export NODE_ENV=production

LOG_DIR="/var/log/greendotball-bot"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="$LOG_DIR/bot_$TIMESTAMP.log"

sudo mkdir -p $LOG_DIR
sudo chown ec2-user:ec2-user $LOG_DIR

echo "========================================" | tee -a $LOG_FILE
echo "Bot started at $(date)" | tee -a $LOG_FILE
echo "Instance ID: $(ec2-metadata --instance-id | cut -d ' ' -f 2)" | tee -a $LOG_FILE
echo "========================================" | tee -a $LOG_FILE

cd /opt/greendotball-bot

echo "Syncing data from S3..." | tee -a $LOG_FILE
aws s3 sync s3://greendotball-bot-data/images/ ./data/sample-images/ 2>&1 | tee -a $LOG_FILE
aws s3 cp s3://greendotball-bot-data/config/config.json ./config/config.json 2>&1 | tee -a $LOG_FILE

sleep 5

echo "Starting bot execution..." | tee -a $LOG_FILE
npm run batch 2>&1 | tee -a $LOG_FILE

EXIT_CODE=$?
echo "Bot finished with exit code: $EXIT_CODE" | tee -a $LOG_FILE

echo "Uploading logs to S3..." | tee -a $LOG_FILE
INSTANCE_ID=$(ec2-metadata --instance-id | cut -d ' ' -f 2)
aws s3 cp $LOG_FILE "s3://greendotball-bot-data/logs/$INSTANCE_ID/$TIMESTAMP.log" 2>&1 | tee -a $LOG_FILE
aws s3 cp /opt/greendotball-bot/logs/ "s3://greendotball-bot-data/logs/$INSTANCE_ID/" --recursive 2>&1 | tee -a $LOG_FILE

echo "Script completed at $(date)" | tee -a $LOG_FILE

# Auto-shutdown instance after completion
echo "Shutting down instance in 60 seconds..." | tee -a $LOG_FILE
sleep 60
sudo shutdown -h now
```

**Save and exit:**
- Press Ctrl+X
- Press Y
- Press Enter

```bash
# Make executable
sudo chmod +x /opt/greendotball-bot/run-bot.sh

# Test it
/opt/greendotball-bot/run-bot.sh
```

### Step 5.2: Create Systemd Service

```bash
sudo nano /etc/systemd/system/greendotball-bot.service
```

**Paste this content:**

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
Environment="PUPPETEER_EXECUTABLE_PATH=/usr/bin/google-chrome"
Environment="HOME=/home/ec2-user"
ExecStart=/opt/greendotball-bot/run-bot.sh
StandardOutput=journal
StandardError=journal
RemainAfterExit=no

[Install]
WantedBy=multi-user.target
```

**Save and exit:**
- Press Ctrl+X
- Press Y
- Press Enter

```bash
# Enable service
sudo systemctl daemon-reload
sudo systemctl enable greendotball-bot.service

# Test service
sudo systemctl start greendotball-bot.service
sudo systemctl status greendotball-bot.service
```

### Step 5.3: Test Auto-Start on Reboot

```bash
# Reboot instance
sudo reboot
```

**Wait 2-3 minutes, then reconnect:**

```bash
ssh -i greendotball-bot-key.pem ec2-user@13.127.45.123

# Check if bot ran automatically
sudo systemctl status greendotball-bot.service
ls -la /var/log/greendotball-bot/
```

✅ **Auto-start works!**

---

## Phase 6: Create AMI (Image) - AWS Console (10 minutes)

### Step 6.1: Clean Up Instance

In your SSH session:

```bash
# Clear history
history -c
cat /dev/null > ~/.bash_history

# Clear logs
sudo rm -rf /var/log/greendotball-bot/*
sudo rm -rf /opt/greendotball-bot/logs/*

# Clear cache
sudo dnf clean all
sudo rm -rf /tmp/*
sudo rm -rf /var/tmp/*

# Exit SSH
exit
```

### Step 6.2: Stop Instance (AWS Console)

1. Go to **EC2 Console** → **Instances**
2. Select your instance: `greendotball-bot-base`
3. Click **"Instance state"** dropdown (top right)
4. Click **"Stop instance"**
5. Click **"Stop"** in the confirmation dialog
6. Wait for **Instance state** to show: `Stopped` (red)

### Step 6.3: Create AMI (AWS Console)

1. Keep the instance selected: `greendotball-bot-base`
2. Click **"Actions"** dropdown (top)
3. Hover over **"Image and templates"**
4. Click **"Create image"**

**Create Image Settings:**
- **Image name**: `greendotball-bot-amazon-linux-v1`
- **Image description**: `Green Dot Ball Bot on Amazon Linux 2023 with auto-start - v1.0`
- **No reboot**: Leave UNCHECKED (instance is already stopped)
- **Instance volumes**: Keep defaults
- **Tags**: (Optional) Add tags if you want
- Click **"Create image"** (orange button)

### Step 6.4: Wait for AMI Creation

1. Click **"AMIs"** in the left sidebar (under "Images")
2. You'll see your AMI: `greendotball-bot-amazon-linux-v1`
3. **Status** will show: `Pending` (yellow)
4. Wait 5-10 minutes for **Status** to show: `Available` (green)
5. **Copy the AMI ID** (e.g., `ami-0abc123def456789`)

✅ **AMI Created!** You can now launch unlimited instances from this image!

---

## Phase 7: Create Launch Template - AWS Console (10 minutes)

### Step 7.1: Create Launch Template

1. In EC2 Console, click **"Launch Templates"** in left sidebar
2. Click **"Create launch template"** (orange button)

**Launch template name and description:**
- **Launch template name**: `greendotball-bot-template`
- **Template version description**: `v1.0 - Amazon Linux 2023 with auto-start`
- **Auto Scaling guidance**: Leave unchecked

**Application and OS Images (AMI):**
- Click **"My AMIs"** tab
- Click **"Owned by me"**
- Select: `greendotball-bot-amazon-linux-v1` (your AMI)

**Instance type:**
- **Instance type**: `t3.small`

**Key pair (login):**
- **Key pair name**: Select `greendotball-bot-key` (or your key)

**Network settings:**
- **Subnet**: Don't include in launch template
- **Firewall (security groups)**: Select existing security group
  - Select: `greendotball-bot-sg` (or create new with SSH access)

**Configure storage:**
- Keep defaults (8 GiB gp3)

**Resource tags:**
- Click **"Add tag"**
- **Key**: `Name`, **Value**: `greendotball-bot-worker`
- **Key**: `Project`, **Value**: `greendotball`

**Advanced details:**
- Scroll down to **"IAM instance profile"**
- Select: `EC2-GreenDotBall-S3-Access`
- Scroll down to **"Purchasing option"**
- Check: ✅ **"Request Spot Instances"** (for 70% cost savings!)
- Leave other settings as default

**Summary:**
- Review settings
- Click **"Create launch template"** (orange button)

✅ **Launch Template Created!**

---

## Phase 8: Launch Instances from Template (5 minutes)

### Step 8.1: Launch 1 Instance (10 submissions)

1. Go to **EC2 Console** → **Launch Templates**
2. Select: `greendotball-bot-template`
3. Click **"Actions"** → **"Launch instance from template"**

**Number of instances:**
- **Number of instances**: `1`

**Review and launch:**
- Click **"Launch instance"** (orange button)
- Click **"View all instances"**

**Monitor:**
- Wait 2-3 minutes for instance to start
- Bot will automatically run 10 submissions!
- Check logs in S3 after 5-10 minutes

### Step 8.2: Launch 10 Instances (100 submissions)

Same steps as above, but:
- **Number of instances**: `10`

### Step 8.3: Launch 100 Instances (1000 submissions)

Same steps as above, but:
- **Number of instances**: `100`

✅ **Instances Launched!** Bot runs automatically on each instance!

---

## Phase 9: Monitor & Download Logs (5 minutes)

### Step 9.1: Check Running Instances

1. Go to **EC2 Console** → **Instances**
2. You'll see all your running instances
3. Filter by tag: `Project = greendotball`
4. Watch them complete (takes 4-5 minutes per instance)

### Step 9.2: Download Logs from S3

1. Go to **S3 Console**
2. Click on bucket: `greendotball-bot-data`
3. Click on folder: `logs`
4. You'll see folders for each instance (by instance ID)
5. Click on an instance folder
6. Click on a log file
7. Click **"Download"** to download the log

**Or download all logs:**
1. Select the `logs` folder
2. Click **"Actions"** → **"Download as"**
3. Choose location and download

### Step 9.3: Terminate Instances When Done

**Important:** Instances will keep running (and costing money) until you stop them!

1. Go to **EC2 Console** → **Instances**
2. Select all bot instances (check boxes)
3. Click **"Instance state"** → **"Terminate instance"**
4. Click **"Terminate"** in confirmation

**Or enable auto-shutdown:**
- Edit `/opt/greendotball-bot/run-bot.sh` before creating AMI
- Uncomment the `sudo shutdown -h now` line at the end
- Instances will automatically terminate after bot completes!

---

## 🎯 Quick Reference - Daily Usage

### To Run 10 Submissions:
1. EC2 Console → Launch Templates
2. Select `greendotball-bot-template`
3. Actions → Launch instance from template
4. Number of instances: `1`
5. Launch instance
6. Wait 5 minutes
7. Download logs from S3
8. Terminate instance

### To Run 100 Submissions:
- Same as above, but **Number of instances: `10`**

### To Run 1000 Submissions:
- Same as above, but **Number of instances: `100`**

---

## 💰 Cost Summary

### One-Time Setup
- AMI storage: $0.40/month
- S3 storage: $0.02/month

### Per Run (Spot Instances)

| Submissions | Instances | Cost/Run | Daily | Monthly (30x) |
|-------------|-----------|----------|-------|---------------|
| 10 | 1 | $0.0004 | $0.0004 | $0.012 |
| 100 | 10 | $0.004 | $0.004 | $0.12 |
| 1000 | 100 | $0.041 | $0.041 | $1.23 |

**Total for 1000 submissions/day: ~$1.65/month**

---

## 🆘 Troubleshooting

### Bot doesn't run on instance start
1. SSH into instance
2. Run: `sudo systemctl status greendotball-bot.service`
3. Check logs: `sudo journalctl -u greendotball-bot.service -n 50`

### Can't SSH to instance
1. Check security group allows SSH from your IP
2. Verify you're using correct key pair
3. Check instance is in "Running" state

### S3 access denied
1. Verify IAM role is attached to instance
2. Check role has S3 permissions
3. Verify bucket name is correct

### Out of memory errors
1. Use t3.medium instead of t3.small
2. Or add swap space (see troubleshooting in detailed guide)

---

## ✅ Summary

**What you've built:**
- ✅ EC2 instance that auto-runs bot on startup
- ✅ Custom AMI for unlimited replication
- ✅ Launch template for easy scaling
- ✅ S3 bucket for centralized data and logs
- ✅ Spot instances for 70% cost savings

**How to use:**
1. Launch N instances from template (AWS Console)
2. Wait 5-10 minutes
3. Download logs from S3
4. Terminate instances

**Cost:**
- 10 submissions: $0.0004
- 100 submissions: $0.004
- 1000 submissions: $0.041

**No CLI needed - everything done in AWS Console!** 🎉
