# GreenDotBall Project Documentation

## Project Overview

The GreenDotBall project is an automated system that processes phone numbers and images stored in Amazon S3 to perform submissions through a web form. The system is designed to scale by launching multiple EC2 instances, with each instance handling one phone number and processing multiple images.

## System Architecture

### Core Components

1. **EC2 Instances**: Each instance runs a bot that processes a single phone number with multiple images
2. **S3 Storage**: Stores phone numbers and images to be processed
3. **Lambda Functions**: Handle various backend operations such as uploading phone numbers, listing campaigns
4. **Web Interface**: Provides a dashboard to monitor and manage campaigns

### Data Flow

1. Phone numbers are stored in S3 (either directly or through Lambda functions)
2. Images are stored in S3 in the `/data/images` directory
3. The `launch-100-instances.sh` script reads the phone numbers file and launches one EC2 instance per phone number
4. Each instance receives a specific mobile index number as a parameter
5. Each instance processes all images in the S3 bucket using its assigned phone number

## Instance Management

### Instance Launch Process

1. The `launch-100-instances.sh` script reads `data/mobile-numbers.txt` to determine how many instances to launch
2. For each phone number, an EC2 instance is created with:
   - A unique mobile index parameter passed through user-data
   - IAM role for S3 access
   - Appropriate security group and key pair
3. Each instance is tagged with:
   - Name: `greendotball-worker-{index}`
   - MobileIndex: The assigned index number
   - Project: `greendotball`
   - Batch: Timestamp of the batch launch

### Instance Configuration

Each EC2 instance is configured with:
- AMI: `ami-0a39d12e7514ee458`
- Instance Type: `t3.small`
- Key Pair: `greendotball-bot-key-v2`
- Security Group: `greendotball-bot-sg`
- IAM Role: `EC2-GreenDotBall-S3-Access`
- Region: `ap-south-1`

## Phone Number Management

Phone numbers are stored in a simple text file (`data/mobile-numbers.txt`) with one number per line. When an instance starts:

1. It reads the mobile index passed as a parameter
2. It loads the corresponding phone number from the file (index - 1)
3. That phone number is used for all image submissions by that instance

The phone numbers can also be managed through Lambda functions:
- `upload-phone-numbers.js`: Uploads phone numbers to S3 for a campaign
- `process-phone-numbers.js`: Processes and validates phone numbers from S3

## Image Processing

Images are stored in the `data/images` directory. When an instance runs:

1. The bot loads all images from the directory
2. For each image, it submits a form with:
   - The assigned phone number for the instance
   - The current image being processed

The system handles random or sequential selection of images based on configuration.

## Bot Functionality

The bot (`src/bot.js`) operates as follows:

1. Initializes and validates configuration
2. Launches a browser using Puppeteer
3. Navigates to the target form
4. For each image:
   - Uploads the image to the form
   - Enters the phone number
   - Accepts terms and conditions
   - Submits the form
   - Waits for response and logs the result

### Key Bot Features

- Retry mechanism for failed submissions
- Detailed logging of each submission
- Support for both batch and single submission modes
- Random selection of phone numbers and images (optional)
- Screenshot capture on errors for debugging

## Scaling Capability

The system is designed to scale horizontally:

1. If there are 50 phone numbers, 50 instances will be launched
2. If there are 80 images, each instance will process all 80 images
3. This results in 50 × 80 = 4,000 total submissions

The architecture allows for easy scaling by simply adding more phone numbers or images to the respective S3 locations.

## Lambda Functions

Three main Lambda functions handle backend operations:

1. `list-campaigns.js`: Lists all campaigns stored in S3
2. `process-phone-numbers.js`: Processes and validates phone numbers from S3
3. `upload-phone-numbers.js`: Uploads phone numbers to S3 and manages campaign metadata

## Web Interface

The web interface in the `website/greendotball` directory provides:

1. A dashboard to monitor campaigns
2. Forms to upload phone numbers and images
3. Interface to launch new campaigns

## Deployment and Execution

To run the system:

1. Ensure phone numbers are uploaded to `data/mobile-numbers.txt`
2. Ensure images are available in `data/images/`
3. Run `scripts/launch-100-instances.sh` to start the process
4. Monitor the EC2 instances through AWS Console or using the provided commands

## Monitoring

The script provides commands to:
- Monitor instances: `aws ec2 describe-instances --region ap-south-1 --filters "Name=tag:Project,Values=greendotball" "Name=instance-state-name,Values=running"`
- Check logs in S3: `aws s3 ls s3://greendotball-bot-data/logs/ --recursive`
- Terminate instances: `aws ec2 terminate-instances --region ap-south-1 --instance-ids [ids]`
