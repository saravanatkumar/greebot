const fs = require('fs');
const path = require('path');
const logger = require('./utils/logger');
const { validatePhoneNumber } = require('./utils/helpers');

class Validator {
  static validateConfig(config) {
    const errors = [];

    if (!config.targetUrl) {
      errors.push('targetUrl is required in config');
    }

    if (!config.phoneNumbers || config.phoneNumbers.length === 0) {
      errors.push('At least one phone number is required');
    }

    config.phoneNumbers.forEach((phone, index) => {
      if (!validatePhoneNumber(phone)) {
        errors.push(`Invalid phone number at index ${index}: ${phone}`);
      }
    });

    if (!config.imagePath) {
      errors.push('imagePath is required in config');
    } else {
      const imagePath = path.resolve(config.imagePath);
      if (!fs.existsSync(imagePath)) {
        errors.push(`Image file not found: ${imagePath}`);
      }
    }

    if (errors.length > 0) {
      errors.forEach(error => logger.error(error));
      return { valid: false, errors };
    }

    return { valid: true, errors: [] };
  }

  static validateImageFile(filePath) {
    const allowedExtensions = ['.jpg', '.jpeg', '.png', '.gif', '.webp'];
    const ext = path.extname(filePath).toLowerCase();
    
    if (!allowedExtensions.includes(ext)) {
      return { valid: false, error: `Invalid image format: ${ext}` };
    }

    const stats = fs.statSync(filePath);
    const fileSizeMB = stats.size / (1024 * 1024);
    
    if (fileSizeMB > 10) {
      return { valid: false, error: `Image too large: ${fileSizeMB.toFixed(2)}MB (max 10MB)` };
    }

    return { valid: true };
  }
}

module.exports = Validator;
