#!/bin/bash

SOURCE_BUCKET="s3://greendotball-bot-data/rename-images/"
DEST_BUCKET="s3://greendotball-bot-data/green_ball_image_11apr/"
NUM_IMAGES=2500

echo "Fetching existing images in destination..."
aws s3 ls "$DEST_BUCKET" | awk '{print $4}' > /tmp/existing_images.txt

echo "Fetching all images from source..."
aws s3 ls "$SOURCE_BUCKET" | awk '{print $4}' > /tmp/source_images.txt

echo "Filtering out existing images..."
grep -vxFf /tmp/existing_images.txt /tmp/source_images.txt > /tmp/available_images.txt

AVAILABLE_COUNT=$(wc -l < /tmp/available_images.txt)
echo "Available images to copy: $AVAILABLE_COUNT"

if [ "$AVAILABLE_COUNT" -lt "$NUM_IMAGES" ]; then
    echo "Warning: Only $AVAILABLE_COUNT images available, less than requested $NUM_IMAGES"
    NUM_IMAGES=$AVAILABLE_COUNT
fi

echo "Randomly selecting $NUM_IMAGES images..."
awk -v count="$NUM_IMAGES" 'BEGIN {srand()} {print rand() "\t" $0}' /tmp/available_images.txt | sort -n | cut -f2- | head -n "$NUM_IMAGES" > /tmp/selected_images.txt

echo "Copying $NUM_IMAGES images..."
COUNTER=0
while IFS= read -r image; do
    COUNTER=$((COUNTER + 1))
    echo "[$COUNTER/$NUM_IMAGES] Copying $image"
    aws s3 cp "${SOURCE_BUCKET}${image}" "${DEST_BUCKET}${image}"
done < /tmp/selected_images.txt

echo "Done! Copied $COUNTER images to $DEST_BUCKET"

rm -f /tmp/existing_images.txt /tmp/source_images.txt /tmp/available_images.txt /tmp/selected_images.txt
