# AWS Console Setup Guide - Manual IAM Configuration

This guide provides step-by-step instructions for setting up external S3 user access through the AWS Console (without using CLI scripts).

## Prerequisites

- AWS account with admin access
- Access to AWS Console: https://console.aws.amazon.com/

## Setup Overview

You will create:
1. IAM Policy with full S3 permissions
2. IAM User Group
3. IAM User with console access

**Estimated time:** 10-15 minutes

---

## Step 1: Create IAM Policy

### 1.1 Navigate to IAM Policies

1. Login to AWS Console
2. Search for "IAM" in the top search bar
3. Click **IAM** service
4. In the left sidebar, click **Policies**
5. Click **Create policy** button

### 1.2 Define Policy Permissions

1. Click the **JSON** tab
2. Delete the existing JSON content
3. Paste the following policy:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "S3FullManagementAccess",
      "Effect": "Allow",
      "Action": "s3:*",
      "Resource": "*"
    }
  ]
}
```

4. Click **Next: Tags**

### 1.3 Add Tags (Optional)

1. Add tags if desired (optional):
   - Key: `Purpose`, Value: `ExternalS3Access`
   - Key: `ManagedBy`, Value: `Admin`
2. Click **Next: Review**

### 1.4 Review and Create

1. **Name:** `S3-FullManagement-Policy`
2. **Description:** `Full S3 management access for external users`
3. Review the JSON policy
4. Click **Create policy**

✅ **Policy created successfully!**

---

## Step 2: Create IAM User Group

### 2.1 Navigate to User Groups

1. In IAM console, click **User groups** in left sidebar
2. Click **Create group** button

### 2.2 Configure Group

1. **User group name:** `ExternalS3Managers`
2. Scroll down to **Attach permissions policies**
3. In the search box, type: `S3-FullManagement-Policy`
4. Check the box next to **S3-FullManagement-Policy**
5. Scroll down and click **Create group**

✅ **User group created successfully!**

---

## Step 3: Create IAM User

### 3.1 Navigate to Users

1. In IAM console, click **Users** in left sidebar
2. Click **Create user** button

### 3.2 Specify User Details

1. **User name:** `vinod-provigence`
2. Check ✅ **Provide user access to the AWS Management Console**
3. Select **I want to create an IAM user**
4. **Console password:** Select **Custom password**
5. Enter a temporary password (user will change on first login)
   - Example: `TempPass123!` (or generate a strong random password)
6. Check ✅ **Users must create a new password at next sign-in**
7. Click **Next**

### 3.3 Set Permissions

1. Select **Add user to group**
2. Check the box next to **ExternalS3Managers**
3. Click **Next**

### 3.4 Add Tags (Optional)

1. Add tags if desired:
   - Key: `Email`, Value: `vinod@provigence.com`
   - Key: `Type`, Value: `ExternalUser`
2. Click **Next**

### 3.5 Review and Create

1. Review all settings:
   - User name: `vinod-provigence`
   - Console access: Enabled
   - Group: ExternalS3Managers
   - Password reset required: Yes
2. Click **Create user**

✅ **User created successfully!**

### 3.6 Save Credentials

**IMPORTANT:** Save these credentials immediately!

1. You'll see a success page with:
   - **Console sign-in URL**
   - **User name**
   - **Console password** (if you chose to show it)

2. Click **Download .csv** to save credentials

3. **Note down:**
   - AWS Account ID (from the sign-in URL)
   - Username: `vinod-provigence`
   - Temporary password
   - Sign-in URL

---

## Step 4: Verify Setup

### 4.1 Check User Permissions

1. Go to **Users** → Click **vinod-provigence**
2. Click **Permissions** tab
3. You should see:
   - Group: ExternalS3Managers
   - Policy: S3-FullManagement-Policy (inherited from group)

### 4.2 Test Login (Optional)

1. Open an incognito/private browser window
2. Go to the sign-in URL
3. Enter:
   - Account ID or alias
   - Username: `vinod-provigence`
   - Password: temporary password
4. You'll be prompted to change password
5. After changing password, you should see AWS Console
6. Search for "S3" - you should have access
7. Try searching for "EC2" - you should see "Access Denied" (this is correct)

---

## Step 5: Share Credentials with User

### What to Share

Send the following to vinod@provigence.com (through secure channel):

```
AWS Account Access - S3 Upload

Login URL: https://<ACCOUNT_ID>.signin.aws.amazon.com/console
Username: vinod-provigence
Temporary Password: <password>

Instructions:
1. Click the login URL
2. Enter your username and password
3. You'll be prompted to change your password
4. After login, search for "S3" to access S3 service
5. You have full access to all S3 buckets

For detailed instructions, see the attached USER_GUIDE.md
```

### Security Tips

- ✅ Send password through encrypted email or password manager
- ✅ Send login URL and username separately from password
- ✅ Inform user to change password immediately
- ❌ Never send credentials in plain text
- ❌ Never share credentials via Slack/Teams/SMS

---

## Managing Users (Console)

### Add Another User

1. Go to **IAM** → **Users** → **Create user**
2. Follow Step 3 above
3. Add to **ExternalS3Managers** group
4. Save and share credentials

### Reset User Password

1. Go to **IAM** → **Users**
2. Click on the username
3. Click **Security credentials** tab
4. Under **Console sign-in**, click **Manage**
5. Click **Enable** (if disabled) or **Reset password**
6. Choose **Custom password** or **Autogenerated password**
7. Check **User must create a new password at next sign-in**
8. Click **Apply**
9. Share new password with user

### Remove User Access

**Option 1: Remove from group (keeps user, revokes S3 access)**
1. Go to **IAM** → **Users** → Click username
2. Click **Groups** tab
3. Select **ExternalS3Managers**
4. Click **Remove from group**

**Option 2: Delete user completely**
1. Go to **IAM** → **Users**
2. Check box next to username
3. Click **Delete**
4. Confirm by typing username
5. Click **Delete**

### View User Activity

1. Go to **CloudTrail** service
2. Click **Event history**
3. Filter by:
   - **User name:** `vinod-provigence`
   - **Event source:** `s3.amazonaws.com`
4. View all S3 actions performed by user

---

## Troubleshooting

### Policy Not Appearing in Group Creation

- Wait a few seconds and refresh
- Make sure policy was created successfully
- Check policy name is exactly: `S3-FullManagement-Policy`

### User Cannot Login

- Verify sign-in URL includes correct Account ID
- Check username is exactly: `vinod-provigence` (case-sensitive)
- Verify password was copied correctly
- Try resetting password

### User Sees "Access Denied" for S3

- Check user is in **ExternalS3Managers** group
- Verify group has **S3-FullManagement-Policy** attached
- Check no deny policies are attached to user directly

### Cannot Delete User

- Remove user from all groups first
- Delete any access keys
- Delete login profile (console password)
- Then delete user

---

## Quick Reference

| Task | Navigation |
|------|------------|
| Create policy | IAM → Policies → Create policy |
| Create group | IAM → User groups → Create group |
| Create user | IAM → Users → Create user |
| Reset password | IAM → Users → [username] → Security credentials |
| View activity | CloudTrail → Event history |
| Delete user | IAM → Users → [select] → Delete |

---

## Alternative: Use CLI Scripts

For faster setup, use the automated scripts:

```bash
# One-command setup
./iam/setup-s3-external-access.sh

# Add more users
./iam/create-additional-user.sh <username> <email>

# Reset password
./iam/reset-user-password.sh <username>
```

See `ADMIN_GUIDE.md` for CLI script documentation.

---

## Next Steps

After setup:
1. ✅ Share credentials with user securely
2. ✅ Provide USER_GUIDE.md to user
3. ✅ Enable CloudTrail for monitoring (if not already enabled)
4. ✅ Set up billing alerts
5. ✅ Document user access in your records

---

**Setup Complete!** The external user now has full S3 access through the AWS Console.
