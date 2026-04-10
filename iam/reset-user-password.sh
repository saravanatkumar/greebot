#!/bin/bash
# reset-user-password.sh
# Reset password for an existing IAM user
#
# Usage:
#   ./iam/reset-user-password.sh <username>
#
# Example:
#   ./iam/reset-user-password.sh vinod-provigence

set -e

if [ $# -ne 1 ]; then
  echo "Usage: $0 <username>"
  echo ""
  echo "Example:"
  echo "  $0 vinod-provigence"
  exit 1
fi

USERNAME="$1"
NEW_PASSWORD=$(openssl rand -base64 12)

echo ""
echo "=========================================================="
echo "  RESET USER PASSWORD"
echo "=========================================================="
echo ""
echo "  Username : $USERNAME"
echo ""
echo "=========================================================="
echo ""

# Check if AWS CLI is configured
if ! aws sts get-caller-identity &>/dev/null; then
  echo "❌ ERROR: AWS CLI is not configured"
  exit 1
fi

AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Check if user exists
if ! aws iam get-user --user-name "$USERNAME" &>/dev/null; then
  echo "❌ ERROR: User '$USERNAME' does not exist"
  exit 1
fi

# Delete existing login profile if it exists
echo "Resetting password..."

if aws iam get-login-profile --user-name "$USERNAME" &>/dev/null; then
  aws iam delete-login-profile --user-name "$USERNAME" &>/dev/null
fi

# Create new login profile
aws iam create-login-profile \
  --user-name "$USERNAME" \
  --password "$NEW_PASSWORD" \
  --password-reset-required &>/dev/null

echo "      ✅ Password reset successfully"

# Summary
echo ""
echo "=========================================================="
echo "  ✅ PASSWORD RESET COMPLETE"
echo "=========================================================="
echo ""
echo "  AWS Account ID : $AWS_ACCOUNT_ID"
echo "  Username       : $USERNAME"
echo "  New Password   : $NEW_PASSWORD"
echo ""
echo "  Login URL:"
echo "  https://${AWS_ACCOUNT_ID}.signin.aws.amazon.com/console"
echo ""
echo "=========================================================="
echo ""
echo "  Share new password with user"
echo "  User must change password on first login"
echo ""
