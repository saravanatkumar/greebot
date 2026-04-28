# GreenDotBall Form Automation System - Developer Guide

## 📋 Project Overview

**GreenDotBall** is a comprehensive automated form submission system designed to submit entries to https://greendotball.com/2026/ at scale. The system combines local bot automation with AWS cloud infrastructure for distributed, high-volume form submissions.

### Key Capabilities
- 🤖 **Automated Form Submission**: Puppeteer-based bot handles image upload, phone number entry, terms acceptance, and slide-to-submit interaction
- ☁️ **AWS Cloud Deployment**: Scalable architecture using EC2, Lambda, Step Functions, and ECS Fargate
- 📊 **Campaign Management**: Web-based dashboard for managing campaigns, uploading data, and monitoring progress
- 🔄 **Batch Processing**: Process thousands of submissions with different phone numbers and images
- 📈 **Real-time Monitoring**: Track submission status, success rates, and campaign progress

---

## 🏗️ Architecture

### Local Bot Architecture
```
┌─────────────────────────────────────────────┐
│         Puppeteer Bot (Node.js)             │
├─────────────────────────────────────────────┤
│  • Image Upload Handler                     │
│  • Phone Number Entry                       │
│  • Terms & Conditions Acceptance            │
│  • Slide-to-Submit Automation               │
│  • Success/Error Detection                  │
│  • Retry Logic with Exponential Backoff     │
└─────────────────────────────────────────────┘
```

### AWS Cloud Architecture
```
┌──────────────────────────────────────────────────────────────┐
│                    Campaign Launch (Web UI)                  │
└────────────────────────┬─────────────────────────────────────┘
                         ↓
┌──────────────────────────────────────────────────────────────┐
│              AWS Step Functions Orchestration                 │
│  ┌────────────────────────────────────────────────────────┐  │
│  │ 1. Create Jobs (Lambda)                                │  │
│  │    • Read phone numbers & list images from S3          │  │
│  │    • Generate job files (job-001.json, job-002.json)   │  │
│  └──────────────────┬─────────────────────────────────────┘  │
│                     ↓                                         │
│  ┌────────────────────────────────────────────────────────┐  │
│  │ 2. Launch Workers (EC2/ECS Fargate - Parallel)        │  │
│  │    • Each worker processes assigned phone + images     │  │
│  │    • Runs Puppeteer bot in headless mode              │  │
│  │    • Uploads results to S3                            │  │
│  └──────────────────┬─────────────────────────────────────┘  │
│                     ↓                                         │
│  ┌────────────────────────────────────────────────────────┐  │
│  │ 3. Aggregate Results (Lambda)                          │  │
│  │    • Collect job results from S3                       │  │
│  │    • Generate campaign summary                         │  │
│  └────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────┘
                         ↓
┌──────────────────────────────────────────────────────────────┐
│                    S3 Storage                                 │
│  • Phone Numbers (data/phones.txt)                           │
│  • Images (data/images/)                                     │
│  • Job Files (campaigns/{id}/jobs/)                          │
│  • Results (campaigns/{id}/results/)                         │
│  • Logs (logs/)                                              │
└──────────────────────────────────────────────────────────────┘
```

---

## 📁 Project Structure

```
windsurf-project-2/
├── src/                          # Core bot source code
│   ├── bot.js                    # Main bot logic (single submission)
│   ├── bot_new.js                # Enhanced bot for AWS deployment
│   ├── formHandler.js            # Form interaction handlers
│   ├── validator.js              # Input validation
│   ├── dynamicConfig.js          # Dynamic configuration loader
│   └── utils/
│       ├── logger.js             # Winston logger
│       └── helpers.js            # Utility functions
│
├── scripts/                      # Deployment & management scripts
│   ├── launch-campaign-waves.sh  # Launch EC2 instances in waves
│   ├── launch-campaign-instances.sh # Launch campaign workers
│   ├── create-jobs.js            # Generate job files from data
│   ├── terminate-instances.sh    # Cleanup EC2 instances
│   ├── monitor-wave-progress.sh  # Monitor campaign progress
│   ├── sync-dashboard-data.js    # Sync data to dashboard
│   └── create-campaign-pool-20img.sh # Create campaign with image pool
│
├── lambdas/                      # AWS Lambda functions
│   ├── upload-campaign.js        # Upload campaign data to S3
│   ├── upload-phone-numbers.js   # Upload phone numbers
│   ├── create-jobs.js            # Create job files
│   ├── start-campaign.js         # Start campaign execution
│   ├── get-campaign-status.js    # Get campaign status
│   └── list-campaigns.js         # List all campaigns
│
├── stepfunctions/                # AWS Step Functions definitions
│   ├── state-machine.json        # Main orchestration workflow
│   └── batch-orchestrator.json   # Batch processing workflow
│
├── website/greendotball/         # Web dashboard
│   ├── index.html                # Landing page
│   ├── dashboard.html            # Campaign dashboard
│   ├── launch-campaign.html      # Campaign launcher
│   ├── upload-images.html        # Image upload interface
│   └── upload-phones.html        # Phone number upload
│
├── iam/                          # IAM policies & setup scripts
│   ├── ec2-campaign-launcher-policy.json
│   ├── s3-full-management-policy.json
│   ├── setup-s3-external-access.sh
│   └── README.md
│
├── config/                       # Configuration files
│   ├── config.json               # Bot configuration
│   └── wave-config.json          # Wave deployment config
│
├── data/                         # Data storage
│   ├── phones.txt                # Phone numbers
│   ├── phone_batch_*.txt         # Phone number batches
│   ├── images/                   # Image files
│   └── sample-images/            # Sample images for testing
│
├── docker/                       # Docker configuration
│   └── Dockerfile                # Container for ECS Fargate
│
├── ecs/                          # ECS task definitions
│   └── task-definition.json
│
├── docs/                         # Additional documentation
│   ├── AWS_DEPLOYMENT_PLAN.md
│   ├── SERVERLESS_ARCHITECTURE.md
│   ├── QUICKSTART.md
│   ├── WAVE_ORCHESTRATION_GUIDE.md
│   └── TEST_INSTANCE_GUIDE.md
│
├── package.json                  # Node.js dependencies
├── .env.example                  # Environment variables template
└── README.md                     # User-facing documentation
```

---

## 🚀 Getting Started

### Prerequisites

**Local Development:**
- Node.js 16+ 
- npm or yarn
- Chrome/Chromium (installed automatically by Puppeteer)

**AWS Deployment:**
- AWS Account with appropriate permissions
- AWS CLI configured
- IAM roles for EC2, Lambda, S3, Step Functions
- S3 bucket: `greendotball-bot-data`

### Installation

```bash
# Clone the repository
cd /Users/apple/CascadeProjects/windsurf-project-2

# Install dependencies
npm install

# Copy environment template
cp .env.example .env

# Edit configuration
nano config/config.json
```

### Configuration

Edit `config/config.json`:

```json
{
  "targetUrl": "https://greendotball.com/2026/",
  "headless": false,
  "slowMo": 100,
  "timeout": 30000,
  "retryAttempts": 3,
  "delayBetweenSubmissions": 5000,
  "phoneNumbers": ["9876543210"],
  "imagePath": "./data/sample-images/green-ball.jpg",
  "slideStrategy": "mouse",
  "screenshotOnError": true,
  "maxSubmissionsPerSession": 10
}
```

---

## 💻 Usage

### Local Testing

**Single Submission:**
```bash
npm start
```

**Batch Mode (multiple phone numbers):**
```bash
npm run batch
```

**Debug Mode (visible browser):**
```bash
npm run debug
```

### AWS Campaign Deployment

**1. Prepare Campaign Data:**
```bash
# Upload phone numbers to S3
aws s3 cp data/phones.txt s3://greendotball-bot-data/campaigns/campaign-001/phones.txt

# Upload images to S3
aws s3 sync data/images/ s3://greendotball-bot-data/campaigns/campaign-001/images/
```

**2. Create Jobs:**
```bash
# Generate job files from phone numbers and images
node scripts/create-jobs.js --campaign campaign-001
```

**3. Launch Campaign:**

**Option A: EC2 Instances (Wave-based)**
```bash
# Launch in waves (recommended for large campaigns)
./scripts/launch-campaign-waves.sh campaign-001 20 5
# Args: campaign-id, instances-per-wave, delay-minutes
```

**Option B: Step Functions + ECS Fargate (Serverless)**
```bash
# Trigger Step Functions workflow
aws stepfunctions start-execution \
  --state-machine-arn arn:aws:states:ap-south-1:ACCOUNT:stateMachine:CampaignOrchestrator \
  --input '{"campaignId": "campaign-001"}'
```

**4. Monitor Progress:**
```bash
# Monitor running instances
./scripts/monitor-wave-progress.sh campaign-001

# Check dashboard
open website/greendotball/dashboard.html

# View logs in S3
aws s3 ls s3://greendotball-bot-data/campaigns/campaign-001/results/
```

**5. Cleanup:**
```bash
# Terminate all campaign instances
./scripts/terminate-instances.sh campaign-001
```

---

## 🔧 Key Components

### 1. Bot Engine (`src/bot.js`, `src/bot_new.js`)

**Features:**
- Puppeteer-based browser automation
- Stealth mode to avoid detection
- Automatic retry with exponential backoff
- Screenshot capture on errors
- Comprehensive logging

**Form Interaction:**
- Image upload via file input
- Phone number entry with validation
- Terms checkbox acceptance
- Slide-to-submit mechanism (mouse drag or JavaScript)
- Success/error modal detection

### 2. Form Handler (`src/formHandler.js`)

Handles all DOM interactions:
- `uploadImage()` - File upload handling
- `enterPhoneNumber()` - Phone input with validation
- `acceptTerms()` - Checkbox interaction
- `performSlideToSubmit()` - Slide mechanism automation
- `waitForResponse()` - Modal detection and parsing

### 3. Lambda Functions

**Campaign Management:**
- `upload-campaign.js` - Upload campaign data
- `start-campaign.js` - Initiate campaign execution
- `get-campaign-status.js` - Real-time status
- `list-campaigns.js` - List all campaigns

**Job Processing:**
- `create-jobs.js` - Generate job files
- `process-phone-numbers.js` - Validate phone numbers

### 4. Step Functions Workflow

Orchestrates the entire campaign:
1. **Create Jobs** - Generate job assignments
2. **Launch Workers** - Parallel task execution
3. **Aggregate Results** - Collect and summarize
4. **Notify** - Send completion notifications

### 5. Web Dashboard

**Features:**
- Campaign creation and management
- Real-time progress monitoring
- Phone number and image upload
- Success/failure statistics
- Historical campaign data

**Access:**
```bash
# Deploy dashboard to S3
./scripts/deploy-dashboard.sh

# Or open locally
open website/greendotball/dashboard.html
```

---

## 📊 Data Management

### Phone Numbers

**Format:** One phone number per line (10 digits)
```
9876543210
9876543211
9876543212
```

**Storage:**
- Local: `data/phones.txt`
- S3: `s3://greendotball-bot-data/campaigns/{id}/phones.txt`

**Batching:**
```bash
# Split phone numbers into batches
python scripts/split_phones.py data/masterPhone.txt 240
```

### Images

**Supported Formats:** JPG, PNG, GIF, WEBP

**Storage:**
- Local: `data/images/`
- S3: `s3://greendotball-bot-data/campaigns/{id}/images/`

**Upload:**
```bash
# Sync images to S3
aws s3 sync data/images/ s3://greendotball-bot-data/campaigns/campaign-001/images/
```

**Image Pool Management:**
```bash
# Create campaign with 20 random images per job
./scripts/create-campaign-pool-20img.sh campaign-001
```

### Results

**Location:** `s3://greendotball-bot-data/campaigns/{id}/results/`

**Format:**
```json
{
  "jobId": "job-001",
  "phoneNumber": "98765*****",
  "totalImages": 20,
  "successful": 18,
  "failed": 2,
  "results": [
    {
      "image": "image1.jpg",
      "status": "success",
      "timestamp": "2026-04-22T10:30:15Z"
    }
  ]
}
```

---

## 🔐 AWS Setup

### IAM Roles

**1. EC2 Instance Role:** `EC2-GreenDotBall-S3-Access`
- S3 read/write access
- CloudWatch logs

**2. Lambda Execution Role:**
- S3 access
- CloudWatch logs
- Step Functions execution

**3. ECS Task Role:**
- S3 access
- CloudWatch logs

### Setup Scripts

```bash
# Setup S3 external access
./iam/setup-s3-external-access.sh

# Attach EC2 policy
./iam/attach-ec2-policy.sh

# Create additional IAM user
./iam/create-additional-user.sh username
```

### Security Groups

**greendotball-bot-sg:**
- Outbound: All traffic (for web access)
- Inbound: SSH (optional, for debugging)

---

## 📈 Scaling & Performance

### Horizontal Scaling

**EC2 Wave Deployment:**
- Launch instances in waves to avoid AWS limits
- Default: 20 instances per wave, 5-minute intervals
- Supports 100+ concurrent instances

**ECS Fargate:**
- Serverless, auto-scaling
- No instance management
- Pay per task execution

### Performance Optimization

**Bot Configuration:**
```json
{
  "headless": true,           // Faster execution
  "slowMo": 0,                // No artificial delays
  "slideStrategy": "javascript", // More reliable
  "delayBetweenSubmissions": 3000 // Reduce delays
}
```

**AWS Optimization:**
- Use Spot Instances for cost savings (up to 70% cheaper)
- Enable ECS Fargate Spot for serverless tasks
- Use S3 Transfer Acceleration for faster uploads

### Capacity Planning

**Example Campaign:**
- 5,000 phone numbers
- 20 images per phone number
- Total submissions: 100,000

**EC2 Approach:**
- 50 instances × 100 jobs each
- ~2 hours total (with waves)
- Cost: ~$5-10 (with Spot Instances)

**ECS Fargate Approach:**
- 100 parallel tasks
- ~1.5 hours total
- Cost: ~$8-12

---

## 🐛 Troubleshooting

### Common Issues

**1. Image Upload Fails**
```bash
# Check image exists
ls -la data/sample-images/

# Verify image format
file data/sample-images/image.jpg

# Check file size (should be < 10MB)
du -h data/sample-images/image.jpg
```

**2. Slide-to-Submit Fails**
```json
// Try JavaScript strategy
"slideStrategy": "javascript"
```

**3. EC2 Instances Not Starting**
```bash
# Check IAM role
aws iam get-role --role-name EC2-GreenDotBall-S3-Access

# Check security group
aws ec2 describe-security-groups --group-names greendotball-bot-sg

# Check AMI availability
aws ec2 describe-images --image-ids ami-0a39d12e7514ee458 --region ap-south-1
```

**4. Lambda Function Errors**
```bash
# Check CloudWatch logs
aws logs tail /aws/lambda/upload-campaign --follow

# Test Lambda locally
node lambdas/upload-campaign.js
```

### Debugging

**Enable Debug Logging:**
```bash
DEBUG=true npm start
```

**View Bot in Action:**
```json
{
  "headless": false,
  "slowMo": 500
}
```

**Check Logs:**
```bash
# Local logs
tail -f logs/bot-activity.log
tail -f logs/error.log

# S3 logs
aws s3 ls s3://greendotball-bot-data/logs/ --recursive
aws s3 cp s3://greendotball-bot-data/logs/campaign-001/ . --recursive
```

---

## 📚 Documentation

### Quick References
- **QUICKSTART.md** - 2-minute setup guide
- **QUICKSTART_DYNAMIC.md** - Dynamic configuration guide
- **QUICK_REFERENCE.md** - Command cheat sheet

### Deployment Guides
- **AWS_DEPLOYMENT_PLAN.md** - Complete AWS setup
- **AWS_EC2_DEPLOYMENT_PLAN.md** - EC2-specific deployment
- **SERVERLESS_ARCHITECTURE.md** - Serverless approach
- **AWS_CONSOLE_DEPLOYMENT_GUIDE.md** - Manual console setup

### Advanced Topics
- **WAVE_ORCHESTRATION_GUIDE.md** - Wave-based deployment
- **DYNAMIC_ASSIGNMENT_PLAN.md** - Dynamic job assignment
- **RANDOM_SELECTION_GUIDE.md** - Random image/phone selection
- **AMI-UPDATE-GUIDE.md** - Update EC2 AMI

### IAM & Security
- **iam/README.md** - IAM setup overview
- **iam/ADMIN_GUIDE.md** - Administrator guide
- **iam/USER_GUIDE.md** - User guide
- **iam/CONSOLE_SETUP_GUIDE.md** - Console setup

---

## 🧪 Testing

### Local Testing

```bash
# Test bot with single submission
npm test

# Test with debug mode
npm run debug

# Test batch mode
npm run batch
```

### AWS Testing

```bash
# Launch single test instance
./scripts/launch-test-instance.sh

# Create test campaign
./scripts/create-test-campaign.sh

# Manual EC2 test
./scripts/manual-ec2-test.sh
```

### Validation

```bash
# Validate configuration
node src/validator.js

# Check phone number format
grep -E '^[0-9]{10}$' data/phones.txt

# Verify images
find data/images -type f -name "*.jpg" -o -name "*.png"
```

---

## 🔄 Deployment Workflows

### Workflow 1: Quick Local Test
```bash
1. Add test phone number to config.json
2. Add test image to data/sample-images/
3. Run: npm start
4. Check logs/bot-activity.log
```

### Workflow 2: Small Campaign (< 100 submissions)
```bash
1. Prepare data/phones.txt and data/images/
2. Run: node scripts/create-jobs.js
3. Run: ./scripts/launch-campaign-instances.sh campaign-001
4. Monitor: ./scripts/monitor-wave-progress.sh campaign-001
5. Cleanup: ./scripts/terminate-instances.sh campaign-001
```

### Workflow 3: Large Campaign (1000+ submissions)
```bash
1. Upload data to S3
2. Create jobs: node scripts/create-jobs.js --campaign campaign-001
3. Launch waves: ./scripts/launch-campaign-waves.sh campaign-001 20 5
4. Monitor dashboard: open website/greendotball/dashboard.html
5. Sync results: node scripts/sync-dashboard-data.js
6. Cleanup: ./scripts/terminate-instances.sh campaign-001
```

### Workflow 4: Serverless Campaign (ECS Fargate)
```bash
1. Upload data to S3
2. Trigger Step Functions:
   aws stepfunctions start-execution \
     --state-machine-arn arn:aws:states:ap-south-1:ACCOUNT:stateMachine:CampaignOrchestrator \
     --input '{"campaignId": "campaign-001"}'
3. Monitor execution:
   aws stepfunctions describe-execution --execution-arn <arn>
4. Check results in S3
```

---

## 💰 Cost Estimation

### EC2 Deployment
- **t3.small Spot Instance:** ~$0.006/hour
- **100 instances × 2 hours:** ~$1.20
- **S3 storage (10GB):** ~$0.23/month
- **Data transfer:** ~$0.50
- **Total:** ~$2-3 per campaign

### ECS Fargate Deployment
- **0.5 vCPU, 1GB RAM:** ~$0.04/hour
- **100 tasks × 1.5 hours:** ~$6
- **S3 storage:** ~$0.23/month
- **Total:** ~$6-8 per campaign

### Lambda + Step Functions
- **Lambda executions:** ~$0.20
- **Step Functions transitions:** ~$0.25
- **S3 operations:** ~$0.10
- **Total:** ~$0.55 per campaign

---

## 🤝 Contributing

### Code Style
- Use ES6+ syntax
- Follow existing naming conventions
- Add JSDoc comments for functions
- Use Winston logger for all logging

### Testing
- Test locally before AWS deployment
- Validate with small datasets first
- Check logs for errors
- Verify S3 uploads

### Pull Request Process
1. Create feature branch
2. Test thoroughly
3. Update documentation
4. Submit PR with description

---

## 📝 License

MIT License - See LICENSE file for details

---

## 📞 Support

### Resources
- Check logs: `logs/` directory
- Review documentation: `docs/` directory
- AWS CloudWatch: Monitor Lambda/EC2 logs
- S3 results: Check campaign results

### Common Commands

```bash
# Check running instances
aws ec2 describe-instances --region ap-south-1 \
  --filters "Name=tag:Project,Values=greendotball" \
  "Name=instance-state-name,Values=running"

# View Lambda logs
aws logs tail /aws/lambda/start-campaign --follow

# List campaigns
aws s3 ls s3://greendotball-bot-data/campaigns/

# Download results
aws s3 sync s3://greendotball-bot-data/campaigns/campaign-001/results/ ./results/
```

---

## 🎯 Quick Start Checklist

- [ ] Install Node.js 16+
- [ ] Run `npm install`
- [ ] Configure `config/config.json`
- [ ] Add phone numbers to `data/phones.txt`
- [ ] Add images to `data/images/`
- [ ] Test locally: `npm start`
- [ ] Setup AWS credentials
- [ ] Create S3 bucket: `greendotball-bot-data`
- [ ] Setup IAM roles
- [ ] Test AWS deployment: `./scripts/launch-test-instance.sh`
- [ ] Launch campaign: `./scripts/launch-campaign-waves.sh`

---

**Version:** 1.0.0  
**Last Updated:** April 22, 2026  
**Status:** Production Ready  
**Maintainer:** Development Team
