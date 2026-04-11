#!/bin/bash
# attach-ec2-policy.sh
# Attaches EC2 campaign launcher permissions to the EC2-GreenDotBall-S3-Access role

set -e

ROLE_NAME="EC2-GreenDotBall-S3-Access"
POLICY_NAME="EC2-CampaignLauncher-Policy"
POLICY_FILE="$(dirname "$0")/ec2-campaign-launcher-policy.json"

echo "=================================================="
echo "  ATTACH EC2 POLICY TO ROLE"
echo "  Role   : $ROLE_NAME"
echo "  Policy : $POLICY_NAME"
echo "=================================================="
echo ""

# Check if policy file exists
if [ ! -f "$POLICY_FILE" ]; then
  echo "❌ ERROR: Policy file not found: $POLICY_FILE"
  exit 1
fi

# Get AWS account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "AWS Account ID: $ACCOUNT_ID"
echo ""

# Create or update the policy
POLICY_ARN="arn:aws:iam::${ACCOUNT_ID}:policy/${POLICY_NAME}"

echo "Checking if policy exists..."
if aws iam get-policy --policy-arn "$POLICY_ARN" &>/dev/null; then
  echo "  ✅ Policy exists, creating new version..."
  
  # Create new policy version
  aws iam create-policy-version \
    --policy-arn "$POLICY_ARN" \
    --policy-document "file://${POLICY_FILE}" \
    --set-as-default
  
  echo "  ✅ Policy updated"
else
  echo "  Creating new policy..."
  
  # Create the policy
  aws iam create-policy \
    --policy-name "$POLICY_NAME" \
    --policy-document "file://${POLICY_FILE}" \
    --description "Allows EC2 instances to launch campaign instances"
  
  echo "  ✅ Policy created"
fi

echo ""
echo "Attaching policy to role..."

# Attach policy to role
aws iam attach-role-policy \
  --role-name "$ROLE_NAME" \
  --policy-arn "$POLICY_ARN"

echo "  ✅ Policy attached to role"
echo ""

# Verify attachment
echo "Verifying policy attachment..."
if aws iam list-attached-role-policies --role-name "$ROLE_NAME" | grep -q "$POLICY_NAME"; then
  echo "  ✅ Verified: Policy is attached to role"
else
  echo "  ⚠️  Warning: Could not verify policy attachment"
fi

echo ""
echo "=================================================="
echo "  SETUP COMPLETE"
echo "=================================================="
echo ""
echo "The role '$ROLE_NAME' now has permissions to:"
echo "  - Describe security groups"
echo "  - Launch EC2 instances"
echo "  - Create tags"
echo "  - Terminate instances"
echo "  - Describe instances and images"
echo ""
echo "You can now run launch-campaign-instances.sh from EC2 instances"
echo "using this role."
echo ""
