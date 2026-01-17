#!/bin/bash

# Script to rename all images to random names
# Usage: ./rename-images.sh [images-directory]

IMAGES_DIR="${1:-/opt/greendotball-bot/data/images}"

if [ ! -d "$IMAGES_DIR" ]; then
  echo "ERROR: Directory not found: $IMAGES_DIR"
  exit 1
fi

echo "=========================================="
echo "Renaming images to random names"
echo "Directory: $IMAGES_DIR"
echo "=========================================="
echo ""

cd "$IMAGES_DIR"
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

echo ""
echo "=========================================="
echo "Done! Renamed $count images to random names"
echo "=========================================="
