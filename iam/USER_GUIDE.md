# User Guide - AWS S3 Access for External Users

Welcome! This guide will help you access and use AWS S3 to upload and manage images.

## What You Can Do

You have been granted full S3 access, which means you can:

✅ **View all S3 buckets** in the account  
✅ **Upload files** to any bucket  
✅ **Download files** from any bucket  
✅ **Delete files** from any bucket  
✅ **Create new S3 buckets**  
✅ **Delete S3 buckets**  
✅ **Organize files** in folders within buckets  

❌ You **cannot** access other AWS services (EC2, Lambda, databases, etc.)

## Getting Started

### Step 1: Receive Your Credentials

You should have received the following information:

- **AWS Account ID**: 12-digit number (e.g., `123456789012`)
- **Username**: `vinod-provigence`
- **Temporary Password**: Random password (must be changed on first login)
- **Login URL**: `https://<ACCOUNT_ID>.signin.aws.amazon.com/console`

### Step 2: First Login

1. **Open the login URL** in your web browser
   - Example: `https://123456789012.signin.aws.amazon.com/console`

2. **Enter your credentials:**
   - Account ID: (already filled in the URL)
   - IAM user name: `vinod-provigence`
   - Password: Your temporary password

3. **Change your password:**
   - You'll be prompted to change your password immediately
   - Choose a strong password (at least 8 characters)
   - Remember this password - you'll need it for future logins

4. **You're in!** You should see the AWS Console homepage

### Step 3: Navigate to S3

1. In the AWS Console, find the search bar at the top
2. Type "S3" and click on **S3** service
3. You'll see the S3 dashboard with all buckets

## Using S3

### View Buckets

- The main S3 page shows all buckets in the account
- You'll see buckets like `greendotball-bot-data` and others
- Click on any bucket name to view its contents

### Upload Files (Images)

**Method 1: Using the Console (Easy)**

1. Click on the bucket name (e.g., `greendotball-bot-data`)
2. Navigate to the folder where you want to upload (e.g., `images/` or `images-pool/`)
3. Click the **Upload** button
4. Click **Add files** or drag and drop files
5. Select your image files from your computer
6. Click **Upload** at the bottom
7. Wait for upload to complete - you'll see a success message

**Method 2: Create a Folder First**

1. Inside a bucket, click **Create folder**
2. Enter folder name (e.g., `my-images`)
3. Click **Create folder**
4. Click on the new folder
5. Upload files as described above

### Download Files

1. Navigate to the file you want to download
2. Check the checkbox next to the file
3. Click **Download** button
4. File will download to your computer

### Delete Files

1. Navigate to the file you want to delete
2. Check the checkbox next to the file
3. Click **Delete** button
4. Confirm deletion by typing "delete" in the confirmation box
5. Click **Delete objects**

### Create a New Bucket

1. From the S3 main page, click **Create bucket**
2. Enter a unique bucket name (must be globally unique across all AWS)
   - Example: `vinod-images-2026`
   - Use lowercase letters, numbers, and hyphens only
3. Select region: **Asia Pacific (Mumbai) ap-south-1** (recommended)
4. Leave other settings as default
5. Click **Create bucket**

### Delete a Bucket

1. Select the bucket by checking its checkbox
2. Click **Delete** button
3. **Important:** Bucket must be empty before deletion
4. If not empty, open bucket and delete all files first
5. Confirm deletion by typing the bucket name
6. Click **Delete bucket**

## Important Buckets

### greendotball-bot-data

This is the main bucket for the GreenDotBall project. It contains:

- `images/` - General images
- `images-pool/` - Pool of images for campaigns
- `rename-images/` - Renamed images
- `campaigns/` - Campaign data and results

**When uploading images here:**
- Use the `images-pool/` folder for general image uploads
- Supported formats: JPG, JPEG, PNG, GIF, WEBP
- Keep file names simple (no special characters)

## Tips & Best Practices

### File Naming

✅ **Good file names:**
- `image_001.jpg`
- `product-photo.png`
- `banner_2026.jpg`

❌ **Avoid:**
- Spaces in names: `my image.jpg` → use `my_image.jpg`
- Special characters: `photo@#$.jpg`
- Very long names

### File Organization

- Use folders to organize files by category
- Example structure:
  ```
  greendotball-bot-data/
  ├── images-pool/
  │   ├── category1/
  │   ├── category2/
  │   └── category3/
  ```

### File Size

- S3 can handle files up to 5TB
- For web images, keep under 5MB for faster loading
- Compress large images before uploading

### Security

- **Never share your password** with anyone
- **Log out** when done: Click your username → Sign Out
- **Change password regularly** (every 90 days recommended)
- If you forget your password, contact the admin for a reset

## Troubleshooting

### Cannot Login

**Problem:** "Invalid credentials" error

**Solutions:**
1. Double-check AWS Account ID is correct
2. Verify username is exactly: `vinod-provigence` (case-sensitive)
3. Make sure you're using the correct password
4. Contact admin to reset password if forgotten

### Cannot See S3 Service

**Problem:** S3 not visible in AWS Console

**Solutions:**
1. Use the search bar at top and type "S3"
2. You may see "Access Denied" for other services - this is normal
3. You only have access to S3

### Upload Fails

**Problem:** File upload shows error

**Solutions:**
1. Check file size (very large files may timeout)
2. Check internet connection
3. Try uploading one file at a time
4. Refresh the page and try again
5. Try a different browser (Chrome, Firefox, Safari)

### "Access Denied" Error

**Problem:** Cannot access a bucket or file

**Solutions:**
1. This shouldn't happen - you have full S3 access
2. Contact admin if you consistently see this error
3. Try logging out and logging back in

## Advanced: Using AWS CLI (Optional)

If you're comfortable with command line tools, you can use AWS CLI for faster uploads.

### Setup AWS CLI

1. Install AWS CLI: https://aws.amazon.com/cli/
2. Run: `aws configure`
3. You'll need to create access keys (contact admin)

### Upload Files via CLI

```bash
# Upload single file
aws s3 cp myimage.jpg s3://greendotball-bot-data/images-pool/

# Upload entire folder
aws s3 sync ./my-images/ s3://greendotball-bot-data/images-pool/

# List bucket contents
aws s3 ls s3://greendotball-bot-data/images-pool/

# Download file
aws s3 cp s3://greendotball-bot-data/images-pool/image.jpg ./
```

## Keyboard Shortcuts

When in S3 Console:

- **Ctrl/Cmd + F**: Search within current page
- **Refresh**: F5 or Cmd+R to refresh bucket contents
- **Select All**: Ctrl/Cmd + A (when in file list)

## Getting Help

### Need to Reset Password?

Contact the admin who set up your account.

### Questions About S3?

- AWS S3 Documentation: https://docs.aws.amazon.com/s3/
- AWS Support: Available through AWS Console (if enabled)

### Technical Issues?

Contact your admin with:
- What you were trying to do
- Error message (take a screenshot)
- Browser and operating system you're using

## Quick Reference

| Task | Steps |
|------|-------|
| Login | Use login URL → Enter username & password |
| Upload file | S3 → Bucket → Upload → Add files → Upload |
| Download file | Select file → Download |
| Delete file | Select file → Delete → Confirm |
| Create folder | Inside bucket → Create folder |
| Create bucket | S3 main page → Create bucket |
| Logout | Username (top right) → Sign Out |

## Contact Information

For account issues, password resets, or access problems, contact your AWS account administrator.

---

**Welcome to AWS S3!** You now have full access to manage images and files. If you have any questions, don't hesitate to reach out to your admin.
