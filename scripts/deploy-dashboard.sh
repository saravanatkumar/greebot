#!/bin/bash
# deploy-dashboard.sh
# Syncs S3 data locally, then uploads dashboard to myortho S3 bucket
#
# Usage: ./scripts/deploy-dashboard.sh

set -e

BUCKET="myortho"
REGION="us-east-2"
S3_PATH="logs"

echo ""
echo "=============================================="
echo "  GreenDotBall Dashboard Deploy"
echo "=============================================="
echo ""

# Step 1: Download latest campaign data from greendotball-bot-data
echo "[1/2] Syncing campaign data from S3..."
node scripts/sync-dashboard-data.js

# Step 2: Upload dashboard files to myortho bucket
echo "[2/2] Uploading dashboard to s3://${BUCKET}/${S3_PATH}/..."

aws s3 cp dashboards/log-dashboard.html \
  "s3://${BUCKET}/${S3_PATH}/log-dashboard.html" \
  --region $REGION \
  --content-type "text/html" \
  --cache-control "no-cache"

aws s3 cp dashboards/data/dashboard-data.json \
  "s3://${BUCKET}/${S3_PATH}/data/dashboard-data.json" \
  --region $REGION \
  --content-type "application/json" \
  --cache-control "no-cache"

echo ""
echo "=============================================="
echo "  ✅ DEPLOY COMPLETE"
echo "=============================================="
echo ""
echo "  Dashboard URL:"
echo "  https://www.sklearn.in/logs/log-dashboard.html"
echo ""
