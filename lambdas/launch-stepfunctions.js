const AWS = require('aws-sdk');
const sf = new AWS.StepFunctions({ region: 'ap-south-1' });

exports.handler = async (event) => {
  const body = JSON.parse(event.body);
  const exec = await sf.startExecution({
    stateMachineArn: process.env.STATE_MACHINE_ARN,
    name: `${body.campaignId}-${Date.now()}`,
    input: JSON.stringify(body)
  }).promise();
  
  return {
    statusCode: 200,
    body: JSON.stringify({ executionArn: exec.executionArn })
  };
};
