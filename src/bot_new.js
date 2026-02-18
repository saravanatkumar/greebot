const puppeteer = require('puppeteer');
const path = require('path');
const fs = require('fs');
const AWS = require('aws-sdk');
const s3 = new AWS.S3();
const logger = require('./utils/logger');
const { sleep, maskPhoneNumber, getRandomItem } = require('./utils/helpers');
const Validator = require('./validator');
const FormHandler = require('./formHandler');

class GreenDotBallJobBot {
  constructor(config) {
    this.config = config;
    this.browser = null;
    this.page = null;
    this.formHandler = null;
    this.jobId = process.env.JOB_ID || this.config.jobId;
    this.submissionCount = 0;
    this.s3Bucket = 'greendotball-bot-data';
    this.instanceId = null;
  }

  async init() {
    try {
      logger.info('='.repeat(60));
      logger.info(`Initializing Green Dot Ball Job Bot for Job ID: ${this.jobId}`);
      logger.info('='.repeat(60));
      
      if (!this.jobId) {
        throw new Error('No Job ID provided. Set JOB_ID environment variable or jobId in config.');
      }
      
      // Get EC2 instance ID for logging
      try {
        const metadata = new AWS.MetadataService();
        this.instanceId = await new Promise((resolve, reject) => {
          metadata.request('/latest/meta-data/instance-id', (err, data) => {
            if (err) reject(err);
            else resolve(data);
          });
        });
        logger.info(`Running on instance: ${this.instanceId}`);
      } catch (err) {
        logger.warn('Could not retrieve instance ID. Running locally?');
        this.instanceId = `local-${Date.now()}`;
      }
      
      // Load job data
      await this.loadJobData();
      
      const validation = Validator.validateConfig(this.config);
      if (!validation.valid) {
        throw new Error('Configuration validation failed');
      }

      logger.info('Configuration validated successfully');
      logger.info(`Job has ${this.jobData.pairs.length} phone-image pairs to process`);
      return true;
    } catch (error) {
      logger.error('Initialization failed:', error.message);
      throw error;
    }
  }
  
  async loadJobData() {
    try {
      logger.info(`Loading job data for Job ID: ${this.jobId}`);
      
      let jobFilePath;
      
      // Try to load from local file first
      const localJobPath = path.join(__dirname, `../data/jobs/${this.jobId}.json`);
      if (fs.existsSync(localJobPath)) {
        logger.info(`Loading job data from local file: ${localJobPath}`);
        this.jobData = JSON.parse(fs.readFileSync(localJobPath, 'utf8'));
      } else {
        // Load from S3 if not available locally
        logger.info(`Loading job data from S3: jobs/${this.jobId}.json`);
        const params = {
          Bucket: this.s3Bucket,
          Key: `jobs/${this.jobId}.json`
        };
        
        const response = await s3.getObject(params).promise();
        this.jobData = JSON.parse(response.Body.toString());
      }
      
      if (!this.jobData || !this.jobData.pairs || !Array.isArray(this.jobData.pairs)) {
        throw new Error(`Invalid job data format for job ${this.jobId}`);
      }
      
      logger.info(`Successfully loaded job data with ${this.jobData.pairs.length} pairs`);
      return this.jobData;
    } catch (error) {
      logger.error(`Failed to load job data: ${error.message}`);
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
      logger.info(`Job ID: ${this.jobId}`);
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
        await this.formHandler.takeScreenshot(`error-${this.jobId}-${Date.now()}.png`);
      }

      await this.formHandler.closeModal();
      await sleep(2000);

      return result;
    } catch (error) {
      logger.error('Form submission error:', error.message);
      
      if (this.config.screenshotOnError) {
        await this.formHandler.takeScreenshot(`error-${this.jobId}-${Date.now()}.png`);
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

  async processJobPairs() {
    try {
      logger.info(`Starting job processing for ${this.jobData.pairs.length} pairs...`);
      
      const results = [];
      const jobStartTime = Date.now();
      const maxRunTime = this.config.maxRunTimeMinutes || 55; // Default to 55 minutes to be safe
      let timeExpired = false;
      
      // Process job pairs
      for (let i = 0; i < this.jobData.pairs.length; i++) {
        // Check if we're approaching the time limit (EC2 instances typically run for 1 hour)
        const elapsedMinutes = (Date.now() - jobStartTime) / (1000 * 60);
        if (elapsedMinutes >= maxRunTime) {
          logger.warn(`Maximum run time of ${maxRunTime} minutes reached. Stopping processing.`);
          timeExpired = true;
          break;
        }
        
        const pair = this.jobData.pairs[i];
        const submissionNum = i + 1;
        const phoneNumber = pair.phoneNumber;
        
        // Resolve image path - could be relative to project root
        let imagePath = pair.imagePath;
        if (!path.isAbsolute(imagePath)) {
          imagePath = path.join(__dirname, '..', imagePath);
        }
        
        logger.info(`\n${'='.repeat(60)}`);
        logger.info(`📤 SUBMISSION ${submissionNum}/${this.jobData.pairs.length}`);
        logger.info(`Phone: ${maskPhoneNumber(phoneNumber)}`);
        logger.info(`Image: ${path.basename(imagePath)}`);
        logger.info(`Job ID: ${this.jobId}`);
        logger.info(`Pair ID: ${pair.id}`);
        logger.info(`${'='.repeat(60)}\n`);

        // Check if image exists
        if (!fs.existsSync(imagePath)) {
          logger.error(`Image file not found: ${imagePath}`);
          results.push({
            pairId: pair.id,
            phoneNumber: maskPhoneNumber(phoneNumber),
            image: path.basename(imagePath),
            success: false,
            message: 'Image file not found',
            timestamp: new Date().toISOString(),
            jobId: this.jobId
          });
          continue;
        }
        
        // Process this pair
        const result = await this.submitWithRetry(
          phoneNumber, 
          imagePath, 
          this.config.retryAttempts || 3
        );

        results.push({
          pairId: pair.id,
          phoneNumber: maskPhoneNumber(phoneNumber),
          image: path.basename(imagePath),
          success: result.success,
          message: result.message ? result.message.replace(/<[^>]*>/g, '').trim() : '',
          timestamp: new Date().toISOString(),
          jobId: this.jobId
        });

        // Log individual result to console with server response
        if (result.success) {
          console.log(`\n✅ SUCCESS #${submissionNum}: Phone ${maskPhoneNumber(phoneNumber)} | Image: ${path.basename(imagePath)}`);
          if (result.message) {
            console.log(`   Server Response: ${result.message.replace(/<[^>]*>/g, '').trim()}`);
          }
        } else {
          console.log(`\n❌ FAILED #${submissionNum}: Phone ${maskPhoneNumber(phoneNumber)} | Image: ${path.basename(imagePath)}`);
          if (result.message) {
            console.log(`   Server Response: ${result.message.replace(/<[^>]*>/g, '').trim()}`);
          }
        }

        // Save progress after each submission
        await this.saveProgress(results);
        
        if (i < this.jobData.pairs.length - 1 && !timeExpired) {
          const delay = this.config.delayBetweenSubmissions || 5000;
          logger.info(`Waiting ${delay / 1000} seconds before next submission...`);
          await sleep(delay);
        }
      }

      // Save final results
      await this.saveProgress(results, true);
      
      logger.info('\n' + '='.repeat(60));
      logger.info('JOB SUMMARY');
      logger.info('='.repeat(60));
      logger.info(`Total submissions: ${results.length} of ${this.jobData.pairs.length}`);
      logger.info(`Successful: ${results.filter(r => r.success).length}`);
      logger.info(`Failed: ${results.filter(r => !r.success).length}`);
      logger.info(`Incomplete: ${this.jobData.pairs.length - results.length}`);
      logger.info(`Job ID: ${this.jobId}`);
      logger.info(`Time expired: ${timeExpired ? 'YES' : 'NO'}`);
      logger.info('='.repeat(60));
      
      return {
        processed: results.length,
        successful: results.filter(r => r.success).length,
        failed: results.filter(r => !r.success).length,
        incomplete: this.jobData.pairs.length - results.length,
        timeExpired
      };
    } catch (error) {
      logger.error('Job processing failed:', error.message);
      throw error;
    }
  }
  
  async saveProgress(results, isFinal = false) {
    try {
      // Create a results object
      const resultsData = {
        jobId: this.jobId,
        instanceId: this.instanceId,
        timestamp: new Date().toISOString(),
        isFinal: isFinal,
        processed: results.length,
        total: this.jobData.pairs.length,
        successful: results.filter(r => r.success).length,
        failed: results.filter(r => !r.success).length,
        results: results
      };
      
      // Save to S3
      const params = {
        Bucket: this.s3Bucket,
        Key: `logs/job-${this.jobId}/results-${this.instanceId}-${isFinal ? 'final' : Date.now()}.json`,
        Body: JSON.stringify(resultsData, null, 2),
        ContentType: 'application/json'
      };
      
      await s3.putObject(params).promise();
      logger.info(`Progress saved to S3: ${params.Key}`);
      
      return true;
    } catch (error) {
      logger.error('Failed to save progress:', error.message);
      return false;
    }
  }

  async run() {
    try {
      await this.init();
      await this.launchBrowser();
      await this.navigateToForm();

      const jobResults = await this.processJobPairs();
      
      logger.info(`Job processing completed. Processed ${jobResults.processed}/${this.jobData.pairs.length} pairs.`);
      logger.info(`Success rate: ${Math.round((jobResults.successful / jobResults.processed) * 100)}%`);
      
      return jobResults;
    } catch (error) {
      logger.error('Bot execution failed:', error.message);
      throw error;
    } finally {
      await this.cleanup();
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
    
    // Parse job ID argument
    let jobId = process.env.JOB_ID || null;
    
    for (let i = 0; i < args.length; i++) {
      if (args[i] === '--job-id' && args[i + 1]) {
        jobId = args[i + 1];
      }
    }
    
    if (!jobId) {
      console.error('ERROR: No Job ID provided. Use --job-id parameter or set JOB_ID environment variable.');
      process.exit(1);
    }
    
    // Store job ID in config
    config.jobId = jobId;
    
    if (args.includes('--debug')) {
      config.headless = false;
      config.slowMo = 100;
    }

    bot = new GreenDotBallJobBot(config);
    const results = await bot.run();
    
    logger.info('✓ Job processing completed');
    console.log('\nJob Summary:');
    console.log(`- Job ID: ${jobId}`);
    console.log(`- Processed: ${results.processed}/${bot.jobData.pairs.length}`);
    console.log(`- Successful: ${results.successful}`);
    console.log(`- Failed: ${results.failed}`);
    console.log(`- Incomplete: ${results.incomplete}`);
    console.log(`- Time expired: ${results.timeExpired ? 'YES' : 'NO'}`);
    
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

module.exports = GreenDotBallJobBot;
