# Quick Start: Dynamic Assignment System

## 🚀 Setup in 7 Steps

### Step 1: Prepare Your Data (Local Machine)

**Create mobile numbers file:**
```bash
# Create a file with 100 phone numbers (one per line)
nano data/mobile-numbers.txt
```

Example content:
```
9911329839
8368210629
9708064895
... (100 lines total)
```

**Organize your 10,000 images:**
```bash
# Put all images in one folder
mkdir -p all-images
# Copy your 10,000 images here

# Run the organizer script
chmod +x scripts/organize-images.sh
./scripts/organize-images.sh all-images data/image-batches

# This creates:
# data/image-batches/batch-001/ (100 images)
# data/image-batches/batch-002/ (100 images)
# ... batch-100/ (100 images)
```

---

### Step 2: Upload to S3

```bash
# Upload mobile numbers
aws s3 cp data/mobile-numbers.txt s3://greendotball-bot-data/config/mobile-numbers.txt

# Upload all image batches
aws s3 sync data/image-batches/ s3://greendotball-bot-data/images/batches/

# Verify upload
aws s3 ls s3://greendotball-bot-data/images/batches/
```

---

### Step 3: Update Bot Code on EC2

**SSH into your base EC2 instance:**
```bash
ssh -i greendotball-bot-key.pem ec2-user@<your-instance-ip>
```

**Pull latest code:**
```bash
cd /opt/greendotball-bot
git pull origin main

# Or manually upload the new files:
# - src/bot.js (updated)
# - src/dynamicConfig.js (new)
```

**Copy the dynamic startup script:**
```bash
# Upload from local machine
scp -i greendotball-bot-key.pem scripts/run-bot-dynamic.sh ec2-user@<ip>:/tmp/

# On EC2 instance
sudo cp /tmp/run-bot-dynamic.sh /opt/greendotball-bot/run-bot.sh
sudo chmod +x /opt/greendotball-bot/run-bot.sh
```

---

### Step 4: Test with Single Instance

**Test locally first:**
```bash
# On EC2 instance
cd /opt/greendotball-bot

# Create test data
mkdir -p data/image-batches/batch-001
echo "9911329839" > data/mobile-numbers.txt

# Copy 5 test images to batch-001
# (for quick testing)

# Test with mobile index 1
node src/bot.js --batch --mobile-index 1
```

**Expected output:**
```
🎯 DYNAMIC ASSIGNMENT MODE - Mobile Index: 1
Assigned Mobile: 991****39
Assigned Images: 5
Total Submissions: 5
...
✅ SUCCESS #1: Phone 991****39 | Image: img-001.jpg
...
📊 BATCH SUMMARY
Total submissions: 5
✅ Successful: 5
❌ Failed: 0
🏷️  Mobile Index: 1
📱 Mobile Number: 991****39
```

---

### Step 5: Create New AMI

**Clean up and create AMI:**
```bash
# On EC2 instance
history -c
cat /dev/null > ~/.bash_history
sudo rm -rf /var/log/greendotball-bot/*
sudo rm -rf /opt/greendotball-bot/logs/*
exit
```

**Via AWS Console:**
1. EC2 → Instances
2. Select your base instance
3. Instance state → Stop instance
4. Actions → Image and templates → Create image
5. Name: `greendotball-bot-dynamic-v1`
6. Description: `Bot with dynamic mobile+image assignment`
7. Create image
8. Wait 5-10 minutes for AMI to be ready

---

### Step 6: Update Launch Template

**Via AWS Console:**
1. EC2 → Launch Templates
2. Select `greendotball-bot-template`
3. Actions → Modify template (Create new version)
4. **Application and OS Images:**
   - My AMIs → Select `greendotball-bot-dynamic-v1`
5. **Advanced details → User data:**
   ```bash
   #!/bin/bash
   MOBILE_INDEX=1
   ```
   (This is a placeholder - will be overridden at launch)
6. Create template version
7. Actions → Set default version → Select new version

---

### Step 7: Launch 100 Instances

**Option A: Automated (Recommended)**

```bash
# On your local machine
chmod +x scripts/launch-100-instances.sh
./scripts/launch-100-instances.sh
```

This will:
- Launch 100 instances
- Each with unique MOBILE_INDEX (1-100)
- Auto-tag each instance
- Show progress in real-time

**Option B: Manual (AWS Console)**

For each instance (1-100):
1. EC2 → Launch Templates
2. Select template → Actions → Launch instance from template
3. **Advanced details → User data:**
   ```bash
   #!/bin/bash
   MOBILE_INDEX=1  # Change this: 1, 2, 3...100
   ```
4. Launch instance
5. Repeat with MOBILE_INDEX=2, 3, 4...100

---

## 📊 Monitoring

### Check Running Instances
```bash
aws ec2 describe-instances \
  --filters "Name=tag:Project,Values=greendotball" "Name=instance-state-name,Values=running" \
  --query 'Reservations[*].Instances[*].[InstanceId,Tags[?Key==`MobileIndex`].Value|[0],State.Name]' \
  --output table
```

### Monitor Logs in S3
```bash
# List all logs
aws s3 ls s3://greendotball-bot-data/logs/ --recursive

# Download logs
aws s3 sync s3://greendotball-bot-data/logs/ ./logs/

# Count successful submissions
grep -r "✅ SUCCESS" ./logs/ | wc -l
```

### Check Progress
```bash
# Count completed instances (logs uploaded)
aws s3 ls s3://greendotball-bot-data/logs/ | wc -l

# Expected: 100 folders (one per instance)
```

---

## 🎯 Expected Results

**Per Instance:**
- 1 mobile number
- 100 images
- 100 submissions
- ~20 minutes runtime
- Auto-shutdown after completion

**Total (100 instances):**
- 100 mobile numbers
- 10,000 images
- 10,000 submissions
- ~20-30 minutes total time
- Cost: ~$1 (On-Demand) or ~$0.31 (Spot)

---

## 🔧 Troubleshooting

### Instance not starting
- Check launch template has correct AMI
- Verify IAM role attached
- Check security group allows SSH

### Bot fails with "Mobile numbers file not found"
- Verify S3 upload: `aws s3 ls s3://greendotball-bot-data/config/mobile-numbers.txt`
- Check IAM role has S3 permissions

### Bot fails with "Batch directory not found"
- Verify S3 upload: `aws s3 ls s3://greendotball-bot-data/images/batches/`
- Check batch numbers are formatted correctly (batch-001, batch-002, etc.)

### No logs in S3
- Check instance has internet access
- Verify IAM role has S3 write permissions
- SSH into instance and check: `sudo journalctl -u greendotball-bot.service -n 50`

### Instances not shutting down
- Check run-bot.sh has `sudo shutdown -h now` at the end
- Verify script completed successfully
- Manually terminate if needed

---

## 💡 Tips

1. **Test with 1 instance first** before launching 100
2. **Monitor first few instances** to ensure everything works
3. **Use Spot instances** to save 70% on costs (if limit allows)
4. **Launch in batches** if you hit API limits (e.g., 20 at a time)
5. **Keep AMI updated** with latest bot code
6. **Tag instances properly** for easy tracking and cost allocation

---

## 📝 Summary

You've built a fully automated system that:
- ✅ Assigns unique mobile + images to each instance
- ✅ Zero duplicate submissions
- ✅ Scales to 100+ instances
- ✅ Auto-shuts down after completion
- ✅ Centralized logging in S3
- ✅ Costs ~$0.0001 per submission

**Total: 10,000 submissions for ~$1!** 🎉
