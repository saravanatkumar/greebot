# Green Dot Ball Form Auto-Submission Bot

Automated bot to submit forms on https://greendotball.com/2026/ with image upload, phone number entry, terms acceptance, and slide-to-submit interaction.

## Features

- ✅ Automated image upload
- ✅ Phone number entry with validation
- ✅ Terms and conditions acceptance
- ✅ Slide-to-submit mechanism automation (mouse drag or JavaScript injection)
- ✅ Success/error modal detection
- ✅ Retry logic with exponential backoff
- ✅ Comprehensive logging
- ✅ Batch submission mode
- ✅ Screenshot on error
- ✅ Configurable parameters

## Prerequisites

- Node.js 16+ installed
- Internet connection
- Valid phone numbers (10 digits)
- Image file (JPG, PNG, GIF, WEBP)

## Installation

```bash
cd /Users/apple/CascadeProjects/windsurf-project-2
npm install
```

## Configuration

Edit `config/config.json` to customize bot behavior:

```json
{
  "targetUrl": "https://greendotball.com/2026/",
  "headless": false,
  "slowMo": 100,
  "timeout": 30000,
  "retryAttempts": 3,
  "delayBetweenSubmissions": 5000,
  "phoneNumbers": ["9876543210"],
  "imagePath": "./data/sample-images/green-ball.jpg",
  "slideStrategy": "mouse",
  "screenshotOnError": true,
  "maxSubmissionsPerSession": 10
}
```

### Configuration Options

| Option | Description | Default |
|--------|-------------|---------|
| `targetUrl` | Form URL | https://greendotball.com/2026/ |
| `headless` | Run browser in headless mode | false |
| `slowMo` | Slow down operations (ms) | 100 |
| `timeout` | Page load timeout (ms) | 30000 |
| `retryAttempts` | Max retry attempts per submission | 3 |
| `delayBetweenSubmissions` | Delay between batch submissions (ms) | 5000 |
| `phoneNumbers` | Array of 10-digit phone numbers | [] |
| `imagePath` | Path to image file | "" |
| `slideStrategy` | "mouse" or "javascript" | "mouse" |
| `screenshotOnError` | Take screenshot on error | true |
| `maxSubmissionsPerSession` | Max submissions in batch mode | 10 |

## Usage

### Single Submission

Submit form once with the first phone number in config:

```bash
npm start
```

### Batch Mode

Submit form multiple times with different phone numbers:

```bash
npm run batch
```

### Debug Mode

Run with visible browser and slower execution:

```bash
npm run debug
```

## Project Structure

```
windsurf-project-2/
├── package.json
├── README.md
├── plan.md
├── config/
│   └── config.json          # Bot configuration
├── src/
│   ├── bot.js               # Main bot logic
│   ├── formHandler.js       # Form interaction handlers
│   ├── validator.js         # Input validation
│   └── utils/
│       ├── logger.js        # Logging utility
│       └── helpers.js       # Helper functions
├── data/
│   └── sample-images/       # Test images (add your images here)
└── logs/
    ├── bot-activity.log     # Activity logs
    └── error.log            # Error logs
```

## Adding Your Data

### 1. Add Images

Place your image files in `data/sample-images/`:

```bash
mkdir -p data/sample-images
cp /path/to/your/image.jpg data/sample-images/
```

Update `config.json`:

```json
{
  "imagePath": "./data/sample-images/your-image.jpg"
}
```

### 2. Add Phone Numbers

Edit `config.json` and add phone numbers:

```json
{
  "phoneNumbers": [
    "9876543210",
    "9876543211",
    "9876543212"
  ]
}
```

## Slide-to-Submit Strategies

### Mouse Drag (Recommended)

Simulates human mouse movements:

```json
{
  "slideStrategy": "mouse"
}
```

**Pros**: More realistic, mimics human behavior  
**Cons**: Slightly slower

### JavaScript Injection

Directly manipulates DOM:

```json
{
  "slideStrategy": "javascript"
}
```

**Pros**: Faster, more reliable  
**Cons**: Less realistic, may be detected

## Logging

Logs are saved in the `logs/` directory:

- `bot-activity.log` - All bot activities
- `error.log` - Errors only
- Console output - Real-time progress

Example log output:

```
[2026-01-10 22:15:30] INFO: Starting bot...
[2026-01-10 22:15:35] INFO: Navigated to https://greendotball.com/2026/
[2026-01-10 22:15:40] INFO: Image uploaded successfully
[2026-01-10 22:15:42] INFO: Phone number entered: 98765*****
[2026-01-10 22:15:43] INFO: Terms accepted
[2026-01-10 22:15:45] INFO: Slide-to-submit completed
[2026-01-10 22:15:48] INFO: ✓ Submission successful!
```

## Error Handling

The bot includes comprehensive error handling:

- **Validation errors**: Invalid phone numbers, missing images
- **Network errors**: Timeouts, connection issues
- **Form errors**: Upload failures, slide mechanism issues
- **Server errors**: API errors, duplicate submissions

When an error occurs:
1. Error is logged to `logs/error.log`
2. Screenshot is saved (if enabled)
3. Bot retries with exponential backoff
4. After max retries, bot moves to next submission (batch mode)

## Troubleshooting

### Bot doesn't start

```bash
# Check Node.js version
node --version  # Should be 16+

# Reinstall dependencies
rm -rf node_modules package-lock.json
npm install
```

### Image upload fails

- Check image file exists at specified path
- Verify image format (JPG, PNG, GIF, WEBP)
- Ensure image size is under 10MB

### Slide-to-submit fails

- Try switching strategy in config:
  - `"slideStrategy": "javascript"` (more reliable)
  - `"slideStrategy": "mouse"` (more realistic)

### Form validation errors

- Verify phone numbers are exactly 10 digits
- Check terms checkbox is being clicked
- Review logs for specific validation errors

## Security & Ethics

⚠️ **Important Considerations**:

1. **Rate Limiting**: Bot includes delays to respect server resources
2. **Terms of Service**: Ensure automation complies with website's TOS
3. **Data Privacy**: Phone numbers are masked in logs
4. **Testing**: Test thoroughly before production use
5. **Responsibility**: Use responsibly and ethically

## Advanced Usage

### Custom User Agent

The bot automatically rotates user agents. To customize, edit `src/utils/helpers.js`.

### Proxy Support

Add proxy configuration to `src/bot.js`:

```javascript
const launchOptions = {
  args: ['--proxy-server=http://proxy-server:port']
};
```

### CAPTCHA Handling

If CAPTCHA appears, the bot will:
1. Log a warning
2. Take a screenshot
3. Wait for manual intervention

## Support

For issues or questions:
1. Check logs in `logs/` directory
2. Review screenshots in `logs/` (if errors occurred)
3. Verify configuration in `config/config.json`
4. Check technical plan in `plan.md`

## License

MIT License - See LICENSE file for details

---

**Version**: 1.0.0  
**Last Updated**: 2026-01-10  
**Status**: Ready for testing
