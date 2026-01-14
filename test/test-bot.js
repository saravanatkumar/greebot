const path = require('path');
const fs = require('fs');

console.log('='.repeat(60));
console.log('Green Dot Ball Bot - Configuration Test');
console.log('='.repeat(60));

const configPath = path.join(__dirname, '../config/config.json');

try {
  if (!fs.existsSync(configPath)) {
    console.error('❌ config.json not found');
    process.exit(1);
  }

  const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
  console.log('✓ Configuration file loaded');

  console.log('\nConfiguration:');
  console.log(`  Target URL: ${config.targetUrl}`);
  console.log(`  Headless: ${config.headless}`);
  console.log(`  Slide Strategy: ${config.slideStrategy}`);
  console.log(`  Phone Numbers: ${config.phoneNumbers.length}`);
  console.log(`  Image Path: ${config.imagePath}`);

  const imagePath = path.resolve(config.imagePath);
  if (fs.existsSync(imagePath)) {
    const stats = fs.statSync(imagePath);
    const sizeMB = (stats.size / (1024 * 1024)).toFixed(2);
    console.log(`\n✓ Image file found (${sizeMB}MB)`);
  } else {
    console.log(`\n❌ Image file not found: ${imagePath}`);
    console.log('   Please add an image file to data/sample-images/');
  }

  const phoneRegex = /^\d{10}$/;
  let validPhones = 0;
  config.phoneNumbers.forEach((phone, index) => {
    if (phoneRegex.test(phone)) {
      validPhones++;
    } else {
      console.log(`\n❌ Invalid phone number at index ${index}: ${phone}`);
    }
  });

  if (validPhones === config.phoneNumbers.length) {
    console.log(`✓ All ${validPhones} phone numbers are valid`);
  } else {
    console.log(`⚠️  ${validPhones}/${config.phoneNumbers.length} phone numbers are valid`);
  }

  console.log('\n' + '='.repeat(60));
  console.log('Test completed. Ready to run bot!');
  console.log('='.repeat(60));
  console.log('\nNext steps:');
  console.log('  1. Add your image to data/sample-images/');
  console.log('  2. Update config.json with your phone numbers');
  console.log('  3. Run: npm start');
  console.log('');

} catch (error) {
  console.error('❌ Test failed:', error.message);
  process.exit(1);
}
