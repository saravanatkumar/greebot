# GreenDotBall New Campaign System

## Overview

The new campaign system implements a "1 phone number × 1 image" approach that creates more efficient utilization of AWS instances. Instead of launching one AWS instance per phone number (which could be inefficient if you have many phone numbers), this system:

1. Divides the workload into **jobs** (batches of phone-image pairs)
2. Launches fewer instances, with each instance processing a specific job
3. Allows multiple instances to run in parallel for different jobs

## System Components

### 1. Job Structure

The system uses a two-level job structure:

#### Master Job File (`masterjob.json`)
```json
{
  "campaign_name": "February2026Campaign",
  "created_at": "2026-02-18T12:00:00Z",
  "total_jobs": 20,
  "jobs": [
    {"id": "job-1", "name": "Batch 1", "file": "jobs/job-1.json", "image_count": 50},
    {"id": "job-2", "name": "Batch 2", "file": "jobs/job-2.json", "image_count": 50},
    ...
  ]
}
```

#### Individual Job Files (`job-1.json`, `job-2.json`, etc.)
```json
{
  "job_id": "job-1",
  "name": "Batch 1",
  "created_at": "2026-02-18T12:00:00Z",
  "pairs": [
    {"id": "pair-1", "phoneNumber": "9810887396", "imagePath": "data/images/080fgvr999ja.jpg"},
    {"id": "pair-2", "phoneNumber": "9810846436", "imagePath": "data/images/0c29s0fateae.jpg"},
    ...
  ]
}
```

### 2. New Bot Implementation (`bot_new.js`)

A new bot implementation has been created that:
- Processes specific job files
- Handles phone-image pairs sequentially
- Has a time limit (default 55 minutes) to ensure completion before EC2 instance termination
- Saves progress to S3 after each submission
- Creates detailed logs and reports

### 3. Instance Launch Script (`launch-job-instance.sh`)

A modified launch script that:
- Takes a job ID as input
- Can launch multiple instances for a single job if needed
- Tags instances with the job ID for easier tracking

### 4. Job Creation Script (`create-jobs.js`)

A Node.js script that:
- Generates all possible phone-image pairs
- Divides pairs into configurable job sizes
- Creates master job file and individual job files
- Can optionally upload files to S3

## How to Use the New System

### 1. Create Jobs

```bash
# Create jobs with default settings
node scripts/create-jobs.js

# Create jobs with custom settings
node scripts/create-jobs.js --campaign="February2026" --job-size=100 --total-jobs=10

# Create and upload to S3
node scripts/create-jobs.js --upload-s3
```

This will:
- Generate all phone-image pairs from your data directory
- Create job files in `data/jobs/`
- Create a master job file `data/jobs/masterjob.json`

### 2. Launch Job Instances

```bash
# Launch a single instance for job-1
./scripts/launch-job-instance.sh job-1

# Launch 5 parallel instances for job-2
./scripts/launch-job-instance.sh job-2 5
```

Each instance will:
- Process its assigned job file
- Handle each phone-image pair sequentially
- Run for up to 55 minutes (configurable)
- Save progress to S3

### 3. Monitor Progress

Monitor instances and results:
```bash
# Monitor instances for a specific job
aws ec2 describe-instances --region ap-south-1 --filters "Name=tag:JobID,Values=job-1" "Name=instance-state-name,Values=running"

# Check logs in S3
aws s3 ls s3://greendotball-bot-data/logs/job-1/ --recursive
```

## Key Benefits

1. **Efficient Resource Utilization**: Instead of one instance per phone number, use one instance per job batch
2. **Controlled Runtime**: Each instance runs for a limited time (default 55 minutes)
3. **Parallel Processing**: Launch multiple instances for faster processing
4. **Detailed Tracking**: Each submission is tracked with detailed logs and reports
5. **Resume Capability**: If an instance stops, you can launch new instances to continue processing

## Technical Details

### Instance Configuration

Each instance is configured with:
- AMI: `ami-0a39d12e7514ee458`
- Instance Type: `t3.small`
- Key Pair: `greendotball-bot-key-v2`
- Security Group: `greendotball-bot-sg`
- IAM Role: `EC2-GreenDotBall-S3-Access`
- Region: `ap-south-1`
- Tags:
  - Name: `greendotball-job-{job-id}-{index}`
  - JobID: `{job-id}`
  - Project: `greendotball`
  - Batch: `{timestamp}`

### Data Management

- Phone numbers from `data/mobile-numbers.txt`
- Images from `data/images/`
- Job files in `data/jobs/`
- Results in S3 under `s3://greendotball-bot-data/logs/job-{job-id}/`
