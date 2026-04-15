const AWS = require('aws-sdk');

exports.handler = async (event) => {
  const { batches, batchesPerWave = 5, delayBetweenWaves = 60 } = event;
  
  const waveGroups = [];
  
  for (let i = 0; i < batches.length; i += batchesPerWave) {
    const waveBatches = batches.slice(i, i + batchesPerWave);
    waveGroups.push({
      waveNumber: Math.floor(i / batchesPerWave) + 1,
      batches: waveBatches,
      batchCount: waveBatches.length
    });
  }
  
  return {
    waveGroups,
    totalWaves: waveGroups.length,
    batchesPerWave,
    delayBetweenWaves,
    totalBatches: batches.length
  };
};
