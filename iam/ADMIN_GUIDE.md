# Admin Guide - External S3 User Management

This guide explains how to manage external users with S3 access in your AWS account.

## Overview

The IAM setup provides external users (like vinod@provigence.com) with full S3 management access while restricting access to all other AWS services.

**What external users can do:**
- View all S3 buckets in the account
- Create new S3 buckets
- Upload, download, and delete files in any bucket
- Delete S3 buckets
- Access AWS Console (S3 section only)

**What external users CANNOT do:**
- Access any other AWS services (EC2, Lambda, IAM, RDS, etc.)
- Create or manage IAM users/roles
- View billing information
- Modify security settings

## Architecture

```
IAM Policy: S3-FullManagement-Policy
    ↓ (attached to)
IAM Group: ExternalS3Managers
    ↓ (contains)
IAM Users: vinod-provigence, [future users...]
```

## Initial Setup

### Option 1: Automated Setup (Recommended)

Run the main setup script to create everything:

```bash
cd /Users/apple/CascadeProjects/windsurf-project-2
chmod +x iam/setup-s3-external-access.sh
./iam/setup-s3-external-access.sh
```

This creates:
- IAM Policy: `S3-FullManagement-Policy`
- IAM Group: `ExternalS3Managers`
- IAM User: `vinod-provigence`
- Console login profile with temporary password

The script outputs:
- AWS Account ID
- Username
- Temporary password
- Login URL

### Option 2: Manual Setup

See `iam/CONSOLE_SETUP_GUIDE.md` for step-by-step AWS Console instructions.

## Managing Users

### Add a New External User

```bash
./iam/create-additional-user.sh <username> <email>
```

**Example:**
```bash
./iam/create-additional-user.sh john-doe john@example.com
```

The script will:
- Create the IAM user
- Add user to ExternalS3Managers group
- Create console login profile
- Generate temporary password
- Output credentials to share

### Reset User Password

If a user forgets their password or you need to reset it:

```bash
./iam/reset-user-password.sh <username>
```

**Example:**
```bash
./iam/reset-user-password.sh vinod-provigence
```

The script outputs a new temporary password that the user must change on first login.

### Revoke User Access

**Option 1: Remove from group (user keeps existing, loses S3 access)**
```bash
./iam/revoke-user-access.sh <username>
```

**Option 2: Delete user completely**
```bash
./iam/revoke-user-access.sh <username> --delete
```

**Example:**
```bash
# Just revoke access
./iam/revoke-user-access.sh vinod-provigence

# Delete user completely
./iam/revoke-user-access.sh vinod-provigence --delete
```

## Sharing Credentials with External Users

After creating a user, share these details securely:

1. **AWS Account ID**: Found in script output or run `aws sts get-caller-identity --query Account --output text`
2. **Username**: e.g., `vinod-provigence`
3. **Temporary Password**: From script output
4. **Login URL**: `https://<ACCOUNT_ID>.signin.aws.amazon.com/console`

**Security best practices:**
- Share password through secure channel (encrypted email, password manager, etc.)
- Never share credentials in plain text
- Inform user they must change password on first login
- Provide them with `iam/USER_GUIDE.md` for instructions

## Monitoring User Activity

### View User's S3 Activity (CloudTrail)

1. Go to AWS Console → CloudTrail
2. Event history
3. Filter by:
   - User name: `vinod-provigence`
   - Event source: `s3.amazonaws.com`

### Monitor S3 Usage (CloudWatch)

1. Go to AWS Console → S3
2. Select bucket → Metrics tab
3. View:
   - Number of requests
   - Data transferred
   - Storage metrics

### Enable S3 Access Logging (Optional)

For detailed bucket-level access logs:

```bash
# Enable logging for a specific bucket
aws s3api put-bucket-logging \
  --bucket greendotball-bot-data \
  --bucket-logging-status file://logging-config.json
```

## Troubleshooting

### User Cannot Login

**Problem:** User gets "Invalid credentials" error

**Solutions:**
1. Verify username is correct (case-sensitive)
2. Verify AWS Account ID is correct
3. Reset password: `./iam/reset-user-password.sh <username>`
4. Check if user exists: `aws iam get-user --user-name <username>`

### User Cannot Access S3

**Problem:** User can login but sees "Access Denied" in S3

**Solutions:**
1. Verify user is in group: `aws iam list-groups-for-user --user-name <username>`
2. Verify group has policy attached: `aws iam list-attached-group-policies --group-name ExternalS3Managers`
3. Re-add user to group: `aws iam add-user-to-group --user-name <username> --group-name ExternalS3Managers`

### User Can Access Other AWS Services

**Problem:** User should only see S3 but can access other services

**Solution:** This shouldn't happen with the current setup. Verify:
1. User only belongs to ExternalS3Managers group
2. No additional policies attached directly to user
3. Check: `aws iam list-attached-user-policies --user-name <username>` (should be empty)

## Security Best Practices

### Regular Audits

- Review user list monthly: `aws iam get-group --group-name ExternalS3Managers`
- Check CloudTrail for unusual activity
- Remove users who no longer need access

### Password Policy

Current setup enforces:
- Password change on first login
- AWS default password complexity requirements

To enforce stronger policies, update account password policy:
```bash
aws iam update-account-password-policy \
  --minimum-password-length 14 \
  --require-symbols \
  --require-numbers \
  --require-uppercase-characters \
  --require-lowercase-characters \
  --max-password-age 90
```

### Enable MFA (Optional)

For additional security, require MFA for external users:

1. User logs in to AWS Console
2. User goes to IAM → My Security Credentials
3. User sets up MFA device (virtual or hardware)

### CloudTrail Monitoring

Ensure CloudTrail is enabled to log all API calls:
```bash
aws cloudtrail describe-trails
```

## Cost Considerations

**IAM Costs:**
- IAM users, groups, and policies: **FREE**

**S3 Costs (user activity):**
- Storage: $0.023/GB/month (ap-south-1)
- PUT requests: $0.005 per 1,000 requests
- GET requests: $0.0004 per 1,000 requests
- Data transfer out: $0.09/GB (first 10TB)

**CloudTrail Costs:**
- First trail: **FREE**
- Additional trails: $2.00 per 100,000 events

## Quick Reference Commands

```bash
# List all users in group
aws iam get-group --group-name ExternalS3Managers

# Check user details
aws iam get-user --user-name vinod-provigence

# List user's groups
aws iam list-groups-for-user --user-name vinod-provigence

# View group's policies
aws iam list-attached-group-policies --group-name ExternalS3Managers

# Get AWS Account ID
aws sts get-caller-identity --query Account --output text

# List all S3 buckets
aws s3 ls

# View CloudTrail events for user
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=Username,AttributeValue=vinod-provigence \
  --max-results 50
```

## Support

For issues or questions:
1. Check troubleshooting section above
2. Review AWS IAM documentation: https://docs.aws.amazon.com/IAM/
3. Check CloudTrail logs for error details
4. Contact AWS Support if needed

## Files Reference

- `iam/s3-full-management-policy.json` - IAM policy document
- `iam/setup-s3-external-access.sh` - Initial setup script
- `iam/create-additional-user.sh` - Add new users
- `iam/reset-user-password.sh` - Reset passwords
- `iam/revoke-user-access.sh` - Revoke access or delete users
- `iam/USER_GUIDE.md` - Guide for external users
- `iam/CONSOLE_SETUP_GUIDE.md` - Manual AWS Console setup steps
