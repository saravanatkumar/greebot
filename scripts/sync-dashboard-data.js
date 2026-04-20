#!/usr/bin/env node
/**
 * sync-dashboard-data.js
 * Downloads campaign results from S3 into dashboards/data/ (incremental)
 * then re-aggregates everything into dashboards/data/dashboard-data.json
 *
 * Usage: node scripts/sync-dashboard-data.js
 *        node scripts/sync-dashboard-data.js --force   (re-download all)
 */

const AWS = require('aws-sdk');
const fs = require('fs');
const path = require('path');

const S3_BUCKET = 'greendotball-bot-data';
const REGION = 'ap-south-1';
const CAMPAIGNS_PREFIX = 'campaigns/';
const DASHBOARDS_DIR = path.join(__dirname, '..', 'dashboards', 'data');
const CAMPAIGNS_LOCAL = path.join(DASHBOARDS_DIR, 'campaigns');
const OUTPUT_FILE = path.join(DASHBOARDS_DIR, 'dashboard-data.json');

const FORCE = process.argv.includes('--force');

const s3 = new AWS.S3({ region: REGION });

// ── Helpers ──────────────────────────────────────────────────────────────────

function ensureDir(dir) {
  if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
}

async function s3ListAll(prefix) {
  const keys = [];
  let continuationToken;
  do {
    const params = {
      Bucket: S3_BUCKET,
      Prefix: prefix,
      ContinuationToken: continuationToken,
    };
    const resp = await s3.listObjectsV2(params).promise();
    for (const obj of resp.Contents || []) keys.push(obj.Key);
    continuationToken = resp.IsTruncated ? resp.NextContinuationToken : null;
  } while (continuationToken);
  return keys;
}

async function s3Get(key) {
  const resp = await s3.getObject({ Bucket: S3_BUCKET, Key: key }).promise();
  return resp.Body.toString('utf-8');
}

async function downloadFile(key, localPath) {
  ensureDir(path.dirname(localPath));
  const content = await s3Get(key);
  fs.writeFileSync(localPath, content, 'utf-8');
}

// ── List all campaigns ────────────────────────────────────────────────────────

async function listCampaigns() {
  const resp = await s3.listObjectsV2({
    Bucket: S3_BUCKET,
    Prefix: CAMPAIGNS_PREFIX,
    Delimiter: '/',
  }).promise();
  return (resp.CommonPrefixes || []).map(p =>
    p.Prefix.replace(CAMPAIGNS_PREFIX, '').replace(/\/$/, '')
  );
}

// ── Download one campaign ─────────────────────────────────────────────────────

async function downloadCampaign(campaignId) {
  const base = `${CAMPAIGNS_PREFIX}${campaignId}/`;
  const localBase = path.join(CAMPAIGNS_LOCAL, campaignId);

  // metadata.json
  try {
    await downloadFile(`${base}metadata.json`, path.join(localBase, 'metadata.json'));
  } catch (_) { /* some old campaigns may lack it */ }

  // results/*.json
  const allKeys = await s3ListAll(`${base}results/`);
  const resultKeys = allKeys.filter(k => k.endsWith('.json'));
  for (const key of resultKeys) {
    const filename = path.basename(key);
    const localPath = path.join(localBase, 'results', filename);
    await downloadFile(key, localPath);
  }

  return resultKeys.length;
}

// ── Parse date from campaign ID ───────────────────────────────────────────────
// IDs look like: apr-08-2026-batch-5-camp-223629
function parseCampaignDate(id) {
  const m = id.match(/^([a-z]{3})-(\d{2})-(\d{4})/);
  if (!m) return null;
  const months = { jan:0,feb:1,mar:2,apr:3,may:4,jun:5,jul:6,aug:7,sep:8,oct:9,nov:10,dec:11 };
  const month = months[m[1]];
  if (month === undefined) return null;
  return new Date(parseInt(m[3]), month, parseInt(m[2]));
}

function formatDate(d) {
  if (!d) return 'unknown';
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  return `${y}-${m}-${day}`;
}

// ── Aggregate all local data ──────────────────────────────────────────────────

function aggregateAll(campaignIds) {
  const summary = { totalCampaigns: 0, totalSubmissions: 0, totalSucceeded: 0, totalFailed: 0 };
  const campaigns = [];
  const byDate = {};       // date → { succeeded, failed }
  const failureReasons = {};  // message → count
  const byPhone = {};      // phone → [{ campaignId, jobId, date, success, message, image, timestamp }]

  for (const campaignId of campaignIds) {
    const localBase = path.join(CAMPAIGNS_LOCAL, campaignId);
    const resultsDir = path.join(localBase, 'results');

    // Read metadata
    let metadata = {};
    const metaPath = path.join(localBase, 'metadata.json');
    if (fs.existsSync(metaPath)) {
      try { metadata = JSON.parse(fs.readFileSync(metaPath, 'utf-8')); } catch (_) {}
    }

    const date = formatDate(parseCampaignDate(campaignId));
    const campaign = {
      id: campaignId,
      date,
      name: metadata.campaignName || campaignId,
      totalJobs: metadata.totalJobs || 0,
      phoneCount: metadata.phoneCount || 0,
      total: 0,
      succeeded: 0,
      failed: 0,
      jobs: [],
      failureReasons: {},
    };

    if (!fs.existsSync(resultsDir)) {
      campaigns.push(campaign);
      continue;
    }

    const resultFiles = fs.readdirSync(resultsDir).filter(f => f.endsWith('.json'));
    for (const file of resultFiles) {
      let jobResult;
      try {
        jobResult = JSON.parse(fs.readFileSync(path.join(resultsDir, file), 'utf-8'));
      } catch (_) { continue; }

      const jobEntry = {
        jobId: jobResult.jobId || file,
        total: jobResult.total || 0,
        succeeded: jobResult.succeeded || 0,
        failed: jobResult.failed || 0,
        completedAt: jobResult.completedAt || null,
      };
      campaign.jobs.push(jobEntry);
      campaign.total += jobEntry.total;
      campaign.succeeded += jobEntry.succeeded;
      campaign.failed += jobEntry.failed;

      // Process individual results
      for (const r of (jobResult.results || [])) {
        const phone = r.phone || 'unknown';
        const ts = r.timestamp || jobResult.completedAt || null;
        const entryDate = ts ? ts.split('T')[0] : date;

        // by-phone index
        if (!byPhone[phone]) byPhone[phone] = [];
        byPhone[phone].push({
          campaignId,
          campaignDate: date,
          jobId: jobResult.jobId || '',
          pairId: r.pairId || '',
          success: r.success,
          message: r.message || '',
          image: r.image || '',
          timestamp: ts,
        });

        // by-date stats
        if (!byDate[entryDate]) byDate[entryDate] = { succeeded: 0, failed: 0 };
        if (r.success) byDate[entryDate].succeeded++;
        else byDate[entryDate].failed++;

        // failure reasons
        if (!r.success && r.message) {
          const reason = r.message.trim();
          failureReasons[reason] = (failureReasons[reason] || 0) + 1;
          campaign.failureReasons[reason] = (campaign.failureReasons[reason] || 0) + 1;
        }
      }
    }

    // Sort jobs by jobId
    campaign.jobs.sort((a, b) => a.jobId.localeCompare(b.jobId));

    campaigns.push(campaign);
    summary.totalSubmissions += campaign.total;
    summary.totalSucceeded += campaign.succeeded;
    summary.totalFailed += campaign.failed;
  }

  summary.totalCampaigns = campaigns.length;

  // Sort campaigns by date desc
  campaigns.sort((a, b) => (b.date > a.date ? 1 : b.date < a.date ? -1 : 0));

  // Sort byDate keys
  const dateStats = Object.entries(byDate)
    .sort(([a], [b]) => a.localeCompare(b))
    .map(([date, stats]) => ({ date, ...stats }));

  // Sort failure reasons by count desc
  const sortedFailureReasons = Object.entries(failureReasons)
    .sort(([, a], [, b]) => b - a)
    .map(([reason, count]) => ({ reason, count }));

  return {
    generatedAt: new Date().toISOString(),
    summary,
    campaigns,
    dateStats,
    failureReasons: sortedFailureReasons,
    byPhone,
  };
}

// ── Main ──────────────────────────────────────────────────────────────────────

async function main() {
  ensureDir(CAMPAIGNS_LOCAL);

  console.log('');
  console.log('================================================');
  console.log('  GreenDotBall Dashboard Data Sync');
  console.log('================================================');
  console.log('');

  // List all campaigns from S3
  console.log('Fetching campaign list from S3...');
  const allCampaigns = await listCampaigns();
  console.log(`Found ${allCampaigns.length} campaigns on S3`);
  console.log('');

  // Determine which to download
  const toDownload = FORCE
    ? allCampaigns
    : allCampaigns.filter(id => {
        const localBase = path.join(CAMPAIGNS_LOCAL, id);
        const resultsDir = path.join(localBase, 'results');
        return !fs.existsSync(resultsDir) ||
               fs.readdirSync(resultsDir).filter(f => f.endsWith('.json')).length === 0;
      });

  if (toDownload.length === 0) {
    console.log('✅ All campaigns already downloaded locally. Nothing new to fetch.');
    console.log('   (Use --force to re-download everything)');
  } else {
    console.log(`Downloading ${toDownload.length} new campaign(s)...`);
    console.log('');
    for (let i = 0; i < toDownload.length; i++) {
      const id = toDownload[i];
      process.stdout.write(`  [${String(i + 1).padStart(3)}/${toDownload.length}] ${id} ... `);
      try {
        const count = await downloadCampaign(id);
        console.log(`✅ ${count} result file(s)`);
      } catch (err) {
        console.log(`❌ ERROR: ${err.message}`);
      }
    }
  }

  console.log('');
  console.log('Aggregating all local data...');
  const data = aggregateAll(allCampaigns);

  fs.writeFileSync(OUTPUT_FILE, JSON.stringify(data), 'utf-8');

  const phoneCount = Object.keys(data.byPhone).length;
  console.log('');
  console.log('================================================');
  console.log('  ✅ SYNC COMPLETE');
  console.log('================================================');
  console.log(`  Campaigns    : ${data.summary.totalCampaigns}`);
  console.log(`  Submissions  : ${data.summary.totalSubmissions.toLocaleString()}`);
  console.log(`  Succeeded    : ${data.summary.totalSucceeded.toLocaleString()}`);
  console.log(`  Failed       : ${data.summary.totalFailed.toLocaleString()}`);
  console.log(`  Unique phones: ${phoneCount.toLocaleString()}`);
  console.log(`  Output       : dashboards/data/dashboard-data.json`);
  console.log('');
  console.log('  To view dashboard:');
  console.log('    npx serve dashboards');
  console.log('');
}

main().catch(err => {
  console.error('Fatal error:', err);
  process.exit(1);
});
