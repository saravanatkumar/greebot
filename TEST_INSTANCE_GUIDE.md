# Test Instance Quick Guide

## Purpose
Launch a single EC2 test instance for:
- Creating campaigns
- Testing bot functionality
- Manual campaign launches
- Debugging

## Launch Test Instance

```bash
./scripts/launch-test-instance.sh
```

The script will:
1. ✅ Use existing AMI: `ami-069329948418953db`
2. ✅ Launch t3.small instance
3. ✅ Disable auto-shutdown (manual control)
4. ✅ Disable auto-start service
5. ✅ Provide SSH connection details

## Connect to Instance

After launch, you'll get the SSH command:

```bash
ssh -i ~/.ssh/greendotball-bot-key-v2.pem ec2-user@<PUBLIC_IP>
```

## Common Tasks on Test Instance

### 1. Create a Campaign

```bash
# Navigate to bot directory
cd /opt/greendotball-bot

# Pull latest code (if needed)
git pull origin design-rethink

# Create campaign with 20 images per job
./scripts/create-campaign-pool-20img.sh

# Or create campaign with custom settings
./scripts/create-campaign-pool.sh
```

### 2. List Campaigns in S3

```bash
# List all campaigns
aws s3 ls s3://greendotball-bot-data/campaigns/

# List jobs in a campaign
aws s3 ls s3://greendotball-bot-data/campaigns/apr-04-2026-pool-120055/jobs/

# View a specific job file
aws s3 cp s3://greendotball-bot-data/campaigns/apr-04-2026-pool-120055/jobs/job-001.json - | jq
```

### 3. Test Run a Job Manually

```bash
cd /opt/greendotball-bot

# Set environment variables
export CAMPAIGN_ID=apr-04-2026-pool-120055
export JOB_IDS=job-001

# Run the bot
node src/bot_new.js
```

### 4. Launch Campaign from Server

Once you've created a campaign on the test instance, launch it from your **local machine**:

```bash
# Set campaign details
export CAMPAIGN_ID="apr-04-2026-pool-120055"
export JOB_IDS="job-001,job-002,job-003"

# Launch instances for all jobs
./scripts/launch-campaign-instances.sh
```

Or pass as arguments:

```bash
./scripts/launch-campaign-instances.sh apr-04-2026-pool-120055 job-001,job-002,job-003
```

### 5. Monitor Campaign Progress

```bash
# Check running instances
aws ec2 describe-instances \
  --region ap-south-1 \
  --filters "Name=tag:CampaignId,Values=apr-04-2026-pool-120055" \
  --query 'Reservations[*].Instances[*].[InstanceId,Tags[?Key==`Name`].Value|[0],State.Name]' \
  --output table

# Check S3 logs
aws s3 ls s3://greendotball-bot-data/campaigns/apr-04-2026-pool-120055/logs/ --recursive

# Check S3 results
aws s3 ls s3://greendotball-bot-data/campaigns/apr-04-2026-pool-120055/results/ --recursive
```

### 6. Download Campaign Results

```bash
# Download all logs
aws s3 sync s3://greendotball-bot-data/campaigns/apr-04-2026-pool-120055/logs/ ./local-logs/

# Download all results
aws s3 sync s3://greendotball-bot-data/campaigns/apr-04-2026-pool-120055/results/ ./local-results/
```

## Terminate Test Instance

**IMPORTANT:** The test instance will NOT auto-shutdown. You must manually terminate it:

```bash
# From your local machine
aws ec2 terminate-instances --region ap-south-1 --instance-ids i-xxxxxxxxxxxxxxxxx
```

Or from AWS Console:
1. Go to EC2 → Instances
2. Select the test instance
3. Instance state → Terminate instance

## Typical Workflow

### Option 1: Create Campaign on Test Instance, Launch from Local

1. **Launch test instance** (local machine):
   ```bash
   ./scripts/launch-test-instance.sh
   ```

2. **SSH to test instance**:
   ```bash
   ssh -i ~/.ssh/greendotball-bot-key-v2.pem ec2-user@<IP>
   ```

3. **Create campaign** (on test instance):
   ```bash
   cd /opt/greendotball-bot
   ./scripts/create-campaign-pool-20img.sh
   # Note the CAMPAIGN_ID from output
   ```

4. **Launch campaign** (local machine):
   ```bash
   export CAMPAIGN_ID="apr-04-2026-pool-120055"
   export JOB_IDS="job-001,job-002,job-003"
   ./scripts/launch-campaign-instances.sh
   ```

5. **Monitor progress** (local machine):
   ```bash
   # Check instances
   aws ec2 describe-instances --region ap-south-1 \
     --filters "Name=tag:CampaignId,Values=apr-04-2026-pool-120055" \
     --query 'Reservations[*].Instances[*].[InstanceId,State.Name]' \
     --output table
   
   # Check logs
   aws s3 ls s3://greendotball-bot-data/campaigns/apr-04-2026-pool-120055/logs/ --recursive
   ```

6. **Terminate test instance** (local machine):
   ```bash
   aws ec2 terminate-instances --region ap-south-1 --instance-ids i-xxxxxxxxxxxxxxxxx
   ```

### Option 2: Create and Launch Campaign from Local

1. **Create campaign locally**:
   ```bash
   cd /Users/apple/CascadeProjects/windsurf-project-2
   ./scripts/create-campaign-pool-20img.sh
   ```

2. **Launch campaign**:
   ```bash
   export CAMPAIGN_ID="apr-04-2026-pool-120055"
   export JOB_IDS="job-001,job-002,job-003"
   ./scripts/launch-campaign-instances.sh
   ```

3. **Monitor** (same as above)

## Cost Considerations

- **Test instance**: ~$0.0062/hour (t3.small spot) = ~$0.15/day if left running
- **Campaign instances**: Auto-shutdown after 55 minutes
- **Remember to terminate** the test instance when done!

## Troubleshooting

### Can't SSH to instance
```bash
# Check instance is running
aws ec2 describe-instances --region ap-south-1 \
  --filters "Name=tag:Name,Values=greendotball-test-instance" \
  --query 'Reservations[*].Instances[*].[InstanceId,State.Name,PublicIpAddress]' \
  --output table

# Check security group allows your IP
aws ec2 describe-security-groups --region ap-south-1 \
  --filters "Name=group-name,Values=greendotball-bot-sg" \
  --query 'SecurityGroups[*].IpPermissions[*]'
```

### Bot not working on test instance
```bash
# Check service status
sudo systemctl status greendotball-job-bot.service

# Check logs
sudo journalctl -u greendotball-job-bot.service -n 50

# Manually run bot
cd /opt/greendotball-bot
export PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true
export PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium-browser
npm run batch
```

### S3 access issues
```bash
# Check IAM role
aws sts get-caller-identity

# Test S3 access
aws s3 ls s3://greendotball-bot-data/
```

## Summary

✅ **Test instance** = Manual control, no auto-shutdown  
✅ **Campaign instances** = Auto-shutdown after 55 min  
✅ **Create campaigns** = On test instance or locally  
✅ **Launch campaigns** = From local machine  
✅ **Monitor** = AWS CLI or Console  
✅ **Remember** = Terminate test instance when done!
