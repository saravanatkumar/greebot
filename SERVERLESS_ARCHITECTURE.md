# Serverless Campaign Architecture

## Overview

This architecture replaces manual EC2 instance management with a fully automated, serverless solution using AWS Step Functions, ECS Fargate, and Lambda.

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                     Campaign Launch (API/Web)                    │
└────────────────────────────┬────────────────────────────────────┘
                             ↓
┌─────────────────────────────────────────────────────────────────┐
│              AWS Step Functions State Machine                    │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ 1. Create Jobs (Lambda)                                   │  │
│  │    - Read phones.txt, list images                         │  │
│  │    - Generate job files (job-001.json, job-002.json...)   │  │
│  │    - Save to S3                                           │  │
│  └────────────────┬─────────────────────────────────────────┘  │
│                   ↓                                              │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ 2. Launch Fargate Tasks (Map State - Parallel)           │  │
│  │    ┌─────────────┐  ┌─────────────┐  ┌─────────────┐    │  │
│  │    │ Task 1      │  │ Task 2      │  │ Task N      │    │  │
│  │    │ job-001     │  │ job-002     │  │ job-N       │    │  │
│  │    │ (Fargate)   │  │ (Fargate)   │  │ (Fargate)   │    │  │
│  │    └─────────────┘  └─────────────┘  └─────────────┘    │  │
│  │    Each task:                                             │  │
│  │    - Pulls Docker image                                   │  │
│  │    - Runs bot_new.js with assigned job                    │  │
│  │    - Uploads results to S3                                │  │
│  │    - Exits (auto-cleanup)                                 │  │
│  └────────────────┬─────────────────────────────────────────┘  │
│                   ↓                                              │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ 3. Aggregate Results (Lambda)                             │  │
│  │    - Collect all job results from S3                      │  │
│  │    - Generate campaign summary                            │  │
│  │    - Update campaign status                               │  │
│  └────────────────┬─────────────────────────────────────────┘  │
│                   ↓                                              │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ 4. Send Notification (Lambda/SNS)                         │  │
│  │    - Email/SMS campaign completion                        │  │
│  │    - Include success/failure stats                        │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

## Components

### 1. Step Functions State Machine
- **Purpose**: Orchestrates entire campaign workflow
- **Features**:
  - Parallel task execution
  - Automatic retries on failure
  - Built-in error handling
  - Progress tracking
  - Timeout management

### 2. ECS Fargate Tasks
- **Purpose**: Run bot workers
- **Configuration**:
  - CPU: 0.5 vCPU (512 units)
  - Memory: 1 GB
  - Container: Custom Docker image with Puppeteer + Chrome
  - Network: VPC with NAT Gateway (for S3 access)
- **Lifecycle**:
  1. Task starts
  2. Downloads job file from S3
  3. Downloads images from S3
  4. Runs bot_new.js
  5. Uploads results to S3
  6. Exits (Fargate auto-cleans up)

### 3. Lambda Functions

#### a. `create-jobs` (existing)
- Already implemented
- No changes needed

#### b. `launch-campaign-stepfunctions` (new)
- Triggers Step Functions execution
- Passes campaign ID and configuration

#### c. `aggregate-results` (new)
- Collects all job results
- Generates campaign summary
- Updates campaign metadata

#### d. `get-campaign-status` (enhanced)
- Query Step Functions execution status
- Show real-time progress

### 4. Docker Container
- Base: `node:18-slim`
- Includes: Puppeteer, Chrome, AWS SDK
- Entry point: `node src/bot_new.js`

## Cost Analysis

### Current EC2 Approach
| Resource | Cost | Notes |
|----------|------|-------|
| t3.medium | $0.0416/hour | Billed per hour |
| 10 instances × 1 hour | **$0.416** | Even if jobs finish in 20 min |

### New Fargate Approach
| Resource | Cost | Notes |
|----------|------|-------|
| Fargate (0.5 vCPU, 1GB) | $0.025/hour | Billed per second |
| 10 tasks × 20 min actual | **$0.083** | 80% cheaper! |
| Step Functions | $0.025/1000 transitions | ~$0.001 per campaign |
| Lambda | Free tier | Negligible |

**Savings: ~80% for typical campaigns**

## Scalability

### Concurrency Control
```json
{
  "maxConcurrency": 10
}
```
- Limit parallel tasks to control costs
- Prevent overwhelming target server
- Adjust based on budget

### Auto-scaling
- No manual intervention needed
- Launch 1 or 1000 jobs with same code
- Step Functions handles orchestration

## Deployment Steps

### 1. Create Docker Image
```bash
cd /Users/apple/CascadeProjects/windsurf-project-2
docker build -t greendotball-bot:latest -f docker/Dockerfile .
```

### 2. Push to ECR
```bash
aws ecr create-repository --repository-name greendotball-bot --region ap-south-1
aws ecr get-login-password --region ap-south-1 | docker login --username AWS --password-stdin <account-id>.dkr.ecr.ap-south-1.amazonaws.com
docker tag greendotball-bot:latest <account-id>.dkr.ecr.ap-south-1.amazonaws.com/greendotball-bot:latest
docker push <account-id>.dkr.ecr.ap-south-1.amazonaws.com/greendotball-bot:latest
```

### 3. Create ECS Task Definition
```bash
aws ecs register-task-definition --cli-input-json file://ecs/task-definition.json
```

### 4. Deploy Step Functions State Machine
```bash
aws stepfunctions create-state-machine \
  --name greendotball-campaign-executor \
  --definition file://stepfunctions/state-machine.json \
  --role-arn arn:aws:iam::<account-id>:role/StepFunctionsExecutionRole
```

### 5. Deploy Lambda Functions
```bash
cd lambdas
zip -r launch-campaign-stepfunctions.zip launch-campaign-stepfunctions.js
aws lambda create-function \
  --function-name launch-campaign-stepfunctions \
  --runtime nodejs18.x \
  --handler launch-campaign-stepfunctions.handler \
  --zip-file fileb://launch-campaign-stepfunctions.zip \
  --role arn:aws:iam::<account-id>:role/LambdaExecutionRole
```

## Usage

### Launch Campaign
```bash
curl -X POST https://your-api.execute-api.ap-south-1.amazonaws.com/prod/launch-campaign \
  -H "Content-Type: application/json" \
  -d '{
    "campaignId": "apr-13-2026-batch-01-c64807",
    "maxConcurrency": 10,
    "phonesPerJob": 10,
    "imagesPerJob": 20
  }'
```

### Check Status
```bash
curl https://your-api.execute-api.ap-south-1.amazonaws.com/prod/campaign-status?campaignId=apr-13-2026-batch-01-c64807
```

Response:
```json
{
  "campaignId": "apr-13-2026-batch-01-c64807",
  "status": "RUNNING",
  "progress": {
    "completedJobs": 5,
    "totalJobs": 10,
    "progressPct": 50
  },
  "runningTasks": 5,
  "estimatedTimeRemaining": "15 minutes"
}
```

## Monitoring

### CloudWatch Dashboards
- Step Functions execution status
- Fargate task metrics (CPU, memory)
- Lambda invocation counts
- Error rates

### Alarms
- Task failures > 10%
- Step Functions execution timeout
- Lambda errors

## Migration Path

### Phase 1: Parallel Testing (1 week)
- Deploy new architecture
- Run small test campaigns
- Compare results with EC2 approach

### Phase 2: Gradual Migration (2 weeks)
- Run 50% campaigns on new architecture
- Monitor costs and performance
- Fix any issues

### Phase 3: Full Migration (1 week)
- Migrate all campaigns to new architecture
- Decommission EC2 instances
- Update documentation

## Rollback Plan

If issues arise:
1. Keep EC2 AMI and scripts intact
2. Switch back to EC2 launch scripts
3. Debug new architecture offline
4. Re-deploy when ready

## Security

### IAM Roles
- **ECS Task Role**: S3 read/write, CloudWatch logs
- **Step Functions Role**: ECS RunTask, Lambda Invoke
- **Lambda Role**: S3, ECS, Step Functions

### Network
- Fargate tasks in private subnet
- NAT Gateway for internet access
- Security group: Outbound HTTPS only

### Secrets
- Store credentials in AWS Secrets Manager
- Inject into Fargate tasks via environment variables

## Future Enhancements

1. **Spot Fargate**: Use Fargate Spot for 70% additional savings
2. **SQS Queue**: Decouple job creation from execution
3. **DynamoDB**: Real-time job status tracking
4. **EventBridge**: Schedule campaigns
5. **Auto-retry**: Failed submissions retry with exponential backoff

## Support

For issues or questions:
1. Check CloudWatch logs
2. Review Step Functions execution history
3. Inspect Fargate task logs
4. Contact: [your-email]
