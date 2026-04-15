# Fix: "Target closed" Error After Form Submission

## Problem
Bot fails with `Protocol error (Runtime.callFunctionOn): Target closed` after completing slide-to-submit action.

## Error Details
```
{"level":"error","message":"Failed to get response:","service":"greendotball-bot","timestamp":"2026-04-14 16:50:40"}
Protocol error (Runtime.callFunctionOn): Target closed
```

## Root Cause
The browser page/tab closes or navigates away after form submission, before the bot can read the success/failure modal. This happens during `waitForResponse()` at line 245 in `formHandler.js`.

## Current Flow
1. ✅ Slide-to-submit completes successfully
2. ⏳ Bot waits for `#successModal` to appear (60s timeout)
3. ❌ Page closes/navigates → Protocol error
4. ❌ Submission marked as failed (even if it actually succeeded)

## Possible Causes
- Website redirects to a success/thank-you page
- Form submission opens new window and closes current one
- Anti-bot detection forcefully closes the session
- Browser crash due to memory/resource issues

## Solution: Add Navigation/Close Detection

### Implementation Steps

1. **Modify `waitForResponse()` in `formHandler.js`** (line 240-271)
   - Add event listeners for page navigation/close
   - Race between modal appearance and page events
   - Handle navigation as potential success case

2. **Add navigation handler**
   ```javascript
   const navigationPromise = new Promise((resolve) => {
     this.page.on('framenavigated', (frame) => {
       if (frame === this.page.mainFrame()) {
         resolve({ navigated: true, url: frame.url() });
       }
     });
   });
   ```

3. **Race conditions**
   ```javascript
   const result = await Promise.race([
     modalPromise,
     navigationPromise,
     closePromise
   ]);
   ```

4. **Handle each outcome**
   - **Modal appears** → Read success/failure normally
   - **Page navigates** → Check URL for success indicators (e.g., `/success`, `/thank-you`)
   - **Page closes** → Log as uncertain, require manual verification

### Code Changes Required

**File:** `src/formHandler.js`

**Function:** `waitForResponse()` (lines 240-271)

**Changes:**
- Add page event listeners before waiting
- Implement Promise.race() for multiple outcomes
- Add URL pattern matching for success detection
- Improve error handling for "Target closed" scenario
- Add fallback logging for uncertain cases

### Success URL Patterns to Check
- `/success`
- `/thank-you`
- `/confirmation`
- Query params: `?status=success`, `?submitted=true`

### Testing Plan
1. Run bot with modified code
2. Monitor for "Target closed" errors
3. Check if navigation is detected
4. Verify success detection from URL patterns
5. Confirm submissions are properly recorded

## Alternative Solutions

### Option 2: Retry with Fresh Browser
- Catch "Target closed" error
- Restart browser instance
- Retry the same phone/image combination
- **Downside:** May cause duplicate submissions

### Option 3: Pre-emptive Screenshot
- Take screenshot before submission
- If error occurs, save screenshot for manual review
- **Downside:** Doesn't solve the problem, just documents it

## Recommended Action
Implement **Option 1** (Navigation/Close Detection) as it:
- Handles legitimate redirects gracefully
- Reduces false negatives
- Provides better logging for debugging
- Doesn't risk duplicate submissions

## Files to Modify
- [ ] `src/formHandler.js` - Add navigation detection to `waitForResponse()`
- [ ] `src/utils/logger.js` - Add logging for navigation events (if needed)
- [ ] Test with sample phone numbers

## Priority
**HIGH** - This error causes valid submissions to be marked as failed, requiring manual verification and potential re-submission.
