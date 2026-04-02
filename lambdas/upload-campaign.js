// Lambda: upload-campaign
// Receives: multipart/form-data with campaignName, phoneNumbers (text), imagesZip (file)
// Does:     unzips images → S3, saves phones.txt → S3, returns campaignId + counts
// Requires: Lambda layer with 'adm-zip' OR use /tmp for unzip

const AWS = require('aws-sdk');
const s3 = new AWS.S3();
const AdmZip = require('adm-zip');

const S3_BUCKET      = 'greendotball-bot-data';
const ALLOWED_EXTS   = ['.jpg', '.jpeg', '.png', '.gif', '.webp'];

const corsHeaders = {
  'Content-Type': 'application/json',
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST,OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'
};

function generateCampaignId(name) {
  const now  = new Date();
  const mon  = now.toLocaleString('en-us', { month: 'short' }).toLowerCase();
  const day  = String(now.getDate()).padStart(2, '0');
  const yr   = now.getFullYear();
  const slug = name.trim().toLowerCase().replace(/\s+/g, '-').replace(/[^a-z0-9-]/g, '').slice(0, 12);
  const hh   = String(now.getHours()).padStart(2, '0');
  const mm   = String(now.getMinutes()).padStart(2, '0');
  const ss   = String(now.getSeconds()).padStart(2, '0');
  return `${mon}-${day}-${yr}-${slug}-${hh}${mm}${ss}`;
}

function parseMultipart(event) {
  // API Gateway passes body as base64 when binary
  const contentType = event.headers['content-type'] || event.headers['Content-Type'] || '';
  const boundary    = contentType.split('boundary=')[1];
  if (!boundary) throw new Error('Missing multipart boundary');

  const body   = Buffer.from(event.body, event.isBase64Encoded ? 'base64' : 'utf8');
  const parts  = {};
  const sep    = Buffer.from(`--${boundary}`);
  let   offset = 0;

  while (offset < body.length) {
    const sepIdx = body.indexOf(sep, offset);
    if (sepIdx === -1) break;
    offset = sepIdx + sep.length + 2; // skip \r\n

    const headersEnd = body.indexOf('\r\n\r\n', offset);
    if (headersEnd === -1) break;

    const rawHeaders = body.slice(offset, headersEnd).toString();
    offset = headersEnd + 4;

    const nextSep = body.indexOf(sep, offset);
    const partEnd = nextSep === -1 ? body.length : nextSep - 2; // trim \r\n before sep

    const cdMatch   = rawHeaders.match(/name="([^"]+)"/);
    const fileMatch = rawHeaders.match(/filename="([^"]+)"/);
    if (!cdMatch) continue;

    const name    = cdMatch[1];
    const content = body.slice(offset, partEnd);
    parts[name]   = { content, filename: fileMatch ? fileMatch[1] : null };
    offset        = partEnd;
  }
  return parts;
}

exports.handler = async (event) => {
  if (event.httpMethod === 'OPTIONS') {
    return { statusCode: 200, headers: corsHeaders, body: '' };
  }

  try {
    const parts       = parseMultipart(event);
    const campaignName = parts.campaignName?.content.toString().trim();
    const phoneText    = parts.phoneNumbers?.content.toString().trim();
    const zipContent   = parts.imagesZip?.content;

    if (!campaignName) throw new Error('Missing campaignName');
    if (!phoneText)    throw new Error('Missing phoneNumbers');
    if (!zipContent)   throw new Error('Missing imagesZip');

    // Validate + collect phone numbers
    const phones = phoneText.split('\n')
      .map(p => p.trim())
      .filter(p => p.length > 0);

    const validPhones   = phones.filter(p => /^\d{10}$/.test(p));
    const invalidPhones = phones.filter(p => !/^\d{10}$/.test(p));

    if (validPhones.length === 0) throw new Error('No valid 10-digit phone numbers found');

    // Generate campaign ID
    const campaignId  = generateCampaignId(campaignName);
    const imageFolder = `campaigns/${campaignId}/images/`;

    // Save phones.txt to S3
    await s3.putObject({
      Bucket:      S3_BUCKET,
      Key:         `campaigns/${campaignId}/phones.txt`,
      Body:        validPhones.join('\n'),
      ContentType: 'text/plain'
    }).promise();

    // Unzip images and upload each to S3
    const zip        = new AdmZip(zipContent);
    const zipEntries = zip.getEntries();
    const uploadedImages = [];

    for (const entry of zipEntries) {
      if (entry.isDirectory) continue;

      const fname = entry.name.toLowerCase();
      const ext   = '.' + fname.split('.').pop();
      if (!ALLOWED_EXTS.includes(ext)) continue;

      const imgBuffer = entry.getData();
      const s3Key     = `${imageFolder}${entry.name}`;

      await s3.putObject({
        Bucket:      S3_BUCKET,
        Key:         s3Key,
        Body:        imgBuffer,
        ContentType: `image/${ext.slice(1)}`
      }).promise();

      uploadedImages.push(entry.name);
    }

    if (uploadedImages.length === 0) throw new Error('No valid images found in zip (jpg/jpeg/png/gif/webp)');

    // Save campaign metadata
    const metadata = {
      campaignId,
      campaignName,
      createdAt:    new Date().toISOString(),
      phoneCount:   validPhones.length,
      imageCount:   uploadedImages.length,
      imageFolder,
      status:       'uploaded'
    };

    await s3.putObject({
      Bucket:      S3_BUCKET,
      Key:         `campaigns/${campaignId}/metadata.json`,
      Body:        JSON.stringify(metadata, null, 2),
      ContentType: 'application/json'
    }).promise();

    // Update campaigns index
    try {
      let index = { campaigns: [] };
      try {
        const existing = await s3.getObject({ Bucket: S3_BUCKET, Key: 'campaigns/index.json' }).promise();
        index = JSON.parse(existing.Body.toString());
      } catch (_) {}
      index.campaigns.unshift({ campaignId, campaignName, createdAt: metadata.createdAt, phoneCount: validPhones.length, imageCount: uploadedImages.length });
      await s3.putObject({
        Bucket: S3_BUCKET, Key: 'campaigns/index.json',
        Body: JSON.stringify(index, null, 2), ContentType: 'application/json'
      }).promise();
    } catch (_) {}

    return {
      statusCode: 200,
      headers: corsHeaders,
      body: JSON.stringify({
        success:        true,
        campaignId,
        campaignName,
        phoneCount:     validPhones.length,
        invalidCount:   invalidPhones.length,
        imageCount:     uploadedImages.length,
        imageFolder,
        images:         uploadedImages
      })
    };

  } catch (err) {
    console.error('upload-campaign error:', err);
    return {
      statusCode: 500,
      headers: corsHeaders,
      body: JSON.stringify({ success: false, error: err.message })
    };
  }
};
