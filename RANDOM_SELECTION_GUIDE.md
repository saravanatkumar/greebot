# Random Selection Guide

The bot now supports **random selection** of phone numbers and images for each submission!

## How It Works

When `randomSelection: true` is enabled in config, the bot will:
- Pick a **random phone number** from your list
- Pick a **random image** from your images list
- Use different combinations for each submission

This is perfect for:
- Testing with multiple phone numbers
- Using different images to avoid duplicates
- Simulating more natural/varied submissions

## Setup Instructions

### 1. Add Your Phone Numbers

Edit `config/config.json`:

```json
{
  "randomSelection": true,
  "phoneNumbers": [
    "9876543210",
    "9876543211",
    "9876543212",
    "9876543213",
    "9876543214"
  ]
}
```

### 2. Add Your Images

Place multiple images in `data/sample-images/`:

```bash
cp ~/Downloads/image1.jpg data/sample-images/
cp ~/Downloads/image2.jpg data/sample-images/
cp ~/Downloads/image3.jpg data/sample-images/
```

Then update config:

```json
{
  "images": [
    "./data/sample-images/green-ball.jpg",
    "./data/sample-images/image1.jpg",
    "./data/sample-images/image2.jpg",
    "./data/sample-images/image3.jpg"
  ]
}
```

### 3. Enable Random Selection

```json
{
  "randomSelection": true
}
```

## Complete Example Configuration

```json
{
  "targetUrl": "https://greendotball.com/",
  "headless": false,
  "slowMo": 100,
  "timeout": 30000,
  "retryAttempts": 3,
  "delayBetweenSubmissions": 5000,
  "randomSelection": true,
  "phoneNumbers": [
    "9876543210",
    "9876543211",
    "9876543212",
    "9876543213",
    "9876543214"
  ],
  "images": [
    "./data/sample-images/green-ball.jpg",
    "./data/sample-images/ball1.jpg",
    "./data/sample-images/ball2.jpg",
    "./data/sample-images/ball3.jpg"
  ],
  "imagePath": "./data/sample-images/green-ball.jpg",
  "slideStrategy": "mouse",
  "screenshotOnError": true,
  "maxSubmissionsPerSession": 10
}
```

## Usage

### Single Submission (Random)
```bash
npm start
```
Output:
```
Random selection enabled
Selected Phone: 98765*****
Selected Image: ball2.jpg
```

### Batch Mode (Random for each submission)
```bash
npm run batch
```
Output:
```
Starting batch mode with 5 phone numbers
Available images: 4
Random selection: ENABLED

Processing 1/5 - RANDOM SELECTION
Selected Phone: 98765*****
Selected Image: ball3.jpg

Processing 2/5 - RANDOM SELECTION
Selected Phone: 98765*****
Selected Image: green-ball.jpg

Processing 3/5 - RANDOM SELECTION
Selected Phone: 98765*****
Selected Image: ball1.jpg
```

## Sequential Mode (No Random)

If you want to use phone numbers and images in order:

```json
{
  "randomSelection": false
}
```

This will:
- Use phone numbers in order: phoneNumbers[0], phoneNumbers[1], etc.
- Cycle through images in order
- Good for controlled testing

## Tips

### Maximum Variety
```json
{
  "randomSelection": true,
  "phoneNumbers": [/* 10+ numbers */],
  "images": [/* 5+ images */],
  "maxSubmissionsPerSession": 20
}
```

### Quick Test
```json
{
  "randomSelection": true,
  "phoneNumbers": ["9876543210", "9876543211"],
  "images": ["./data/sample-images/image1.jpg", "./data/sample-images/image2.jpg"],
  "maxSubmissionsPerSession": 5
}
```

### Production Run
```json
{
  "randomSelection": true,
  "headless": true,
  "slowMo": 0,
  "delayBetweenSubmissions": 10000,
  "maxSubmissionsPerSession": 50
}
```

## Logs

Random selections are logged for tracking:

```
[2026-01-10 22:50:07] info: Random selection enabled
[2026-01-10 22:50:07] info: Selected Phone: 98765*****
[2026-01-10 22:50:07] info: Selected Image: ball2.jpg
[2026-01-10 22:50:07] info: Starting form submission #1
```

## Batch Summary

At the end of batch mode, you'll see which combinations were used:

```
BATCH SUMMARY
============================================================
Total submissions: 10
Successful: 9
Failed: 1

Results include phone number (masked) and image filename for each submission.
```

## Troubleshooting

**Images not found?**
```bash
# List your images
ls -la data/sample-images/

# Make sure paths in config match actual files
```

**Want to see which combinations are being used?**
```bash
# Check logs
cat logs/bot-activity.log | grep "Selected"
```

**Need more control?**
- Set `randomSelection: false` for sequential selection
- Reduce `maxSubmissionsPerSession` for shorter runs
- Use `headless: false` to watch the bot in action

---

**Pro Tip**: With random selection, you can submit the same form multiple times with different data combinations, making it perfect for testing or legitimate multiple entries!
