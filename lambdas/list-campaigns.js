// Lambda function to list campaigns and their details
const AWS = require('aws-sdk');
const s3 = new AWS.S3();

// CORS headers for all responses
const corsHeaders = {
    'Content-Type': 'application/json',
    'Access-Control-Allow-Origin': '*', // For CORS support
    'Access-Control-Allow-Methods': 'GET,POST,OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'
};

exports.handler = async (event) => {
    console.log('Event received:', JSON.stringify(event));
    
    try {
        // Check if we're requesting a specific campaign's details
        let campaignId = null;
        
        if (event.queryStringParameters && event.queryStringParameters.campaignId) {
            campaignId = event.queryStringParameters.campaignId;
            return await getCampaignDetails(campaignId);
        } else {
            return await listCampaigns();
        }
    } catch (error) {
        console.error('Error in campaign operation:', error);
        
        return {
            statusCode: 500,
            headers: corsHeaders,
            body: JSON.stringify({
                success: false,
                error: error.message
            })
        };
    }
};

// Function to list all campaigns
async function listCampaigns() {
    try {
        // Try to get campaigns index file
        const indexParams = {
            Bucket: 'greendotball-bot-data',
            Key: 'campaigns/index.json'
        };
        
        let campaignsIndex = { campaigns: [] };
        
        try {
            const indexData = await s3.getObject(indexParams).promise();
            campaignsIndex = JSON.parse(indexData.Body.toString());
        } catch (err) {
            // No campaigns index yet, create it from folder structure
            console.log('No campaigns index found, checking folders');
            
            const listParams = {
                Bucket: 'greendotball-bot-data',
                Prefix: 'campaigns/',
                Delimiter: '/'
            };
            
            const folderData = await s3.listObjectsV2(listParams).promise();
            
            if (folderData.CommonPrefixes && folderData.CommonPrefixes.length > 0) {
                // Process folders to extract campaign IDs
                for (const prefix of folderData.CommonPrefixes) {
                    const campaignFolder = prefix.Prefix;
                    // Extract campaign ID from the folder path (campaigns/campaign-id/)
                    const campaignId = campaignFolder.replace('campaigns/', '').replace('/', '');
                    
                    if (campaignId) {
                        try {
                            // Try to get metadata if it exists
                            const metadataParams = {
                                Bucket: 'greendotball-bot-data',
                                Key: `campaigns/${campaignId}/metadata.json`
                            };
                            
                            let campaignDetails = {
                                id: campaignId,
                                name: campaignId,
                                createdAt: new Date().toISOString()
                            };
                            
                            try {
                                const metadataData = await s3.getObject(metadataParams).promise();
                                campaignDetails = JSON.parse(metadataData.Body.toString());
                            } catch (metaErr) {
                                // No metadata, just use basic info
                                console.log(`No metadata for campaign: ${campaignId}`);
                            }
                            
                            campaignsIndex.campaigns.push(campaignDetails);
                        } catch (err) {
                            console.error(`Error processing campaign folder: ${campaignId}`, err);
                        }
                    }
                }
            }
            
            // Also check for mobile-numbers.txt in the config folder
            try {
                const configParams = {
                    Bucket: 'greendotball-bot-data',
                    Key: 'config/mobile-numbers.txt'
                };
                
                const configData = await s3.getObject(configParams).promise();
                const phoneContent = configData.Body.toString();
                const phoneCount = phoneContent.split('\n').filter(line => line.trim().length > 0).length;
                
                // Add as a default campaign
                campaignsIndex.campaigns.push({
                    id: 'default',
                    name: 'Default Campaign',
                    phoneCount: phoneCount,
                    createdAt: new Date().toISOString()
                });
            } catch (err) {
                console.log('No default mobile-numbers.txt found');
            }
        }
        
        return {
            statusCode: 200,
            headers: corsHeaders,
            body: JSON.stringify({
                success: true,
                campaigns: campaignsIndex.campaigns
            })
        };
        
    } catch (error) {
        console.error('Error listing campaigns:', error);
        throw error;
    }
}

// Function to get details for a specific campaign
async function getCampaignDetails(campaignId) {
    try {
        let campaignDetails = {};
        let phoneNumbers = [];
        let imageFiles = [];
        
        // Special handling for 'default' campaign
        if (campaignId === 'default') {
            // Get phone numbers from config/mobile-numbers.txt
            try {
                const phoneParams = {
                    Bucket: 'greendotball-bot-data',
                    Key: 'config/mobile-numbers.txt'
                };
                
                const phoneData = await s3.getObject(phoneParams).promise();
                phoneNumbers = phoneData.Body.toString().split('\n')
                    .map(num => num.trim())
                    .filter(num => num.length > 0);
                
                campaignDetails = {
                    id: 'default',
                    name: 'Default Campaign',
                    phoneCount: phoneNumbers.length,
                    createdAt: new Date().toISOString()
                };
            } catch (err) {
                console.error('Error getting default phone numbers:', err);
                throw new Error('Default phone numbers file not found');
            }
            
            // Try to get images from images folder
            try {
                const listParams = {
                    Bucket: 'greendotball-bot-data',
                    Prefix: 'images/',
                    MaxKeys: 1000
                };
                
                const imageData = await s3.listObjectsV2(listParams).promise();
                
                if (imageData.Contents && imageData.Contents.length > 0) {
                    imageFiles = imageData.Contents
                        .filter(item => !item.Key.endsWith('/')) // Filter out folders
                        .map(item => {
                            const name = item.Key.split('/').pop();
                            return {
                                key: item.Key,
                                name: name,
                                size: item.Size,
                                lastModified: item.LastModified
                            };
                        });
                }
                
                campaignDetails.imageCount = imageFiles.length;
            } catch (err) {
                console.error('Error listing default images:', err);
            }
            
        } else {
            // Regular campaign
            
            // Try to get campaign metadata
            try {
                const metadataParams = {
                    Bucket: 'greendotball-bot-data',
                    Key: `campaigns/${campaignId}/metadata.json`
                };
                
                const metadataData = await s3.getObject(metadataParams).promise();
                campaignDetails = JSON.parse(metadataData.Body.toString());
            } catch (err) {
                console.log(`No metadata for campaign: ${campaignId}`);
                campaignDetails = {
                    id: campaignId,
                    name: campaignId,
                    createdAt: new Date().toISOString()
                };
            }
            
            // Get phone numbers
            try {
                const phoneParams = {
                    Bucket: 'greendotball-bot-data',
                    Key: `campaigns/${campaignId}/phone-numbers.txt`
                };
                
                const phoneData = await s3.getObject(phoneParams).promise();
                phoneNumbers = phoneData.Body.toString().split('\n')
                    .map(num => num.trim())
                    .filter(num => num.length > 0);
                
                campaignDetails.phoneCount = phoneNumbers.length;
            } catch (err) {
                console.log(`No phone numbers for campaign: ${campaignId}`);
                campaignDetails.phoneCount = 0;
            }
            
            // List campaign images
            try {
                const listParams = {
                    Bucket: 'greendotball-bot-data',
                    Prefix: `campaigns/${campaignId}/images/`,
                    MaxKeys: 1000
                };
                
                const imageData = await s3.listObjectsV2(listParams).promise();
                
                if (imageData.Contents && imageData.Contents.length > 0) {
                    imageFiles = imageData.Contents
                        .filter(item => !item.Key.endsWith('/')) // Filter out folders
                        .map(item => {
                            const name = item.Key.split('/').pop();
                            return {
                                key: item.Key,
                                name: name,
                                size: item.Size,
                                lastModified: item.LastModified
                            };
                        });
                }
                
                campaignDetails.imageCount = imageFiles.length;
            } catch (err) {
                console.log(`Error listing images for campaign: ${campaignId}`, err);
                campaignDetails.imageCount = 0;
            }
        }
        
        return {
            statusCode: 200,
            headers: corsHeaders,
            body: JSON.stringify({
                success: true,
                campaign: campaignDetails,
                phoneNumbers: phoneNumbers,
                images: imageFiles
            })
        };
        
    } catch (error) {
        console.error(`Error getting campaign details for ${campaignId}:`, error);
        throw error;
    }
}
