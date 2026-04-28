#!/bin/bash
# copy-random-s3-images.sh
# Copy random images from one S3 prefix to another
#
# Usage:
#   chmod +x scripts/copy-random-s3-images.sh
#   ./scripts/copy-random-s3-images.sh <source_prefix> <dest_prefix> <count>
#
# Example:
#   ./scripts/copy-random-s3-images.sh green_ball_image_20_v1apr green_ball_image_28apr 4000

set -e

# ─── CONFIG ────────────────────────────────────────────────────────────────────
S3_BUCKET="greendotball-bot-data"
REGION="ap-south-1"
# ───────────────────────────────────────────────────────────────────────────────

# ─── ARGUMENTS ─────────────────────────────────────────────────────────────────
SRC_PREFIX="${1}"
DEST_PREFIX="${2}"
COUNT="${3:-4000}"
# ───────────────────────────────────────────────────────────────────────────────

echo ""
echo "=================================================="
echo "  COPY RANDOM S3 IMAGES"
echo "  Source  : s3://${S3_BUCKET}/${SRC_PREFIX}/"
echo "  Dest    : s3://${S3_BUCKET}/${DEST_PREFIX}/"
echo "  Count   : ${COUNT} images"
echo "  Region  : ${REGION}"
echo "=================================================="
echo ""

# ─── VALIDATE ARGS ─────────────────────────────────────────────────────────────
if [ -z "$SRC_PREFIX" ] || [ -z "$DEST_PREFIX" ]; then
  echo "❌ Usage: $0 <source_prefix> <dest_prefix> [count]"
  echo "   Example: $0 green_ball_image_20_v1apr green_ball_image_28apr 4000"
  exit 1
fi

if ! [[ "$COUNT" =~ ^[0-9]+$ ]]; then
  echo "❌ Count must be a number"
  exit 1
fi
# ───────────────────────────────────────────────────────────────────────────────

# ─── CHECK AWS CLI ─────────────────────────────────────────────────────────────
if ! command -v aws &>/dev/null; then
  echo "❌ AWS CLI not found. Please install it first."
  exit 1
fi
echo "✅ AWS CLI: $(aws --version 2>&1 | head -1)"
echo ""
# ───────────────────────────────────────────────────────────────────────────────

# ─── GET SOURCE IMAGE LIST ─────────────────────────────────────────────────────
echo "🔍 Fetching image list from source..."
TEMP_LIST=$(mktemp)

aws s3 ls "s3://${S3_BUCKET}/${SRC_PREFIX}/" --recursive --region "$REGION" | \
  awk '{print $4}' | \
  grep -E '\.(jpg|jpeg|png|gif|webp|bmp|tiff)$' > "$TEMP_LIST"

TOTAL_AVAILABLE=$(wc -l < "$TEMP_LIST" | tr -d ' ')

if [ "$TOTAL_AVAILABLE" -eq 0 ]; then
  echo "❌ No images found in s3://${S3_BUCKET}/${SRC_PREFIX}/"
  rm -f "$TEMP_LIST"
  exit 1
fi

echo "✅ Found $TOTAL_AVAILABLE images in source"

if [ "$COUNT" -gt "$TOTAL_AVAILABLE" ]; then
  echo "⚠️  Requested $COUNT images but only $TOTAL_AVAILABLE available"
  echo "   Will copy all $TOTAL_AVAILABLE images"
  COUNT=$TOTAL_AVAILABLE
fi
echo ""
# ───────────────────────────────────────────────────────────────────────────────

# ─── SELECT RANDOM IMAGES ──────────────────────────────────────────────────────
echo "🎲 Selecting $COUNT random images..."
RANDOM_LIST=$(mktemp)
shuf -n "$COUNT" "$TEMP_LIST" > "$RANDOM_LIST"
echo "✅ Selected $COUNT images"
echo ""
# ───────────────────────────────────────────────────────────────────────────────

# ─── COPY IMAGES ───────────────────────────────────────────────────────────────
echo "──────────────────────────────────────────────────"
echo "  Copying images to destination..."
echo "──────────────────────────────────────────────────"

COPIED=0
FAILED=0
SKIPPED=0

while IFS= read -r src_key; do
  # Extract just the filename
  FILENAME=$(basename "$src_key")
  
  # Build S3 paths
  SRC_PATH="s3://${S3_BUCKET}/${src_key}"
  DEST_PATH="s3://${S3_BUCKET}/${DEST_PREFIX}/${FILENAME}"
  
  # Check if destination already exists
  if aws s3 ls "$DEST_PATH" --region "$REGION" &>/dev/null; then
    SKIPPED=$((SKIPPED + 1))
    echo "  ⏭️  [$((COPIED + SKIPPED + FAILED))/$COUNT] $FILENAME (already exists)"
    continue
  fi
  
  # Copy image
  if aws s3 cp "$SRC_PATH" "$DEST_PATH" --region "$REGION" --quiet; then
    COPIED=$((COPIED + 1))
    echo "  ✅ [$((COPIED + SKIPPED + FAILED))/$COUNT] $FILENAME"
  else
    FAILED=$((FAILED + 1))
    echo "  ❌ FAILED: $FILENAME"
  fi
  
done < "$RANDOM_LIST"
# ───────────────────────────────────────────────────────────────────────────────

# ─── CLEANUP ───────────────────────────────────────────────────────────────────
rm -f "$TEMP_LIST" "$RANDOM_LIST"
# ───────────────────────────────────────────────────────────────────────────────

# ─── SUMMARY ───────────────────────────────────────────────────────────────────
echo ""
echo "=================================================="
echo "  ✅ DONE"
echo "  Copied   : $COPIED images"
if [ "$SKIPPED" -gt 0 ]; then
  echo "  Skipped  : $SKIPPED images (already existed)"
fi
if [ "$FAILED" -gt 0 ]; then
  echo "  ❌ Failed: $FAILED images"
fi
echo "  Dest     : s3://${S3_BUCKET}/${DEST_PREFIX}/"
echo "=================================================="
echo ""
echo "  Verify destination count:"
echo "    aws s3 ls s3://${S3_BUCKET}/${DEST_PREFIX}/ --recursive | wc -l"
echo ""
# ───────────────────────────────────────────────────────────────────────────────
