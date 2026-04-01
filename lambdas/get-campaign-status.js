// Lambda: get-campaign-status
// Receives: { campaignId } via GET ?campaignId=xxx  OR POST body
// Returns:  campaign metadata, EC2 instance states, job result counts

const AWS = require('aws-sdk');
const s3   = new AWS.S3();

const S3_BUCKET      = 'greendotball-bot-data';
const DEFAULT_REGION = 'ap-south-1';

const corsHeaders = {
  'Content-Type': 'application/json',
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET,POST,OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'
};

exports.handler = async (event) => {
  if (event.httpMethod === 'OPTIONS') {
    return { statusCode: 200, headers: corsHeaders, body: '' };
  }

  try {
    // Support both GET querystring and POST body
    let campaignId;
    if (event.queryStringParameters && event.queryStringParameters.campaignId) {
      campaignId = event.queryStringParameters.campaignId;
    } else if (event.body) {
      const body = typeof event.body === 'string' ? JSON.parse(event.body) : event.body;
      campaignId = body.campaignId;
    }

    if (!campaignId) throw new Error('Missing campaignId');

    // ── 1. Load campaign metadata from S3 ──────────────────────────────────
    let metadata = {};
    try {
      const metaObj = await s3.getObject({
        Bucket: S3_BUCKET,
        Key:    `campaigns/${campaignId}/metadata.json`
      }).promise();
      metadata = JSON.parse(metaObj.Body.toString());
    } catch (e) {
      throw new Error(`Campaign not found: ${campaignId}`);
    }

    // ── 2. Load launch manifest (instance list) ────────────────────────────
    let manifest = null;
    try {
      const manifestObj = await s3.getObject({
        Bucket: S3_BUCKET,
        Key:    `campaigns/${campaignId}/launch-manifest.json`
      }).promise();
      manifest = JSON.parse(manifestObj.Body.toString());
    } catch (_) {}

    // ── 3. Query EC2 for live instance states ──────────────────────────────
    let instanceStatuses = [];
    if (manifest && manifest.launched && manifest.launched.length > 0) {
      const region = manifest.region || DEFAULT_REGION;
      const ec2    = new AWS.EC2({ region });

      const instanceIds = manifest.launched.map(i => i.instanceId).filter(Boolean);
      if (instanceIds.length > 0) {
        try {
          const descRes = await ec2.describeInstances({
            InstanceIds: instanceIds
          }).promise();

          for (const reservation of descRes.Reservations) {
            for (const inst of reservation.Instances) {
              const nameTag     = inst.Tags?.find(t => t.Key === 'Name')?.Value || '';
              const jobIdsTag   = inst.Tags?.find(t => t.Key === 'JobIds')?.Value || '';
              const firstJobTag = inst.Tags?.find(t => t.Key === 'FirstJobId')?.Value || '';
              const batchTag    = inst.Tags?.find(t => t.Key === 'BatchNum')?.Value || '';

              instanceStatuses.push({
                instanceId:   inst.InstanceId,
                instanceName: nameTag,
                state:        inst.State.Name,        // pending | running | shutting-down | terminated | stopped
                launchTime:   inst.LaunchTime,
                batchNum:     batchTag,
                firstJobId:   firstJobTag,
                jobIds:       jobIdsTag
              });
            }
          }
        } catch (ec2Err) {
          console.error('EC2 describe error:', ec2Err.message);
        }
      }
    }

    // ── 4. Count result files in S3 (completed jobs) ───────────────────────
    let completedJobs = 0;
    let totalJobs     = metadata.totalJobs || 0;
    try {
      const listRes = await s3.listObjectsV2({
        Bucket: S3_BUCKET,
        Prefix: `campaigns/${campaignId}/results/`
      }).promise();
      completedJobs = listRes.KeyCount || 0;
    } catch (_) {}

    // ── 5. Count log files ────────────────────────────────────────────────
    let logFiles = 0;
    try {
      const logsRes = await s3.listObjectsV2({
        Bucket: S3_BUCKET,
        Prefix: `campaigns/${campaignId}/logs/`
      }).promise();
      logFiles = logsRes.KeyCount || 0;
    } catch (_) {}

    // ── 6. Derive summary states ───────────────────────────────────────────
    const runningCount    = instanceStatuses.filter(i => i.state === 'running').length;
    const terminatedCount = instanceStatuses.filter(i => ['terminated', 'shutting-down', 'stopped'].includes(i.state)).length;
    const pendingCount    = instanceStatuses.filter(i => i.state === 'pending').length;

    const progressPct = totalJobs > 0 ? Math.round((completedJobs / totalJobs) * 100) : 0;

    return {
      statusCode: 200,
      headers:    corsHeaders,
      body:       JSON.stringify({
        success: true,
        campaignId,
        campaign: {
          name:              metadata.campaignName || campaignId,
          status:            metadata.status || 'unknown',
          createdAt:         metadata.createdAt,
          launchedAt:        metadata.launchedAt,
          phoneCount:        metadata.phoneCount,
          imageCount:        metadata.imageCount,
          totalJobs,
          instancesLaunched: metadata.instancesLaunched || instanceStatuses.length
        },
        progress: {
          completedJobs,
          totalJobs,
          progressPct,
          logFiles
        },
        instances: {
          total:      instanceStatuses.length,
          running:    runningCount,
          terminated: terminatedCount,
          pending:    pendingCount,
          details:    instanceStatuses
        }
      })
    };

  } catch (err) {
    console.error('get-campaign-status error:', err);
    return {
      statusCode: err.message.startsWith('Campaign not found') ? 404 : 500,
      headers:    corsHeaders,
      body:       JSON.stringify({ success: false, error: err.message })
    };
  }
};
