// Lambda: create-jobs
// Receives: { campaignId, imagesPerJob (default 10) }
// Does:     reads phones.txt + lists images from S3, generates job combos,
//           saves job-NNN.json + masterjob.json to S3, returns job list
// Rule:     1 phone × 10 images = 1 job

const AWS = require('aws-sdk');
const s3  = new AWS.S3();

const S3_BUCKET     = 'greendotball-bot-data';
const corsHeaders   = {
  'Content-Type': 'application/json',
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST,OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'
};

async function listAllImages(campaignId) {
  const prefix = `campaigns/${campaignId}/images/`;
  const images = [];
  let token;
  do {
    const params = { Bucket: S3_BUCKET, Prefix: prefix, ContinuationToken: token };
    const res    = await s3.listObjectsV2(params).promise();
    for (const obj of res.Contents || []) {
      const key  = obj.Key;
      const name = key.split('/').pop();
      if (!name) continue;
      const ext  = name.split('.').pop().toLowerCase();
      if (['jpg','jpeg','png','gif','webp'].includes(ext)) {
        images.push(key);
      }
    }
    token = res.IsTruncated ? res.NextContinuationToken : null;
  } while (token);
  return images;
}

exports.handler = async (event) => {
  if (event.httpMethod === 'OPTIONS') {
    return { statusCode: 200, headers: corsHeaders, body: '' };
  }

  try {
    const body         = typeof event.body === 'string' ? JSON.parse(event.body) : event.body;
    const campaignId   = body.campaignId;
    const imagesPerJob = parseInt(body.imagesPerJob || '10', 10);

    if (!campaignId) throw new Error('Missing campaignId');

    // Load phones
    const phonesObj = await s3.getObject({
      Bucket: S3_BUCKET,
      Key:    `campaigns/${campaignId}/phones.txt`
    }).promise();

    const phones = phonesObj.Body.toString()
      .split('\n').map(p => p.trim()).filter(p => /^\d{10}$/.test(p));

    if (phones.length === 0) throw new Error('No valid phone numbers found in phones.txt');

    // List all images for this campaign
    const imageKeys = await listAllImages(campaignId);
    if (imageKeys.length === 0) throw new Error('No images found in S3 for this campaign');

    // Generate jobs: 1 phone × imagesPerJob images = 1 job
    // Each phone gets ceil(imageCount / imagesPerJob) jobs
    const jobs = [];
    let   jobNum = 1;

    for (const phone of phones) {
      // Chunk images into groups of imagesPerJob
      for (let i = 0; i < imageKeys.length; i += imagesPerJob) {
        const chunk  = imageKeys.slice(i, i + imagesPerJob);
        const jobId  = `job-${String(jobNum).padStart(3, '0')}`;
        const pairs  = chunk.map((imgKey, idx) => ({
          id:          `${jobId}-pair-${idx + 1}`,
          phoneNumber: phone,
          imagePath:   imgKey    // S3 key, bot will download from S3
        }));

        jobs.push({
          jobId,
          phone,
          imageRange:  `${i + 1}–${Math.min(i + imagesPerJob, imageKeys.length)}`,
          imageCount:  chunk.length,
          submissions: chunk.length,
          pairs
        });

        jobNum++;
      }
    }

    // Save each job file to S3
    for (const job of jobs) {
      await s3.putObject({
        Bucket:      S3_BUCKET,
        Key:         `campaigns/${campaignId}/jobs/${job.jobId}.json`,
        Body:        JSON.stringify({
          jobId:      job.jobId,
          campaignId,
          phone:      job.phone,
          imageCount: job.imageCount,
          createdAt:  new Date().toISOString(),
          pairs:      job.pairs
        }, null, 2),
        ContentType: 'application/json'
      }).promise();
    }

    // Save masterjob.json
    const masterJob = {
      campaignId,
      createdAt:   new Date().toISOString(),
      totalJobs:   jobs.length,
      phoneCount:  phones.length,
      imageCount:  imageKeys.length,
      imagesPerJob,
      jobs: jobs.map(j => ({
        jobId:       j.jobId,
        phone:       j.phone,
        imageRange:  j.imageRange,
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

    // Update campaign metadata status
    try {
      const metaObj  = await s3.getObject({ Bucket: S3_BUCKET, Key: `campaigns/${campaignId}/metadata.json` }).promise();
      const metadata = JSON.parse(metaObj.Body.toString());
      metadata.status   = 'jobs_created';
      metadata.jobCount = jobs.length;
      await s3.putObject({
        Bucket: S3_BUCKET, Key: `campaigns/${campaignId}/metadata.json`,
        Body: JSON.stringify(metadata, null, 2), ContentType: 'application/json'
      }).promise();
    } catch (_) {}

    // Return job list (without pairs, to keep response small)
    const jobSummary = jobs.map(j => ({
      jobId:       j.jobId,
      phone:       j.phone,
      imageRange:  j.imageRange,
      imageCount:  j.imageCount,
      submissions: j.submissions
    }));

    return {
      statusCode: 200,
      headers:    corsHeaders,
      body:       JSON.stringify({
        success:          true,
        campaignId,
        totalJobs:        jobs.length,
        phoneCount:       phones.length,
        imageCount:       imageKeys.length,
        imagesPerJob,
        instancesNeeded:  Math.ceil(jobs.length / 12),
        jobs:             jobSummary
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
