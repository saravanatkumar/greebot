// Lambda: create-jobs
// Receives: { campaignId, imagesPerJob (default 10), phonesPerJob (default 10), imageSource ('upload'|'pool') }
// Does:     reads phones.txt + lists images from S3, generates jobs,
//           saves job-NNN.json + masterjob.json to S3, returns job list
// Rule:     1 job = phonesPerJob phones × imagesPerJob images = 100 submissions
//           1 EC2 instance = 1 job

const AWS = require('aws-sdk');
const s3  = new AWS.S3();

const S3_BUCKET         = 'greendotball-bot-data';
const IMAGE_POOL_PREFIX = 'images-pool/';   // shared pool: s3://greendotball-bot-data/images-pool/

const corsHeaders = {
  'Content-Type': 'application/json',
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST,OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'
};

async function listImages(prefix) {
  const images = [];
  let token;
  do {
    const res = await s3.listObjectsV2({ Bucket: S3_BUCKET, Prefix: prefix, ContinuationToken: token }).promise();
    for (const obj of res.Contents || []) {
      const name = obj.Key.split('/').pop();
      if (!name) continue;
      const ext = name.split('.').pop().toLowerCase();
      if (['jpg','jpeg','png','gif','webp'].includes(ext)) images.push(obj.Key);
    }
    token = res.IsTruncated ? res.NextContinuationToken : null;
  } while (token);
  return images;
}

function shuffle(arr) {
  for (let i = arr.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [arr[i], arr[j]] = [arr[j], arr[i]];
  }
  return arr;
}

function chunkArray(arr, size) {
  const chunks = [];
  for (let i = 0; i < arr.length; i += size) chunks.push(arr.slice(i, i + size));
  return chunks;
}

exports.handler = async (event) => {
  if (event.httpMethod === 'OPTIONS') {
    return { statusCode: 200, headers: corsHeaders, body: '' };
  }

  try {
    const body         = typeof event.body === 'string' ? JSON.parse(event.body) : event.body;
    const campaignId   = body.campaignId;
    const imagesPerJob = parseInt(body.imagesPerJob  || '10',  10);
    const phonesPerJob = parseInt(body.phonesPerJob  || '10',  10);
    const imageSource  = body.imageSource || 'upload'; // 'upload' | 'pool'

    if (!campaignId) throw new Error('Missing campaignId');

    // ── Load phones ──────────────────────────────────────────────────────────
    const phonesObj = await s3.getObject({
      Bucket: S3_BUCKET, Key: `campaigns/${campaignId}/phones.txt`
    }).promise();

    const phones = phonesObj.Body.toString()
      .split('\n').map(p => p.trim()).filter(p => /^\d{10}$/.test(p));

    if (phones.length === 0) throw new Error('No valid phone numbers found in phones.txt');

    // ── Load images ──────────────────────────────────────────────────────────
    let allImageKeys;
    if (imageSource === 'pool') {
      allImageKeys = await listImages(IMAGE_POOL_PREFIX);
      if (allImageKeys.length === 0) throw new Error(`No images found in pool (s3://${S3_BUCKET}/${IMAGE_POOL_PREFIX})`);
      shuffle(allImageKeys);
    } else {
      allImageKeys = await listImages(`campaigns/${campaignId}/images/`);
      if (allImageKeys.length === 0) throw new Error('No images found in S3 for this campaign');
    }

    // ── Generate jobs: phonesPerJob phones × imagesPerJob images = 1 job ────
    // Chunk phones into groups of phonesPerJob
    const phoneChunks = chunkArray(phones, phonesPerJob);
    const jobs = [];
    let jobNum = 1;

    for (const phoneGroup of phoneChunks) {
      const jobId = `job-${String(jobNum).padStart(3, '0')}`;

      // Pick imagesPerJob images for this job
      // For pool: rotate through the pool (wrap around if fewer images than jobs need)
      const imgOffset  = ((jobNum - 1) * imagesPerJob) % allImageKeys.length;
      const imgSlice   = [];
      for (let k = 0; k < imagesPerJob; k++) {
        imgSlice.push(allImageKeys[(imgOffset + k) % allImageKeys.length]);
      }

      // Build pairs: every phone × every image in this job
      const pairs = [];
      let pairIdx = 1;
      for (const phone of phoneGroup) {
        for (const imgKey of imgSlice) {
          pairs.push({
            id:          `${jobId}-pair-${pairIdx}`,
            phoneNumber: phone,
            imagePath:   imgKey
          });
          pairIdx++;
        }
      }

      jobs.push({
        jobId,
        phoneCount:  phoneGroup.length,
        imageCount:  imgSlice.length,
        submissions: pairs.length,
        pairs
      });

      jobNum++;
    }

    // ── Save each job file to S3 ─────────────────────────────────────────────
    for (const job of jobs) {
      await s3.putObject({
        Bucket:      S3_BUCKET,
        Key:         `campaigns/${campaignId}/jobs/${job.jobId}.json`,
        Body:        JSON.stringify({
          jobId:       job.jobId,
          campaignId,
          phoneCount:  job.phoneCount,
          imageCount:  job.imageCount,
          submissions: job.submissions,
          imageSource,
          createdAt:   new Date().toISOString(),
          pairs:       job.pairs
        }, null, 2),
        ContentType: 'application/json'
      }).promise();
    }

    // ── Save masterjob.json ──────────────────────────────────────────────────
    const masterJob = {
      campaignId,
      createdAt:    new Date().toISOString(),
      imageSource,
      totalJobs:    jobs.length,
      phoneCount:   phones.length,
      imageCount:   allImageKeys.length,
      imagesPerJob,
      phonesPerJob,
      totalSubmissions: jobs.reduce((s, j) => s + j.submissions, 0),
      jobs: jobs.map(j => ({
        jobId:       j.jobId,
        phoneCount:  j.phoneCount,
        imageCount:  j.imageCount,
        submissions: j.submissions,
        file:        `campaigns/${campaignId}/jobs/${j.jobId}.json`
      }))
    };

    await s3.putObject({
      Bucket:      S3_BUCKET,
      Key:         `campaigns/${campaignId}/jobs/masterjob.json`,
      Body:        JSON.stringify(masterJob, null, 2),
      ContentType: 'application/json'
    }).promise();

    // ── Update campaign metadata ─────────────────────────────────────────────
    try {
      const metaObj  = await s3.getObject({ Bucket: S3_BUCKET, Key: `campaigns/${campaignId}/metadata.json` }).promise();
      const metadata = JSON.parse(metaObj.Body.toString());
      metadata.status          = 'jobs_created';
      metadata.jobCount        = jobs.length;
      metadata.totalSubmissions = masterJob.totalSubmissions;
      metadata.imageSource     = imageSource;
      await s3.putObject({
        Bucket: S3_BUCKET, Key: `campaigns/${campaignId}/metadata.json`,
        Body: JSON.stringify(metadata, null, 2), ContentType: 'application/json'
      }).promise();
    } catch (_) {}

    // ── Return summary (no pairs to keep response small) ────────────────────
    return {
      statusCode: 200,
      headers:    corsHeaders,
      body:       JSON.stringify({
        success:          true,
        campaignId,
        imageSource,
        totalJobs:        jobs.length,
        phoneCount:       phones.length,
        imageCount:       allImageKeys.length,
        imagesPerJob,
        phonesPerJob,
        totalSubmissions: masterJob.totalSubmissions,
        instancesNeeded:  jobs.length,   // 1 instance per job
        jobs: jobs.map(j => ({
          jobId:       j.jobId,
          phoneCount:  j.phoneCount,
          imageCount:  j.imageCount,
          submissions: j.submissions
        }))
      })
    };

  } catch (err) {
    console.error('create-jobs error:', err);
    return {
      statusCode: 500,
      headers:    corsHeaders,
      body:       JSON.stringify({ success: false, error: err.message })
    };
  }
};
