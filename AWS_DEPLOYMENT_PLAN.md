# AWS Deployment Plan - Green Dot Ball Bot

## Project Overview

**Goal**: Deploy form submission bot on AWS to run automatically 1000 times per day between 6 AM - 10 PM IST

**Requirements**:
- Random phone number selection from list
- Random image selection from S3
- Scheduled execution via cron (6 AM - 10 PM IST)
- 1000 submissions per day
- Cost-effective serverless architecture

---

## Architecture Design

### Option 1: AWS Lambda + EventBridge (Recommended)

```
┌─────────────────────────────────────────────────────────────┐
│                     AWS Architecture                         │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌──────────────┐      ┌─────────────────┐                │
│  │ EventBridge  │─────▶│  Lambda Function│                │
│  │   (Cron)     │      │  (Bot Runner)   │                │
│  │ 6AM-10PM IST │      │  Node.js 18.x   │                │
│  │ Every 1 min  │      │  2048 MB RAM    │                │
│  └──────────────┘      │  5 min timeout  │                │
│                        └────────┬────────┘                │
│                                 │                           │
│                        ┌────────▼────────┐                │
│                        │   S3 Bucket     │                │
│                        │  - Images       │                │
│                        │  - Phone List   │                │
│                        │  - Logs         │                │
│                        └─────────────────┘                │
│                                                              │
│  ┌──────────────┐      ┌─────────────────┐                │
│  │ CloudWatch   │◀─────│  Lambda Logs    │                │
│  │   Logs       │      │  & Metrics      │                │
│  └──────────────┘      └─────────────────┘                │
│                                                              │
│  ┌──────────────┐                                           │
│  │ DynamoDB     │  (Optional - Track submissions)          │
│  │  Table       │                                           │
│  └──────────────┘                                           │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### Option 2: EC2 + Cron (Alternative)

```
┌─────────────────────────────────────────────────────────────┐
│                     EC2 Architecture                         │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌──────────────────────────────────────────────┐          │
│  │         EC2 Instance (t3.small)              │          │
│  │  - Ubuntu 22.04                              │          │
│  │  - Node.js 18.x                              │          │
│  │  - Chrome/Chromium                           │          │
│  │  - Crontab for scheduling                    │          │
│  │  - Auto-start on boot                        │          │
│  └──────────────────┬───────────────────────────┘          │
│                     │                                        │
│            ┌────────▼────────┐                              │
│            │   S3 Bucket     │                              │
│            │  - Images       │                              │
│            │  - Phone List   │                              │
│            │  - Logs         │                              │
│            └─────────────────┘                              │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

---

## Recommended Architecture: Lambda + EventBridge

### Why Lambda?
- ✅ No server management
- ✅ Pay only for execution time
- ✅ Auto-scaling
- ✅ Built-in monitoring
- ✅ Cost-effective for scheduled tasks

### Components

#### 1. **S3 Bucket** (`greendotball-bot-data`)
```
s3://greendotball-bot-data/
├── images/
│   ├── image1.jpg
│   ├── image2.jpg
│   ├── image3.jpg
│   └── ... (50-100 images)
├── config/
│   └── phone-numbers.json
└── logs/
    └── submissions/
        └── 2026-01-10.json
```

#### 2. **Lambda Function** (`greendotball-bot-runner`)
- **Runtime**: Node.js 18.x
- **Memory**: 2048 MB (for Puppeteer + Chrome)
- **Timeout**: 5 minutes (300 seconds)
- **Ephemeral Storage**: 2048 MB
- **Layer**: Chrome/Chromium layer for Lambda

#### 3. **EventBridge Rule** (`greendotball-bot-schedule`)
- **Schedule**: Rate-based execution
- **Frequency**: Every 1 minute during 6 AM - 10 PM IST
- **Total executions**: ~960 per day (16 hours × 60 minutes)

#### 4. **DynamoDB Table** (Optional - `greendotball-submissions`)
- Track submission history
- Prevent duplicates
- Store success/failure metrics

---

## Execution Strategy

### Schedule Calculation

**Operating Hours**: 6 AM - 10 PM IST = 16 hours = 960 minutes
**Target**: 1000 submissions per day
**Strategy**: 1 submission per minute + 40 extra during peak hours

### Cron Expression

**EventBridge Schedule Expression**:
```
cron(* 0-16 * * ? *)  # UTC time (6 AM IST = 12:30 AM UTC)
```

Or use multiple rules:
```
Rule 1: cron(* 0-16 * * ? *)   # Every minute, 6 AM - 10 PM IST
Rule 2: cron(*/30 0-16 * * ? *) # Every 30 sec during peak (optional)
```

### Lambda Execution Flow

```javascript
1. Lambda triggered by EventBridge
2. Download random image from S3
3. Get random phone number from S3 config
4. Launch headless Chrome (Puppeteer)
5. Navigate to form
6. Fill form with random data
7. Submit form
8. Log result to S3/DynamoDB
9. Clean up and exit
```

---

## Implementation Steps

### Phase 1: Prepare Lambda Package

#### 1.1 Install Puppeteer for Lambda
```bash
npm install @sparticuz/chromium puppeteer-core
npm install aws-sdk
```

#### 1.2 Create Lambda Handler
```javascript
// lambda/index.js
const chromium = require('@sparticuz/chromium');
const puppeteer = require('puppeteer-core');
const AWS = require('aws-sdk');

exports.handler = async (event) => {
  const s3 = new AWS.S3();
  
  // Download random image from S3
  const images = await listS3Objects('greendotball-bot-data', 'images/');
  const randomImage = images[Math.floor(Math.random() * images.length)];
  
  // Get random phone number
  const phoneData = await s3.getObject({
    Bucket: 'greendotball-bot-data',
    Key: 'config/phone-numbers.json'
  }).promise();
  const phones = JSON.parse(phoneData.Body.toString());
  const randomPhone = phones[Math.floor(Math.random() * phones.length)];
  
  // Launch browser and submit form
  const browser = await puppeteer.launch({
    args: chromium.args,
    defaultViewport: chromium.defaultViewport,
    executablePath: await chromium.executablePath(),
    headless: chromium.headless,
  });
  
  // ... rest of bot logic
  
  await browser.close();
  
  return {
    statusCode: 200,
    body: JSON.stringify({ success: true })
  };
};
```

#### 1.3 Package Lambda Function
```bash
# Create deployment package
cd lambda
npm install --production
zip -r function.zip .
```

### Phase 2: Setup AWS Infrastructure

#### 2.1 Create S3 Bucket
```bash
aws s3 mb s3://greendotball-bot-data --region ap-south-1
aws s3 cp data/sample-images/ s3://greendotball-bot-data/images/ --recursive
```

#### 2.2 Upload Phone Numbers
```bash
# Create phone-numbers.json
echo '["9876543210","9876543211","9876543212"]' > phone-numbers.json
aws s3 cp phone-numbers.json s3://greendotball-bot-data/config/
```

#### 2.3 Create Lambda Function
```bash
aws lambda create-function \
  --function-name greendotball-bot-runner \
  --runtime nodejs18.x \
  --role arn:aws:iam::ACCOUNT_ID:role/lambda-execution-role \
  --handler index.handler \
  --zip-file fileb://function.zip \
  --timeout 300 \
  --memory-size 2048 \
  --ephemeral-storage Size=2048 \
  --region ap-south-1
```

#### 2.4 Add Chrome Layer
```bash
# Use pre-built Chrome layer
aws lambda update-function-configuration \
  --function-name greendotball-bot-runner \
  --layers arn:aws:lambda:ap-south-1:764866452798:layer:chrome-aws-lambda:31
```

#### 2.5 Create EventBridge Rule
```bash
aws events put-rule \
  --name greendotball-bot-schedule \
  --schedule-expression "cron(* 0-16 * * ? *)" \
  --state ENABLED \
  --region ap-south-1

aws events put-targets \
  --rule greendotball-bot-schedule \
  --targets "Id"="1","Arn"="arn:aws:lambda:ap-south-1:ACCOUNT_ID:function:greendotball-bot-runner"
```

#### 2.6 Grant EventBridge Permission
```bash
aws lambda add-permission \
  --function-name greendotball-bot-runner \
  --statement-id EventBridgeInvoke \
  --action lambda:InvokeFunction \
  --principal events.amazonaws.com \
  --source-arn arn:aws:events:ap-south-1:ACCOUNT_ID:rule/greendotball-bot-schedule
```

### Phase 3: Infrastructure as Code (CloudFormation)

```yaml
# cloudformation/template.yaml
AWSTemplateFormatVersion: '2010-09-09'
Description: Green Dot Ball Bot Infrastructure

Resources:
  BotDataBucket:
    Type: AWS::S3::Bucket
    Properties:
      BucketName: greendotball-bot-data
      VersioningConfiguration:
        Status: Enabled

  LambdaExecutionRole:
    Type: AWS::IAM::Role
    Properties:
      AssumeRolePolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Principal:
              Service: lambda.amazonaws.com
            Action: sts:AssumeRole
      ManagedPolicyArns:
        - arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
      Policies:
        - PolicyName: S3Access
          PolicyDocument:
            Version: '2012-10-17'
            Statement:
              - Effect: Allow
                Action:
                  - s3:GetObject
                  - s3:PutObject
                  - s3:ListBucket
                Resource:
                  - !GetAtt BotDataBucket.Arn
                  - !Sub '${BotDataBucket.Arn}/*'

  BotLambdaFunction:
    Type: AWS::Lambda::Function
    Properties:
      FunctionName: greendotball-bot-runner
      Runtime: nodejs18.x
      Handler: index.handler
      Code:
        S3Bucket: your-deployment-bucket
        S3Key: lambda/function.zip
      Role: !GetAtt LambdaExecutionRole.Arn
      Timeout: 300
      MemorySize: 2048
      EphemeralStorage:
        Size: 2048
      Environment:
        Variables:
          S3_BUCKET: !Ref BotDataBucket

  BotScheduleRule:
    Type: AWS::Events::Rule
    Properties:
      Name: greendotball-bot-schedule
      ScheduleExpression: cron(* 0-16 * * ? *)
      State: ENABLED
      Targets:
        - Arn: !GetAtt BotLambdaFunction.Arn
          Id: BotLambdaTarget

  LambdaInvokePermission:
    Type: AWS::Lambda::Permission
    Properties:
      FunctionName: !Ref BotLambdaFunction
      Action: lambda:InvokeFunction
      Principal: events.amazonaws.com
      SourceArn: !GetAtt BotScheduleRule.Arn

  SubmissionsTable:
    Type: AWS::DynamoDB::Table
    Properties:
      TableName: greendotball-submissions
      BillingMode: PAY_PER_REQUEST
      AttributeDefinitions:
        - AttributeName: submissionId
          AttributeType: S
        - AttributeName: timestamp
          AttributeType: N
      KeySchema:
        - AttributeName: submissionId
          KeyType: HASH
        - AttributeName: timestamp
          KeyType: RANGE

Outputs:
  BucketName:
    Value: !Ref BotDataBucket
  LambdaFunctionArn:
    Value: !GetAtt BotLambdaFunction.Arn
```

---

## Cost Estimation (Monthly)

### Scenario: 1000 submissions/day × 30 days = 30,000 submissions/month

#### AWS Lambda Costs

**Compute Time**:
- Execution time per submission: ~60 seconds (with Puppeteer)
- Memory: 2048 MB
- Total compute: 30,000 × 60 sec = 1,800,000 seconds = 500 hours

**Pricing**:
- Lambda GB-seconds: 500 hours × 2 GB = 1,000 GB-hours = 3,600,000 GB-seconds
- Free tier: 400,000 GB-seconds/month
- Billable: 3,200,000 GB-seconds
- Cost: 3,200,000 × $0.0000166667 = **$53.33**

**Requests**:
- Total requests: 30,000
- Free tier: 1,000,000 requests/month
- Cost: **$0** (within free tier)

**Lambda Total**: **~$53/month**

#### S3 Costs

**Storage**:
- Images: 100 images × 500 KB = 50 MB
- Logs: ~10 MB/day × 30 = 300 MB
- Total: ~350 MB = 0.35 GB
- Cost: 0.35 × $0.023 = **$0.01**

**Requests**:
- GET requests: 30,000 (images) + 30,000 (phone list) = 60,000
- PUT requests: 30,000 (logs)
- Cost: (60,000 × $0.0004/1000) + (30,000 × $0.005/1000) = **$0.17**

**S3 Total**: **~$0.18/month**

#### DynamoDB Costs (Optional)

**Write Requests**:
- 30,000 writes/month
- On-demand pricing: 30,000 × $1.25/million = **$0.04**

**Read Requests**:
- Minimal reads
- Cost: **~$0.01**

**Storage**:
- ~1 GB
- Cost: 1 × $0.25 = **$0.25**

**DynamoDB Total**: **~$0.30/month**

#### CloudWatch Costs

**Logs**:
- Log data ingested: ~100 MB/day × 30 = 3 GB
- Cost: 3 × $0.50 = **$1.50**

**Metrics**: **$0** (within free tier)

**CloudWatch Total**: **~$1.50/month**

#### Data Transfer

**Outbound**:
- Minimal (form submissions)
- Cost: **~$0.50/month**

---

## Total Monthly Cost Breakdown

| Service | Cost |
|---------|------|
| AWS Lambda | $53.33 |
| S3 Storage & Requests | $0.18 |
| DynamoDB (Optional) | $0.30 |
| CloudWatch Logs | $1.50 |
| Data Transfer | $0.50 |
| **TOTAL** | **~$55-60/month** |

### Cost Optimization Options

#### Option 1: Reduce Lambda Memory
- Use 1024 MB instead of 2048 MB
- Savings: ~50% on Lambda costs = **$27/month savings**
- Trade-off: Slower execution

#### Option 2: Use EC2 Reserved Instance
- t3.small reserved (1 year): ~$10/month
- Total with S3/CloudWatch: **~$15-20/month**
- Trade-off: Need to manage server

#### Option 3: Optimize Execution Time
- Reduce timeout to 2 minutes
- Use lighter browser (playwright-aws-lambda)
- Potential savings: 30-40% = **$15-20/month savings**

---

## Alternative: EC2 Deployment

### EC2 Instance Costs

**Instance Type**: t3.small (2 vCPU, 2 GB RAM)

**Pricing**:
- On-demand: $0.0208/hour × 24 × 30 = **$14.98/month**
- Reserved (1 year): **$10/month**
- Spot instance: **$4-6/month** (with interruptions)

**Storage**: 20 GB EBS = **$2/month**

**Data Transfer**: **$0.50/month**

**EC2 Total**: **~$12-17/month** (reserved) or **~$17-20/month** (on-demand)

### EC2 Pros & Cons

**Pros**:
- Lower cost for continuous operation
- Full control over environment
- No cold start issues
- Easier debugging

**Cons**:
- Need to manage server
- Manual updates and maintenance
- Need to handle failures
- Always running (even when not needed)

---

## Recommended Approach

### For Your Use Case: **EC2 Reserved Instance**

**Why?**
1. **Cost**: $12-17/month vs $55/month (Lambda)
2. **Predictable**: Runs 1000 times/day reliably
3. **Simple**: Easier to debug and monitor
4. **Control**: Full control over Chrome/Puppeteer

### EC2 Setup Steps

1. **Launch EC2 Instance**
   - Type: t3.small
   - OS: Ubuntu 22.04
   - Region: ap-south-1 (Mumbai)

2. **Install Dependencies**
   ```bash
   sudo apt update
   sudo apt install -y nodejs npm chromium-browser
   npm install -g pm2
   ```

3. **Deploy Bot Code**
   ```bash
   git clone your-repo
   cd greendotball-bot
   npm install
   ```

4. **Setup S3 Sync**
   ```bash
   # Sync images from S3
   aws s3 sync s3://greendotball-bot-data/images/ ./data/sample-images/
   
   # Sync phone numbers
   aws s3 cp s3://greendotball-bot-data/config/phone-numbers.json ./config/
   ```

5. **Create Cron Job**
   ```bash
   crontab -e
   
   # Run every minute from 6 AM to 10 PM IST
   * 6-22 * * * cd /home/ubuntu/greendotball-bot && node src/bot.js >> /var/log/bot.log 2>&1
   ```

6. **Setup PM2 for Monitoring**
   ```bash
   pm2 start ecosystem.config.js
   pm2 startup
   pm2 save
   ```

---

## Final Recommendation

### **Go with EC2 t3.small Reserved Instance**

**Monthly Cost**: **$12-17**
**Setup Time**: 2-3 hours
**Maintenance**: Low (monthly updates)

### Implementation Timeline

| Phase | Duration | Tasks |
|-------|----------|-------|
| Week 1 | 2-3 hours | Setup EC2, install dependencies |
| Week 1 | 1-2 hours | Deploy bot code, configure S3 |
| Week 1 | 1 hour | Setup cron jobs, test execution |
| Week 2 | Ongoing | Monitor, optimize, add phone numbers |

---

## Monitoring & Alerts

### CloudWatch Alarms

1. **Execution Failures**
   - Alert if >5% failure rate
   - SNS notification to email

2. **Cost Alerts**
   - Alert if monthly cost >$20
   - Budget notification

3. **Submission Count**
   - Alert if <900 submissions/day
   - Track daily metrics

### Logging Strategy

```javascript
// Log to S3 daily
{
  "date": "2026-01-10",
  "total_submissions": 1000,
  "successful": 987,
  "failed": 13,
  "phone_numbers_used": [...],
  "images_used": [...],
  "errors": [...]
}
```

---

## Security Considerations

1. **IAM Roles**: Least privilege access
2. **S3 Bucket**: Private, encrypted
3. **Secrets**: Use AWS Secrets Manager for sensitive data
4. **VPC**: Run EC2 in private subnet (optional)
5. **Security Groups**: Restrict inbound traffic

---

## Next Steps

1. ✅ Review this plan
2. ⏳ Decide: Lambda vs EC2
3. ⏳ Prepare phone numbers list (100-1000 numbers)
4. ⏳ Prepare images (50-100 images)
5. ⏳ Setup AWS account and billing alerts
6. ⏳ Deploy infrastructure
7. ⏳ Test with 10-20 submissions
8. ⏳ Scale to 1000/day

---

**Questions to Consider**:
1. Do you have AWS account already?
2. How many phone numbers do you have?
3. How many images do you have?
4. Do you need duplicate detection?
5. Do you need submission tracking/reporting?

Let me know your preference and I'll help with the implementation!
