#!/bin/bash

# Script to rename all images in image-batches to random names
# Usage: ./rename-images.sh [batch-directory]

BATCH_DIR="${1:-/opt/greendotball-bot/data/images}"

if [ ! -d "$BATCH_DIR" ]; then
  echo "ERROR: Directory not found: $BATCH_DIR"
  exit 1
fi

echo "=========================================="
echo "Renaming images to random names"
echo "Directory: $BATCH_DIR"
echo "=========================================="
echo ""

# Process each batch folder
for batch_folder in "$BATCH_DIR"/batch-*/; do
  if [ -d "$batch_folder" ]; then
    batch_name=$(basename "$batch_folder")
    echo "Processing $batch_name..."
    
    cd "$batch_folder"
    count=0
    
    for file in *; do
      if [ -f "$file" ]; then
        # Get file extension
        ext="${file##*.}"
        
        # Generate random name (12 characters)
        random_name=$(cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 12 | head -n 1)
        
        # Rename file
        mv "$file" "${random_name}.${ext}"
        echo "  ✓ $file -> ${random_name}.${ext}"
        ((count++))
      fi
    done
    
    echo "  Renamed $count images in $batch_name"
    echo ""
  fi
done

echo "=========================================="
echo "Done! All images renamed to random names"
echo "=========================================="
