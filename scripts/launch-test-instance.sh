#!/bin/bash
# launch-test-instance.sh
# Launches a single test EC2 instance for campaign creation and testing
# This instance will NOT auto-shutdown and can be used interactively
#
# Usage:
#   ./scripts/launch-test-instance.sh

set -e

# ── Config ────────────────────────────────────────────────────────────────────
AMI_ID="ami-069329948418953db"          # greendotball-bot AMI
INSTANCE_TYPE="t3.small"
KEY_NAME="greendotball-bot-key-v2"
SECURITY_GROUP_NAME="greendotball-bot-sg"
IAM_ROLE="EC2-GreenDotBall-S3-Access"
REGION="ap-south-1"
INSTANCE_NAME="greendotball-test-instance"

echo ""
echo "=================================================="
echo "  LAUNCH TEST INSTANCE"
echo "=================================================="
echo "  Name      : $INSTANCE_NAME"
echo "  AMI       : $AMI_ID"
echo "  Type      : $INSTANCE_TYPE"
echo "  Region    : $REGION"
echo "  Purpose   : Campaign creation & testing"
echo "  Shutdown  : MANUAL (will not auto-shutdown)"
echo "=================================================="
echo ""

# ── Get security group ID ─────────────────────────────────────────────────────
echo "Fetching security group ID..."
SECURITY_GROUP_ID=$(aws ec2 describe-security-groups \
  --region "$REGION" \
  --filters "Name=group-name,Values=$SECURITY_GROUP_NAME" \
  --query 'SecurityGroups[0].GroupId' \
  --output text)

if [ -z "$SECURITY_GROUP_ID" ] || [ "$SECURITY_GROUP_ID" == "None" ]; then
  echo "❌ ERROR: Security group '$SECURITY_GROUP_NAME' not found in $REGION"
  exit 1
fi
echo "  ✅ Security Group: $SECURITY_GROUP_ID"
echo ""

# ── Confirm ───────────────────────────────────────────────────────────────────
read -p "Launch test instance? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
  echo "Aborted."
  exit 0
fi

echo ""
echo "Launching instance..."
echo ""

# USER_DATA: Disable auto-shutdown for test instance
USER_DATA=$(cat <<'EOF'
#!/bin/bash
# Test instance - disable auto-shutdown
mkdir -p /etc
cat > /etc/greendotball-env <<ENVEOF
TEST_MODE=true
DISABLE_AUTO_SHUTDOWN=true
ENVEOF
chmod 644 /etc/greendotball-env

# Disable the auto-start service for test instance
systemctl disable greendotball-job-bot.service || true
EOF
)

# Launch instance
RESULT=$(aws ec2 run-instances \
  --region "$REGION" \
  --image-id "$AMI_ID" \
  --instance-type "$INSTANCE_TYPE" \
  --key-name "$KEY_NAME" \
  --security-group-ids "$SECURITY_GROUP_ID" \
  --iam-instance-profile "Name=$IAM_ROLE" \
  --user-data "$USER_DATA" \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=${INSTANCE_NAME}},{Key=Purpose,Value=test},{Key=Project,Value=greendotball},{Key=AutoShutdown,Value=disabled}]" \
  --count 1 \
  --output json 2>&1)

EXIT_CODE=$?

if [ $EXIT_CODE -ne 0 ]; then
  echo "❌ ERROR: Failed to launch instance"
  echo "$RESULT"
  exit 1
fi

# Extract instance ID
INSTANCE_ID=$(echo "$RESULT" | grep -o '"InstanceId": "[^"]*"' | head -1 | cut -d'"' -f4)

if [ -z "$INSTANCE_ID" ]; then
  echo "❌ ERROR: Could not extract instance ID"
  exit 1
fi

echo "  ✅ Instance launched: $INSTANCE_ID"
echo ""
echo "Waiting for instance to start..."

# Wait for instance to be running
aws ec2 wait instance-running \
  --region "$REGION" \
  --instance-ids "$INSTANCE_ID"

# Get public IP
PUBLIC_IP=$(aws ec2 describe-instances \
  --region "$REGION" \
  --instance-ids "$INSTANCE_ID" \
  --query 'Reservations[0].Instances[0].PublicIpAddress' \
  --output text)

echo ""
echo "=================================================="
echo "  TEST INSTANCE READY"
echo "=================================================="
echo "  Instance ID   : $INSTANCE_ID"
echo "  Public IP     : $PUBLIC_IP"
echo "  SSH Key       : $KEY_NAME"
echo "  Auto-shutdown : DISABLED"
echo "=================================================="
echo ""
echo "📌 CONNECT TO INSTANCE:"
echo "   ssh -i ~/.ssh/${KEY_NAME}.pem ec2-user@${PUBLIC_IP}"
echo ""
echo "📌 USEFUL COMMANDS ON INSTANCE:"
echo "   # Navigate to bot directory"
echo "   cd /opt/greendotball-bot"
echo ""
echo "   # Pull latest code"
echo "   git pull origin design-rethink"
echo ""
echo "   # Create campaign"
echo "   ./scripts/create-campaign-pool.sh"
echo ""
echo "   # Check S3 campaigns"
echo "   aws s3 ls s3://greendotball-bot-data/campaigns/"
echo ""
echo "   # Test run a job manually"
echo "   export CAMPAIGN_ID=your-campaign-id"
echo "   export JOB_IDS=job-001"
echo "   node src/bot_new.js"
echo ""
echo "📌 TERMINATE INSTANCE WHEN DONE:"
echo "   aws ec2 terminate-instances --region $REGION --instance-ids $INSTANCE_ID"
echo ""
echo "⚠️  REMEMBER: This instance will NOT auto-shutdown!"
echo "    You must manually terminate it to avoid charges."
echo ""
