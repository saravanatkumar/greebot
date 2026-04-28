# Campaign Launch Guide - Step-by-Step

This guide walks you through launching a new GreenDotBall campaign from start to finish.

---

## 📋 Prerequisites Checklist

Before starting a campaign, ensure you have:

- [ ] AWS credentials configured (`aws configure`)
- [ ] S3 bucket `greendotball-bot-data` exists
- [ ] IAM roles configured (EC2, Lambda, Step Functions)
- [ ] Phone numbers file prepared
- [ ] Images collected and ready
- [ ] Node.js 16+ installed
- [ ] Project dependencies installed (`npm install`)

---

## 🚀 Campaign Launch Process

### Step 1: Create Campaign Directory Structure

```bash
# Set your campaign ID (use descriptive names with dates)
export CAMPAIGN_ID="campaign-apr22-2026"

# Create local campaign directory
mkdir -p data/campaigns/${CAMPAIGN_ID}/{phones,images,jobs,results}

echo "✓ Campaign directory created: data/campaigns/${CAMPAIGN_ID}"
```

---

### Step 2: Prepare Phone Numbers

**Option A: Use Existing Phone Numbers**

```bash
# Copy from master phone list
cp data/masterPhone.txt data/campaigns/${CAMPAIGN_ID}/phones/phones.txt

# Or copy from specific batch
cp data/phone_batch_1.txt data/campaigns/${CAMPAIGN_ID}/phones/phones.txt
```

**Option B: Create New Phone Number List**

```bash
# Create new phone numbers file
nano data/campaigns/${CAMPAIGN_ID}/phones/phones.txt
```

**Format:** One phone number per line (10 digits, no spaces or special characters)
```
9876543210
9876543211
9876543212
9876543213
```

**Validate Phone Numbers:**
```bash
# Check format (should only show valid 10-digit numbers)
grep -E '^[0-9]{10}$' data/campaigns/${CAMPAIGN_ID}/phones/phones.txt

# Count total phone numbers
wc -l data/campaigns/${CAMPAIGN_ID}/phones/phones.txt

# Check for duplicates
sort data/campaigns/${CAMPAIGN_ID}/phones/phones.txt | uniq -d
```

**Split into Batches (Optional - for large campaigns):**
```bash
# Split into batches of 240 numbers each
python scripts/split_phones.py data/campaigns/${CAMPAIGN_ID}/phones/phones.txt 240

# This creates: phone_batch_1.txt, phone_batch_2.txt, etc.
```

---

### Step 3: Prepare Images

**Option A: Copy Existing Images**

```bash
# Copy all images from main pool
cp data/images/*.jpg data/campaigns/${CAMPAIGN_ID}/images/

# Or copy specific images
cp data/images/image-{1..20}.jpg data/campaigns/${CAMPAIGN_ID}/images/
```

**Option B: Add New Images**

```bash
# Copy from your local directory
cp ~/Downloads/campaign-images/*.jpg data/campaigns/${CAMPAIGN_ID}/images/

# Or download from URL
cd data/campaigns/${CAMPAIGN_ID}/images/
curl -O https://example.com/image1.jpg
curl -O https://example.com/image2.jpg
```

**Validate Images:**
```bash
# Check image count
ls -1 data/campaigns/${CAMPAIGN_ID}/images/ | wc -l

# Verify image formats
file data/campaigns/${CAMPAIGN_ID}/images/*

# Check image sizes (should be < 10MB each)
du -h data/campaigns/${CAMPAIGN_ID}/images/*

# Rename images to sequential format (optional)
cd data/campaigns/${CAMPAIGN_ID}/images/
./scripts/rename-images.sh
```

**Recommended Image Setup:**
- Minimum: 10 images
- Recommended: 20-50 images
- Maximum: 100+ images
- Formats: JPG, PNG, GIF, WEBP
- Size: < 10MB per image

---

### Step 4: Upload Data to S3

```bash
# Upload phone numbers
aws s3 cp data/campaigns/${CAMPAIGN_ID}/phones/phones.txt \
  s3://greendotball-bot-data/campaigns/${CAMPAIGN_ID}/phones.txt

# Upload images
aws s3 sync data/campaigns/${CAMPAIGN_ID}/images/ \
  s3://greendotball-bot-data/campaigns/${CAMPAIGN_ID}/images/

# Verify uploads
aws s3 ls s3://greendotball-bot-data/campaigns/${CAMPAIGN_ID}/

echo "✓ Data uploaded to S3"
```

**Verify Upload:**
```bash
# Check phone numbers file
aws s3 ls s3://greendotball-bot-data/campaigns/${CAMPAIGN_ID}/phones.txt

# Count images uploaded
aws s3 ls s3://greendotball-bot-data/campaigns/${CAMPAIGN_ID}/images/ | wc -l

# Check total size
aws s3 ls s3://greendotball-bot-data/campaigns/${CAMPAIGN_ID}/ --recursive --human-readable --summarize
```

---

### Step 5: Create Job Files

Job files assign specific phone numbers and images to each worker.

**Option A: Standard Job Creation (1 phone = 1 job with all images)**

```bash
# Create jobs using the script
node scripts/create-jobs.js --campaign ${CAMPAIGN_ID}

# This creates job files in S3:
# s3://greendotball-bot-data/campaigns/${CAMPAIGN_ID}/jobs/job-001.json
# s3://greendotball-bot-data/campaigns/${CAMPAIGN_ID}/jobs/job-002.json
# etc.
```

**Option B: Image Pool Jobs (1 phone = 1 job with 20 random images)**

```bash
# Create campaign with 20 random images per job
./scripts/create-campaign-pool-20img.sh ${CAMPAIGN_ID}

# This is more efficient for large image sets
```

**Verify Job Creation:**
```bash
# List all job files
aws s3 ls s3://greendotball-bot-data/campaigns/${CAMPAIGN_ID}/jobs/

# Count total jobs
aws s3 ls s3://greendotball-bot-data/campaigns/${CAMPAIGN_ID}/jobs/ | wc -l

# View a sample job file
aws s3 cp s3://greendotball-bot-data/campaigns/${CAMPAIGN_ID}/jobs/job-001.json - | jq .
```

**Job File Format:**
```json
{
  "jobId": "job-001",
  "campaignId": "campaign-apr22-2026",
  "phoneNumber": "9876543210",
  "images": [
    "s3://greendotball-bot-data/campaigns/campaign-apr22-2026/images/image1.jpg",
    "s3://greendotball-bot-data/campaigns/campaign-apr22-2026/images/image2.jpg"
  ]
}
```

---

### Step 6: Choose Deployment Method

You have three deployment options:

#### **Option A: EC2 Wave Deployment (Recommended for Large Campaigns)**

**Best for:**
- 100+ phone numbers
- Cost-sensitive campaigns
- Controlled resource usage

**Launch:**
```bash
# Launch in waves (20 instances per wave, 5-minute delay)
./scripts/launch-campaign-waves.sh ${CAMPAIGN_ID} 20 5

# Arguments:
# - campaign-id: Your campaign ID
# - instances-per-wave: Number of instances per wave (default: 20)
# - delay-minutes: Minutes between waves (default: 5)
```

**Monitor:**
```bash
# Watch wave progress
./scripts/monitor-wave-progress.sh ${CAMPAIGN_ID}

# Check running instances
aws ec2 describe-instances --region ap-south-1 \
  --filters "Name=tag:Campaign,Values=${CAMPAIGN_ID}" \
  "Name=instance-state-name,Values=running" \
  --query 'Reservations[].Instances[].{ID:InstanceId,State:State.Name,Name:Tags[?Key==`Name`].Value|[0]}'
```

---

#### **Option B: EC2 Direct Launch (For Small Campaigns)**

**Best for:**
- < 50 phone numbers
- Quick testing
- Immediate results

**Launch:**
```bash
# Launch all instances at once
./scripts/launch-campaign-instances.sh ${CAMPAIGN_ID}

# This launches one EC2 instance per job
```

**Monitor:**
```bash
# Check instance status
aws ec2 describe-instances --region ap-south-1 \
  --filters "Name=tag:Campaign,Values=${CAMPAIGN_ID}" \
  --query 'Reservations[].Instances[].[InstanceId,State.Name,Tags[?Key==`Name`].Value|[0]]' \
  --output table
```

---

#### **Option C: Serverless (Step Functions + ECS Fargate)**

**Best for:**
- No instance management
- Auto-scaling needs
- Production deployments

**Prerequisites:**
```bash
# Ensure Docker image is built and pushed to ECR
cd docker/
docker build -t greendotball-bot .
docker tag greendotball-bot:latest <AWS_ACCOUNT_ID>.dkr.ecr.ap-south-1.amazonaws.com/greendotball-bot:latest
docker push <AWS_ACCOUNT_ID>.dkr.ecr.ap-south-1.amazonaws.com/greendotball-bot:latest
```

**Launch:**
```bash
# Trigger Step Functions workflow
aws stepfunctions start-execution \
  --state-machine-arn arn:aws:states:ap-south-1:<ACCOUNT_ID>:stateMachine:CampaignOrchestrator \
  --name "${CAMPAIGN_ID}-execution-$(date +%s)" \
  --input "{\"campaignId\": \"${CAMPAIGN_ID}\"}"

# Save execution ARN
export EXECUTION_ARN="<execution-arn-from-output>"
```

**Monitor:**
```bash
# Check execution status
aws stepfunctions describe-execution --execution-arn ${EXECUTION_ARN}

# View execution history
aws stepfunctions get-execution-history --execution-arn ${EXECUTION_ARN}

# Check ECS tasks
aws ecs list-tasks --cluster greendotball-cluster
```

---

### Step 7: Monitor Campaign Progress

**Real-time Monitoring:**

```bash
# Option 1: Use monitoring script
./scripts/monitor-wave-progress.sh ${CAMPAIGN_ID}

# Option 2: Check EC2 instances
watch -n 30 'aws ec2 describe-instances --region ap-south-1 \
  --filters "Name=tag:Campaign,Values='${CAMPAIGN_ID}'" \
  --query "Reservations[].Instances[].[InstanceId,State.Name]" \
  --output table'

# Option 3: Check S3 results
watch -n 60 'aws s3 ls s3://greendotball-bot-data/campaigns/'${CAMPAIGN_ID}'/results/ | wc -l'
```

**Dashboard Monitoring:**

```bash
# Sync latest data to dashboard
node scripts/sync-dashboard-data.js

# Open dashboard in browser
open website/greendotball/dashboard.html

# Or deploy to S3 and access via URL
./scripts/deploy-dashboard.sh
```

**Check Logs:**

```bash
# View CloudWatch logs (for Lambda/ECS)
aws logs tail /aws/lambda/start-campaign --follow

# Download EC2 instance logs from S3
aws s3 sync s3://greendotball-bot-data/campaigns/${CAMPAIGN_ID}/logs/ ./logs/${CAMPAIGN_ID}/

# View specific instance log
aws s3 cp s3://greendotball-bot-data/campaigns/${CAMPAIGN_ID}/logs/instance-i-1234567890.log -
```

**Check Results:**

```bash
# List result files
aws s3 ls s3://greendotball-bot-data/campaigns/${CAMPAIGN_ID}/results/

# Download all results
aws s3 sync s3://greendotball-bot-data/campaigns/${CAMPAIGN_ID}/results/ \
  ./data/campaigns/${CAMPAIGN_ID}/results/

# View a sample result
aws s3 cp s3://greendotball-bot-data/campaigns/${CAMPAIGN_ID}/results/job-001-result.json - | jq .
```

---

### Step 8: Track Campaign Metrics

**Calculate Success Rate:**

```bash
# Download all results
aws s3 sync s3://greendotball-bot-data/campaigns/${CAMPAIGN_ID}/results/ \
  ./data/campaigns/${CAMPAIGN_ID}/results/

# Count successful submissions
grep -r '"status":"success"' ./data/campaigns/${CAMPAIGN_ID}/results/ | wc -l

# Count failed submissions
grep -r '"status":"failed"' ./data/campaigns/${CAMPAIGN_ID}/results/ | wc -l

# Generate summary report
node scripts/generate-campaign-report.js ${CAMPAIGN_ID}
```

**Key Metrics to Track:**
- Total jobs created
- Jobs completed
- Successful submissions
- Failed submissions
- Success rate (%)
- Average time per submission
- Total campaign duration
- Cost per submission

---

### Step 9: Handle Issues (If Any)

**Common Issues:**

**1. Instance Not Starting:**
```bash
# Check instance status
aws ec2 describe-instances --instance-ids i-1234567890

# View instance system log
aws ec2 get-console-output --instance-id i-1234567890

# Check IAM role
aws iam get-role --role-name EC2-GreenDotBall-S3-Access
```

**2. Job Failures:**
```bash
# Find failed jobs
aws s3 ls s3://greendotball-bot-data/campaigns/${CAMPAIGN_ID}/results/ | grep failed

# Download failed job logs
aws s3 cp s3://greendotball-bot-data/campaigns/${CAMPAIGN_ID}/logs/job-001-error.log -

# Retry failed jobs
./scripts/retry-failed-jobs.sh ${CAMPAIGN_ID}
```

**3. Slow Progress:**
```bash
# Check running instances
aws ec2 describe-instances --region ap-south-1 \
  --filters "Name=tag:Campaign,Values=${CAMPAIGN_ID}" \
  "Name=instance-state-name,Values=running" | jq '.Reservations[].Instances | length'

# Launch additional instances if needed
./scripts/launch-campaign-waves.sh ${CAMPAIGN_ID} 10 2
```

**4. High Costs:**
```bash
# Check current costs
aws ce get-cost-and-usage \
  --time-period Start=2026-04-22,End=2026-04-23 \
  --granularity DAILY \
  --metrics BlendedCost

# Terminate unnecessary instances
./scripts/terminate-instances.sh ${CAMPAIGN_ID}

# Switch to Spot Instances for cost savings
# (Edit launch script to use Spot)
```

---

### Step 10: Campaign Completion & Cleanup

**Wait for Completion:**

```bash
# Check if all jobs are complete
TOTAL_JOBS=$(aws s3 ls s3://greendotball-bot-data/campaigns/${CAMPAIGN_ID}/jobs/ | wc -l)
COMPLETED_JOBS=$(aws s3 ls s3://greendotball-bot-data/campaigns/${CAMPAIGN_ID}/results/ | wc -l)

echo "Progress: ${COMPLETED_JOBS}/${TOTAL_JOBS} jobs completed"

# Wait for all jobs to complete
while [ ${COMPLETED_JOBS} -lt ${TOTAL_JOBS} ]; do
  sleep 60
  COMPLETED_JOBS=$(aws s3 ls s3://greendotball-bot-data/campaigns/${CAMPAIGN_ID}/results/ | wc -l)
  echo "Progress: ${COMPLETED_JOBS}/${TOTAL_JOBS} jobs completed"
done

echo "✓ Campaign completed!"
```

**Generate Final Report:**

```bash
# Download all results
aws s3 sync s3://greendotball-bot-data/campaigns/${CAMPAIGN_ID}/results/ \
  ./data/campaigns/${CAMPAIGN_ID}/results/

# Generate comprehensive report
node scripts/generate-campaign-report.js ${CAMPAIGN_ID}

# View report
cat ./data/campaigns/${CAMPAIGN_ID}/campaign-report.txt
```

**Cleanup Resources:**

```bash
# Terminate all EC2 instances
./scripts/terminate-instances.sh ${CAMPAIGN_ID}

# Verify all instances are terminated
aws ec2 describe-instances --region ap-south-1 \
  --filters "Name=tag:Campaign,Values=${CAMPAIGN_ID}" \
  --query 'Reservations[].Instances[].[InstanceId,State.Name]' \
  --output table

# Optional: Archive campaign data
aws s3 sync s3://greendotball-bot-data/campaigns/${CAMPAIGN_ID}/ \
  s3://greendotball-bot-data/archive/${CAMPAIGN_ID}/

# Optional: Delete campaign data (if no longer needed)
# aws s3 rm s3://greendotball-bot-data/campaigns/${CAMPAIGN_ID}/ --recursive
```

**Backup Results:**

```bash
# Create local backup
mkdir -p backups/${CAMPAIGN_ID}
aws s3 sync s3://greendotball-bot-data/campaigns/${CAMPAIGN_ID}/ \
  backups/${CAMPAIGN_ID}/

# Compress backup
tar -czf backups/${CAMPAIGN_ID}.tar.gz backups/${CAMPAIGN_ID}/

echo "✓ Backup created: backups/${CAMPAIGN_ID}.tar.gz"
```

---

## 📊 Campaign Size Examples

### Small Campaign (Testing)
- **Phone Numbers:** 10
- **Images:** 5
- **Total Submissions:** 50
- **Deployment:** EC2 Direct Launch
- **Duration:** ~15 minutes
- **Cost:** ~$0.10

```bash
export CAMPAIGN_ID="test-campaign-small"
# Follow steps 1-10 with 10 phones, 5 images
./scripts/launch-campaign-instances.sh ${CAMPAIGN_ID}
```

---

### Medium Campaign
- **Phone Numbers:** 100
- **Images:** 20
- **Total Submissions:** 2,000
- **Deployment:** EC2 Wave (20 per wave)
- **Duration:** ~1-2 hours
- **Cost:** ~$2-3

```bash
export CAMPAIGN_ID="campaign-medium-apr22"
# Follow steps 1-10 with 100 phones, 20 images
./scripts/launch-campaign-waves.sh ${CAMPAIGN_ID} 20 5
```

---

### Large Campaign
- **Phone Numbers:** 1,000
- **Images:** 50
- **Total Submissions:** 50,000
- **Deployment:** EC2 Wave (50 per wave) or Serverless
- **Duration:** ~4-6 hours
- **Cost:** ~$15-25

```bash
export CAMPAIGN_ID="campaign-large-apr22"
# Follow steps 1-10 with 1000 phones, 50 images
./scripts/launch-campaign-waves.sh ${CAMPAIGN_ID} 50 10
```

---

### Enterprise Campaign
- **Phone Numbers:** 5,000
- **Images:** 100
- **Total Submissions:** 500,000
- **Deployment:** Serverless (Step Functions + ECS Fargate)
- **Duration:** ~8-12 hours
- **Cost:** ~$50-80

```bash
export CAMPAIGN_ID="campaign-enterprise-apr22"
# Follow steps 1-10 with 5000 phones, 100 images
# Use serverless deployment (Step Functions)
```

---

## 🔍 Quick Reference Commands

```bash
# Set campaign ID
export CAMPAIGN_ID="your-campaign-id"

# Create campaign structure
mkdir -p data/campaigns/${CAMPAIGN_ID}/{phones,images,jobs,results}

# Upload to S3
aws s3 cp data/campaigns/${CAMPAIGN_ID}/phones/phones.txt s3://greendotball-bot-data/campaigns/${CAMPAIGN_ID}/phones.txt
aws s3 sync data/campaigns/${CAMPAIGN_ID}/images/ s3://greendotball-bot-data/campaigns/${CAMPAIGN_ID}/images/

# Create jobs
node scripts/create-jobs.js --campaign ${CAMPAIGN_ID}

# Launch campaign (choose one)
./scripts/launch-campaign-waves.sh ${CAMPAIGN_ID} 20 5          # Wave deployment
./scripts/launch-campaign-instances.sh ${CAMPAIGN_ID}           # Direct launch
aws stepfunctions start-execution --state-machine-arn <ARN> ... # Serverless

# Monitor
./scripts/monitor-wave-progress.sh ${CAMPAIGN_ID}

# Check results
aws s3 ls s3://greendotball-bot-data/campaigns/${CAMPAIGN_ID}/results/

# Cleanup
./scripts/terminate-instances.sh ${CAMPAIGN_ID}
```

---

## ✅ Pre-Launch Checklist

Before launching your campaign, verify:

- [ ] Campaign ID is unique and descriptive
- [ ] Phone numbers file is formatted correctly (10 digits, one per line)
- [ ] No duplicate phone numbers
- [ ] Images are valid format (JPG, PNG, GIF, WEBP)
- [ ] Images are < 10MB each
- [ ] Data uploaded to S3 successfully
- [ ] Job files created successfully
- [ ] AWS credentials are configured
- [ ] IAM roles have correct permissions
- [ ] S3 bucket exists and is accessible
- [ ] Sufficient AWS service limits (EC2 instances, ECS tasks)
- [ ] Budget allocated for campaign costs
- [ ] Monitoring tools ready (dashboard, scripts)

---

## 🚨 Emergency Procedures

**Stop Campaign Immediately:**
```bash
# Emergency stop all instances
./scripts/emergency-stop-waves.sh

# Or force terminate all
./scripts/force-terminate-all.sh ${CAMPAIGN_ID}
```

**Pause Campaign:**
```bash
# Stop launching new waves (Ctrl+C the launch script)
# Existing instances will continue

# Or stop Step Functions execution
aws stepfunctions stop-execution --execution-arn ${EXECUTION_ARN}
```

**Resume Campaign:**
```bash
# Check which jobs are incomplete
node scripts/find-incomplete-jobs.js ${CAMPAIGN_ID}

# Launch instances for incomplete jobs only
./scripts/resume-campaign.sh ${CAMPAIGN_ID}
```

---

## 📞 Support & Troubleshooting

**Check Documentation:**
- `DEVELOPER_README.md` - Complete developer guide
- `AWS_DEPLOYMENT_PLAN.md` - AWS setup details
- `WAVE_ORCHESTRATION_GUIDE.md` - Wave deployment guide
- `TROUBLESHOOTING.md` - Common issues

**View Logs:**
```bash
# Local logs
tail -f logs/bot-activity.log

# S3 logs
aws s3 ls s3://greendotball-bot-data/campaigns/${CAMPAIGN_ID}/logs/

# CloudWatch logs
aws logs tail /aws/lambda/start-campaign --follow
```

**Get Help:**
1. Check campaign status: `./scripts/monitor-wave-progress.sh ${CAMPAIGN_ID}`
2. Review error logs in S3
3. Check AWS Console for instance/task status
4. Verify IAM permissions
5. Contact team lead with campaign ID and error details

---

**Happy Campaigning! 🚀**

*Last Updated: April 22, 2026*
