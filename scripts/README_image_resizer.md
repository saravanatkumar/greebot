# Image Resizer Script

A Python script that resizes images while maintaining aspect ratio and generates random filenames.

## Features

- **Aspect Ratio Preservation**: Maintains original aspect ratio for both square and rectangular images
- **Image Type Detection**: Automatically identifies square vs rectangular images
- **Multiple Resize Options**: Default resizes to 90%, 80%, and 75% of original size
- **Random Filename Generation**: Creates unique filenames with random strings and timestamps
- **Batch Processing**: Processes all images in a directory recursively
- **Format Support**: Supports JPG, PNG, BMP, TIFF, GIF, and WebP formats

## Installation

1. Install required dependencies:
```bash
pip install -r requirements.txt
```

## Usage

### Basic Usage
```bash
python image_resizer.py <source_directory> <destination_directory>
```

### Custom Resize Percentages
```bash
python image_resizer.py <source_directory> <destination_directory> --percentages 0.9 0.7 0.5
```

### Examples

1. **Resize images to default sizes (90%, 80%, 75%):**
```bash
python image_resizer.py ./original_images ./resized_images
```

2. **Resize to custom percentages:**
```bash
python image_resizer.py ./original_images ./resized_images --percentages 0.95 0.85 0.7
```

3. **Resize to specific sizes (50%, 25%):**
```bash
python image_resizer.py ./original_images ./resized_images --percentages 0.5 0.25
```

## Output

The script will:
- Process all supported image files in the source directory
- Create resized versions for each specified percentage
- Generate random filenames like: `img_abc12345_20240428_203045_90_resized.jpg`
- Preserve the original images unchanged
- Save resized images to the destination directory

## Filename Format

Generated filenames follow this pattern:
```
img_<random_string>_<timestamp>_<percentage>_resized.<extension>
```

Example: `img_k9m2n7p4_20240428_203045_90_resized.png`

## Supported Image Formats

- JPEG (.jpg, .jpeg)
- PNG (.png)
- BMP (.bmp)
- TIFF (.tiff)
- GIF (.gif)
- WebP (.webp)

## Notes

- The script uses high-quality LANCZOS resampling for best image quality
- Original images are never modified
- Destination directory is created automatically if it doesn't exist
- Processing is recursive - all subdirectories in source are processed
