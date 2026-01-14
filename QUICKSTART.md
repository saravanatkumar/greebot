# Quick Start Guide

## Setup (2 minutes)

### 1. Add Your Image

Place any image file in the `data/sample-images/` folder:

```bash
# Example: Copy an image from your Downloads
cp ~/Downloads/your-image.jpg data/sample-images/green-ball.jpg
```

Or create a simple test image:
```bash
# Download a sample green ball image
curl -o data/sample-images/green-ball.jpg "https://via.placeholder.com/500x500/00FF00/FFFFFF?text=Green+Ball"
```

### 2. Update Phone Numbers

Edit `config/config.json` and add your phone numbers:

```json
{
  "phoneNumbers": [
    "9876543210",
    "9876543211"
  ]
}
```

### 3. Run the Bot

**Single submission:**
```bash
npm start
```

**Multiple submissions (batch mode):**
```bash
npm run batch
```

**Debug mode (visible browser, slower):**
```bash
npm run debug
```

## What the Bot Does

1. ✅ Opens browser and navigates to https://greendotball.com/2026/
2. ✅ Uploads your image file
3. ✅ Enters phone number
4. ✅ Accepts terms and conditions
5. ✅ Performs slide-to-submit action
6. ✅ Waits for success/error response
7. ✅ Logs results and takes screenshots on errors
8. ✅ Retries on failure (up to 3 times)

## Configuration Tips

### For Testing
```json
{
  "headless": false,
  "slowMo": 100,
  "slideStrategy": "mouse"
}
```

### For Production
```json
{
  "headless": true,
  "slowMo": 0,
  "slideStrategy": "javascript",
  "delayBetweenSubmissions": 10000
}
```

## Troubleshooting

**Image not found?**
```bash
# Check if image exists
ls -la data/sample-images/

# Update path in config.json
"imagePath": "./data/sample-images/YOUR_IMAGE_NAME.jpg"
```

**Slide mechanism not working?**
```json
// Try JavaScript strategy instead
"slideStrategy": "javascript"
```

**Want to see what's happening?**
```bash
npm run debug
```

## Logs

Check logs for detailed information:
- `logs/bot-activity.log` - All activities
- `logs/error.log` - Errors only
- `logs/*.png` - Error screenshots

## Example Output

```
[2026-01-10 22:30:15] INFO: Initializing Green Dot Ball Bot...
[2026-01-10 22:30:16] INFO: Configuration validated successfully
[2026-01-10 22:30:17] INFO: Launching browser...
[2026-01-10 22:30:20] INFO: Browser launched successfully
[2026-01-10 22:30:21] INFO: Navigating to https://greendotball.com/2026/...
[2026-01-10 22:30:25] INFO: Page loaded: Spot Any Green Dot | Win Tata WPL Merch & Tickets
[2026-01-10 22:30:26] INFO: Starting form submission #1
[2026-01-10 22:30:27] INFO: Uploading image...
[2026-01-10 22:30:30] INFO: Image uploaded successfully
[2026-01-10 22:30:31] INFO: Entering phone number: 98765*****
[2026-01-10 22:30:33] INFO: Phone number entered successfully
[2026-01-10 22:30:34] INFO: Accepting terms and conditions...
[2026-01-10 22:30:35] INFO: Terms accepted successfully
[2026-01-10 22:30:36] INFO: Performing slide-to-submit...
[2026-01-10 22:30:37] INFO: Using mouse drag strategy...
[2026-01-10 22:30:40] INFO: Mouse drag completed
[2026-01-10 22:30:42] INFO: Waiting for submission response...
[2026-01-10 22:30:45] INFO: ✓ Submission successful!
[2026-01-10 22:30:45] INFO: Message: Your entry has been submitted successfully...
[2026-01-10 22:30:47] INFO: Modal closed
[2026-01-10 22:30:48] INFO: ✓ Form submitted successfully!
```

## Need Help?

1. Run configuration test: `npm test`
2. Check logs in `logs/` directory
3. Review `README.md` for detailed documentation
4. Check `plan.md` for technical details

---

Ready to go! 🚀
