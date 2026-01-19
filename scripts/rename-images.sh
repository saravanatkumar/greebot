#!/bin/bash

# Script to rename all images to random names
# Usage: ./rename-images.sh [images-directory]

IMAGES_DIR="${1:-/Users/apple/CascadeProjects/windsurf-project-2/data/images}"

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
    
    # Generate random name (12 characters) - macOS compatible
    random_name=$(LC_ALL=C tr -dc 'a-z0-9' < /dev/urandom | head -c 12)
    
    # Fallback if random_name is empty
    if [ -z "$random_name" ]; then
      random_name=$(openssl rand -hex 6)
    fi
    
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
