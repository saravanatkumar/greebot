const puppeteer = require('puppeteer');
const path = require('path');
const fs = require('fs');
const logger = require('./utils/logger');
const { sleep, maskPhoneNumber, getRandomItem } = require('./utils/helpers');
const Validator = require('./validator');
const FormHandler = require('./formHandler');

class GreenDotBallBot {
  constructor(config) {
    this.config = config;
    this.browser = null;
    this.page = null;
    this.formHandler = null;
    this.submissionCount = 0;
  }

  async init() {
    try {
      logger.info('Initializing Green Dot Ball Bot...');
      
      const validation = Validator.validateConfig(this.config);
      if (!validation.valid) {
        throw new Error('Configuration validation failed');
      }

      const imagePath = path.resolve(this.config.imagePath);
      const imageValidation = Validator.validateImageFile(imagePath);
      if (!imageValidation.valid) {
        throw new Error(imageValidation.error);
      }

      logger.info('Configuration validated successfully');
      return true;
    } catch (error) {
      logger.error('Initialization failed:', error.message);
      throw error;
    }
  }

  async launchBrowser() {
    try {
      logger.info('Launching browser...');
      
      const launchOptions = {
        headless: this.config.headless !== false ? 'new' : false,
        slowMo: this.config.slowMo || 0,
        args: [
          '--no-sandbox',
          '--disable-setuid-sandbox',
          '--disable-dev-shm-usage',
          '--disable-blink-features=AutomationControlled'
        ]
      };

      this.browser = await puppeteer.launch(launchOptions);
      this.page = await this.browser.newPage();

      await this.page.setViewport({ width: 1280, height: 800 });

      await this.page.evaluateOnNewDocument(() => {
        Object.defineProperty(navigator, 'webdriver', {
          get: () => false
        });
      });

      logger.info('Browser launched successfully');
      return true;
    } catch (error) {
      logger.error('Browser launch failed:', error.message);
      throw error;
    }
  }

  async navigateToForm() {
    try {
      logger.info(`Navigating to ${this.config.targetUrl}...`);
      
      await this.page.goto(this.config.targetUrl, {
        waitUntil: 'networkidle2',
        timeout: this.config.timeout || 30000
      });

      await sleep(2000);

      const title = await this.page.title();
      logger.info(`Page loaded: ${title}`);

      this.formHandler = new FormHandler(this.page, this.config);
      
      return true;
    } catch (error) {
      logger.error('Navigation failed:', error.message);
      throw error;
    }
  }

  async submitForm(phoneNumber, imagePath) {
    try {
      logger.info('='.repeat(60));
      logger.info(`Starting form submission #${this.submissionCount + 1}`);
      logger.info(`Phone: ${maskPhoneNumber(phoneNumber)}`);
      logger.info(`Image: ${path.basename(imagePath)}`);
      logger.info('='.repeat(60));

      await this.formHandler.uploadImage(imagePath);
      await sleep(500);

      await this.formHandler.enterPhoneNumber(phoneNumber);
      await sleep(500);

      await this.formHandler.acceptTerms();
      await sleep(500);

      await this.formHandler.performSlideSubmit();
      await sleep(1000);

      const result = await this.formHandler.waitForResponse();

      if (result.success) {
        logger.info('✓ Form submitted successfully!');
        this.submissionCount++;
      } else {
        logger.warn('✗ Form submission failed');
      }

      if (this.config.screenshotOnError && !result.success) {
        await this.formHandler.takeScreenshot(`error-${Date.now()}.png`);
      }

      await this.formHandler.closeModal();
      await sleep(2000);

      return result;
    } catch (error) {
      logger.error('Form submission error:', error.message);
      
      if (this.config.screenshotOnError) {
        await this.formHandler.takeScreenshot(`error-${Date.now()}.png`);
      }

      throw error;
    }
  }

  async submitWithRetry(phoneNumber, imagePath, maxRetries = 3) {
    for (let attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        logger.info(`Attempt ${attempt}/${maxRetries}`);
        
        const result = await this.submitForm(phoneNumber, imagePath);
        
        if (result.success) {
          return { success: true, result };
        } else {
          if (attempt < maxRetries) {
            logger.warn(`Retrying in ${2 * attempt} seconds...`);
            await sleep(2000 * attempt);
            
            await this.page.reload({ waitUntil: 'networkidle2' });
            await sleep(2000);
          }
        }
      } catch (error) {
        logger.error(`Attempt ${attempt} failed:`, error.message);
        
        if (attempt === maxRetries) {
          return { success: false, error: error.message };
        }
        
        logger.warn(`Retrying in ${2 * attempt} seconds...`);
        await sleep(2000 * attempt);
        
        try {
          await this.page.reload({ waitUntil: 'networkidle2' });
          await sleep(2000);
        } catch (reloadError) {
          logger.error('Page reload failed:', reloadError.message);
        }
      }
    }
    
    return { success: false, error: 'Max retries exceeded' };
  }

  async runBatch() {
    try {
      const phoneNumbers = this.config.phoneNumbers;
      const images = this.config.images || [this.config.imagePath];
      const randomSelection = this.config.randomSelection || false;
      const maxSubmissions = this.config.maxSubmissionsPerSession || 10;

      logger.info(`Starting batch mode with ${phoneNumbers.length} phone numbers`);
      logger.info(`Available images: ${images.length}`);
      logger.info(`Random selection: ${randomSelection ? 'ENABLED' : 'DISABLED'}`);
      logger.info(`Max submissions per session: ${maxSubmissions}`);

      const results = [];

      for (let i = 0; i < phoneNumbers.length && i < maxSubmissions; i++) {
        let phoneNumber, imagePath;
        
        if (randomSelection) {
          phoneNumber = getRandomItem(phoneNumbers);
          imagePath = path.resolve(getRandomItem(images));
          logger.info(`\n${'='.repeat(60)}`);
          logger.info(`Processing ${i + 1}/${Math.min(phoneNumbers.length, maxSubmissions)} - RANDOM SELECTION`);
          logger.info(`Selected Phone: ${maskPhoneNumber(phoneNumber)}`);
          logger.info(`Selected Image: ${path.basename(imagePath)}`);
          logger.info(`${'='.repeat(60)}\n`);
        } else {
          phoneNumber = phoneNumbers[i];
          imagePath = path.resolve(images[i % images.length]);
          logger.info(`\n${'='.repeat(60)}`);
          logger.info(`Processing ${i + 1}/${Math.min(phoneNumbers.length, maxSubmissions)}`);
          logger.info(`${'='.repeat(60)}\n`);
        }

        const result = await this.submitWithRetry(
          phoneNumber, 
          imagePath, 
          this.config.retryAttempts || 3
        );

        results.push({
          phoneNumber: maskPhoneNumber(phoneNumber),
          image: path.basename(imagePath),
          success: result.success,
          timestamp: new Date().toISOString()
        });

        // Log individual result to console
        if (result.success) {
          console.log(`\n✅ SUCCESS #${i + 1}: Phone ${maskPhoneNumber(phoneNumber)} | Image: ${path.basename(imagePath)}`);
        } else {
          console.log(`\n❌ FAILED #${i + 1}: Phone ${maskPhoneNumber(phoneNumber)} | Image: ${path.basename(imagePath)}`);
        }

        if (i < phoneNumbers.length - 1 && i < maxSubmissions - 1) {
          const delay = this.config.delayBetweenSubmissions || 5000;
          logger.info(`Waiting ${delay / 1000} seconds before next submission...`);
          await sleep(delay);
        }
      }

      logger.info('\n' + '='.repeat(60));
      logger.info('BATCH SUMMARY');
      logger.info('='.repeat(60));
      logger.info(`Total submissions: ${results.length}`);
      logger.info(`Successful: ${results.filter(r => r.success).length}`);
      logger.info(`Failed: ${results.filter(r => !r.success).length}`);
      logger.info('='.repeat(60));
      
      // Console summary
      console.log('\n' + '='.repeat(60));
      console.log('📊 BATCH SUMMARY');
      console.log('='.repeat(60));
      console.log(`Total submissions: ${results.length}`);
      console.log(`✅ Successful: ${results.filter(r => r.success).length}`);
      console.log(`❌ Failed: ${results.filter(r => !r.success).length}`);
      console.log('='.repeat(60));
      
      // Detailed results
      console.log('\n📋 DETAILED RESULTS:');
      results.forEach((r, idx) => {
        const status = r.success ? '✅ SUCCESS' : '❌ FAILED';
        console.log(`${idx + 1}. ${status} | Phone: ${r.phoneNumber} | Image: ${r.image} | Time: ${new Date(r.timestamp).toLocaleTimeString()}`);
      });
      console.log('='.repeat(60));

      return results;
    } catch (error) {
      logger.error('Batch processing failed:', error.message);
      throw error;
    }
  }

  async run() {
    try {
      await this.init();
      await this.launchBrowser();
      await this.navigateToForm();

      const args = process.argv.slice(2);
      const isBatchMode = args.includes('--batch');

      if (isBatchMode) {
        await this.runBatch();
      } else {
        const randomSelection = this.config.randomSelection || false;
        const images = this.config.images || [this.config.imagePath];
        
        let phoneNumber, imagePath;
        
        if (randomSelection) {
          phoneNumber = getRandomItem(this.config.phoneNumbers);
          imagePath = path.resolve(getRandomItem(images));
          logger.info(`Random selection enabled`);
          logger.info(`Selected Phone: ${maskPhoneNumber(phoneNumber)}`);
          logger.info(`Selected Image: ${path.basename(imagePath)}`);
        } else {
          phoneNumber = this.config.phoneNumbers[0];
          imagePath = path.resolve(this.config.imagePath);
        }
        
        await this.submitWithRetry(
          phoneNumber, 
          imagePath, 
          this.config.retryAttempts || 3
        );
      }

      logger.info('Bot execution completed successfully');
    } catch (error) {
      logger.error('Bot execution failed:', error.message);
      throw error;
    }
  }

  async cleanup() {
    try {
      if (this.browser) {
        await this.browser.close();
        logger.info('Browser closed');
      }
    } catch (error) {
      logger.error('Cleanup failed:', error.message);
    }
  }
}

async function main() {
  let bot = null;
  
  try {
    const configPath = path.join(__dirname, '../config/config.json');
    const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));

    const args = process.argv.slice(2);
    if (args.includes('--debug')) {
      config.headless = false;
      config.slowMo = 100;
    }

    bot = new GreenDotBallBot(config);
    await bot.run();
    
    logger.info('✓ All tasks completed successfully');
    process.exit(0);
  } catch (error) {
    logger.error('Fatal error:', error.message);
    logger.error(error.stack);
    process.exit(1);
  } finally {
    if (bot) {
      await bot.cleanup();
    }
  }
}

if (require.main === module) {
  main();
}

module.exports = GreenDotBallBot;
