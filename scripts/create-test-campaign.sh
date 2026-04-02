#!/bin/bash
# create-test-campaign.sh
# Run this LOCALLY (needs AWS CLI + your images in data/images/)
# Creates a minimal test campaign in S3 so you can test bot_new.js on EC2
#
# Usage:
#   chmod +x scripts/create-test-campaign.sh
#   ./scripts/create-test-campaign.sh

set -e

S3_BUCKET="greendotball-bot-data"
REGION="ap-south-1"

# ── Generate a test campaign ID ───────────────────────────────────────────────
TIMESTAMP=$(date +"%H%M%S")
CAMPAIGN_ID="test-$(date +%b | tr '[:upper:]' '[:lower:]')-$(date +%d-%Y)-manual-${TIMESTAMP}"
echo ""
echo "=================================================="
echo "  TEST CAMPAIGN SETUP"
echo "  Campaign ID: $CAMPAIGN_ID"
echo "=================================================="
echo ""

# ── 1. Upload test phone numbers (2 phones) ───────────────────────────────────
echo "[1/5] Uploading phones.txt..."
printf "9810887396\n9810846436\n" > /tmp/test-phones.txt
aws s3 cp /tmp/test-phones.txt "s3://${S3_BUCKET}/campaigns/${CAMPAIGN_ID}/phones.txt" --region $REGION
echo "      ✅ phones.txt uploaded (2 numbers)"

# ── 2. Upload test images (first 10 images from data/images/) ─────────────────
echo "[2/5] Uploading test images..."
IMAGE_DIR="data/images"
if [ ! -d "$IMAGE_DIR" ]; then
  echo "      ❌ ERROR: $IMAGE_DIR not found. Run from repo root."
  exit 1
fi

IMAGES=($(ls "$IMAGE_DIR"/*.{jpg,jpeg,png,JPG,PNG} 2>/dev/null | head -10))
if [ ${#IMAGES[@]} -eq 0 ]; then
  echo "      ❌ ERROR: No images found in $IMAGE_DIR"
  exit 1
fi

IMG_COUNT=0
for img in "${IMAGES[@]}"; do
  FILENAME=$(basename "$img")
  aws s3 cp "$img" "s3://${S3_BUCKET}/campaigns/${CAMPAIGN_ID}/images/${FILENAME}" --region $REGION
  IMG_COUNT=$((IMG_COUNT + 1))
done
echo "      ✅ $IMG_COUNT images uploaded"

# ── 3. Create job files (1 phone × 10 images = 1 job, ×2 phones = 2 jobs) ────
echo "[3/5] Creating job files..."

PHONES=("9810887396" "9810846436")
JOB_NUM=1
ALL_JOB_IDS=""

for PHONE in "${PHONES[@]}"; do
  JOB_ID=$(printf "job-%03d" $JOB_NUM)
  JOB_FILE="/tmp/${JOB_ID}.json"

  # Build image list JSON array
  IMG_JSON="["
  FIRST=true
  for img in "${IMAGES[@]}"; do
    FILENAME=$(basename "$img")
    if [ "$FIRST" = true ]; then FIRST=false; else IMG_JSON="${IMG_JSON},"; fi
    IMG_JSON="${IMG_JSON}\"campaigns/${CAMPAIGN_ID}/images/${FILENAME}\""
  done
  IMG_JSON="${IMG_JSON}]"

  cat > "$JOB_FILE" <<EOF
{
  "jobId": "${JOB_ID}",
  "campaignId": "${CAMPAIGN_ID}",
  "phone": "${PHONE}",
  "images": ${IMG_JSON},
  "submissions": ${#IMAGES[@]},
  "status": "pending",
  "createdAt": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF

  aws s3 cp "$JOB_FILE" "s3://${S3_BUCKET}/campaigns/${CAMPAIGN_ID}/jobs/${JOB_ID}.json" --region $REGION
  echo "      ✅ Uploaded ${JOB_ID} (phone: ${PHONE}, images: ${#IMAGES[@]})"

  if [ -z "$ALL_JOB_IDS" ]; then ALL_JOB_IDS="$JOB_ID"; else ALL_JOB_IDS="${ALL_JOB_IDS},${JOB_ID}"; fi
  JOB_NUM=$((JOB_NUM + 1))
done

# ── 4. Upload masterjob.json ──────────────────────────────────────────────────
echo "[4/5] Uploading masterjob.json..."
cat > /tmp/masterjob.json <<EOF
{
  "campaignId": "${CAMPAIGN_ID}",
  "totalJobs": $((JOB_NUM - 1)),
  "jobIds": ["$(echo $ALL_JOB_IDS | sed 's/,/","/g')"],
  "createdAt": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
aws s3 cp /tmp/masterjob.json "s3://${S3_BUCKET}/campaigns/${CAMPAIGN_ID}/jobs/masterjob.json" --region $REGION
echo "      ✅ masterjob.json uploaded"

# ── 5. Upload metadata.json ───────────────────────────────────────────────────
echo "[5/5] Uploading metadata.json..."
cat > /tmp/metadata.json <<EOF
{
  "campaignId": "${CAMPAIGN_ID}",
  "campaignName": "Manual Test Campaign",
  "phoneCount": 2,
  "imageCount": ${#IMAGES[@]},
  "totalJobs": $((JOB_NUM - 1)),
  "status": "jobs_created",
  "createdAt": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
aws s3 cp /tmp/metadata.json "s3://${S3_BUCKET}/campaigns/${CAMPAIGN_ID}/metadata.json" --region $REGION
echo "      ✅ metadata.json uploaded"

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "=================================================="
echo "  ✅ TEST CAMPAIGN READY"
echo "=================================================="
echo ""
echo "  Campaign ID : $CAMPAIGN_ID"
echo "  Job IDs     : $ALL_JOB_IDS"
echo "  S3 Path     : s3://${S3_BUCKET}/campaigns/${CAMPAIGN_ID}/"
echo ""
echo "  Copy these exports for the EC2 test:"
echo ""
echo "  export CAMPAIGN_ID=\"${CAMPAIGN_ID}\""
echo "  export JOB_IDS=\"${ALL_JOB_IDS}\""
echo ""
echo "  Then on EC2 run:"
echo "    node src/bot_new.js"
echo "  Or full startup script test:"
echo "    bash scripts/run-job-bot.sh"
echo ""
