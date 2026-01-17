const fs = require('fs');
const path = require('path');
const logger = require('./utils/logger');

class DynamicConfig {
  static async loadMobileNumber(index) {
    try {
      const mobileFile = path.join(__dirname, '../data/mobile-numbers.txt');
      
      if (!fs.existsSync(mobileFile)) {
        throw new Error(`Mobile numbers file not found: ${mobileFile}`);
      }
      
      const mobiles = fs.readFileSync(mobileFile, 'utf8')
        .split('\n')
        .map(line => line.trim())
        .filter(line => line.length > 0);
      
      if (mobiles.length === 0) {
        throw new Error('No mobile numbers found in file');
      }
      
      if (index < 1 || index > mobiles.length) {
        throw new Error(`Mobile index ${index} out of range (1-${mobiles.length})`);
      }
      
      const mobile = mobiles[index - 1];
      logger.info(`Loaded mobile number for index ${index}: ${mobile.substring(0, 3)}****${mobile.substring(mobile.length - 2)}`);
      return mobile;
    } catch (error) {
      logger.error('Failed to load mobile number:', error.message);
      throw error;
    }
  }

  static async loadImageBatch(batchNumber) {
    try {
      const batchDir = path.join(__dirname, `../data/image-batches/batch-${batchNumber.toString().padStart(3, '0')}`);
      
      if (!fs.existsSync(batchDir)) {
        throw new Error(`Batch directory not found: ${batchDir}`);
      }
      
      const images = fs.readdirSync(batchDir)
        .filter(file => /\.(jpg|jpeg|png|gif|webp)$/i.test(file))
        .map(file => path.join(batchDir, file));
      
      if (images.length === 0) {
        throw new Error(`No images found in batch ${batchNumber}`);
      }
      
      logger.info(`Loaded ${images.length} images from batch ${batchNumber}`);
      return images;
    } catch (error) {
      logger.error('Failed to load image batch:', error.message);
      throw error;
    }
  }

  static getMobileIndexFromEnvironment() {
    // Try to get from global variable (set by CLI args)
    if (global.MOBILE_INDEX) {
      return global.MOBILE_INDEX;
    }
    
    // Try to get from environment variable
    if (process.env.MOBILE_INDEX) {
      return parseInt(process.env.MOBILE_INDEX);
    }
    
    return null;
  }
}

module.exports = DynamicConfig;
