#!/bin/bash

set -e

S3_BUCKET="s3://greendotball-bot-data"
SOURCE_FOLDERS=("green_ball_image_18apr" "green_ball_image_19apr" "green_ball_image_20apr")
DEST_FOLDER="green_ball_image_20_v1apr"

TEMP_DIR="/tmp/s3-copy-$$"
mkdir -p "$TEMP_DIR"

echo "=========================================="
echo "S3 Image Copy Script"
echo "=========================================="
echo "Destination: ${S3_BUCKET}/${DEST_FOLDER}/"
echo ""

if ! command -v aws &> /dev/null; then
    echo "Error: AWS CLI is not installed or not in PATH"
    exit 1
fi

TOTAL_COPIED=0
declare -A SOURCE_COUNTS

for SOURCE in "${SOURCE_FOLDERS[@]}"; do
    SOURCE_PATH="${S3_BUCKET}/${SOURCE}/"
    SOURCE_ID=$(echo "$SOURCE" | grep -oE '[0-9]+apr')
    
    echo "Processing source: $SOURCE"
    echo "Listing images from $SOURCE_PATH..."
    
    aws s3 ls "$SOURCE_PATH" | awk '{print $4}' | grep -E '\.(jpg|jpeg|png|gif|bmp|webp|JPG|JPEG|PNG|GIF|BMP|WEBP)$' > "${TEMP_DIR}/${SOURCE}.txt" || true
    
    IMAGE_COUNT=$(wc -l < "${TEMP_DIR}/${SOURCE}.txt" | tr -d ' ')
    
    if [ "$IMAGE_COUNT" -eq 0 ]; then
        echo "  No images found in $SOURCE"
        echo ""
        continue
    fi
    
    echo "  Found $IMAGE_COUNT images"
    
    COUNTER=0
    while IFS= read -r image; do
        if [ -z "$image" ]; then
            continue
        fi
        
        COUNTER=$((COUNTER + 1))
        
        FILENAME="${image%.*}"
        EXTENSION="${image##*.}"
        
        if [[ "$SOURCE" == "green_ball_image_18apr" || "$SOURCE" == "green_ball_image_19apr" ]]; then
            RANDOM_SUFFIX=$(shuf -i 100000-999999 -n 1)
            NEW_FILENAME="${FILENAME}_${RANDOM_SUFFIX}.${EXTENSION}"
        else
            NEW_FILENAME="${FILENAME}_${SOURCE_ID}.${EXTENSION}"
        fi
        
        echo "  [$COUNTER/$IMAGE_COUNT] Copying: $image -> $NEW_FILENAME"
        
        if aws s3 cp "${SOURCE_PATH}${image}" "${S3_BUCKET}/${DEST_FOLDER}/${NEW_FILENAME}" --quiet; then
            TOTAL_COPIED=$((TOTAL_COPIED + 1))
        else
            echo "    Warning: Failed to copy $image"
        fi
        
    done < "${TEMP_DIR}/${SOURCE}.txt"
    
    SOURCE_COUNTS[$SOURCE]=$COUNTER
    echo "  Completed: $COUNTER images from $SOURCE"
    echo ""
done

echo "=========================================="
echo "Copy Summary"
echo "=========================================="
for SOURCE in "${SOURCE_FOLDERS[@]}"; do
    COUNT=${SOURCE_COUNTS[$SOURCE]:-0}
    echo "  $SOURCE: $COUNT images"
done
echo "----------------------------------------"
echo "  Total copied: $TOTAL_COPIED images"
echo "=========================================="

rm -rf "$TEMP_DIR"

echo ""
echo "Done! All images copied to ${S3_BUCKET}/${DEST_FOLDER}/"
