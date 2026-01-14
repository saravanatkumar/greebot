# Green Dot Ball Form Auto-Submission Bot - Technical Plan

## Project Overview
Automated bot to submit forms on https://greendotball.com/ with image upload, phone number entry, terms acceptance, and slide-to-submit interaction.

---

## 1. Form Analysis

### Form Structure (from HTML)
- **URL**: `https://greendotball.com/2026/`
- **Submission Endpoint**: `../api/submit.php` (relative path)
- **Method**: POST with FormData
- **Required Fields**:
  1. Image file upload (`#fileInput`)
  2. Phone number - 10 digits (`input.mobile-number`)
  3. Terms checkbox (`#termsCheckbox`)
  4. Slide-to-submit mechanism (`#slideButton`, `#slideTrack`)

### Form Validation Logic
```javascript
// Client-side validation checks:
- fileUploaded === true (file must be selected)
- phoneNumber.length === 10 && /^\d+$/.test(phoneNumber)
- termsAccepted === true (checkbox must be checked)
- Slide button must be dragged 80% across the track
```

### Submission Flow (from screenshots)
1. **Initial State**: Upload button, phone input, terms checkbox, slide track
2. **After Upload**: "IMAGE UPLOADED ✓" confirmation
3. **Slide Action**: User drags ball button from left to right
4. **Submission**: When slide reaches 80%, form submits via AJAX
5. **Success Modal**: Shows "SUCCESS!" with confirmation message

### API Payload Structure
```javascript
FormData {
  phone: "10-digit number",
  image: File object,
  utm_source: (optional),
  utm_medium: (optional),
  utm_campaign: (optional),
  utm_term: (optional),
  utm_content: (optional)
}
```

---

## 2. Technical Architecture

### Technology Stack
- **Node.js**: Runtime environment
- **Puppeteer**: Headless browser automation
- **Express**: Optional test server for local testing
- **Axios**: HTTP client for API testing (optional)

### Project Structure
```
windsurf-project-2/
├── package.json
├── plan.md (this file)
├── README.md
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
│   ├── sample-images/       # Test images
│   └── phone-numbers.json   # Phone numbers to use
├── logs/
│   └── bot-activity.log     # Activity logs
└── test/
    └── test-server.js       # Local test server (optional)
```

---

## 3. Implementation Strategy

### Phase 1: Setup & Configuration
**Files**: `package.json`, `config/config.json`, `README.md`

**Dependencies**:
```json
{
  "puppeteer": "^21.0.0",
  "winston": "^3.11.0",
  "dotenv": "^16.3.1"
}
```

**Configuration Options**:
```json
{
  "targetUrl": "https://greendotball.com/",
  "headless": false,
  "slowMo": 100,
  "timeout": 30000,
  "retryAttempts": 3,
  "delayBetweenSubmissions": 5000,
  "phoneNumbers": ["9876543210"],
  "imagePath": "./data/sample-images/green-ball.jpg",
  "utmParams": {
    "utm_source": "bot",
    "utm_medium": "automation",
    "utm_campaign": "test"
  }
}
```

### Phase 2: Core Bot Implementation
**File**: `src/bot.js`

**Key Functions**:
1. `initBrowser()` - Launch Puppeteer browser
2. `navigateToForm()` - Navigate to target URL
3. `fillForm()` - Populate all form fields
4. `performSlideSubmit()` - Automate slide-to-submit
5. `handleResponse()` - Process success/error modals
6. `cleanup()` - Close browser and save logs

### Phase 3: Form Interaction Handlers
**File**: `src/formHandler.js`

**Critical Interactions**:

#### A. Image Upload
```javascript
// Strategy: Upload file via input element
const fileInput = await page.$('#fileInput');
await fileInput.uploadFile(imagePath);
// Wait for "IMAGE UPLOADED ✓" confirmation
await page.waitForFunction(() => {
  const btn = document.querySelector('.upload-btn-wrapper .btn-text');
  return btn && btn.textContent.includes('IMAGE UPLOADED');
});
```

#### B. Phone Number Entry
```javascript
// Strategy: Type into input field
await page.type('input.mobile-number', phoneNumber, {delay: 50});
// Validate 10 digits
await page.waitForFunction(() => {
  const input = document.querySelector('.mobile-number');
  return input.value.length === 10;
});
```

#### C. Terms Checkbox
```javascript
// Strategy: Click checkbox element
await page.click('#termsCheckbox');
// Verify checked state
await page.waitForFunction(() => {
  return document.getElementById('termsCheckbox').checked === true;
});
```

#### D. Slide-to-Submit Mechanism
**Challenge**: Custom drag interaction, not a standard HTML element

**Solution Options**:

**Option 1: Mouse Drag Simulation (Recommended)**
```javascript
const slideButton = await page.$('#slideButton');
const slideTrack = await page.$('#slideTrack');

// Get bounding boxes
const buttonBox = await slideButton.boundingBox();
const trackBox = await slideTrack.boundingBox();

// Calculate drag distance (80% of track width)
const dragDistance = (trackBox.width - buttonBox.width - 10) * 0.85;

// Perform drag
await page.mouse.move(buttonBox.x + buttonBox.width/2, buttonBox.y + buttonBox.height/2);
await page.mouse.down();
await page.mouse.move(buttonBox.x + dragDistance, buttonBox.y + buttonBox.height/2, {steps: 20});
await page.mouse.up();
```

**Option 2: JavaScript Injection**
```javascript
await page.evaluate(() => {
  const slideButton = document.getElementById('slideButton');
  const slideTrack = document.getElementById('slideTrack');
  const trackWidth = slideTrack.offsetWidth;
  const buttonWidth = slideButton.offsetWidth;
  const maxSlide = trackWidth - buttonWidth - 10;
  
  // Trigger drag completion
  slideButton.style.transform = `translateX(${maxSlide}px)`;
  slideTrack.classList.add('completed');
  slideTrack.querySelector('.slide-text').style.opacity = 0;
  
  // Trigger submit after 300ms (as per original code)
  setTimeout(() => {
    // Call submitForm() function
    submitForm();
  }, 300);
});
```

**Option 3: Direct API Call (Bypass UI)**
```javascript
// Extract form data and call API directly
const formData = new FormData();
formData.append('phone', phoneNumber);
formData.append('image', fs.createReadStream(imagePath));

const response = await axios.post('https://greendotball.com/api/submit.php', formData, {
  headers: formData.getHeaders()
});
```

### Phase 4: Response Handling
**File**: `src/bot.js`

**Success Detection**:
```javascript
// Wait for modal to appear
await page.waitForSelector('#successModal.active', {timeout: 10000});

// Check if success or error
const isSuccess = await page.evaluate(() => {
  const modal = document.getElementById('successModal');
  const title = modal.querySelector('.modal-title').textContent;
  return title === 'Success!';
});

if (isSuccess) {
  const message = await page.$eval('.modal-message', el => el.textContent);
  logger.info('Submission successful:', message);
} else {
  const errorMsg = await page.$eval('.modal-message', el => el.textContent);
  logger.error('Submission failed:', errorMsg);
}
```

### Phase 5: Error Handling & Retry Logic
**File**: `src/validator.js`

**Error Scenarios**:
1. Network timeout
2. Invalid phone number
3. Image upload failure
4. Duplicate submission
5. Server error (500)
6. Rate limiting

**Retry Strategy**:
```javascript
async function submitWithRetry(maxRetries = 3) {
  for (let attempt = 1; attempt <= maxRetries; attempt++) {
    try {
      await fillAndSubmitForm();
      return { success: true };
    } catch (error) {
      logger.warn(`Attempt ${attempt} failed:`, error.message);
      if (attempt === maxRetries) {
        return { success: false, error };
      }
      await sleep(2000 * attempt); // Exponential backoff
    }
  }
}
```

### Phase 6: Logging & Monitoring
**File**: `src/utils/logger.js`

**Log Levels**:
- INFO: Successful submissions
- WARN: Retries, validation warnings
- ERROR: Failed submissions, crashes

**Log Format**:
```
[2026-01-10 22:15:30] INFO: Starting bot...
[2026-01-10 22:15:35] INFO: Navigated to https://greendotball.com/2026/
[2026-01-10 22:15:40] INFO: Image uploaded successfully
[2026-01-10 22:15:42] INFO: Phone number entered: 98765*****
[2026-01-10 22:15:43] INFO: Terms accepted
[2026-01-10 22:15:45] INFO: Slide-to-submit completed
[2026-01-10 22:15:48] INFO: Submission successful - Entry ID: #12345
```

---

## 4. Advanced Features

### A. Multi-Submission Mode
```javascript
// Submit multiple entries with different data
const submissions = [
  { phone: '9876543210', image: 'image1.jpg' },
  { phone: '9876543211', image: 'image2.jpg' },
];

for (const data of submissions) {
  await submitForm(data);
  await sleep(config.delayBetweenSubmissions);
}
```

### B. Proxy Support
```javascript
// Use proxies to avoid rate limiting
const browser = await puppeteer.launch({
  args: ['--proxy-server=http://proxy-server:port']
});
```

### C. CAPTCHA Detection
```javascript
// Check if CAPTCHA appears
const hasCaptcha = await page.$('iframe[src*="recaptcha"]');
if (hasCaptcha) {
  logger.warn('CAPTCHA detected - manual intervention required');
  await page.screenshot({ path: 'captcha.png' });
}
```

### D. Screenshot on Error
```javascript
catch (error) {
  await page.screenshot({ 
    path: `logs/error-${Date.now()}.png`,
    fullPage: true 
  });
  logger.error('Error screenshot saved');
}
```

---

## 5. Testing Strategy

### Unit Tests
- Validate phone number format
- Check image file existence
- Test configuration loading

### Integration Tests
- Test form filling without submission
- Verify slide mechanism
- Test modal detection

### End-to-End Tests
1. Submit with valid data → Expect success
2. Submit with invalid phone → Expect error
3. Submit without image → Expect error
4. Submit duplicate → Check duplicate handling

---

## 6. Deployment & Usage

### Installation
```bash
cd /Users/apple/CascadeProjects/windsurf-project-2
npm install
```

### Configuration
```bash
# Edit config/config.json with your settings
# Add images to data/sample-images/
# Add phone numbers to data/phone-numbers.json
```

### Running the Bot
```bash
# Single submission
npm start

# Multiple submissions
npm run batch

# Debug mode (visible browser)
npm run debug
```

---

## 7. Security & Ethical Considerations

### ⚠️ Important Notes
1. **Rate Limiting**: Respect server resources, add delays between submissions
2. **Terms of Service**: Ensure automation complies with website's TOS
3. **Data Privacy**: Handle phone numbers securely, don't log sensitive data
4. **Duplicate Prevention**: Check for duplicate submissions
5. **Testing**: Use test environment if available

### Recommended Safeguards
```javascript
// Add random delays to mimic human behavior
const humanDelay = () => Math.random() * 2000 + 1000;

// Limit submissions per session
const MAX_SUBMISSIONS_PER_SESSION = 10;

// Add user-agent rotation
const userAgents = [/* list of user agents */];
```

---

## 8. Potential Challenges & Solutions

| Challenge | Solution |
|-----------|----------|
| Slide mechanism detection | Use mouse drag simulation or JavaScript injection |
| Dynamic content loading | Use `waitForSelector` and `waitForFunction` |
| Network timeouts | Implement retry logic with exponential backoff |
| CAPTCHA protection | Manual intervention or CAPTCHA solving service |
| Rate limiting | Add delays, use proxies, rotate IPs |
| Modal timing issues | Wait for modal with explicit timeout |
| Duplicate detection | Track submitted entries, check server response |

---

## 9. Success Metrics

- ✅ Form fills correctly 100% of the time
- ✅ Slide-to-submit automation works reliably
- ✅ Success/error modals detected accurately
- ✅ Retry logic handles transient failures
- ✅ Logs provide clear audit trail
- ✅ No crashes or unhandled exceptions

---

## 10. Next Steps

1. ✅ **Create plan.md** (this document)
2. ⏳ Set up project structure and dependencies
3. ⏳ Implement core bot logic
4. ⏳ Test slide-to-submit automation
5. ⏳ Add error handling and logging
6. ⏳ Test with sample data
7. ⏳ Document usage and configuration
8. ⏳ Final testing and optimization

---

## Appendix: Key Selectors

```javascript
const SELECTORS = {
  fileInput: '#fileInput',
  phoneInput: 'input.mobile-number',
  termsCheckbox: '#termsCheckbox',
  slideButton: '#slideButton',
  slideTrack: '#slideTrack',
  uploadConfirmation: '.upload-btn-wrapper .btn-text',
  successModal: '#successModal.active',
  modalTitle: '.modal-title',
  modalMessage: '.modal-message',
  errorMessage: '#errorMessage'
};
```

---

**Document Version**: 1.0  
**Last Updated**: 2026-01-10  
**Author**: Cascade AI  
**Status**: Ready for Implementation
