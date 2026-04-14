const logger = require('./utils/logger');
const { sleep, humanDelay } = require('./utils/helpers');

const SELECTORS = {
  fileInput:    '#imageInput',
  phoneInput:   '#phoneInput',
  termsCheckbox: '#termsCheckbox',
  slideKnob:    '#knob',
  slideTrack:   '#slider',
  successModal: '#successModal',
  modalTitle:   '.modal-title',
  modalMessage: '.modal-message',
  modalClose:   '.modal-close-btn',
  errorMessage: '#errorMessage'
};

class FormHandler {
  constructor(page, config) {
    this.page = page;
    this.config = config;
  }

  async uploadImage(imagePath) {
    try {
      logger.info('Uploading image...');

      await this.page.waitForSelector(SELECTORS.fileInput, { 
        timeout: 15000
      });
      
      const fileInput = await this.page.$(SELECTORS.fileInput);
      if (!fileInput) {
        throw new Error('File input not found (#imageInput)');
      }

      await fileInput.uploadFile(imagePath);
      // Puppeteer's uploadFile is synchronous — give the page JS time to process
      await sleep(1500);
      await sleep(await humanDelay());
      logger.info('Image uploaded successfully');
      return true;
    } catch (error) {
      logger.error('Image upload failed:', error.message);
      throw error;
    }
  }

  async enterPhoneNumber(phoneNumber) {
    try {
      logger.info(`Entering phone number: ${phoneNumber}`);
      
      await this.page.waitForSelector(SELECTORS.phoneInput, { timeout: 5000 });
      await sleep(1000);
      await this.page.click(SELECTORS.phoneInput);
      await sleep(500);
      
      await this.page.evaluate((selector) => {
        const input = document.querySelector(selector);
        if (input) input.value = '';
      }, SELECTORS.phoneInput);
      await sleep(300);
      
      await this.page.type(SELECTORS.phoneInput, phoneNumber, { delay: 100 });
      await sleep(1000);

      const enteredValue = await this.page.$eval(SELECTORS.phoneInput, el => el.value);
      if (enteredValue !== phoneNumber) {
        throw new Error('Phone number not entered correctly');
      }

      logger.info('Phone number entered successfully');
      return true;
    } catch (error) {
      logger.error('Phone number entry failed:', error.message);
      throw error;
    }
  }

  async acceptTerms() {
    try {
      logger.info('Accepting terms and conditions...');

      await this.page.waitForSelector(SELECTORS.termsCheckbox, { timeout: 5000 });

      // Layer 1: direct click
      await this.page.click(SELECTORS.termsCheckbox);
      await sleep(500);

      let isChecked = await this.page.$eval(SELECTORS.termsCheckbox, el => el.checked);

      // Layer 2: click the associated <label> (handles custom-styled hidden checkboxes)
      if (!isChecked) {
        logger.warn('Direct click did not check — trying label click...');
        await this.page.evaluate(() => {
          const label = document.querySelector('label[for="termsCheckbox"]');
          if (label) label.click();
        });
        await sleep(500);
        isChecked = await this.page.$eval(SELECTORS.termsCheckbox, el => el.checked);
      }

      // Layer 3: force-check via JS (last resort)
      if (!isChecked) {
        logger.warn('Label click did not check — forcing via JS...');
        await this.page.evaluate(() => {
          const cb = document.querySelector('#termsCheckbox');
          if (cb) {
            cb.checked = true;
            cb.dispatchEvent(new Event('change', { bubbles: true }));
            cb.dispatchEvent(new Event('click',  { bubbles: true }));
          }
        });
        await sleep(500);
        isChecked = await this.page.$eval(SELECTORS.termsCheckbox, el => el.checked);
      }

      if (!isChecked) {
        throw new Error('Terms checkbox not checked');
      }

      logger.info('Terms accepted successfully');
      return true;
    } catch (error) {
      logger.error('Terms acceptance failed:', error.message);
      throw error;
    }
  }

  async performSlideSubmit() {
    try {
      logger.info('Performing slide-to-submit...');
      
      const strategy = this.config.slideStrategy || 'mouse';
      
      if (strategy === 'mouse') {
        return await this.slideWithMouse();
      } else if (strategy === 'javascript') {
        return await this.slideWithJavaScript();
      } else {
        throw new Error(`Unknown slide strategy: ${strategy}`);
      }
    } catch (error) {
      logger.error('Slide-to-submit failed:', error.message);
      throw error;
    }
  }

  async slideWithMouse() {
    try {
      logger.info('Using mouse drag strategy...');

      await this.page.waitForSelector(SELECTORS.slideKnob,  { timeout: 5000 });
      await this.page.waitForSelector(SELECTORS.slideTrack, { timeout: 5000 });

      const slideButton = await this.page.$(SELECTORS.slideKnob);
      const slideTrack  = await this.page.$(SELECTORS.slideTrack);

      const buttonBox = await slideButton.boundingBox();
      const trackBox  = await slideTrack.boundingBox();

      if (!buttonBox || !trackBox) {
        throw new Error('Could not get bounding boxes for slide elements');
      }

      const dragDistance = trackBox.width - buttonBox.width - 2; // 100% to end

      const startX = buttonBox.x + buttonBox.width / 2;
      const startY = buttonBox.y + buttonBox.height / 2;
      const endX   = startX + dragDistance;

      logger.info(`Dragging from ${startX.toFixed(0)} to ${endX.toFixed(0)} (full track)`);

      await this.page.mouse.move(startX, startY);
      await sleep(200);
      await this.page.mouse.down();
      await sleep(100);

      const steps = 40; // more steps = smoother, more reliable
      for (let i = 0; i <= steps; i++) {
        const x = startX + (dragDistance * i / steps);
        await this.page.mouse.move(x, startY);
        await sleep(20);
      }

      // Hold at end briefly before releasing
      await sleep(200);
      await this.page.mouse.up();

      logger.info('Mouse drag completed');
      await sleep(500);

      return true;
    } catch (error) {
      logger.error('Mouse drag failed:', error.message);
      throw error;
    }
  }

  async slideWithJavaScript() {
    try {
      logger.info('Using JavaScript injection strategy...');

      await this.page.evaluate(() => {
        const slideButton = document.getElementById('knob');
        const slideTrack  = document.getElementById('slider');

        if (!slideButton || !slideTrack) {
          throw new Error('Slide elements not found (#knob / #slider)');
        }

        const trackWidth  = slideTrack.offsetWidth;
        const buttonWidth = slideButton.offsetWidth;
        const maxSlide    = trackWidth - buttonWidth - 10;

        slideButton.style.transform  = `translateX(${maxSlide}px)`;
        slideButton.style.transition = 'all 0.3s ease';
        slideTrack.classList.add('completed');

        const slideText = slideTrack.querySelector('.slide-text');
        if (slideText) slideText.style.opacity = 0;
      });

      logger.info('JavaScript injection completed');
      await sleep(500);

      await this.page.evaluate(() => {
        if (typeof submitForm === 'function') {
          submitForm();
        }
      });

      logger.info('Submit function triggered');
      return true;
    } catch (error) {
      logger.error('JavaScript injection failed:', error.message);
      throw error;
    }
  }

  async waitForResponse() {
    try {
      logger.info('Waiting for submission response...');

      // Wait until #successModal becomes visible (display != none, not relying on .active class)
      await this.page.waitForFunction(() => {
        const modal = document.querySelector('#successModal');
        if (!modal) return false;
        const style = window.getComputedStyle(modal);
        return style.display !== 'none' && style.visibility !== 'hidden' && style.opacity !== '0';
      }, { timeout: 60000 });

      await sleep(2000);

      const modalTitle   = await this.page.$eval(SELECTORS.modalTitle,   el => el.textContent).catch(() => '');
      const modalMessage = await this.page.$eval(SELECTORS.modalMessage, el => el.innerHTML).catch(() => '');

      const isSuccess = modalTitle.toLowerCase().includes('success');

      if (isSuccess) {
        logger.info('✓ Submission successful!');
        logger.info(`Message: ${modalMessage.replace(/<[^>]*>/g, '').trim()}`);
        return { success: true, message: modalMessage };
      } else {
        logger.warn('✗ Submission failed');
        logger.warn(`Title: ${modalTitle} | Message: ${modalMessage.replace(/<[^>]*>/g, '').trim()}`);
        return { success: false, message: modalMessage };
      }
    } catch (error) {
      logger.error('Failed to get response:', error.message);
      throw error;
    }
  }

  async closeModal() {
    try {
      const closeButton = await this.page.$(SELECTORS.modalClose);
      if (closeButton) {
        await closeButton.click();
        await sleep(800);
        logger.info('Modal closed');
      }
    } catch (error) {
      logger.warn('Could not close modal:', error.message);
    }
  }

  async takeScreenshot(filename) {
    try {
      await this.page.screenshot({ 
        path: `logs/${filename}`,
        fullPage: true 
      });
      logger.info(`Screenshot saved: logs/${filename}`);
    } catch (error) {
      logger.error('Screenshot failed:', error.message);
    }
  }
}

module.exports = FormHandler;
