#!/bin/bash
# launch-campaign-instances.sh
# Launches 1 EC2 instance per job for a campaign created by create-campaign-pool.sh.
# Each instance runs bot_new.js for its assigned job and auto-shuts down within 50 min.
#
# Usage (run from repo root):
#   export CAMPAIGN_ID="apr-04-2026-pool-120055"
#   export JOB_IDS="job-001,job-002,job-003"
#   ./scripts/launch-campaign-instances.sh
#
# Or pass as arguments:
#   ./scripts/launch-campaign-instances.sh apr-04-2026-pool-120055 job-001,job-002,job-003

set -e

# ── Config ────────────────────────────────────────────────────────────────────
#AMI_ID="ami-062031225a90c8e48"          # greendotball-bot-v4 (working submissions, 2026-04-04)
AMI_ID="ami-069329948418953db"
INSTANCE_TYPE="t3.small"
KEY_NAME="greendotball-bot-key-v2"
SECURITY_GROUP_NAME="greendotball-bot-sg"
IAM_ROLE="EC2-GreenDotBall-S3-Access"
REGION="ap-south-1"
S3_BUCKET="greendotball-bot-data"
GIT_BRANCH="design-rethink"

# ── Read inputs ───────────────────────────────────────────────────────────────
CAMPAIGN_ID="${1:-${CAMPAIGN_ID:-}}"
JOB_IDS_CSV="${2:-${JOB_IDS:-}}"

if [ -z "$CAMPAIGN_ID" ]; then
  echo "❌ ERROR: CAMPAIGN_ID not set."
  echo "   export CAMPAIGN_ID=\"...\" && export JOB_IDS=\"...\" && ./scripts/launch-campaign-instances.sh"
  exit 1
fi

if [ -z "$JOB_IDS_CSV" ]; then
  echo "❌ ERROR: JOB_IDS not set."
  echo "   export JOB_IDS=\"job-001,job-002,...\""
  exit 1
fi

# Split comma-separated job IDs into array
IFS=',' read -r -a JOB_ARRAY <<< "$JOB_IDS_CSV"
TOTAL_JOBS=${#JOB_ARRAY[@]}

echo ""
echo "=================================================="
echo "  LAUNCH CAMPAIGN INSTANCES"
echo "  Campaign  : $CAMPAIGN_ID"
echo "  Jobs      : $TOTAL_JOBS"
echo "  AMI       : $AMI_ID"
echo "  Type      : $INSTANCE_TYPE"
echo "  Region    : $REGION"
echo "  Shutdown  : 55 min hard limit per instance"
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
# Skip confirmation if AUTO_CONFIRM=1 is set (e.g., from wave orchestrator)
if [[ "${AUTO_CONFIRM:-0}" == "1" ]]; then
  echo "Auto-confirming launch of $TOTAL_JOBS instances for campaign '$CAMPAIGN_ID'"
else
  read -p "Launch $TOTAL_JOBS instances for campaign '$CAMPAIGN_ID'? (yes/no): " confirm
  if [ "$confirm" != "yes" ]; then
    echo "Aborted."
    exit 0
  fi
fi

echo ""
echo "Launching instances..."
echo ""

SUCCESS_COUNT=0
FAIL_COUNT=0
INSTANCE_IDS=()
LAUNCH_TIMESTAMP=$(date +%Y%m%d-%H%M%S)

for i in "${!JOB_ARRAY[@]}"; do
  JOB_ID="${JOB_ARRAY[$i]}"
  INST_NUM=$((i + 1))
  INSTANCE_NAME="${CAMPAIGN_ID}-${JOB_ID}-inst-${INST_NUM}"

  # USER_DATA: write env vars to /etc/greendotball-env so run-job-bot.sh can source them
  USER_DATA=$(cat <<EOF
#!/bin/bash
mkdir -p /etc
cat > /etc/greendotball-env <<ENVEOF
CAMPAIGN_ID=${CAMPAIGN_ID}
JOB_IDS=${JOB_ID}
ENVEOF
chmod 644 /etc/greendotball-env
EOF
)

  RESULT=$(aws ec2 run-instances \
    --region "$REGION" \
    --image-id "$AMI_ID" \
    --instance-type "$INSTANCE_TYPE" \
    --key-name "$KEY_NAME" \
    --security-group-ids "$SECURITY_GROUP_ID" \
    --iam-instance-profile "Name=$IAM_ROLE" \
    --user-data "$USER_DATA" \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=${INSTANCE_NAME}},{Key=CampaignId,Value=${CAMPAIGN_ID}},{Key=JobId,Value=${JOB_ID}},{Key=BatchNum,Value=${INST_NUM}},{Key=Project,Value=greendotball},{Key=LaunchedAt,Value=${LAUNCH_TIMESTAMP}}]" \
    --count 1 \
    --output json 2>&1)

  EXIT_CODE=$?

  if [ $EXIT_CODE -eq 0 ]; then
    INSTANCE_ID=$(echo "$RESULT" | grep -o '"InstanceId": "[^"]*"' | head -1 | cut -d'"' -f4)
    echo "  ✅ [$INST_NUM/$TOTAL_JOBS] $INSTANCE_NAME → $INSTANCE_ID"
    INSTANCE_IDS+=("$INSTANCE_ID")
    SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
  else
    echo "  ❌ [$INST_NUM/$TOTAL_JOBS] $JOB_ID FAILED: $(echo "$RESULT" | tail -1)"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi

  # Throttle: pause every 10 launches
  if [ $(( INST_NUM % 10 )) -eq 0 ] && [ $INST_NUM -lt $TOTAL_JOBS ]; then
    echo "  ⏳ Pausing 5s to avoid API throttling..."
    sleep 5
  else
    sleep 0.5
  fi
done

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "=================================================="
echo "  LAUNCH SUMMARY"
echo "=================================================="
echo "  Total jobs      : $TOTAL_JOBS"
echo "  ✅ Launched     : $SUCCESS_COUNT"
echo "  ❌ Failed       : $FAIL_COUNT"
echo "  Auto-shutdown   : 55 min from launch"
echo ""

if [ $SUCCESS_COUNT -gt 0 ]; then
  echo "  Instance IDs:"
  printf '    %s\n' "${INSTANCE_IDS[@]}"
  echo ""
  echo "  Monitor (AWS console filter by CampaignId tag):"
  echo "    aws ec2 describe-instances --region $REGION \\"
  echo "      --filters \"Name=tag:CampaignId,Values=${CAMPAIGN_ID}\" \\"
  echo "      --query 'Reservations[*].Instances[*].[InstanceId,Tags[?Key==\`Name\`].Value|[0],State.Name]' \\"
  echo "      --output table"
  echo ""
  echo "  Check S3 logs:"
  echo "    aws s3 ls s3://${S3_BUCKET}/campaigns/${CAMPAIGN_ID}/logs/ --recursive"
  echo ""
  echo "  Check S3 results:"
  echo "    aws s3 ls s3://${S3_BUCKET}/campaigns/${CAMPAIGN_ID}/results/ --recursive"
  echo ""
  echo "  Terminate all immediately (emergency):"
  echo "    aws ec2 terminate-instances --region $REGION --instance-ids ${INSTANCE_IDS[*]}"
fi
echo ""
