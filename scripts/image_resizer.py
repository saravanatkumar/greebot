#!/usr/bin/env python3
"""
Image Resizer Script
Resizes images to different dimensions while maintaining aspect ratio.
Supports both square and rectangular images.
"""

import os
import sys
import random
import string
from datetime import datetime
from pathlib import Path
from PIL import Image
import argparse

class ImageResizer:
    def __init__(self, src_dir, dest_dir, resize_percentages=[0.9, 0.8, 0.75]):
        self.src_dir = Path(src_dir)
        self.dest_dir = Path(dest_dir)
        self.resize_percentages = resize_percentages
        self.supported_formats = {'.jpg', '.jpeg', '.png', '.bmp', '.tiff', '.gif', '.webp'}
        
    def is_square_image(self, width, height):
        """Check if image is square (aspect ratio 1:1)"""
        return width == height
    
    def generate_random_filename(self, original_filename, percentage):
        """Generate random filename with prefix and suffix"""
        # Get original file extension
        original_path = Path(original_filename)
        extension = original_path.suffix.lower()
        
        # Generate random string
        random_str = ''.join(random.choices(string.ascii_lowercase + string.digits, k=8))
        
        # Create timestamp
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        
        # Create new filename: prefix_random_timestamp_percentage_suffix.extension
        new_filename = f"img_{random_str}_{timestamp}_{int(percentage*100)}_resized{extension}"
        
        return new_filename
    
    def resize_image(self, image_path, output_path, percentage):
        """Resize image to given percentage of original size"""
        try:
            with Image.open(image_path) as img:
                # Get original dimensions
                original_width, original_height = img.size
                
                # Calculate new dimensions
                new_width = int(original_width * percentage)
                new_height = int(original_height * percentage)
                
                # Resize image using high-quality downsampling
                resized_img = img.resize((new_width, new_height), Image.Resampling.LANCZOS)
                
                # Save resized image
                resized_img.save(output_path)
                
                print(f"✓ Resized {image_path.name} from {original_width}x{original_height} to {new_width}x{new_height}")
                return True
                
        except Exception as e:
            print(f"✗ Error resizing {image_path.name}: {str(e)}")
            return False
    
    def process_images(self):
        """Process all images in source directory"""
        # Create destination directory if it doesn't exist
        self.dest_dir.mkdir(parents=True, exist_ok=True)
        
        # Find all image files in source directory
        image_files = []
        for file_path in self.src_dir.rglob('*'):
            if file_path.is_file() and file_path.suffix.lower() in self.supported_formats:
                image_files.append(file_path)
        
        if not image_files:
            print(f"No image files found in {self.src_dir}")
            return
        
        print(f"Found {len(image_files)} images to process...")
        
        processed_count = 0
        for image_path in image_files:
            print(f"\nProcessing: {image_path.name}")
            
            # Get image dimensions to determine type
            try:
                with Image.open(image_path) as img:
                    width, height = img.size
                    is_square = self.is_square_image(width, height)
                    
                    if is_square:
                        print(f"  Square image: {width}x{height}")
                    else:
                        print(f"  Rectangular image: {width}x{height} (aspect ratio: {width/height:.2f})")
                    
                    # Process each resize percentage
                    for percentage in self.resize_percentages:
                        # Generate random filename
                        new_filename = self.generate_random_filename(image_path.name, percentage)
                        output_path = self.dest_dir / new_filename
                        
                        # Resize image
                        success = self.resize_image(image_path, output_path, percentage)
                        if success:
                            processed_count += 1
                        
            except Exception as e:
                print(f"  ✗ Error processing {image_path.name}: {str(e)}")
                continue
        
        print(f"\n✓ Processing complete! Processed {processed_count} images.")
        print(f"✓ Resized images saved to: {self.dest_dir}")

def main():
    parser = argparse.ArgumentParser(description='Resize images while maintaining aspect ratio')
    parser.add_argument('src_dir', help='Source directory containing images')
    parser.add_argument('dest_dir', help='Destination directory for resized images')
    parser.add_argument('--percentages', nargs='+', type=float, default=[0.9, 0.8, 0.75],
                       help='Resize percentages (default: 0.9 0.8 0.75)')
    
    args = parser.parse_args()
    
    # Validate source directory
    if not os.path.exists(args.src_dir):
        print(f"Error: Source directory '{args.src_dir}' does not exist.")
        sys.exit(1)
    
    # Validate percentages
    for p in args.percentages:
        if p <= 0 or p > 1:
            print(f"Error: Percentage {p} must be between 0 and 1.")
            sys.exit(1)
    
    # Create resizer and process images
    resizer = ImageResizer(args.src_dir, args.dest_dir, args.percentages)
    resizer.process_images()

if __name__ == "__main__":
    main()
