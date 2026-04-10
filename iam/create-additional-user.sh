#!/bin/bash
# create-additional-user.sh
# Add additional external users to the ExternalS3Managers group
#
# Usage:
#   ./iam/create-additional-user.sh <username> <email>
#
# Example:
#   ./iam/create-additional-user.sh john-doe john@example.com

set -e

if [ $# -ne 2 ]; then
  echo "Usage: $0 <username> <email>"
  echo ""
  echo "Example:"
  echo "  $0 john-doe john@example.com"
  exit 1
fi

USERNAME="$1"
EMAIL="$2"
GROUP_NAME="ExternalS3Managers"
TEMP_PASSWORD=$(openssl rand -base64 12)

echo ""
echo "=========================================================="
echo "  CREATE ADDITIONAL S3 USER"
echo "=========================================================="
echo ""
echo "  Username : $USERNAME"
echo "  Email    : $EMAIL"
echo "  Group    : $GROUP_NAME"
echo ""
echo "=========================================================="
echo ""

# Check if AWS CLI is configured
if ! aws sts get-caller-identity &>/dev/null; then
  echo "❌ ERROR: AWS CLI is not configured"
  exit 1
fi

AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Check if group exists
if ! aws iam get-group --group-name "$GROUP_NAME" &>/dev/null; then
  echo "❌ ERROR: Group '$GROUP_NAME' does not exist"
  echo "   Run: ./iam/setup-s3-external-access.sh first"
  exit 1
fi

# Create user
echo "[1/3] Creating IAM user: $USERNAME..."

if aws iam get-user --user-name "$USERNAME" &>/dev/null; then
  echo "      ❌ ERROR: User '$USERNAME' already exists"
  exit 1
fi

aws iam create-user \
  --user-name "$USERNAME" \
  --tags Key=Email,Value="$EMAIL" Key=Type,Value=ExternalUser &>/dev/null

echo "      ✅ User created"

# Add to group
echo "[2/3] Adding user to group..."

aws iam add-user-to-group \
  --user-name "$USERNAME" \
  --group-name "$GROUP_NAME"

echo "      ✅ User added to $GROUP_NAME"

# Create login profile
echo "[3/3] Creating console login profile..."

aws iam create-login-profile \
  --user-name "$USERNAME" \
  --password "$TEMP_PASSWORD" \
  --password-reset-required &>/dev/null

echo "      ✅ Console access enabled"

# Summary
echo ""
echo "=========================================================="
echo "  ✅ USER CREATED SUCCESSFULLY"
echo "=========================================================="
echo ""
echo "  AWS Account ID : $AWS_ACCOUNT_ID"
echo "  Username       : $USERNAME"
echo "  Email          : $EMAIL"
echo "  Temporary Pass : $TEMP_PASSWORD"
echo ""
echo "  Login URL:"
echo "  https://${AWS_ACCOUNT_ID}.signin.aws.amazon.com/console"
echo ""
echo "=========================================================="
echo ""
echo "  Share these credentials with $EMAIL"
echo "  User must change password on first login"
echo ""
