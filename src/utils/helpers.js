function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

function humanDelay() {
  return Math.random() * 500 + 300;
}

function validatePhoneNumber(phone) {
  return /^\d{10}$/.test(phone);
}

function maskPhoneNumber(phone) {
  if (phone.length !== 10) return phone;
  return phone.substring(0, 5) + '*****';
}

function getRandomUserAgent() {
  const userAgents = [
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.1 Safari/605.1.15'
  ];
  return userAgents[Math.floor(Math.random() * userAgents.length)];
}

function getRandomItem(array) {
  if (!array || array.length === 0) {
    throw new Error('Array is empty or undefined');
  }
  return array[Math.floor(Math.random() * array.length)];
}

function shuffleArray(array) {
  const shuffled = [...array];
  for (let i = shuffled.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [shuffled[i], shuffled[j]] = [shuffled[j], shuffled[i]];
  }
  return shuffled;
}

module.exports = {
  sleep,
  humanDelay,
  validatePhoneNumber,
  maskPhoneNumber,
  getRandomUserAgent,
  getRandomItem,
  shuffleArray
};
