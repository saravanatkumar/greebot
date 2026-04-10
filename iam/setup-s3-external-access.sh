#!/bin/bash
# setup-s3-external-access.sh
# Complete automated setup for external S3 user access
# Creates IAM policy, user group, and initial user with console access
#
# Usage:
#   chmod +x iam/setup-s3-external-access.sh
#   ./iam/setup-s3-external-access.sh
#
# This script creates:
#   1. IAM Policy: S3-FullManagement-Policy
#   2. IAM Group: ExternalS3Managers
#   3. IAM User: vinod-provigence (with console password)

set -e

POLICY_NAME="S3-FullManagement-Policy"
GROUP_NAME="ExternalS3Managers"
USERNAME="vinod-provigence"
POLICY_FILE="iam/s3-full-management-policy.json"
TEMP_PASSWORD=$(openssl rand -base64 12)

echo ""
echo "=========================================================="
echo "  AWS IAM SETUP - EXTERNAL S3 ACCESS"
echo "=========================================================="
echo ""
echo "  Policy : $POLICY_NAME"
echo "  Group  : $GROUP_NAME"
echo "  User   : $USERNAME"
echo ""
echo "=========================================================="
echo ""

# Check if AWS CLI is configured
if ! aws sts get-caller-identity &>/dev/null; then
  echo "❌ ERROR: AWS CLI is not configured or credentials are invalid"
  echo "   Run: aws configure"
  exit 1
fi

AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "✓ AWS Account ID: $AWS_ACCOUNT_ID"
echo ""

# ── Step 1: Create IAM Policy ─────────────────────────────────────────────────
echo "[1/5] Creating IAM Policy: $POLICY_NAME..."

if aws iam get-policy --policy-arn "arn:aws:iam::${AWS_ACCOUNT_ID}:policy/${POLICY_NAME}" &>/dev/null; then
  echo "      ⚠️  Policy already exists, skipping creation"
  POLICY_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:policy/${POLICY_NAME}"
else
  POLICY_ARN=$(aws iam create-policy \
    --policy-name "$POLICY_NAME" \
    --policy-document file://"$POLICY_FILE" \
    --description "Full S3 management access for external users" \
    --query 'Policy.Arn' \
    --output text)
  echo "      ✅ Policy created: $POLICY_ARN"
fi

# ── Step 2: Create IAM Group ──────────────────────────────────────────────────
echo "[2/5] Creating IAM Group: $GROUP_NAME..."

if aws iam get-group --group-name "$GROUP_NAME" &>/dev/null; then
  echo "      ⚠️  Group already exists, skipping creation"
else
  aws iam create-group --group-name "$GROUP_NAME" &>/dev/null
  echo "      ✅ Group created: $GROUP_NAME"
fi

# ── Step 3: Attach Policy to Group ────────────────────────────────────────────
echo "[3/5] Attaching policy to group..."

if aws iam list-attached-group-policies --group-name "$GROUP_NAME" \
  | grep -q "$POLICY_NAME"; then
  echo "      ⚠️  Policy already attached to group"
else
  aws iam attach-group-policy \
    --group-name "$GROUP_NAME" \
    --policy-arn "$POLICY_ARN"
  echo "      ✅ Policy attached to group"
fi

# ── Step 4: Create IAM User ───────────────────────────────────────────────────
echo "[4/5] Creating IAM User: $USERNAME..."

if aws iam get-user --user-name "$USERNAME" &>/dev/null; then
  echo "      ⚠️  User already exists, skipping creation"
  echo "      ℹ️  Use reset-user-password.sh to reset password"
  USER_EXISTS=true
else
  aws iam create-user \
    --user-name "$USERNAME" \
    --tags Key=Email,Value=vinod@provigence.com Key=Type,Value=ExternalUser &>/dev/null
  echo "      ✅ User created: $USERNAME"
  USER_EXISTS=false
fi

# ── Step 5: Add User to Group ─────────────────────────────────────────────────
echo "[5/5] Adding user to group..."

if aws iam list-groups-for-user --user-name "$USERNAME" \
  | grep -q "$GROUP_NAME"; then
  echo "      ⚠️  User already in group"
else
  aws iam add-user-to-group \
    --user-name "$USERNAME" \
    --group-name "$GROUP_NAME"
  echo "      ✅ User added to group"
fi

# ── Create Login Profile (Console Password) ───────────────────────────────────
if [ "$USER_EXISTS" = false ]; then
  echo ""
  echo "Creating console login profile..."
  
  aws iam create-login-profile \
    --user-name "$USERNAME" \
    --password "$TEMP_PASSWORD" \
    --password-reset-required &>/dev/null
  
  echo "      ✅ Console access enabled"
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "=========================================================="
echo "  ✅ SETUP COMPLETE"
echo "=========================================================="
echo ""
echo "  AWS Account ID : $AWS_ACCOUNT_ID"
echo "  Username       : $USERNAME"
echo "  Email          : vinod@provigence.com"
echo ""

if [ "$USER_EXISTS" = false ]; then
  echo "  Temporary Password: $TEMP_PASSWORD"
  echo "  (User must change on first login)"
  echo ""
fi

echo "  Login URL:"
echo "  https://${AWS_ACCOUNT_ID}.signin.aws.amazon.com/console"
echo ""
echo "=========================================================="
echo ""
echo "  NEXT STEPS:"
echo ""
echo "  1. Share credentials with vinod@provigence.com:"
echo "     - AWS Account ID: $AWS_ACCOUNT_ID"
echo "     - Username: $USERNAME"

if [ "$USER_EXISTS" = false ]; then
  echo "     - Temporary Password: $TEMP_PASSWORD"
fi

echo "     - Login URL: https://${AWS_ACCOUNT_ID}.signin.aws.amazon.com/console"
echo ""
echo "  2. User will be prompted to change password on first login"
echo ""
echo "  3. User can access S3 service only (full permissions)"
echo ""
echo "  4. See iam/USER_GUIDE.md for detailed instructions"
echo ""
echo "=========================================================="
echo ""
