# Serverless Campaign Solution

## Problem
- Manual EC2 monitoring
- Pay for full hour even if job takes 20 min
- No auto-shutdown on failure

## Solution: AWS Step Functions + ECS Fargate

### Architecture
```
API Gateway → Step Functions → ECS Fargate Tasks (parallel) → Auto-cleanup
```

### Benefits
1. **Zero monitoring** - Fully automated
2. **Pay-per-second** - Not per hour
3. **Auto-cleanup** - Tasks stop when done
4. **80% cheaper** - Only pay actual runtime
5. **Scalable** - 1 to 100 jobs easily

### Cost Comparison
- **EC2**: $0.0416/hour × 1 hour = $0.0416 (even if 20 min job)
- **Fargate**: $0.025/hour × 0.33 hour = $0.0083 (80% savings!)

### Quick Start
1. Build Docker image with bot code
2. Deploy to ECS Fargate
3. Create Step Functions workflow
4. Launch via API - no monitoring needed!

See implementation files in:
- `docker/Dockerfile`
- `ecs/task-definition.json`
- `stepfunctions/state-machine.json`
- `lambdas/launch-campaign-stepfunctions.js`
