# IAM External S3 Access Setup

This directory contains everything needed to grant external users full S3 access to your AWS account.

## Quick Start

### Automated Setup (Recommended)

Run one command to create everything:

```bash
cd /Users/apple/CascadeProjects/windsurf-project-2
chmod +x iam/*.sh
./iam/setup-s3-external-access.sh
```

This creates:
- IAM Policy: `S3-FullManagement-Policy`
- IAM Group: `ExternalS3Managers`
- IAM User: `vinod-provigence`
- Console login with temporary password

**Output:** AWS Account ID, username, temporary password, and login URL

### Manual Setup

See `CONSOLE_SETUP_GUIDE.md` for step-by-step AWS Console instructions.

## What's Included

### Configuration
- **s3-full-management-policy.json** - IAM policy granting full S3 access

### Scripts
- **setup-s3-external-access.sh** - Complete automated setup
- **create-additional-user.sh** - Add more external users
- **reset-user-password.sh** - Reset user passwords
- **revoke-user-access.sh** - Remove access or delete users

### Documentation
- **ADMIN_GUIDE.md** - Complete admin guide for managing users
- **USER_GUIDE.md** - Instructions for external users (share with vinod@provigence.com)
- **CONSOLE_SETUP_GUIDE.md** - Manual AWS Console setup steps
- **README.md** - This file

## User Details

**Current User:**
- Username: `vinod-provigence`
- Email: vinod@provigence.com
- Access: Full S3 management (all buckets)

**Permissions:**
- ✅ Create/delete S3 buckets
- ✅ Upload/download/delete files
- ✅ List all buckets
- ❌ No access to other AWS services

## Common Tasks

### Setup Initial User
```bash
./iam/setup-s3-external-access.sh
```

### Add Another User
```bash
./iam/create-additional-user.sh john-doe john@example.com
```

### Reset Password
```bash
./iam/reset-user-password.sh vinod-provigence
```

### Revoke Access
```bash
# Remove from group (keeps user)
./iam/revoke-user-access.sh vinod-provigence

# Delete user completely
./iam/revoke-user-access.sh vinod-provigence --delete
```

## Sharing Credentials

After setup, share with the external user:

1. **AWS Account ID** - From script output
2. **Username** - e.g., `vinod-provigence`
3. **Temporary Password** - From script output
4. **Login URL** - `https://<ACCOUNT_ID>.signin.aws.amazon.com/console`
5. **USER_GUIDE.md** - Instructions for using S3

**Security:** Share password through encrypted email or password manager.

## Monitoring

### View User Activity
```bash
# CloudTrail events for user
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=Username,AttributeValue=vinod-provigence \
  --max-results 50
```

### List All External Users
```bash
aws iam get-group --group-name ExternalS3Managers
```

## Prerequisites

- AWS CLI installed and configured
- AWS credentials with IAM admin permissions
- `openssl` for password generation (pre-installed on macOS/Linux)

## Architecture

```
IAM Policy: S3-FullManagement-Policy
    ↓ (attached to)
IAM Group: ExternalS3Managers
    ↓ (contains)
IAM Users: vinod-provigence, [additional users...]
```

## Security Notes

- Users have S3-only access (no other AWS services)
- Console password access only (no programmatic keys)
- Forced password change on first login
- All actions logged in CloudTrail
- Applies to all S3 buckets in the account

## Troubleshooting

### Script Permission Denied
```bash
chmod +x iam/*.sh
```

### AWS CLI Not Configured
```bash
aws configure
```

### User Already Exists
Use `reset-user-password.sh` to reset password instead of creating new user.

## Documentation

- **ADMIN_GUIDE.md** - Complete admin reference
- **USER_GUIDE.md** - User instructions (share with external users)
- **CONSOLE_SETUP_GUIDE.md** - Manual setup without CLI

## Support

For detailed instructions, see:
- Admin tasks: `ADMIN_GUIDE.md`
- User instructions: `USER_GUIDE.md`
- Manual setup: `CONSOLE_SETUP_GUIDE.md`

## Files

```
iam/
├── README.md                          # This file
├── ADMIN_GUIDE.md                     # Admin documentation
├── USER_GUIDE.md                      # User documentation
├── CONSOLE_SETUP_GUIDE.md             # Manual setup guide
├── s3-full-management-policy.json     # IAM policy
├── setup-s3-external-access.sh        # Main setup script
├── create-additional-user.sh          # Add users
├── reset-user-password.sh             # Reset passwords
└── revoke-user-access.sh              # Revoke access
```

## Next Steps

1. Run `./iam/setup-s3-external-access.sh`
2. Save the output (credentials)
3. Share credentials with vinod@provigence.com
4. Provide `USER_GUIDE.md` to the user
5. Monitor access via CloudTrail

---

**Ready to deploy!** Run the setup script to create the IAM user for vinod@provigence.com.
