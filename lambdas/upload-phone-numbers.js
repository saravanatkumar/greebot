// Lambda function to upload phone numbers to S3 bucket
const AWS = require('aws-sdk');
const s3 = new AWS.S3();

exports.handler = async (event) => {
    console.log('Event received:', JSON.stringify(event));
    
    try {
        // Parse request body
        const body = JSON.parse(event.body);
        const { campaignName, phoneNumbers } = body;
        
        if (!campaignName || !phoneNumbers || !Array.isArray(phoneNumbers)) {
            return {
                statusCode: 400,
                headers: corsHeaders,
                body: JSON.stringify({
                    success: false,
                    error: 'Invalid request. Required fields: campaignName, phoneNumbers (array)'
                })
            };
        }
        
        // Generate campaign ID
        const timestamp = Date.now();
        const campaignId = `${campaignName.toLowerCase().replace(/\s+/g, '-')}-${timestamp}`;
        
        // Validate phone numbers (basic 10-digit check)
        const validPhones = [];
        const invalidPhones = [];
        const phoneRegex = /^\d{10}$/;
        
        phoneNumbers.forEach(phone => {
            const cleanPhone = phone.trim();
            if (phoneRegex.test(cleanPhone)) {
                validPhones.push(cleanPhone);
            } else if (cleanPhone.length > 0) {
                invalidPhones.push(cleanPhone);
            }
        });
        
        // Check if we have valid phone numbers
        if (validPhones.length === 0) {
            return {
                statusCode: 400,
                headers: corsHeaders,
                body: JSON.stringify({
                    success: false,
                    error: 'No valid phone numbers found',
                    invalidPhones
                })
            };
        }
        
        // Upload to S3
        const phoneContent = validPhones.join('\n');
        const s3Params = {
            Bucket: 'greendotball-bot-data',
            Key: `campaigns/${campaignId}/phone-numbers.txt`,
            Body: phoneContent,
            ContentType: 'text/plain'
        };
        
        await s3.putObject(s3Params).promise();
        
        // Also update a campaign metadata file
        const metadataParams = {
            Bucket: 'greendotball-bot-data',
            Key: `campaigns/${campaignId}/metadata.json`,
            Body: JSON.stringify({
                id: campaignId,
                name: campaignName,
                createdAt: new Date().toISOString(),
                phoneCount: validPhones.length
            }),
            ContentType: 'application/json'
        };
        
        await s3.putObject(metadataParams).promise();
        
        // Also update the campaigns index file
        try {
            // Try to get existing campaigns index
            const indexParams = {
                Bucket: 'greendotball-bot-data',
                Key: 'campaigns/index.json'
            };
            
            let campaignsIndex = { campaigns: [] };
            
            try {
                const indexData = await s3.getObject(indexParams).promise();
                campaignsIndex = JSON.parse(indexData.Body.toString());
            } catch (err) {
                // Index doesn't exist yet, that's fine
                console.log('Creating new campaigns index');
            }
            
            // Add the new campaign
            campaignsIndex.campaigns.push({
                id: campaignId,
                name: campaignName,
                createdAt: new Date().toISOString(),
                phoneCount: validPhones.length
            });
            
            // Sort by creation date (newest first)
            campaignsIndex.campaigns.sort((a, b) => 
                new Date(b.createdAt) - new Date(a.createdAt));
            
            // Upload updated index
            const updateIndexParams = {
                Bucket: 'greendotball-bot-data',
                Key: 'campaigns/index.json',
                Body: JSON.stringify(campaignsIndex),
                ContentType: 'application/json'
            };
            
            await s3.putObject(updateIndexParams).promise();
        } catch (indexError) {
            console.error('Error updating campaigns index:', indexError);
            // Continue anyway, this is not critical
        }
        
        // Prepare response
        const corsHeaders = {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*', // For CORS support
            'Access-Control-Allow-Methods': 'GET,POST,PUT,OPTIONS',
            'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'
        };
        
        return {
            statusCode: 200,
            headers: corsHeaders,
            body: JSON.stringify({
                success: true,
                campaignId,
                campaignName,
                phoneCount: validPhones.length,
                invalidCount: invalidPhones.length
            })
        };
        
    } catch (error) {
        console.error('Error uploading phone numbers:', error);
        
        const corsHeaders = {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'GET,POST,PUT,OPTIONS',
            'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'
        };
        
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
