// bot_new.js — Job-based bot
// Reads CAMPAIGN_ID + JOB_IDS from environment (set via EC2 USER_DATA or CLI args)
// Downloads job files from S3, downloads images from S3, processes all pairs sequentially

const puppeteer = require('puppeteer');
const path      = require('path');
const fs        = require('fs');
const AWS       = require('aws-sdk');
const s3        = new AWS.S3({ region: process.env.AWS_REGION || 'ap-south-1' });
const logger    = require('./utils/logger');
const { sleep, maskPhoneNumber } = require('./utils/helpers');
const FormHandler = require('./formHandler');

const S3_BUCKET   = 'greendotball-bot-data';
const IMAGES_DIR  = path.join(__dirname, '../data/images-cache');
const JOBS_PER_INSTANCE = 12;

class GreenDotBallJobBot {
  constructor(config) {
    this.config      = config;
    this.campaignId  = process.env.CAMPAIGN_ID  || config.campaignId  || null;
    this.jobIds      = (process.env.JOB_IDS     || config.jobIds      || '').split(',').map(j => j.trim()).filter(Boolean);
    this.browser     = null;
    this.page        = null;
    this.formHandler = null;
    this.instanceId  = null;
    this.totalProcessed = 0;
    this.totalSuccess   = 0;
    this.totalFailed    = 0;
  }

  // ─── Init ──────────────────────────────────────────────────────────────────
  async init() {
    logger.info('='.repeat(60));
    logger.info('GreenDotBall Job Bot — Starting');
    logger.info(`Campaign ID : ${this.campaignId}`);
    logger.info(`Job IDs     : ${this.jobIds.join(', ')}`);
    logger.info('='.repeat(60));

    if (!this.campaignId)       throw new Error('Missing CAMPAIGN_ID. Set env var or pass --campaign-id.');
    if (!this.jobIds.length)    throw new Error('Missing JOB_IDS. Set env var or pass --job-ids.');

    // Get EC2 instance ID
    try {
      const meta = new AWS.MetadataService({ httpOptions: { timeout: 3000 } });
      this.instanceId = await new Promise((res, rej) =>
        meta.request('/latest/meta-data/instance-id', (err, data) => err ? rej(err) : res(data))
      );
    } catch (_) {
      this.instanceId = `local-${Date.now()}`;
    }
    logger.info(`Instance ID : ${this.instanceId}`);

    fs.mkdirSync(IMAGES_DIR, { recursive: true });
  }

  // ─── S3 helpers ───────────────────────────────────────────────────────────
  async loadJobFromS3(jobId) {
    const key = `campaigns/${this.campaignId}/jobs/${jobId}.json`;
    logger.info(`Loading job from S3: ${key}`);
    const res = await s3.getObject({ Bucket: S3_BUCKET, Key: key }).promise();
    return JSON.parse(res.Body.toString());
  }

  async downloadImageFromS3(s3Key) {
    const localName = s3Key.replace(/\//g, '_');
    const localPath = path.join(IMAGES_DIR, localName);
    if (fs.existsSync(localPath)) return localPath;  // already cached

    logger.info(`Downloading image: ${s3Key}`);
    const res  = await s3.getObject({ Bucket: S3_BUCKET, Key: s3Key }).promise();
    fs.writeFileSync(localPath, res.Body);
    return localPath;
  }

  async saveResult(jobId, data) {
    const key = `campaigns/${this.campaignId}/results/${jobId}-${this.instanceId}.json`;
    try {
      await s3.putObject({
        Bucket: S3_BUCKET, Key: key,
        Body: JSON.stringify(data, null, 2), ContentType: 'application/json'
      }).promise();
      logger.info(`Result saved: ${key}`);
    } catch (err) {
      logger.warn(`Could not save result to S3: ${err.message}`);
    }
  }

  // ─── Browser ──────────────────────────────────────────────────────────────
  async launchBrowser() {
    logger.info('Launching browser...');
    this.browser = await puppeteer.launch({
      headless:           this.config.headless !== false ? 'new' : false,
      executablePath:     process.env.PUPPETEER_EXECUTABLE_PATH || undefined,
      slowMo:             this.config.slowMo || 0,
      args: [
        '--no-sandbox', '--disable-setuid-sandbox',
        '--disable-dev-shm-usage', '--disable-blink-features=AutomationControlled'
      ]
    });
    this.page = await this.browser.newPage();
    await this.page.setViewport({ width: 1280, height: 800 });
    await this.page.evaluateOnNewDocument(() => {
      Object.defineProperty(navigator, 'webdriver', { get: () => false });
    });
    logger.info('Browser ready');
  }

  async navigateToForm() {
    logger.info(`Navigating to ${this.config.targetUrl}`);
    await this.page.goto(this.config.targetUrl, {
      waitUntil: 'networkidle2', timeout: this.config.timeout || 30000
    });
    await sleep(1000);
    this.formHandler = new FormHandler(this.page, this.config);
  }

  // ─── Submission ───────────────────────────────────────────────────────────
  async submitForm(phoneNumber, imagePath) {
    await this.formHandler.uploadImage(imagePath);       await sleep(300);
    await this.formHandler.enterPhoneNumber(phoneNumber); await sleep(300);
    await this.formHandler.acceptTerms();                await sleep(300);
    await this.formHandler.performSlideSubmit();         await sleep(500);
    const result = await this.formHandler.waitForResponse();
    if (result.success) this.totalProcessed++;
    await this.formHandler.closeModal();
    await sleep(1000);
    return result;
  }

  async submitWithRetry(phoneNumber, imagePath, retries = 2) {
    for (let attempt = 1; attempt <= retries; attempt++) {
      try {
        const result = await this.submitForm(phoneNumber, imagePath);
        return result;
      } catch (err) {
        logger.warn(`Attempt ${attempt}/${retries} failed: ${err.message}`);
        if (attempt < retries) {
          await sleep(3000 * attempt);
          try { await this.page.reload({ waitUntil: 'networkidle2' }); await sleep(2000); } catch (_) {}
        } else {
          return { success: false, message: err.message };
        }
      }
    }
    return { success: false, message: 'Max retries exceeded' };
  }

  // ─── Process one job ──────────────────────────────────────────────────────
  async processJob(jobId) {
    logger.info(`\n${'─'.repeat(60)}`);
    logger.info(`Processing job: ${jobId}`);
    logger.info(`${'─'.repeat(60)}`);

    const jobData = await this.loadJobFromS3(jobId);
    const pairs   = jobData.pairs || [];
    const results = [];

    for (let i = 0; i < pairs.length; i++) {
      const pair   = pairs[i];
      const phone  = pair.phoneNumber;

      // imagePath in job file is an S3 key like campaigns/{id}/images/img1.jpg
      let localImg;
      try {
        localImg = await this.downloadImageFromS3(pair.imagePath);
      } catch (err) {
        logger.error(`Cannot download image ${pair.imagePath}: ${err.message}`);
        results.push({ pairId: pair.id, success: false, message: 'Image download failed' });
        continue;
      }

      logger.info(`[${i+1}/${pairs.length}] Phone: ${maskPhoneNumber(phone)} | Image: ${path.basename(localImg)}`);

      const result = await this.submitWithRetry(phone, localImg, this.config.retryAttempts || 2);

      results.push({
        pairId:      pair.id,
        phone:       maskPhoneNumber(phone),
        image:       path.basename(localImg),
        success:     result.success,
        message:     (result.message || '').replace(/<[^>]*>/g, '').trim(),
        timestamp:   new Date().toISOString()
      });

      const icon = result.success ? '✅' : '❌';
      console.log(`${icon} [${jobId}] #${i+1} | ${maskPhoneNumber(phone)} | ${path.basename(localImg)}`);

      if (i < pairs.length - 1) await sleep(this.config.delayBetweenSubmissions || 3000);
    }

    const succeeded = results.filter(r => r.success).length;
    this.totalSuccess += succeeded;
    this.totalFailed  += results.length - succeeded;

    await this.saveResult(jobId, {
      jobId, campaignId: this.campaignId, instanceId: this.instanceId,
      completedAt: new Date().toISOString(),
      total: results.length, succeeded, failed: results.length - succeeded,
      results
    });

    logger.info(`Job ${jobId} done: ${succeeded}/${results.length} succeeded`);
    return results;
  }

  // ─── Run all jobs ─────────────────────────────────────────────────────────
  async run() {
    try {
      await this.init();
      await this.launchBrowser();
      await this.navigateToForm();

      const startTime   = Date.now();
      const maxRunMins  = this.config.maxRunTimeMinutes || 55;

      for (const jobId of this.jobIds) {
        const elapsedMins = (Date.now() - startTime) / 60000;
        if (elapsedMins >= maxRunMins) {
          logger.warn(`Time limit ${maxRunMins}min reached. Stopping after ${jobId}.`);
          break;
        }
        await this.processJob(jobId);
      }

      logger.info('\n' + '='.repeat(60));
      logger.info('BATCH COMPLETE');
      logger.info(`Jobs processed : ${this.jobIds.length}`);
      logger.info(`Total success  : ${this.totalSuccess}`);
      logger.info(`Total failed   : ${this.totalFailed}`);
      logger.info('='.repeat(60));

    } catch (err) {
      logger.error('Fatal bot error:', err.message || err.code || String(err));
      logger.error('Stack:', err.stack || 'no stack');
      throw err;
    } finally {
      await this.cleanup();
    }
  }

  async cleanup() {
    try { if (this.browser) { await this.browser.close(); logger.info('Browser closed'); } } catch (_) {}
  }
}

// ─── Entry point ──────────────────────────────────────────────────────────────
async function main() {
  const configPath = path.join(__dirname, '../config/config.json');
  const config     = JSON.parse(fs.readFileSync(configPath, 'utf8'));
  const args       = process.argv.slice(2);

  // CLI overrides: --campaign-id X  --job-ids job-001,job-002,...  --debug
  for (let i = 0; i < args.length; i++) {
    if (args[i] === '--campaign-id' && args[i+1]) { process.env.CAMPAIGN_ID = args[i+1]; i++; }
    if (args[i] === '--job-ids'     && args[i+1]) { process.env.JOB_IDS     = args[i+1]; i++; }
    if (args[i] === '--debug') { config.headless = false; config.slowMo = 100; }
  }

  if (!process.env.CAMPAIGN_ID) {
    console.error('ERROR: CAMPAIGN_ID not set. Use --campaign-id or set env var.');
    process.exit(1);
  }
  if (!process.env.JOB_IDS) {
    console.error('ERROR: JOB_IDS not set. Use --job-ids or set env var.');
    process.exit(1);
  }

  const bot = new GreenDotBallJobBot(config);
  try {
    await bot.run();
    process.exit(0);
  } catch (err) {
    logger.error('Fatal:', err.message || err.code || String(err));
    process.exit(1);
  }
}

if (require.main === module) main();
module.exports = GreenDotBallJobBot;
