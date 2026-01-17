#!/bin/bash

# Script to organize images into batches of 100
# Usage: ./organize-images.sh <source_directory> <output_directory>

SOURCE_DIR="${1:-./all-images}"
OUTPUT_DIR="${2:-./data/image-batches}"
BATCH_SIZE=100

if [ ! -d "$SOURCE_DIR" ]; then
  echo "ERROR: Source directory '$SOURCE_DIR' not found"
  echo "Usage: $0 <source_directory> <output_directory>"
  exit 1
fi

echo "=========================================="
echo "Image Batch Organizer"
echo "=========================================="
echo "Source: $SOURCE_DIR"
echo "Output: $OUTPUT_DIR"
echo "Batch Size: $BATCH_SIZE images per batch"
echo ""

mkdir -p "$OUTPUT_DIR"

# Get all images
images=($(find "$SOURCE_DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.gif" -o -iname "*.webp" \) | sort))
total=${#images[@]}

if [ $total -eq 0 ]; then
  echo "ERROR: No images found in $SOURCE_DIR"
  exit 1
fi

echo "Found $total images"
echo ""

# Calculate number of batches
num_batches=$(( (total + BATCH_SIZE - 1) / BATCH_SIZE ))
echo "Creating $num_batches batches..."
echo ""

# Split into batches
batch_num=1
for ((i=0; i<$total; i+=$BATCH_SIZE)); do
  batch_dir=$(printf "$OUTPUT_DIR/batch-%03d" $batch_num)
  mkdir -p "$batch_dir"
  
  echo "Creating batch $batch_num..."
  
  # Copy up to BATCH_SIZE images to this batch
  count=0
  for ((j=0; j<$BATCH_SIZE && (i+j)<$total; j++)); do
    cp "${images[$((i+j))]}" "$batch_dir/"
    ((count++))
  done
  
  echo "  ✓ Batch $batch_num: $count images in $batch_dir"
  
  ((batch_num++))
done

echo ""
echo "=========================================="
echo "Summary"
echo "=========================================="
echo "Total images: $total"
echo "Batches created: $((batch_num-1))"
echo "Images per batch: ~$BATCH_SIZE"
echo "Output directory: $OUTPUT_DIR"
echo ""
echo "Next steps:"
echo "1. Review the batches in $OUTPUT_DIR"
echo "2. Upload to S3: aws s3 sync $OUTPUT_DIR/ s3://greendotball-bot-data/images/batches/"
echo ""
echo "Done!"
