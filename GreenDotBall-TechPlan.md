# GreenDotBall Campaign Manager - Technical Plan

## Overview
This document outlines the technical implementation plan for the GreenDotBall campaign management system, including phone number management, image processing, and campaign launching capabilities.

## System Architecture
```
[Existing myortho S3 Website] → [API Gateway] → [Lambda Functions] → [Existing greendotball-bot-data S3 Storage, EC2 Instances]
```

## Phase 1: Foundation Infrastructure (Week 1)

### 1.1 S3 Website Bucket Setup
- Use existing `myortho` bucket for sklearn.in website hosting
- Verify CORS configuration for API calls
- Ensure proper permissions for uploading new website files

```bash
# Use existing myortho bucket for website (sklearn.in)
aws s3 ls s3://myortho/

# Check existing website configuration
aws s3 website get s3://myortho

# Verify bucket policy (website should already be configured)
aws s3api get-bucket-policy --bucket myortho
```

### 1.2 Campaign Assets Bucket Setup
- Use existing `greendotball-bot-data` bucket for storing campaign data
- Organize within existing folder structure:
  - `config/` - For campaign configuration
  - `images/` - For campaign images
  - `logs/` - For instance logs
- Configure appropriate IAM policies for Lambda access if needed

```bash
# No need to create new bucket, use existing: greendotball-bot-data
# Verify access to the existing bucket
aws s3 ls s3://greendotball-bot-data/

# Ensure appropriate permissions are set
# (Skip this step if permissions are already configured correctly)
```

### 1.3 API Gateway Setup
- Create REST API for backend operations
- Configure API key for protection
- Set up CORS for website domain

```bash
# Create API
aws apigateway create-rest-api --name "GreenDotBallAPI" --endpoint-configuration "{ \"types\": [\"REGIONAL\"] }"

# Create usage plan with low-volume throttling
aws apigateway create-usage-plan \
  --name "GreenDotBallLowUsage" \
  --throttle burstLimit=5,rateLimit=10 \
  --quota limit=1000,period=MONTH
```

### 1.4 Authentication System
- Implement client-side authentication (minimal cost approach)
- Create login/logout functionality
- Protect all pages from unauthorized access

## Phase 2: Phone Number Management (Week 1-2)

### 2.1 Phone Upload Page
- Create HTML form for uploading phone numbers
- Implement campaign name input
- Add validation for proper phone number format
- Connect to API for submission

### 2.2 Phone Processing Lambda
- Create Lambda function to process uploaded phone numbers
- Store phone numbers in S3 with campaign association
- Return confirmation with campaign ID and statistics
- Register with API Gateway

## Phase 3: Image Management (Week 2-3)

### 3.1 Image Upload Page
- Build form for ZIP file upload
- Add campaign selection dropdown
- Implement progress indicator
- Display success/failure messages

### 3.2 Image Processing Lambda
- Create Lambda function to handle ZIP file extraction
- Rename images according to pattern (using existing logic)
- Store processed images in S3 campaign folder
- Update campaign metadata with image count and paths

## Phase 4: Campaign Launch System (Week 3-4)

### 4.1 Campaign Launch Page
- Create form for campaign selection
- Add configuration options (region, instance type)
- Implement launch button with confirmation
- Show launch status and link to dashboard

### 4.2 EC2 Launch Lambda
- Build Lambda function to verify campaign readiness
- Generate user-data script with campaign parameters
- Launch EC2 instances based on phone number count
- Integrate with existing launch-100-instances.sh logic
- Tag instances with campaign ID for tracking

### 4.3 Launch Monitoring
- Create initial dashboard shell when campaign launches
- Set up log collection mechanism
- Configure S3 event triggers for log processing

## Phase 5: Dashboard System (Week 4-5)

### 5.1 Log Collection Script
- Create script to run on EC2 instances
- Periodically upload logs to S3
- Include instance metadata with logs

```bash
#!/bin/bash
# Log collector to run on EC2 instances
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
CAMPAIGN_ID=$(aws ec2 describe-tags --filters "Name=resource-id,Values=$INSTANCE_ID" "Name=key,Values=Campaign" --query "Tags[0].Value" --output text)
PHONE=$(grep -n "" /path/to/phone.txt | head -1 | cut -d: -f2)

# Ship logs every 5 minutes
while true; do
  TIMESTAMP=$(date +%Y%m%d-%H%M)
  aws s3 cp /var/log/greendotball-bot.log \
    s3://greendotball-bot-data/logs/$CAMPAIGN_ID/$INSTANCE_ID-$TIMESTAMP.log
  sleep 300
done
```

### 5.2 Dashboard UI
- Create HTML/CSS/JS for dashboard
- Implement real-time log viewing
- Add statistics and visualizations
- Include controls for instance management

### 5.3 Log Processing Lambda
- Build Lambda function triggered by new logs in S3
- Parse logs to extract submission status
- Update dashboard JSON with latest statistics
- Generate updated HTML for dashboard

## Implementation Details

### Directory Structure
```
sklearn-greendotball-site/
├── index.html
├── css/
│   └── styles.css
├── js/
│   ├── auth.js
│   ├── api.js
│   └── utils.js
├── upload-phones.html
├── upload-images.html
└── launch-campaign.html
```

### Authentication Implementation
```javascript
// auth.js
function checkCredentials(username, password) {
  // Hard-coded for initial implementation
  return username === "admin" && password === "greendot2026";
}

function isAuthenticated() {
  return sessionStorage.getItem('authenticated') === 'true';
}

function authenticateUser(username, password) {
  if (checkCredentials(username, password)) {
    sessionStorage.setItem('authenticated', 'true');
    sessionStorage.setItem('username', username);
    return true;
  }
  return false;
}

function logout() {
  sessionStorage.removeItem('authenticated');
  sessionStorage.removeItem('username');
  window.location.href = 'index.html';
}

// Check authentication on page load
document.addEventListener('DOMContentLoaded', function() {
  if (!isAuthenticated() && window.location.pathname !== '/index.html') {
    window.location.href = 'index.html';
  }
});
```

### API Integration
```javascript
// api.js
const API_ENDPOINT = 'https://api.example.com';
const API_KEY = 'your-api-key';

async function apiCall(path, method, data) {
  try {
    const response = await fetch(`${API_ENDPOINT}${path}`, {
      method: method,
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': API_KEY
      },
      body: data ? JSON.stringify(data) : undefined
    });
    
    return await response.json();
  } catch (error) {
    console.error('API Error:', error);
    return { error: error.message };
  }
}
```

## Deployment Steps

1. Set up AWS infrastructure (S3, API Gateway, IAM)
2. Create and deploy Lambda functions
3. Build and upload website files
4. Test end-to-end functionality
5. Configure monitoring and logging

## Cost Estimates (Monthly)

| Service | Usage | Est. Cost |
|---------|-------|-----------|
| S3 Website (myortho) | Using existing bucket | $0.00 |
| S3 Campaign Storage (greendotball-bot-data) | Using existing bucket | $0.00 |
| API Gateway | ~20K requests/month | $0.20 |
| Lambda | ~20K executions/month | $0.10 |
| **TOTAL** |  | **~$0.45/month** |
