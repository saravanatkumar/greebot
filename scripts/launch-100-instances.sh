#!/bin/bash

# Configuration
TEMPLATE_NAME="greendotball-bot-template"
REGION="ap-south-1"
MOBILE_FILE="data/mobile-numbers.txt"

# Auto-detect number of instances based on mobile numbers
if [ -f "$MOBILE_FILE" ]; then
  TOTAL_INSTANCES=$(grep -v '^$' "$MOBILE_FILE" | wc -l | tr -d ' ')
  echo "=========================================="
  echo "Auto-detected $TOTAL_INSTANCES mobile numbers from $MOBILE_FILE"
  echo "Will launch $TOTAL_INSTANCES instances (1 per mobile number)"
  echo "Template: $TEMPLATE_NAME"
  echo "Region: $REGION"
  echo "=========================================="
  echo ""
else
  echo "ERROR: Mobile numbers file not found: $MOBILE_FILE"
  echo "Please create the file with one mobile number per line."
  exit 1
fi

if [ "$TOTAL_INSTANCES" -eq 0 ]; then
  echo "ERROR: No mobile numbers found in $MOBILE_FILE"
  exit 1
fi

# Check if template exists
echo "Checking if launch template exists..."
aws ec2 describe-launch-templates \
  --region $REGION \
  --launch-template-names $TEMPLATE_NAME \
  > /dev/null 2>&1

if [ $? -ne 0 ]; then
  echo "ERROR: Launch template '$TEMPLATE_NAME' not found in region $REGION"
  echo "Please create the launch template first."
  exit 1
fi

echo "✓ Launch template found"
echo ""

# Confirm with user
read -p "This will launch $TOTAL_INSTANCES instances. Continue? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
  echo "Aborted."
  exit 0
fi

echo ""
echo "Starting instance launches..."
echo ""

SUCCESS_COUNT=0
FAIL_COUNT=0
INSTANCE_IDS=()

for i in $(seq 1 $TOTAL_INSTANCES); do
  # Create user-data with mobile index
  USER_DATA=$(echo "#!/bin/bash
MOBILE_INDEX=$i" | base64)
  
  echo "[$i/$TOTAL_INSTANCES] Launching instance with Mobile Index: $i..."
  
  # Launch instance
  RESULT=$(aws ec2 run-instances \
    --region $REGION \
    --launch-template LaunchTemplateName=$TEMPLATE_NAME \
    --user-data "$USER_DATA" \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=greendotball-worker-$i},{Key=MobileIndex,Value=$i},{Key=Project,Value=greendotball},{Key=Batch,Value=$(date +%Y%m%d-%H%M%S)}]" \
    --count 1 \
    2>&1)
  
  if [ $? -eq 0 ]; then
    INSTANCE_ID=$(echo "$RESULT" | grep -oP '"InstanceId":\s*"\K[^"]+' | head -1)
    echo "  ✅ Success - Instance ID: $INSTANCE_ID"
    INSTANCE_IDS+=("$INSTANCE_ID")
    ((SUCCESS_COUNT++))
  else
    echo "  ❌ Failed - Error: $RESULT"
    ((FAIL_COUNT++))
  fi
  
  # Small delay to avoid API throttling (adjust if needed)
  if [ $((i % 10)) -eq 0 ]; then
    echo "  ⏳ Pausing for 5 seconds to avoid API throttling..."
    sleep 5
  else
    sleep 1
  fi
done

echo ""
echo "=========================================="
echo "Launch Summary"
echo "=========================================="
echo "Total Requested: $TOTAL_INSTANCES"
echo "✅ Successful: $SUCCESS_COUNT"
echo "❌ Failed: $FAIL_COUNT"
echo "=========================================="
echo ""

if [ $SUCCESS_COUNT -gt 0 ]; then
  echo "Launched Instance IDs:"
  printf '%s\n' "${INSTANCE_IDS[@]}"
  echo ""
  
  echo "To monitor instances:"
  echo "  aws ec2 describe-instances --region $REGION --filters \"Name=tag:Project,Values=greendotball\" \"Name=instance-state-name,Values=running\" --query 'Reservations[*].Instances[*].[InstanceId,Tags[?Key==\`MobileIndex\`].Value|[0],State.Name]' --output table"
  echo ""
  
  echo "To check logs in S3:"
  echo "  aws s3 ls s3://greendotball-bot-data/logs/ --recursive"
  echo ""
  
  echo "To terminate all instances:"
  echo "  aws ec2 terminate-instances --region $REGION --instance-ids ${INSTANCE_IDS[@]}"
  echo ""
  
  echo "Expected completion time: ~20-30 minutes"
  echo "Total submissions: $((SUCCESS_COUNT * 100))"
fi

echo "Done!"
