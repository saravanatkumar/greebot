# Updating AMI for New Job-Based Bot System

This guide explains how to update the existing AWS AMI to work with the new job-based system.

## Problem

The current AMI template is configured to automatically run the original bot implementation via systemd service on startup. This won't work with our new job-based approach for these reasons:

1. The existing systemd service runs the original bot, not `bot_new.js`
2. The new bot requires a job ID parameter, which needs to be passed from user-data
3. There's no mechanism to sync job files from S3

## Solution

You need to create a new AMI with updated automation scripts to support the job-based approach.

## AMI Update Steps

1. Launch a new EC2 instance from your existing AMI template
2. SSH into the instance
3. Upload the new files from this project
4. Replace the startup scripts with job-based versions
5. Create a new AMI from this updated instance

## Step-by-Step Instructions

### 1. Launch Test Instance

1. Go to **EC2 Console** → **Launch Templates**
2. Select your existing template: `greendotball-bot-template`
3. Click **"Actions"** → **"Launch instance from template"**
4. Set **"Number of instances"** to `1`
5. Launch the instance
6. Wait for it to reach "Running" state

### 2. SSH into the Instance

```bash
ssh -i ~/path/to/greendotball-bot-key.pem ec2-user@<instance-ip>
```

### 3. Upload New Files

From your local machine:

```bash
# Copy new bot file
scp -i ~/path/to/greendotball-bot-key.pem /Users/apple/CascadeProjects/windsurf-project-2/src/bot_new.js ec2-user@<instance-ip>:/opt/greendotball-bot/src/

# Copy new scripts
scp -i ~/path/to/greendotball-bot-key.pem /Users/apple/CascadeProjects/windsurf-project-2/scripts/run-job-bot.sh ec2-user@<instance-ip>:/opt/greendotball-bot/scripts/

# Make sure script directory exists
ssh -i ~/path/to/greendotball-bot-key.pem ec2-user@<instance-ip> "mkdir -p /opt/greendotball-bot/scripts/"

# Make script executable
ssh -i ~/path/to/greendotball-bot-key.pem ec2-user@<instance-ip> "chmod +x /opt/greendotball-bot/scripts/run-job-bot.sh"

# Create jobs directory
ssh -i ~/path/to/greendotball-bot-key.pem ec2-user@<instance-ip> "mkdir -p /opt/greendotball-bot/data/jobs"
```

### 4. Create New Systemd Service

On the EC2 instance:

```bash
# Create new systemd service file
sudo nano /etc/systemd/system/greendotball-job-bot.service
```

Paste the content from `scripts/greendotball-job-bot.service`

```bash
# Reload systemd and enable new service
sudo systemctl daemon-reload
sudo systemctl enable greendotball-job-bot.service

# Disable old service
sudo systemctl disable greendotball-bot.service
```

### 5. Test the Setup

```bash
# Manually set a JOB_ID in user-data simulation file
echo "JOB_ID=job-1" | sudo tee /var/lib/cloud/instance/user-data.txt

# Run the new script manually
sudo /opt/greendotball-bot/scripts/run-job-bot.sh
```

### 6. Create New AMI

1. Return to **EC2 Console**
2. Stop the test instance
3. Select the instance
4. Click **"Actions"** → **"Image and templates"** → **"Create image"**
5. **Image name**: `greendotball-job-bot-amazon-linux-v1`
6. **Image description**: `Green Dot Ball Job Bot on Amazon Linux 2023 with job-based auto-start - v1.0`
7. Create the image
8. Wait for AMI status to become "Available"

### 7. Create New Launch Template

1. Go to **EC2 Console** → **Launch Templates**
2. Click **"Create launch template"**
3. Use settings similar to your existing template, but:
   - **Launch template name**: `greendotball-job-bot-template`
   - Select your new AMI: `greendotball-job-bot-amazon-linux-v1`
   - Include other settings from your existing template

## Using the New System

Now you can launch instances from your new template and pass the job ID via user-data:

1. Go to **EC2 Console** → **Launch Templates**
2. Select: `greendotball-job-bot-template`
3. Click **"Actions"** → **"Launch instance from template"**
4. Expand **"Advanced details"**
5. Scroll down to **"User data"**
6. Enter: `JOB_ID=job-1` (replace with your actual job ID)
7. Launch the instance

The instance will:
1. Start automatically
2. Read the job ID from user-data
3. Download the appropriate job file from S3
4. Process all phone-image pairs in that job
5. Shut down automatically when finished

You can also use the `launch-job-instance.sh` script, which automates this process.
