# Auto-Features Documentation

## 🚀 Automated Features

This document describes the automated features that make deployment and cost management easier.

---

## Feature 1: Auto-Detect Instance Count

### Overview
The launch script automatically detects how many instances to launch based on the number of mobile numbers in your file.

### How It Works

**Before:**
```bash
# Had to manually specify: TOTAL_INSTANCES=100
./launch-100-instances.sh
```

**Now:**
```bash
# Automatically reads mobile-numbers.txt and launches that many instances
./launch-100-instances.sh
```

### Example

**If you have 50 mobile numbers:**
```bash
# data/mobile-numbers.txt contains 50 lines
./launch-100-instances.sh

# Output:
# Auto-detected 50 mobile numbers from data/mobile-numbers.txt
# Will launch 50 instances (1 per mobile number)
```

**If you have 100 mobile numbers:**
```bash
# data/mobile-numbers.txt contains 100 lines
./launch-100-instances.sh

# Output:
# Auto-detected 100 mobile numbers from data/mobile-numbers.txt
# Will launch 100 instances (1 per mobile number)
```

### Benefits
- ✅ No manual configuration needed
- ✅ Prevents launching too many or too few instances
- ✅ Scales automatically with your data
- ✅ Reduces human error

---

## Feature 2: 45-Minute Auto-Termination

### Overview
Every instance has a built-in 45-minute failsafe timer that automatically terminates the instance if it doesn't complete normally.

### How It Works

**Timeline:**
```
0:00  - Instance starts
0:00  - Failsafe timer starts (45 minutes)
0:20  - Bot completes normally
0:20  - Failsafe timer cancelled
0:21  - Instance shuts down normally (1 minute after completion)
```

**If bot hangs or fails:**
```
0:00  - Instance starts
0:00  - Failsafe timer starts (45 minutes)
0:10  - Bot hangs/crashes
45:00 - Failsafe timer triggers
45:00 - Instance force-terminated
```

### Why 45 Minutes?

**Expected runtime:**
- 100 images × ~25 seconds each = ~42 minutes
- Plus buffer for S3 downloads, log uploads, etc.
- **45 minutes = safe maximum**

### Cost Protection

**Without auto-termination:**
- Instance runs forever if bot crashes
- Cost: $0.0312/hour × 24 hours = $0.75/day per instance
- 100 instances = **$75/day** if all hang!

**With auto-termination:**
- Maximum runtime: 45 minutes
- Maximum cost per instance: $0.0234
- 100 instances max cost: **$2.34** (even if all hang)

### Implementation Details

**In `run-bot-dynamic.sh`:**

```bash
# Start failsafe timer in background
(
  sleep 2700  # 45 minutes
  echo "⚠️  FAILSAFE: 45-minute timeout reached - forcing shutdown"
  sudo shutdown -h now
) &
FAILSAFE_PID=$!

# ... bot runs ...

# Cancel timer if bot completes successfully
kill $FAILSAFE_PID 2>/dev/null || true
```

### Monitoring

**Check if failsafe triggered:**
```bash
# Download logs from S3
aws s3 sync s3://greendotball-bot-data/logs/ ./logs/

# Search for failsafe triggers
grep "FAILSAFE" ./logs/*/*.log

# If found, investigate why bot didn't complete in 45 minutes
```

---

## Feature 3: Normal Auto-Shutdown (1 minute after completion)

### Overview
When bot completes successfully, instance waits 60 seconds then shuts down.

### Why Wait 60 Seconds?

1. **Log upload time** - Ensures S3 uploads complete
2. **Graceful shutdown** - Allows cleanup operations
3. **Debug window** - Time to SSH in if needed

### Timeline

```
Bot completes → Wait 60s → Shutdown
```

**Example:**
```
19:05:51 - Bot completes (5/5 submissions)
19:05:51 - Uploads logs to S3
19:05:52 - "Shutting down instance in 60 seconds..."
19:06:52 - Instance terminates
```

---

## Combined Protection

### Three Layers of Auto-Termination

1. **Normal completion** (60 seconds after bot finishes)
   - Expected: ~20-25 minutes for 100 images
   - Cost: ~$0.01 per instance

2. **Failsafe timer** (45 minutes maximum)
   - Triggers if bot hangs/crashes
   - Cost: ~$0.023 per instance

3. **Manual termination** (as backup)
   - You can always manually terminate via AWS Console
   - Use if you need to stop immediately

### Cost Comparison

| Scenario | Runtime | Cost per Instance | 100 Instances |
|----------|---------|-------------------|---------------|
| Normal completion | 20 min | $0.0104 | $1.04 |
| Bot hangs (failsafe) | 45 min | $0.0234 | $2.34 |
| No auto-termination | 24 hours | $0.7488 | $74.88 |

**Savings: Up to $72 per day with auto-termination!**

---

## Usage Examples

### Example 1: Launch Based on Mobile Count

```bash
# Step 1: Prepare mobile numbers (any count)
cat > data/mobile-numbers.txt << EOF
9911329839
8368210629
9708064895
EOF

# Step 2: Launch (automatically detects 3 mobiles)
./scripts/launch-100-instances.sh

# Output:
# Auto-detected 3 mobile numbers
# Will launch 3 instances
# ...launches 3 instances with MOBILE_INDEX=1,2,3
```

### Example 2: Scale to 100 Instances

```bash
# Step 1: Add 100 mobile numbers to file
# (one per line)

# Step 2: Launch
./scripts/launch-100-instances.sh

# Output:
# Auto-detected 100 mobile numbers
# Will launch 100 instances
# ...launches 100 instances automatically
```

### Example 3: Monitor Failsafe Triggers

```bash
# After instances complete, check logs
aws s3 sync s3://greendotball-bot-data/logs/ ./logs/

# Check for failsafe triggers
grep -r "FAILSAFE" ./logs/

# If found:
# ⚠️  FAILSAFE: 45-minute timeout reached - forcing shutdown

# Investigate:
# - Check bot logs for errors
# - Verify image count (maybe too many images?)
# - Check network issues (S3 download slow?)
```

---

## Configuration

### Adjust Failsafe Timer

If you need more or less time, edit `run-bot-dynamic.sh`:

```bash
# Change this line:
sleep 2700  # 45 minutes = 2700 seconds

# For 30 minutes:
sleep 1800

# For 60 minutes:
sleep 3600
```

### Adjust Normal Shutdown Delay

```bash
# Change this line:
sleep 60  # 60 seconds

# For immediate shutdown:
sleep 0

# For 2 minutes:
sleep 120
```

---

## Troubleshooting

### Instance didn't terminate after 45 minutes

**Possible causes:**
1. Failsafe timer process was killed
2. Shutdown command failed
3. Instance has shutdown protection enabled

**Solution:**
```bash
# Manually terminate via AWS Console or CLI
aws ec2 terminate-instances --instance-ids i-xxxxx
```

### All instances terminated early

**Check:**
1. Bot crashed early (check logs)
2. S3 download failed (check IAM permissions)
3. Image batch not found (verify S3 structure)

**Debug:**
```bash
# SSH into a test instance before it terminates
ssh -i key.pem ec2-user@<ip>

# Check logs
sudo journalctl -u greendotball-bot.service -n 100
tail -f /var/log/greendotball-bot/*.log
```

### Want to prevent auto-termination for debugging

**Temporarily disable:**
```bash
# SSH into instance
ssh -i key.pem ec2-user@<ip>

# Edit startup script
sudo nano /opt/greendotball-bot/run-bot.sh

# Comment out these lines:
# sleep 60
# sudo shutdown -h now

# Save and reboot to test
sudo reboot
```

---

## Summary

### Auto-Features Enabled

✅ **Auto-detect instance count** - Reads mobile-numbers.txt  
✅ **45-minute failsafe** - Prevents runaway costs  
✅ **60-second graceful shutdown** - Normal completion  
✅ **Cost protection** - Maximum $2.34 for 100 instances (vs $75 without)  

### Cost Savings

- **Normal run**: $1.04 for 100 instances (20 min each)
- **Worst case**: $2.34 for 100 instances (45 min each)
- **Without protection**: $74.88+ for 100 instances (24 hours)

**Savings: Up to 97% cost reduction!** 🎉

---

## Next Steps

1. ✅ Test locally with small mobile count (3-5)
2. ✅ Deploy to EC2 and create AMI
3. ✅ Test with 1 instance to verify auto-termination
4. ✅ Scale to full deployment (100 instances)
5. ✅ Monitor logs in S3 for any failsafe triggers

Ready to deploy with confidence! 🚀
