# Dynamic Mobile + Image Assignment System
## 10,000 Submissions with Zero Duplicates

---

## 🎯 Overview

**Goal:** 100 mobile numbers × 100 images each = 10,000 unique submissions

**Strategy:**
- Each EC2 instance = 1 mobile number + 100 unique images
- Instance 1: Mobile #1 + Images 1-100
- Instance 2: Mobile #2 + Images 101-200
- Instance 100: Mobile #100 + Images 9901-10000

**Key Innovation:** Use EC2 User Data to pass unique `MOBILE_INDEX` to each instance at launch.

---

## 📁 Step 1: Organize Your Data

### 1.1: Prepare 100 Mobile Numbers

Create a file with 100 phone numbers:

**Local file: `data/mobile-numbers.txt`**
```
9911329839
8368210629
9708064895
... (100 lines total)
```

### 1.2: Organize 10,000 Images into 100 Batches

**Folder structure:**
```
data/image-batches/
├── batch-001/  (100 images: img-0001.jpg to img-0100.jpg)
├── batch-002/  (100 images: img-0101.jpg to img-0200.jpg)
├── batch-003/  (100 images: img-0201.jpg to img-0300.jpg)
├── ...
└── batch-100/  (100 images: img-9901.jpg to img-10000.jpg)
```

**Script to organize images:**
```bash
#!/bin/bash
# organize-images.sh

SOURCE_DIR="./all-images"
OUTPUT_DIR="./data/image-batches"
BATCH_SIZE=100

mkdir -p $OUTPUT_DIR

# Get all images
images=($(ls $SOURCE_DIR/*.{jpg,png,jpeg} 2>/dev/null))
total=${#images[@]}

echo "Found $total images"

# Split into batches
batch_num=1
for ((i=0; i<$total; i+=$BATCH_SIZE)); do
  batch_dir=$(printf "$OUTPUT_DIR/batch-%03d" $batch_num)
  mkdir -p $batch_dir
  
  # Copy 100 images to this batch
  for ((j=0; j<$BATCH_SIZE && (i+j)<$total; j++)); do
    cp "${images[$((i+j))]}" "$batch_dir/"
  done
  
  echo "Created $batch_dir with $(ls $batch_dir | wc -l) images"
  ((batch_num++))
done

echo "Created $((batch_num-1)) batches"
```

### 1.3: Upload to S3

```bash
# Upload mobile numbers
aws s3 cp data/mobile-numbers.txt s3://greendotball-bot-data/config/mobile-numbers.txt

# Upload all image batches
aws s3 sync data/image-batches/ s3://greendotball-bot-data/images/batches/

# Verify
aws s3 ls s3://greendotball-bot-data/images/batches/
```

---

## 🤖 Step 2: Update Bot Code

### 2.1: Modify bot.js to Accept Mobile Index

**Add CLI argument parsing:**

```javascript
// At the top of src/bot.js, after imports
const args = process.argv.slice(2);
let mobileIndex = null;
let imageBatch = null;

for (let i = 0; i < args.length; i++) {
  if (args[i] === '--mobile-index' && args[i + 1]) {
    mobileIndex = parseInt(args[i + 1]);
  }
  if (args[i] === '--image-batch' && args[i + 1]) {
    imageBatch = args[i + 1];
  }
}

// Export for use in bot
global.MOBILE_INDEX = mobileIndex;
global.IMAGE_BATCH = imageBatch;
```

### 2.2: Create Dynamic Config Loader

**New file: `src/dynamicConfig.js`**

```javascript
const fs = require('fs');
const path = require('path');
const logger = require('./utils/logger');

class DynamicConfig {
  static async loadMobileNumber(index) {
    try {
      const mobileFile = path.join(__dirname, '../data/mobile-numbers.txt');
      const mobiles = fs.readFileSync(mobileFile, 'utf8')
        .split('\n')
        .filter(line => line.trim());
      
      if (index < 1 || index > mobiles.length) {
        throw new Error(`Mobile index ${index} out of range (1-${mobiles.length})`);
      }
      
      const mobile = mobiles[index - 1];
      logger.info(`Loaded mobile number for index ${index}: ${mobile.substring(0, 3)}****`);
      return mobile;
    } catch (error) {
      logger.error('Failed to load mobile number:', error.message);
      throw error;
    }
  }

  static async loadImageBatch(batchNumber) {
    try {
      const batchDir = path.join(__dirname, `../data/image-batches/batch-${batchNumber.toString().padStart(3, '0')}`);
      
      if (!fs.existsSync(batchDir)) {
        throw new Error(`Batch directory not found: ${batchDir}`);
      }
      
      const images = fs.readdirSync(batchDir)
        .filter(file => /\.(jpg|jpeg|png)$/i.test(file))
        .map(file => path.join(batchDir, file));
      
      logger.info(`Loaded ${images.length} images from batch ${batchNumber}`);
      return images;
    } catch (error) {
      logger.error('Failed to load image batch:', error.message);
      throw error;
    }
  }
}

module.exports = DynamicConfig;
```

### 2.3: Update Bot to Use Dynamic Config

**Modify `src/bot.js` runBatch method:**

```javascript
async runBatch() {
  try {
    logger.info('Starting batch submission mode...');
    
    // Load dynamic config if mobile index provided
    let phoneNumber;
    let imagePaths;
    
    if (global.MOBILE_INDEX) {
      const DynamicConfig = require('./dynamicConfig');
      
      // Load assigned mobile number
      phoneNumber = await DynamicConfig.loadMobileNumber(global.MOBILE_INDEX);
      
      // Load assigned image batch
      imagePaths = await DynamicConfig.loadImageBatch(global.MOBILE_INDEX);
      
      logger.info(`Instance assigned: Mobile Index ${global.MOBILE_INDEX}, ${imagePaths.length} images`);
    } else {
      // Fallback to config.json (old behavior)
      phoneNumber = this.config.phoneNumbers[0];
      imagePaths = this.config.images;
    }
    
    const maxSubmissions = imagePaths.length; // Submit all assigned images
    const results = [];
    
    for (let i = 0; i < maxSubmissions; i++) {
      const submissionNum = i + 1;
      logger.info(`\n${'='.repeat(60)}`);
      logger.info(`📤 SUBMISSION ${submissionNum}/${maxSubmissions}`);
      logger.info(`${'='.repeat(60)}`);
      
      const imagePath = imagePaths[i];
      
      try {
        await this.submitForm(phoneNumber, imagePath);
        
        logger.info(`✅ SUCCESS: Submission ${submissionNum}/${maxSubmissions}`);
        logger.info(`   Mobile: ${maskPhoneNumber(phoneNumber)}`);
        logger.info(`   Image: ${path.basename(imagePath)}`);
        
        results.push({ 
          submission: submissionNum, 
          status: 'success',
          phone: phoneNumber,
          image: path.basename(imagePath)
        });
        
        this.submissionCount++;
        
        if (submissionNum < maxSubmissions) {
          const delay = this.config.delayBetweenSubmissions || 3000;
          logger.info(`⏳ Waiting ${delay}ms before next submission...`);
          await sleep(delay);
        }
      } catch (error) {
        logger.error(`❌ FAILED: Submission ${submissionNum}/${maxSubmissions}`);
        logger.error(`   Error: ${error.message}`);
        
        results.push({ 
          submission: submissionNum, 
          status: 'failed', 
          error: error.message,
          phone: phoneNumber,
          image: path.basename(imagePath)
        });
      }
    }
    
    // Summary
    const successful = results.filter(r => r.status === 'success').length;
    const failed = results.filter(r => r.status === 'failed').length;
    
    logger.info(`\n${'='.repeat(60)}`);
    logger.info(`📊 BATCH SUMMARY`);
    logger.info(`${'='.repeat(60)}`);
    logger.info(`Total Submissions: ${maxSubmissions}`);
    logger.info(`✅ Successful: ${successful}`);
    logger.info(`❌ Failed: ${failed}`);
    logger.info(`📱 Mobile Used: ${maskPhoneNumber(phoneNumber)}`);
    logger.info(`🖼️  Images Processed: ${imagePaths.length}`);
    if (global.MOBILE_INDEX) {
      logger.info(`🏷️  Instance Index: ${global.MOBILE_INDEX}`);
    }
    logger.info(`${'='.repeat(60)}\n`);
    
    return results;
  } catch (error) {
    logger.error('Batch execution failed:', error.message);
    throw error;
  }
}
```

---

## 🚀 Step 3: Create Dynamic Startup Script

**New file: `/opt/greendotball-bot/run-bot-dynamic.sh`**

```bash
#!/bin/bash
set -e

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
INSTANCE_ID=$(ec2-metadata --instance-id | cut -d ' ' -f 2)
echo "Instance ID: $INSTANCE_ID" | tee -a $LOG_FILE

# Get MOBILE_INDEX from EC2 user-data
echo "Fetching mobile index from user-data..." | tee -a $LOG_FILE
MOBILE_INDEX=$(ec2-metadata --user-data | grep -oP 'MOBILE_INDEX=\K\d+' || echo "")

if [ -z "$MOBILE_INDEX" ]; then
  echo "ERROR: MOBILE_INDEX not found in user-data" | tee -a $LOG_FILE
  exit 1
fi

echo "Assigned Mobile Index: $MOBILE_INDEX" | tee -a $LOG_FILE
echo "========================================" | tee -a $LOG_FILE

cd /opt/greendotball-bot

# Download mobile numbers list
echo "Downloading mobile numbers..." | tee -a $LOG_FILE
aws s3 cp s3://greendotball-bot-data/config/mobile-numbers.txt ./data/mobile-numbers.txt 2>&1 | tee -a $LOG_FILE

# Download assigned image batch
BATCH_NUM=$(printf "%03d" $MOBILE_INDEX)
echo "Downloading image batch $BATCH_NUM..." | tee -a $LOG_FILE
aws s3 sync s3://greendotball-bot-data/images/batches/batch-$BATCH_NUM/ ./data/image-batches/batch-$BATCH_NUM/ 2>&1 | tee -a $LOG_FILE

IMAGE_COUNT=$(ls ./data/image-batches/batch-$BATCH_NUM/ | wc -l)
echo "Downloaded $IMAGE_COUNT images" | tee -a $LOG_FILE

sleep 5

# Run bot with mobile index
echo "Starting bot execution..." | tee -a $LOG_FILE
echo "Command: node src/bot.js --batch --mobile-index $MOBILE_INDEX" | tee -a $LOG_FILE
node src/bot.js --batch --mobile-index $MOBILE_INDEX 2>&1 | tee -a $LOG_FILE

EXIT_CODE=$?
echo "Bot finished with exit code: $EXIT_CODE" | tee -a $LOG_FILE

# Upload logs to S3
echo "Uploading logs to S3..." | tee -a $LOG_FILE
aws s3 cp $LOG_FILE "s3://greendotball-bot-data/logs/$INSTANCE_ID/$TIMESTAMP.log" 2>&1 | tee -a $LOG_FILE
aws s3 cp /opt/greendotball-bot/logs/ "s3://greendotball-bot-data/logs/$INSTANCE_ID/" --recursive 2>&1 | tee -a $LOG_FILE

echo "Script completed at $(date)" | tee -a $LOG_FILE

# Auto-shutdown
echo "Shutting down instance in 60 seconds..." | tee -a $LOG_FILE
sleep 60
sudo shutdown -h now
```

---

## 🏷️ Step 4: Update Launch Template with User Data

### Via AWS Console

1. **EC2 Console** → **Launch Templates**
2. Select `greendotball-bot-template`
3. **Actions** → **Modify template (Create new version)**
4. Scroll to **Advanced details**
5. **User data** field - Enter:

```bash
#!/bin/bash
MOBILE_INDEX=1
```

**Note:** This is a placeholder. We'll override it when launching instances.

6. **Create template version**
7. **Set as default version**

---

## 🚀 Step 5: Launch 100 Instances with Unique Assignments

### Option A: Manual Launch (AWS Console)

Launch instances one by one, changing user-data each time:

**For Instance 1:**
```bash
#!/bin/bash
MOBILE_INDEX=1
```

**For Instance 2:**
```bash
#!/bin/bash
MOBILE_INDEX=2
```

... (repeat 100 times)

### Option B: Automated Launch (AWS CLI Script) ⭐ RECOMMENDED

**Create launcher script: `launch-100-instances.sh`**

```bash
#!/bin/bash

TEMPLATE_NAME="greendotball-bot-template"
REGION="ap-south-1"

echo "Launching 100 instances with unique mobile assignments..."

for i in {1..100}; do
  USER_DATA=$(echo "#!/bin/bash
MOBILE_INDEX=$i" | base64)
  
  echo "Launching instance $i/100 (Mobile Index: $i)..."
  
  aws ec2 run-instances \
    --region $REGION \
    --launch-template LaunchTemplateName=$TEMPLATE_NAME \
    --user-data "$USER_DATA" \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=greendotball-worker-$i},{Key=MobileIndex,Value=$i},{Key=Project,Value=greendotball}]" \
    --count 1 \
    > /dev/null
  
  if [ $? -eq 0 ]; then
    echo "✅ Instance $i launched successfully"
  else
    echo "❌ Instance $i failed to launch"
  fi
  
  # Small delay to avoid API throttling
  sleep 2
done

echo "All 100 instances launched!"
echo "Each instance will process 100 images with its assigned mobile number"
echo "Total: 10,000 submissions"
```

**Run the launcher:**
```bash
chmod +x launch-100-instances.sh
./launch-100-instances.sh
```

---

## 📊 Step 6: Monitor Progress

### Check Running Instances

```bash
# Count running instances
aws ec2 describe-instances \
  --filters "Name=tag:Project,Values=greendotball" "Name=instance-state-name,Values=running" \
  --query 'Reservations[*].Instances[*].[InstanceId,Tags[?Key==`MobileIndex`].Value|[0],State.Name]' \
  --output table
```

### Monitor Logs in S3

```bash
# List all logs
aws s3 ls s3://greendotball-bot-data/logs/ --recursive

# Download all logs
aws s3 sync s3://greendotball-bot-data/logs/ ./downloaded-logs/

# Count successful submissions
grep -r "✅ SUCCESS" ./downloaded-logs/ | wc -l
```

### CloudWatch Dashboard (Optional)

Create metrics to track:
- Instances launched
- Submissions completed
- Success rate
- Estimated completion time

---

## 💰 Cost Estimation

### Per Run (100 instances, ~20 min each)

**On-Demand:**
- 100 instances × 0.33 hours × $0.0312/hour = **$1.03**

**Spot (if available):**
- 100 instances × 0.33 hours × $0.0093/hour = **$0.31**

### Total for 10,000 Submissions

- **$1.03** (On-Demand) or **$0.31** (Spot)
- **$0.0001 per submission**

Extremely cost-effective! 🎉

---

## ✅ Summary

**What you've built:**
1. ✅ 100 mobile numbers × 100 images each
2. ✅ Zero duplicate submissions
3. ✅ Fully automated assignment via user-data
4. ✅ Auto-shutdown after completion
5. ✅ Centralized logging in S3
6. ✅ One-click launch for 10,000 submissions

**How to use:**
1. Organize data (mobiles + images)
2. Upload to S3
3. Update bot code
4. Create new AMI
5. Run launch script
6. Wait 20-30 minutes
7. Download logs from S3

**Result:** 10,000 unique submissions for ~$1! 🚀
