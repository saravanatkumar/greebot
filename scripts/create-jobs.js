#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const AWS = require('aws-sdk');
const s3 = new AWS.S3();

// Configuration
const JOBS_DIR = path.join(__dirname, '../data/jobs');
const MASTER_JOB_FILE = path.join(JOBS_DIR, 'masterjob.json');
const IMAGES_DIR = path.join(__dirname, '../data/images');
const PHONE_NUMBERS_FILE = path.join(__dirname, '../data/mobile-numbers.txt');
const S3_BUCKET = 'greendotball-bot-data';

// Create jobs directory if it doesn't exist
if (!fs.existsSync(JOBS_DIR)) {
  fs.mkdirSync(JOBS_DIR, { recursive: true });
  console.log(`Created directory: ${JOBS_DIR}`);
}

// Helper function to chunk array into specified sizes
function chunkArray(array, chunkSize) {
  const chunks = [];
  for (let i = 0; i < array.length; i += chunkSize) {
    chunks.push(array.slice(i, i + chunkSize));
  }
  return chunks;
}

// Main function
async function createJobs() {
  try {
    // Parse command line arguments
    const args = process.argv.slice(2);
    const campaignName = args.find(arg => arg.startsWith('--campaign='))?.split('=')[1] || `Campaign-${Date.now()}`;
    const jobSizeArg = args.find(arg => arg.startsWith('--job-size='))?.split('=')[1];
    const jobSize = jobSizeArg ? parseInt(jobSizeArg) : 50;
    const totalJobsArg = args.find(arg => arg.startsWith('--total-jobs='))?.split('=')[1];
    const maxJobCount = totalJobsArg ? parseInt(totalJobsArg) : 20;

    console.log('='.repeat(60));
    console.log('GreenDotBall Job Creator');
    console.log('='.repeat(60));
    console.log(`Campaign: ${campaignName}`);
    console.log(`Job Size: ${jobSize} pairs per job`);
    console.log(`Max Jobs: ${maxJobCount}`);
    console.log('='.repeat(60));

    // Load phone numbers
    if (!fs.existsSync(PHONE_NUMBERS_FILE)) {
      console.error(`Error: Phone numbers file not found: ${PHONE_NUMBERS_FILE}`);
      process.exit(1);
    }

    const phoneNumbers = fs.readFileSync(PHONE_NUMBERS_FILE, 'utf8')
      .split('\n')
      .map(line => line.trim())
      .filter(line => line.length > 0);

    console.log(`Loaded ${phoneNumbers.length} phone numbers`);

    // Load images
    if (!fs.existsSync(IMAGES_DIR)) {
      console.error(`Error: Images directory not found: ${IMAGES_DIR}`);
      process.exit(1);
    }

    const imageFiles = fs.readdirSync(IMAGES_DIR)
      .filter(file => /\.(jpg|jpeg|png|gif|webp)$/i.test(file))
      .map(file => path.join('data/images', file)); // Store relative paths

    console.log(`Loaded ${imageFiles.length} images`);

    // Generate all possible phone-image pairs
    const allPairs = [];
    let pairId = 1;

    for (const phoneNumber of phoneNumbers) {
      for (const imagePath of imageFiles) {
        allPairs.push({
          id: `pair-${pairId++}`,
          phoneNumber,
          imagePath
        });
      }
    }

    console.log(`Generated ${allPairs.length} phone-image pairs`);

    // Split pairs into jobs
    const jobChunks = chunkArray(allPairs, jobSize);
    const jobs = jobChunks.slice(0, maxJobCount).map((pairs, index) => {
      const jobId = `job-${index + 1}`;
      return {
        job_id: jobId,
        name: `Batch ${index + 1}`,
        created_at: new Date().toISOString(),
        pairs
      };
    });

    console.log(`Created ${jobs.length} jobs`);

    // Create master job file
    const masterJob = {
      campaign_name: campaignName,
      created_at: new Date().toISOString(),
      total_jobs: jobs.length,
      jobs: jobs.map(job => ({
        id: job.job_id,
        name: job.name,
        file: `jobs/${job.job_id}.json`,
        image_count: job.pairs.length
      }))
    };

    // Write files
    fs.writeFileSync(MASTER_JOB_FILE, JSON.stringify(masterJob, null, 2));
    console.log(`Created master job file: ${MASTER_JOB_FILE}`);

    for (const job of jobs) {
      const jobFilePath = path.join(JOBS_DIR, `${job.job_id}.json`);
      fs.writeFileSync(jobFilePath, JSON.stringify(job, null, 2));
      console.log(`Created job file: ${jobFilePath}`);
    }

    // Upload files to S3 if requested
    if (args.includes('--upload-s3')) {
      console.log('\nUploading files to S3...');
      
      // Upload master job file
      await s3.putObject({
        Bucket: S3_BUCKET,
        Key: 'jobs/masterjob.json',
        Body: JSON.stringify(masterJob, null, 2),
        ContentType: 'application/json'
      }).promise();
      console.log(`Uploaded masterjob.json to S3`);
      
      // Upload individual job files
      for (const job of jobs) {
        await s3.putObject({
          Bucket: S3_BUCKET,
          Key: `jobs/${job.job_id}.json`,
          Body: JSON.stringify(job, null, 2),
          ContentType: 'application/json'
        }).promise();
        console.log(`Uploaded ${job.job_id}.json to S3`);
      }
      
      console.log('S3 upload complete');
    }

    console.log('\n='.repeat(60));
    console.log('Job Creation Summary');
    console.log('='.repeat(60));
    console.log(`Total phone numbers: ${phoneNumbers.length}`);
    console.log(`Total images: ${imageFiles.length}`);
    console.log(`Total pairs: ${allPairs.length}`);
    console.log(`Total jobs created: ${jobs.length}`);
    console.log(`Pairs per job: ~${jobSize}`);
    console.log(`Files saved to: ${JOBS_DIR}`);
    console.log('='.repeat(60));
    
    console.log('\nTo launch a job instance:');
    console.log(`  ./scripts/launch-job-instance.sh job-1`);
    console.log('\nTo launch multiple instances for a job:');
    console.log(`  ./scripts/launch-job-instance.sh job-1 5`);
    console.log('='.repeat(60));

  } catch (error) {
    console.error(`Error: ${error.message}`);
    console.error(error.stack);
    process.exit(1);
  }
}

// Execute the main function
createJobs();
