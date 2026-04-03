#!/bin/bash
# upload-image-pool.sh
# One-time script: uploads images from data/images/ to the shared S3 pool.
# The pool is used by campaigns that select "Use Image Pool" in the UI.
# S3 path: s3://greendotball-bot-data/images-pool/
#
# Usage (run from repo root):
#   chmod +x scripts/upload-image-pool.sh
#   ./scripts/upload-image-pool.sh [images-dir]
#
# Example:
#   ./scripts/upload-image-pool.sh data/images

set -e

S3_BUCKET="greendotball-bot-data"
POOL_PREFIX="images-pool"
REGION="ap-south-1"
IMAGE_DIR="${1:-data/images}"

echo ""
echo "=================================================="
echo "  UPLOAD IMAGE POOL"
echo "  Source : $IMAGE_DIR"
echo "  S3     : s3://${S3_BUCKET}/${POOL_PREFIX}/"
echo "=================================================="
echo ""

if [ ! -d "$IMAGE_DIR" ]; then
  echo "❌ ERROR: Directory '$IMAGE_DIR' not found."
  echo "   Run from repo root: ./scripts/upload-image-pool.sh data/images"
  exit 1
fi

IMAGES=($(ls "$IMAGE_DIR"/*.{jpg,jpeg,png,JPG,JPEG,PNG,gif,webp} 2>/dev/null))

if [ ${#IMAGES[@]} -eq 0 ]; then
  echo "❌ ERROR: No images found in $IMAGE_DIR"
  exit 1
fi

echo "Found ${#IMAGES[@]} images to upload..."
echo ""

COUNT=0
for img in "${IMAGES[@]}"; do
  FILENAME=$(basename "$img")
  aws s3 cp "$img" "s3://${S3_BUCKET}/${POOL_PREFIX}/${FILENAME}" --region $REGION
  COUNT=$((COUNT + 1))
  echo "  ✅ [$COUNT/${#IMAGES[@]}] $FILENAME"
done

echo ""
echo "=================================================="
echo "  ✅ POOL READY"
echo "  Uploaded : $COUNT images"
echo "  S3 path  : s3://${S3_BUCKET}/${POOL_PREFIX}/"
echo "=================================================="
echo ""
echo "  List pool contents:"
echo "    aws s3 ls s3://${S3_BUCKET}/${POOL_PREFIX}/ --region $REGION"
echo ""
