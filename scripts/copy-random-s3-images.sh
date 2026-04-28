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

# ─── CONFIG ────────────────────────────────────────────────────────────────────
S3_BUCKET="greendotball-bot-data"
REGION="ap-south-1"
PARALLEL=10
# ───────────────────────────────────────────────────────────────────────────────

# ─── ARGUMENTS ─────────────────────────────────────────────────────────────────
SRC_PREFIX="${1}"
DEST_PREFIX="${2}"
COUNT="${3:-4000}"
# ───────────────────────────────────────────────────────────────────────────────

echo ""
echo "=================================================="
echo "  COPY RANDOM S3 IMAGES (PARALLEL)"
echo "  Source  : s3://${S3_BUCKET}/${SRC_PREFIX}/"
echo "  Dest    : s3://${S3_BUCKET}/${DEST_PREFIX}/"
echo "  Count   : ${COUNT} images"
echo "  Workers : ${PARALLEL} parallel"
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

# ─── COPY IMAGES (PARALLEL) ───────────────────────────────────────────────────
echo "──────────────────────────────────────────────────"
echo "  Copying $COUNT images with $PARALLEL parallel workers..."
echo "──────────────────────────────────────────────────"

copy_one() {
  local src_key="$1"
  local bucket="$2"
  local dest_prefix="$3"
  local region="$4"
  local filename
  filename=$(basename "$src_key")
  if aws s3 cp "s3://${bucket}/${src_key}" "s3://${bucket}/${dest_prefix}/${filename}" \
      --region "$region" --quiet 2>/dev/null; then
    echo "  ✅ $filename"
  else
    echo "  ❌ FAILED: $filename" >&2
  fi
}
export -f copy_one

xargs -P "$PARALLEL" -I {} \
  bash -c 'copy_one "$@"' _ {} "$S3_BUCKET" "$DEST_PREFIX" "$REGION" \
  < "$RANDOM_LIST"
# ───────────────────────────────────────────────────────────────────────────────

# ─── CLEANUP ───────────────────────────────────────────────────────────────────
rm -f "$TEMP_LIST" "$RANDOM_LIST"
# ───────────────────────────────────────────────────────────────────────────────

# ─── SUMMARY ───────────────────────────────────────────────────────────────────
echo ""
echo "=================================================="
echo "  ✅ DONE"
FINAL_COUNT=$(aws s3 ls "s3://${S3_BUCKET}/${DEST_PREFIX}/" --recursive --region "$REGION" | wc -l | tr -d ' ')
echo "  Total in dest : $FINAL_COUNT images"
echo "  Dest          : s3://${S3_BUCKET}/${DEST_PREFIX}/"
echo "=================================================="
echo ""
# ───────────────────────────────────────────────────────────────────────────────
