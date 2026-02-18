#!/bin/bash

# Configuration
AMI_ID="ami-0a39d12e7514ee458"
INSTANCE_TYPE="t3.small"
KEY_NAME="greendotball-bot-key-v2"
SECURITY_GROUP_NAME="greendotball-bot-sg"
IAM_ROLE="EC2-GreenDotBall-S3-Access"
REGION="ap-south-1"
JOBS_DIR="data/jobs"
MASTER_JOB_FILE="${JOBS_DIR}/masterjob.json"

# Check if job ID parameter was provided
if [ -z "$1" ]; then
  echo "ERROR: Job ID not provided"
  echo "Usage: $0 <job-id> [number-of-instances]"
  exit 1
fi

JOB_ID="$1"
INSTANCES_TO_LAUNCH="${2:-1}" # Default to 1 instance if not specified

# Validate that the job exists in the master job file
if [ ! -f "$MASTER_JOB_FILE" ]; then
  echo "ERROR: Master job file not found: $MASTER_JOB_FILE"
  exit 1
fi

# Check if job ID exists in master job file
JOB_FILE=$(grep -o "\"file\": \"[^\"]*${JOB_ID}\.json\"" "$MASTER_JOB_FILE" | cut -d'"' -f4)

if [ -z "$JOB_FILE" ]; then
  echo "ERROR: Job ID '$JOB_ID' not found in master job file"
  exit 1
fi

# Ensure the job file exists
if [ ! -f "$JOB_FILE" ]; then
  echo "ERROR: Job file not found: $JOB_FILE"
  exit 1
fi

echo "==========================================="
echo "Launching instances for job: $JOB_ID"
echo "Job file: $JOB_FILE"
echo "Instances to launch: $INSTANCES_TO_LAUNCH"
echo "AMI: $AMI_ID"
echo "Instance Type: $INSTANCE_TYPE"
echo "Region: $REGION"
echo "==========================================="
echo ""

# Get security group ID
echo "Getting security group ID..."
SECURITY_GROUP_ID=$(aws ec2 describe-security-groups \
  --region $REGION \
  --filters "Name=group-name,Values=$SECURITY_GROUP_NAME" \
  --query 'SecurityGroups[0].GroupId' \
  --output text)

if [ -z "$SECURITY_GROUP_ID" ] || [ "$SECURITY_GROUP_ID" == "None" ]; then
  echo "ERROR: Security group '$SECURITY_GROUP_NAME' not found"
  exit 1
fi

echo "✓ Security Group: $SECURITY_GROUP_ID"
echo ""

# Confirm with user
read -p "This will launch $INSTANCES_TO_LAUNCH instances for job $JOB_ID. Continue? (yes/no): " confirm
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

for i in $(seq 1 $INSTANCES_TO_LAUNCH); do
  echo "[$i/$INSTANCES_TO_LAUNCH] Launching instance for Job ID: $JOB_ID..."
  
  # Launch instance with job ID
  RESULT=$(aws ec2 run-instances \
    --region $REGION \
    --image-id $AMI_ID \
    --instance-type $INSTANCE_TYPE \
    --key-name $KEY_NAME \
    --security-group-ids $SECURITY_GROUP_ID \
    --iam-instance-profile Name=$IAM_ROLE \
    --user-data "#!/bin/bash
JOB_ID=$JOB_ID
USE_NEW_BOT=true" \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=greendotball-job-$JOB_ID-$i},{Key=JobID,Value=$JOB_ID},{Key=Project,Value=greendotball},{Key=Batch,Value=$(date +%Y%m%d-%H%M%S)}]" \
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
  
  # Small delay to avoid API throttling
  sleep 2
done

echo ""
echo "=========================================="
echo "Launch Summary"
echo "=========================================="
echo "Total Requested: $INSTANCES_TO_LAUNCH"
echo "✅ Successful: $SUCCESS_COUNT"
echo "❌ Failed: $FAIL_COUNT"
echo "=========================================="
echo ""

if [ $SUCCESS_COUNT -gt 0 ]; then
  echo "Launched Instance IDs:"
  printf '%s\n' "${INSTANCE_IDS[@]}"
  echo ""
  
  echo "To monitor instances:"
  echo "  aws ec2 describe-instances --region $REGION --filters \"Name=tag:JobID,Values=$JOB_ID\" \"Name=instance-state-name,Values=running\" --query 'Reservations[*].Instances[*].[InstanceId,Tags[?Key==\`JobID\`].Value|[0],State.Name]' --output table"
  echo ""
  
  echo "To check logs in S3:"
  echo "  aws s3 ls s3://greendotball-bot-data/logs/job-$JOB_ID/ --recursive"
  echo ""
  
  echo "To terminate all instances:"
  echo "  aws ec2 terminate-instances --region $REGION --instance-ids ${INSTANCE_IDS[@]}"
  echo ""
  
  echo "Expected completion time depends on the number of phone-image pairs in the job"
fi

echo "Done!"
