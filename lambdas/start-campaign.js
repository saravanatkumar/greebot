// Lambda: start-campaign
// Receives: { campaignId, jobs: [jobId,...], jobsPerBatch (default 12), region, instanceType }
// Does:     groups jobs into batches, launches 1 EC2 per batch with USER_DATA
// USER_DATA per instance: CAMPAIGN_ID=xxx\nJOB_IDS=job-001,job-002,...,job-012

const AWS = require('aws-sdk');
const s3  = new AWS.S3();

const S3_BUCKET       = 'greendotball-bot-data';
const AMI_ID          = 'ami-0453f8f8df25935ce'; // greendotball-bot-v2 (2026-04-04)
const KEY_NAME        = 'greendotball-bot-key-v2';
const SECURITY_GROUP  = 'greendotball-bot-sg';
const IAM_ROLE        = 'EC2-GreenDotBall-S3-Access';
const DEFAULT_REGION  = 'ap-south-1';
const JOBS_PER_BATCH  = 1;   // 1 job per instance (1 job = 10 phones × 10 images = 100 submissions)

const corsHeaders = {
  'Content-Type': 'application/json',
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST,OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'
};

function chunkArray(arr, size) {
  const chunks = [];
  for (let i = 0; i < arr.length; i += size) {
    chunks.push(arr.slice(i, i + size));
  }
  return chunks;
}

exports.handler = async (event) => {
  if (event.httpMethod === 'OPTIONS') {
    return { statusCode: 200, headers: corsHeaders, body: '' };
  }

  try {
    const body         = typeof event.body === 'string' ? JSON.parse(event.body) : event.body;
    const campaignId   = body.campaignId;
    const jobIds       = body.jobs;               // array of jobId strings
    const jobsPerBatch = parseInt(body.jobsPerBatch || JOBS_PER_BATCH, 10);
    const region       = body.region       || DEFAULT_REGION;
    const instanceType = body.instanceType || 't3.small';

    if (!campaignId)           throw new Error('Missing campaignId');
    if (!jobIds || !jobIds.length) throw new Error('Missing jobs array');

    const ec2 = new AWS.EC2({ region });

    // Get security group ID
    const sgRes = await ec2.describeSecurityGroups({
      Filters: [{ Name: 'group-name', Values: [SECURITY_GROUP] }]
    }).promise();

    const sgId = sgRes.SecurityGroups?.[0]?.GroupId;
    if (!sgId) throw new Error(`Security group '${SECURITY_GROUP}' not found in region ${region}`);

    // Split jobs into batches of jobsPerBatch
    const batches = chunkArray(jobIds, jobsPerBatch);
    const launchedInstances = [];
    const failedBatches     = [];
    const batchTimestamp    = new Date().toISOString().replace(/[:.]/g, '-').slice(0, 19);

    for (let i = 0; i < batches.length; i++) {
      const batch      = batches[i];
      const batchNum   = i + 1;
      const jobIdsCsv  = batch.join(',');

      // USER_DATA script: EC2 reads these vars on startup
      const userData = [
        '#!/bin/bash',
        `CAMPAIGN_ID=${campaignId}`,
        `JOB_IDS=${jobIdsCsv}`,
        `BATCH_NUM=${batchNum}`,
        `TOTAL_BATCHES=${batches.length}`
      ].join('\n');

      // Instance name: {campaignId}-{firstJobId}-inst-{batchNum}
      const firstJobId    = batch[0];
      const instanceName  = `${campaignId}-${firstJobId}-inst-${batchNum}`;

      try {
        const result = await ec2.runInstances({
          ImageId:          AMI_ID,
          InstanceType:     instanceType,
          KeyName:          KEY_NAME,
          SecurityGroupIds: [sgId],
          IamInstanceProfile: { Name: IAM_ROLE },
          UserData:         Buffer.from(userData).toString('base64'),
          MinCount:         1,
          MaxCount:         1,
          TagSpecifications: [{
            ResourceType: 'instance',
            Tags: [
              { Key: 'Name',        Value: instanceName },
              { Key: 'CampaignId',  Value: campaignId },
              { Key: 'BatchNum',    Value: String(batchNum) },
              { Key: 'FirstJobId',  Value: firstJobId },
              { Key: 'JobIds',      Value: jobIdsCsv.slice(0, 255) }, // tag limit 255 chars
              { Key: 'Project',     Value: 'greendotball' },
              { Key: 'LaunchedAt',  Value: batchTimestamp }
            ]
          }]
        }).promise();

        const instanceId = result.Instances[0].InstanceId;
        launchedInstances.push({
          instanceId,
          instanceName,
          batchNum,
          firstJobId,
          jobBatch: `${batch[0]}–${batch[batch.length - 1]}`,
          jobCount: batch.length,
          status:   'pending'
        });

        // Small delay to avoid EC2 API throttling
        if (i < batches.length - 1) await new Promise(r => setTimeout(r, 800));

      } catch (err) {
        console.error(`Failed to launch batch ${batchNum}:`, err.message);
        failedBatches.push({ batchNum, jobIds: batch, error: err.message });
      }
    }

    // Update campaign metadata
    try {
      const metaObj  = await s3.getObject({ Bucket: S3_BUCKET, Key: `campaigns/${campaignId}/metadata.json` }).promise();
      const metadata = JSON.parse(metaObj.Body.toString());
      metadata.status            = 'running';
      metadata.launchedAt        = new Date().toISOString();
      metadata.instancesLaunched = launchedInstances.length;
      metadata.instanceIds       = launchedInstances.map(i => i.instanceId);
      await s3.putObject({
        Bucket: S3_BUCKET, Key: `campaigns/${campaignId}/metadata.json`,
        Body: JSON.stringify(metadata, null, 2), ContentType: 'application/json'
      }).promise();
    } catch (_) {}

    // Save launch manifest to S3 for reference
    await s3.putObject({
      Bucket:      S3_BUCKET,
      Key:         `campaigns/${campaignId}/launch-manifest.json`,
      Body:        JSON.stringify({
        campaignId,
        launchedAt:   new Date().toISOString(),
        region,
        instanceType,
        totalBatches: batches.length,
        jobsPerBatch,
        launched:     launchedInstances,
        failed:       failedBatches
      }, null, 2),
      ContentType: 'application/json'
    }).promise();

    return {
      statusCode: 200,
      headers:    corsHeaders,
      body:       JSON.stringify({
        success:            true,
        campaignId,
        totalBatches:       batches.length,
        instancesLaunched:  launchedInstances.length,
        instancesFailed:    failedBatches.length,
        instances:          launchedInstances,
        failedBatches
      })
    };

  } catch (err) {
    console.error('start-campaign error:', err);
    return {
      statusCode: 500,
      headers:    corsHeaders,
      body:       JSON.stringify({ success: false, error: err.message })
    };
  }
};
