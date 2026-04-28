#!/bin/bash
# resize-and-upload-s3.sh
# Resizes images from SRC_DIR to DEST_DIR and uploads them to S3.
#
# Usage:
#   chmod +x scripts/resize-and-upload-s3.sh
#   ./scripts/resize-and-upload-s3.sh <src_dir> <dest_dir> [s3_prefix]
#
# Examples:
#   ./scripts/resize-and-upload-s3.sh data/images data/resized_images images-pool
#   ./scripts/resize-and-upload-s3.sh /home/ec2-user/images /home/ec2-user/resized images-resized
#
# Notes:
#   - Requires Python3 + Pillow installed on the server
#   - Requires AWS CLI configured with appropriate IAM permissions
#   - S3 bucket is fixed to greendotball-bot-data (change S3_BUCKET below if needed)

set -e

# ─── CONFIG ────────────────────────────────────────────────────────────────────
S3_BUCKET="greendotball-bot-data"
REGION="ap-south-1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESIZER_SCRIPT="$SCRIPT_DIR/image_resizer.py"
# ───────────────────────────────────────────────────────────────────────────────

# ─── ARGUMENTS ─────────────────────────────────────────────────────────────────
SRC_DIR="${1}"
DEST_DIR="${2}"
S3_PREFIX="${3:-images-resized}"
# ───────────────────────────────────────────────────────────────────────────────

echo ""
echo "=================================================="
echo "  RESIZE + S3 UPLOAD"
echo "  Source  : $SRC_DIR"
echo "  Dest    : $DEST_DIR"
echo "  S3      : s3://${S3_BUCKET}/${S3_PREFIX}/"
echo "  Region  : $REGION"
echo "=================================================="
echo ""

# ─── VALIDATE ARGS ─────────────────────────────────────────────────────────────
if [ -z "$SRC_DIR" ] || [ -z "$DEST_DIR" ]; then
  echo "❌ Usage: $0 <src_dir> <dest_dir> [s3_prefix]"
  echo "   Example: $0 data/images data/resized_images images-resized"
  exit 1
fi

if [ ! -d "$SRC_DIR" ]; then
  echo "❌ ERROR: Source directory '$SRC_DIR' not found."
  exit 1
fi

if [ ! -f "$RESIZER_SCRIPT" ]; then
  echo "❌ ERROR: image_resizer.py not found at $RESIZER_SCRIPT"
  exit 1
fi
# ───────────────────────────────────────────────────────────────────────────────

# ─── CHECK DEPENDENCIES ────────────────────────────────────────────────────────
echo "🔍 Checking dependencies..."

# Check Python3
if ! command -v python3 &>/dev/null; then
  echo "❌ Python3 not found. Installing..."
  sudo yum install -y python3 2>/dev/null || sudo apt-get install -y python3 2>/dev/null || {
    echo "❌ Failed to install Python3. Please install manually."
    exit 1
  }
fi
echo "  ✅ Python3: $(python3 --version)"

# Check Pillow
if ! python3 -c "import PIL" &>/dev/null; then
  echo "📦 Pillow not found. Installing..."
  pip3 install Pillow --quiet
  echo "  ✅ Pillow installed"
else
  echo "  ✅ Pillow: OK"
fi

# Check AWS CLI
if ! command -v aws &>/dev/null; then
  echo "❌ AWS CLI not found. Please install it first."
  echo "   https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html"
  exit 1
fi
echo "  ✅ AWS CLI: $(aws --version 2>&1 | head -1)"
echo ""
# ───────────────────────────────────────────────────────────────────────────────

# ─── STEP 1: RESIZE IMAGES ─────────────────────────────────────────────────────
echo "──────────────────────────────────────────────────"
echo "  STEP 1: Resizing images..."
echo "──────────────────────────────────────────────────"

python3 "$RESIZER_SCRIPT" "$SRC_DIR" "$DEST_DIR"

if [ $? -ne 0 ]; then
  echo "❌ Image resizing failed."
  exit 1
fi
echo ""
# ───────────────────────────────────────────────────────────────────────────────

# ─── STEP 2: UPLOAD TO S3 ─────────────────────────────────────────────────────
echo "──────────────────────────────────────────────────"
echo "  STEP 2: Uploading to S3..."
echo "──────────────────────────────────────────────────"

# Count images to upload
TOTAL=0
while IFS= read -r -d '' img; do
  TOTAL=$((TOTAL + 1))
done < <(find "$DEST_DIR" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.gif' -o -iname '*.webp' -o -iname '*.bmp' -o -iname '*.tiff' -o -iname '*.webp' \) -print0 2>/dev/null)

if [ "$TOTAL" -eq 0 ]; then
  echo "❌ No resized images found in $DEST_DIR"
  exit 1
fi

echo "Found $TOTAL resized images to upload..."
echo ""

COUNT=0
FAILED=0
while IFS= read -r -d '' img; do
  FILENAME=$(basename "$img")
  S3_PATH="s3://${S3_BUCKET}/${S3_PREFIX}/${FILENAME}"

  if aws s3 cp "$img" "$S3_PATH" --region "$REGION" --quiet; then
    COUNT=$((COUNT + 1))
    echo "  ✅ [$COUNT/$TOTAL] $FILENAME"
  else
    FAILED=$((FAILED + 1))
    echo "  ❌ FAILED: $FILENAME"
  fi
done < <(find "$DEST_DIR" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.gif' -o -iname '*.webp' -o -iname '*.bmp' -o -iname '*.tiff' -o -iname '*.webp' \) -print0 2>/dev/null)
# ───────────────────────────────────────────────────────────────────────────────

# ─── SUMMARY ───────────────────────────────────────────────────────────────────
echo ""
echo "=================================================="
echo "  ✅ DONE"
echo "  Uploaded  : $COUNT / $TOTAL images"
if [ "$FAILED" -gt 0 ]; then
  echo "  ❌ Failed : $FAILED images"
fi
echo "  S3 path   : s3://${S3_BUCKET}/${S3_PREFIX}/"
echo "=================================================="
echo ""
echo "  View uploaded images:"
echo "    aws s3 ls s3://${S3_BUCKET}/${S3_PREFIX}/ --region $REGION"
echo ""
# ───────────────────────────────────────────────────────────────────────────────
