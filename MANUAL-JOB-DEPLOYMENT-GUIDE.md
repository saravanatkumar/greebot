# Manual Job Deployment Guide for GreenDotBall

This guide explains how to manually create and run jobs using the new job-based system without relying on systemd or automatic startup.

## 1. Create Job Files

### Step 1.1: Generate Job Files Locally

```bash
# Navigate to the project directory
cd /Users/apple/CascadeProjects/windsurf-project-2

# Run the job creation script
node scripts/create-jobs.js --campaign="TestCampaign" --job-size=50
```

This will:
- Generate job files in `data/jobs/`
- Create a master job file (`masterjob.json`)
- Create individual job files (`job-1.json`, `job-2.json`, etc.)

### Step 1.2: Manually Upload Job Files to S3

```bash
# Create jobs directory in S3 bucket (if it doesn't exist)
aws s3 mb s3://greendotball-bot-data/jobs/

# Upload all job files to S3
aws s3 cp data/jobs/ s3://greendotball-bot-data/jobs/ --recursive
```

## 2. Launch EC2 Instance Manually

### Step 2.1: Launch a Basic EC2 Instance

1. Go to **EC2 Console** → **Instances** → **Launch instances**
2. **Name and tags**: `greendotball-manual-job-instance`
3. **Application and OS Images**: Amazon Linux 2023 AMI
4. **Instance type**: `t3.small`
5. **Key pair**: Your existing key pair (e.g., `greendotball-bot-key-v2`)
6. **Network settings**: Use existing security group `greendotball-bot-sg`
7. **Configure storage**: 8GB gp3
8. **Advanced details**:
   - **IAM instance profile**: `EC2-GreenDotBall-S3-Access`
9. Click **Launch instance**

### Step 2.2: Connect to the Instance

```bash
# SSH into the instance (replace with your actual instance IP)
ssh -i path/to/your-key.pem ec2-user@your-instance-ip
```

### Step 2.3: Install Required Packages

```bash
# Update system
sudo dnf update -y

# Install Node.js
sudo dnf install -y nodejs npm

# Install Chrome dependencies
sudo dnf install -y liberation-fonts nss atk cups-libs gtk3 \
  libXcomposite libXcursor libXdamage libXext libXi libXrandr \
  libXScrnSaver libXtst pango xdg-utils alsa-lib

# Install Google Chrome (Amazon Linux 2023 does not have chromium in default repos)
curl -O https://dl.google.com/linux/direct/google-chrome-stable_current_x86_64.rpm
sudo dnf install -y ./google-chrome-stable_current_x86_64.rpm
rm -f google-chrome-stable_current_x86_64.rpm

# Verify Chrome installation
google-chrome --version

# Install Git
sudo dnf install -y git

# Set environment variables
echo 'export PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true' >> ~/.bashrc
echo 'export PUPPETEER_EXECUTABLE_PATH=/usr/bin/google-chrome' >> ~/.bashrc
source ~/.bashrc
```

## 3. Setup the Project on EC2

### Step 3.1: Clone the Repository

```bash
# Create project directory
sudo mkdir -p /opt/greendotball-bot
sudo chown ec2-user:ec2-user /opt/greendotball-bot
cd /opt/greendotball-bot

# Clone your git repository (if using git)
git clone https://github.com/saravanatkumar/greebot.git .

# OR manually copy files from your local machine
# (Run this on your local machine, not on EC2)
scp -i path/to/key.pem -r /Users/apple/CascadeProjects/windsurf-project-2/* ec2-user@your-instance-ip:/opt/greendotball-bot/
```

### Step 3.2: Install Dependencies

```bash
# Navigate to project directory
cd /opt/greendotball-bot

# Install Node.js dependencies
npm install --production
```

## 4. Download Job Files from S3

```bash
# Create data directories
mkdir -p /opt/greendotball-bot/data/jobs
mkdir -p /opt/greendotball-bot/data/images

# Download job files from S3
aws s3 sync s3://greendotball-bot-data/jobs/ /opt/greendotball-bot/data/jobs/

# Download images from S3
aws s3 sync s3://greendotball-bot-data/images/ /opt/greendotball-bot/data/images/

# Download config file from S3
aws s3 cp s3://greendotball-bot-data/config/config.json /opt/greendotball-bot/config/config.json
```

## 5. Run the Bot Manually with Job ID

```bash
# Navigate to project directory
cd /opt/greendotball-bot

# Run the bot with a specific job ID
node src/bot_new.js --job-id job-1

# To redirect output to log file
node src/bot_new.js --job-id job-1 > job-1-output.log 2>&1
```

## 6. View Results

```bash
# Check the output logs
cat job-1-output.log

# Check local logs directory for any generated logs
ls -la logs/
```

## 7. Upload Results to S3 (Optional)

```bash
# Create a results directory in S3 (if it doesn't exist)
aws s3 mb s3://greendotball-bot-data/results/

# Upload results to S3
aws s3 cp job-1-output.log s3://greendotball-bot-data/results/job-1-output.log

# Upload logs directory to S3
aws s3 cp logs/ s3://greendotball-bot-data/results/logs/ --recursive
```

## 8. Testing Multiple Jobs

To test multiple jobs sequentially:

```bash
# Run jobs one after another
for job_id in job-1 job-2 job-3; do
  echo "Running $job_id..."
  node src/bot_new.js --job-id $job_id > $job_id-output.log 2>&1
  echo "$job_id completed"
done
```

## 9. Monitoring Job Progress

To monitor job progress in real-time:

```bash
# Follow the log output in real-time
tail -f job-1-output.log

# Check CPU and memory usage
top -u ec2-user
```

## 10. Troubleshooting

### Common Issues:

1. **Image not found errors**:
   - Verify the image paths in job files match the actual image locations
   - Check that the images are downloaded correctly from S3

2. **S3 permission issues**:
   - Verify that your EC2 instance has the correct IAM role (`EC2-GreenDotBall-S3-Access`)

3. **Browser-related errors**:
   - If you see Chrome/Puppeteer related errors, try:
     ```bash
     # Verify Chrome installation
     which google-chrome
     google-chrome --version
     
     # Update Puppeteer executable path if needed
     export PUPPETEER_EXECUTABLE_PATH=/usr/bin/google-chrome
     ```

4. **Job file not found**:
   - Verify that the job ID exists in the masterjob.json file
   - Check that the job file exists in /opt/greendotball-bot/data/jobs/
