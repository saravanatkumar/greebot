#!/bin/bash
# create-campaign-pool-20img.sh
# Campaign creator for 5 phones × 20 images = 100 submissions per job
#
# Reads phones from data/phones.txt, picks images from S3 pool,
# creates job files (5 phones × 20 images = 100 submissions per job),
# uploads everything to S3, and prints EC2 export commands.
#
# Usage (run from repo root):
#   chmod +x scripts/create-campaign-pool-20img.sh
#   ./scripts/create-campaign-pool-20img.sh [campaign-name]
#
# Prerequisites:
#   - data/phones.txt exists with 10-digit numbers, one per line
#   - S3 image pool populated: ./scripts/upload-image-pool.sh data/images
#   - AWS CLI configured with access to greendotball-bot-data bucket

set -e

S3_BUCKET="greendotball-bot-data"
POOL_PREFIX="green_ball_image_25apr/"
REGION="ap-south-1"
PHONES_FILE="data/phones.txt"
PHONES_PER_JOB=9
IMAGES_PER_JOB=20
CAMPAIGN_NAME="${1:-pool-campaign}"

# ── Generate campaign ID ──────────────────────────────────────────────────────
TIMESTAMP=$(date +"%H%M%S")
MONTH=$(date +%b | tr '[:upper:]' '[:lower:]')
DAY=$(date +%d)
YEAR=$(date +%Y)
SLUG=$(echo "$CAMPAIGN_NAME" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | sed 's/[^a-z0-9-]//g' | cut -c1-12)
CAMPAIGN_ID="${MONTH}-${DAY}-${YEAR}-${SLUG}-${TIMESTAMP}"

echo ""
echo "=================================================="
echo "  CREATE CAMPAIGN (POOL MODE - 20 IMAGES)"
echo "  Campaign  : $CAMPAIGN_NAME"
echo "  ID        : $CAMPAIGN_ID"
echo "  Phones    : $PHONES_FILE"
echo "  Pool      : s3://${S3_BUCKET}/${POOL_PREFIX}"
echo "  Format    : 6 phones × 20 images = 120 submissions/job"
echo "=================================================="
echo ""

# ── Validate phones file ──────────────────────────────────────────────────────
if [ ! -f "$PHONES_FILE" ]; then
  echo "❌ ERROR: $PHONES_FILE not found."
  echo "   Create it with one 10-digit phone number per line."
  exit 1
fi

# Read valid 10-digit phones
PHONES=()
while IFS= read -r line; do
  p=$(echo "$line" | tr -d '[:space:]')
  if [[ "$p" =~ ^[0-9]{10}$ ]]; then
    PHONES+=("$p")
  fi
done < "$PHONES_FILE"

TOTAL_PHONES=${#PHONES[@]}
if [ "$TOTAL_PHONES" -eq 0 ]; then
  echo "❌ ERROR: No valid 10-digit phone numbers found in $PHONES_FILE"
  exit 1
fi

echo "[1/5] Phones loaded: $TOTAL_PHONES numbers"

# ── Upload phones.txt to S3 ───────────────────────────────────────────────────
printf '%s\n' "${PHONES[@]}" > /tmp/campaign-phones.txt
aws s3 cp /tmp/campaign-phones.txt "s3://${S3_BUCKET}/campaigns/${CAMPAIGN_ID}/phones.txt" \
  --region $REGION --quiet
echo "      ✅ phones.txt uploaded to S3"

# ── List images from pool ─────────────────────────────────────────────────────
echo "[2/5] Fetching image pool from S3..."

echo "      Querying S3 (this may take a moment)..."
IMAGE_LIST=$(aws s3 ls "s3://${S3_BUCKET}/${POOL_PREFIX}" --region $REGION \
  | awk '{print $4}' | grep -iE '\.(jpg|jpeg|png|gif|webp)$')

if [ -z "$IMAGE_LIST" ]; then
  echo "❌ ERROR: No images found in s3://${S3_BUCKET}/${POOL_PREFIX}"
  echo "   Run: ./scripts/upload-image-pool.sh data/images"
  exit 1
fi

# Load images into array
IMAGES=()
while IFS= read -r img; do
  [ -n "$img" ] && IMAGES+=("${POOL_PREFIX}${img}")
done <<< "$IMAGE_LIST"

TOTAL_IMAGES=${#IMAGES[@]}
echo "      ✅ Found $TOTAL_IMAGES images in pool"

# ── Calculate jobs ────────────────────────────────────────────────────────────
TOTAL_JOBS=$(( (TOTAL_PHONES + PHONES_PER_JOB - 1) / PHONES_PER_JOB ))
echo "[3/5] Creating $TOTAL_JOBS jobs (7 phones × 20 images = 140 submissions each)..."
echo ""

ALL_JOB_IDS=""
JOB_NUM=1
GLOBAL_IMG_IDX=0   # sequential pointer across ALL pairs — never repeats until pool exhausted

for (( chunk=0; chunk<TOTAL_PHONES; chunk+=PHONES_PER_JOB )); do
  JOB_ID=$(printf "job-%03d" $JOB_NUM)
  JOB_FILE="/tmp/${CAMPAIGN_ID}-${JOB_ID}.json"

  # Phone group for this job
  PHONE_GROUP=()
  for (( pi=chunk; pi<chunk+PHONES_PER_JOB && pi<TOTAL_PHONES; pi++ )); do
    PHONE_GROUP+=("${PHONES[$pi]}")
  done

  # Build pairs JSON (every phone × images sequentially, no duplicates per phone)
  PAIRS_JSON="["
  FIRST=true
  PAIR_IDX=1
  for phone in "${PHONE_GROUP[@]}"; do
    for (( ki=0; ki<IMAGES_PER_JOB; ki++ )); do
      IMG_IDX=$(( GLOBAL_IMG_IDX % TOTAL_IMAGES ))
      imgKey="${IMAGES[$IMG_IDX]}"
      GLOBAL_IMG_IDX=$(( GLOBAL_IMG_IDX + 1 ))
      if [ "$FIRST" = true ]; then FIRST=false; else PAIRS_JSON="${PAIRS_JSON},"; fi
      PAIRS_JSON="${PAIRS_JSON}
        {\"id\":\"${JOB_ID}-pair-${PAIR_IDX}\",\"phoneNumber\":\"${phone}\",\"imagePath\":\"${imgKey}\"}"
      PAIR_IDX=$((PAIR_IDX + 1))
    done
  done
  PAIRS_JSON="${PAIRS_JSON}
  ]"

  SUBMISSIONS=$((${#PHONE_GROUP[@]} * IMAGES_PER_JOB))

  # Write job JSON file
  cat > "$JOB_FILE" <<EOF
{
  "jobId": "${JOB_ID}",
  "campaignId": "${CAMPAIGN_ID}",
  "imageSource": "pool",
  "phoneCount": ${#PHONE_GROUP[@]},
  "imageCount": ${IMAGES_PER_JOB},
  "submissions": ${SUBMISSIONS},
  "createdAt": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "pairs": ${PAIRS_JSON}
}
EOF

  # Upload to S3
  aws s3 cp "$JOB_FILE" "s3://${S3_BUCKET}/campaigns/${CAMPAIGN_ID}/jobs/${JOB_ID}.json" \
    --region $REGION --quiet

  echo "  ✅ $JOB_ID | phones: ${#PHONE_GROUP[@]} | images: $IMAGES_PER_JOB | submissions: $SUBMISSIONS"

  if [ -z "$ALL_JOB_IDS" ]; then ALL_JOB_IDS="$JOB_ID"; else ALL_JOB_IDS="${ALL_JOB_IDS},${JOB_ID}"; fi
  JOB_NUM=$((JOB_NUM + 1))
done

ACTUAL_JOBS=$((JOB_NUM - 1))
TOTAL_SUBMISSIONS=$((ACTUAL_JOBS * PHONES_PER_JOB * IMAGES_PER_JOB))

# ── Upload masterjob.json ─────────────────────────────────────────────────────
echo ""
echo "[4/5] Uploading masterjob.json..."

JOB_IDS_JSON=$(echo "$ALL_JOB_IDS" | sed 's/,/","/g')
cat > /tmp/masterjob.json <<EOF
{
  "campaignId": "${CAMPAIGN_ID}",
  "campaignName": "${CAMPAIGN_NAME}",
  "imageSource": "pool",
  "totalJobs": ${ACTUAL_JOBS},
  "phoneCount": ${TOTAL_PHONES},
  "imageCount": ${TOTAL_IMAGES},
  "phonesPerJob": ${PHONES_PER_JOB},
  "imagesPerJob": ${IMAGES_PER_JOB},
  "totalSubmissions": ${TOTAL_SUBMISSIONS},
  "jobIds": ["${JOB_IDS_JSON}"],
  "createdAt": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
aws s3 cp /tmp/masterjob.json "s3://${S3_BUCKET}/campaigns/${CAMPAIGN_ID}/jobs/masterjob.json" \
  --region $REGION --quiet
echo "      ✅ masterjob.json uploaded"

# ── Upload metadata.json ──────────────────────────────────────────────────────
echo "[5/5] Uploading metadata.json..."
cat > /tmp/metadata.json <<EOF
{
  "campaignId": "${CAMPAIGN_ID}",
  "campaignName": "${CAMPAIGN_NAME}",
  "imageSource": "pool",
  "phoneCount": ${TOTAL_PHONES},
  "imageCount": ${TOTAL_IMAGES},
  "phonesPerJob": ${PHONES_PER_JOB},
  "imagesPerJob": ${IMAGES_PER_JOB},
  "totalJobs": ${ACTUAL_JOBS},
  "totalSubmissions": ${TOTAL_SUBMISSIONS},
  "status": "jobs_created",
  "createdAt": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
aws s3 cp /tmp/metadata.json "s3://${S3_BUCKET}/campaigns/${CAMPAIGN_ID}/metadata.json" \
  --region $REGION --quiet
echo "      ✅ metadata.json uploaded"

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "=================================================="
echo "  ✅ CAMPAIGN READY"
echo "=================================================="
echo ""
echo "  Campaign ID       : $CAMPAIGN_ID"
echo "  Total phones      : $TOTAL_PHONES"
echo "  Total jobs        : $ACTUAL_JOBS"
echo "  Submissions/job   : $((PHONES_PER_JOB * IMAGES_PER_JOB))"
echo "  Total submissions : $TOTAL_SUBMISSIONS"
echo "  EC2 instances     : $ACTUAL_JOBS (1 per job)"
echo ""
echo "  S3 path: s3://${S3_BUCKET}/campaigns/${CAMPAIGN_ID}/"
echo ""
echo "=================================================="
echo "  COPY THESE FOR EC2:"
echo "=================================================="
echo ""
echo "  export CAMPAIGN_ID=\"${CAMPAIGN_ID}\""
echo "  export JOB_IDS=\"${ALL_JOB_IDS}\""
echo ""
echo "  Then run:"
echo "    ./scripts/launch-campaign-instances.sh"
echo ""
