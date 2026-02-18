// Lambda function to process phone numbers from S3 bucket
const AWS = require('aws-sdk');
const s3 = new AWS.S3();

exports.handler = async (event) => {
    console.log('Event received:', JSON.stringify(event));
    
    try {
        // Get campaign ID from request
        let campaignId = '';
        let customFileName = '';
        
        if (event.queryStringParameters) {
            campaignId = event.queryStringParameters.campaignId || '';
            customFileName = event.queryStringParameters.fileName || '';
        } else if (event.body) {
            const body = JSON.parse(event.body);
            campaignId = body.campaignId || '';
            customFileName = body.fileName || '';
        }
        
        // Determine the file path
        let filePath = 'config/mobile-numbers.txt';
        if (campaignId) {
            filePath = `campaigns/${campaignId}/phone-numbers.txt`;
        } else if (customFileName) {
            filePath = customFileName;
        }
        
        // Get the file from S3
        const params = {
            Bucket: 'greendotball-bot-data',
            Key: filePath
        };
        
        console.log(`Retrieving file: ${filePath}`);
        const data = await s3.getObject(params).promise();
        
        // Process the phone numbers
        const phoneNumbers = data.Body.toString().split('\n')
            .map(num => num.trim())
            .filter(num => num.length > 0);
        
        // Validate phone numbers (basic 10-digit check)
        const validPhones = [];
        const invalidPhones = [];
        
        const phoneRegex = /^\d{10}$/;
        
        phoneNumbers.forEach(phone => {
            if (phoneRegex.test(phone)) {
                validPhones.push(phone);
            } else {
                invalidPhones.push(phone);
            }
        });
        
        // Prepare response
        const response = {
            statusCode: 200,
            headers: {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*', // For CORS support
                'Access-Control-Allow-Methods': 'GET,POST,OPTIONS',
                'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'
            },
            body: JSON.stringify({
                success: true,
                totalCount: phoneNumbers.length,
                validCount: validPhones.length,
                invalidCount: invalidPhones.length,
                validPhones: validPhones,
                invalidPhones: invalidPhones
            })
        };
        
        console.log(`Processed ${validPhones.length} valid and ${invalidPhones.length} invalid phone numbers`);
        return response;
        
    } catch (error) {
        console.error('Error processing phone numbers:', error);
        
        return {
            statusCode: 500,
            headers: {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Methods': 'GET,POST,OPTIONS',
                'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'
            },
            body: JSON.stringify({
                success: false,
                error: error.message
            })
        };
    }
};
