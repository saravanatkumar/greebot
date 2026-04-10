#!/bin/bash
# revoke-user-access.sh
# Revoke S3 access for a user (remove from group or delete user)
#
# Usage:
#   ./iam/revoke-user-access.sh <username> [--delete]
#
# Examples:
#   ./iam/revoke-user-access.sh vinod-provigence          # Remove from group only
#   ./iam/revoke-user-access.sh vinod-provigence --delete # Delete user completely

set -e

if [ $# -lt 1 ]; then
  echo "Usage: $0 <username> [--delete]"
  echo ""
  echo "Examples:"
  echo "  $0 vinod-provigence          # Remove from group (revoke access)"
  echo "  $0 vinod-provigence --delete # Delete user completely"
  exit 1
fi

USERNAME="$1"
DELETE_USER=false
GROUP_NAME="ExternalS3Managers"

if [ "$2" = "--delete" ]; then
  DELETE_USER=true
fi

echo ""
echo "=========================================================="
echo "  REVOKE USER ACCESS"
echo "=========================================================="
echo ""
echo "  Username : $USERNAME"
echo "  Action   : $([ "$DELETE_USER" = true ] && echo "Delete user" || echo "Remove from group")"
echo ""
echo "=========================================================="
echo ""

# Check if AWS CLI is configured
if ! aws sts get-caller-identity &>/dev/null; then
  echo "❌ ERROR: AWS CLI is not configured"
  exit 1
fi

# Check if user exists
if ! aws iam get-user --user-name "$USERNAME" &>/dev/null; then
  echo "❌ ERROR: User '$USERNAME' does not exist"
  exit 1
fi

# Remove from group
echo "[1/3] Removing user from group..."

if aws iam list-groups-for-user --user-name "$USERNAME" | grep -q "$GROUP_NAME"; then
  aws iam remove-user-from-group \
    --user-name "$USERNAME" \
    --group-name "$GROUP_NAME"
  echo "      ✅ User removed from $GROUP_NAME"
else
  echo "      ⚠️  User not in $GROUP_NAME"
fi

if [ "$DELETE_USER" = true ]; then
  # Delete login profile
  echo "[2/3] Deleting login profile..."
  
  if aws iam get-login-profile --user-name "$USERNAME" &>/dev/null; then
    aws iam delete-login-profile --user-name "$USERNAME" &>/dev/null
    echo "      ✅ Login profile deleted"
  else
    echo "      ⚠️  No login profile found"
  fi
  
  # Delete access keys (if any)
  echo "[3/3] Deleting access keys..."
  
  ACCESS_KEYS=$(aws iam list-access-keys --user-name "$USERNAME" --query 'AccessKeyMetadata[].AccessKeyId' --output text)
  
  if [ -n "$ACCESS_KEYS" ]; then
    for key in $ACCESS_KEYS; do
      aws iam delete-access-key --user-name "$USERNAME" --access-key-id "$key"
      echo "      ✅ Deleted access key: $key"
    done
  else
    echo "      ⚠️  No access keys found"
  fi
  
  # Delete user
  echo ""
  echo "Deleting user..."
  
  aws iam delete-user --user-name "$USERNAME"
  echo "      ✅ User deleted"
  
  echo ""
  echo "=========================================================="
  echo "  ✅ USER DELETED SUCCESSFULLY"
  echo "=========================================================="
  echo ""
  echo "  User '$USERNAME' has been completely removed"
  echo ""
else
  echo ""
  echo "=========================================================="
  echo "  ✅ ACCESS REVOKED"
  echo "=========================================================="
  echo ""
  echo "  User '$USERNAME' removed from $GROUP_NAME"
  echo "  User still exists but has no S3 access"
  echo ""
  echo "  To delete user completely, run:"
  echo "  ./iam/revoke-user-access.sh $USERNAME --delete"
  echo ""
fi
