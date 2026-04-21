# AWS Spot Instance Support

The `launch-campaign-instances.sh` script now supports launching EC2 Spot Instances, which can save up to 90% compared to on-demand pricing.

## How to Use

### Default Behavior (On-Demand Instances)
By default, the script launches **on-demand instances**:

```bash
export CAMPAIGN_ID="apr-21-2026-pool-120055"
export JOB_IDS="job-001,job-002,job-003"
./scripts/launch-campaign-instances.sh
```

### Enable Spot Instances
To use **spot instances**, set `USE_SPOT=true` or `USE_SPOT=y`:

```bash
export USE_SPOT=true
export CAMPAIGN_ID="apr-21-2026-pool-120055"
export JOB_IDS="job-001,job-002,job-003"
./scripts/launch-campaign-instances.sh
```

Or use shorthand:

```bash
USE_SPOT=y ./scripts/launch-campaign-instances.sh apr-21-2026-pool-120055 job-001,job-002
```

### Custom Max Price
Set a custom maximum price per hour (default is $0.05):

```bash
export USE_SPOT=true
export SPOT_MAX_PRICE=0.03
./scripts/launch-campaign-instances.sh apr-21-2026-pool-120055 job-001,job-002
```

## Pricing Comparison

| Instance Type | On-Demand Price | Typical Spot Price | Savings |
|---------------|-----------------|-------------------|---------|
| t3.small      | ~$0.0208/hr     | ~$0.006-0.01/hr   | 70-90%  |

## Important Notes

1. **Interruption Risk**: Spot instances can be interrupted by AWS with 2-minute notice if capacity is needed
2. **Best For**: Non-critical workloads, batch jobs, campaigns that can tolerate occasional interruptions
3. **Max Price**: Set `SPOT_MAX_PRICE` to your maximum acceptable price per hour
4. **Auto-Shutdown**: Instances still auto-terminate after 55 minutes as configured

## Accepted Values for USE_SPOT

The following values enable spot instances:
- `true`
- `y`
- `Y`
- `yes`
- `YES`

Any other value (or not setting it) defaults to on-demand instances.

## Wave Launch Scripts

### Option 1: Dedicated Spot Waves Script (Recommended)

Use the dedicated spot instance wave launcher:

```bash
bash scripts/launch-campaign-spot-waves.sh
```

This script has spot instances **enabled by default** and includes:
- Clear indication that spot instances are being used
- Cost savings estimates in output
- Spot-specific logging

To customize the max price:

```bash
export SPOT_MAX_PRICE=0.04
bash scripts/launch-campaign-spot-waves.sh
```

### Option 2: Regular Wave Script with Spot Flag

Use the regular wave launcher with spot flag:

```bash
export USE_SPOT=true
export SPOT_MAX_PRICE=0.04
bash scripts/launch-campaign-waves.sh
```

## Script Comparison

| Script | Default Mode | Best For |
|--------|-------------|----------|
| `launch-campaign-waves.sh` | On-Demand | Production, critical workloads |
| `launch-campaign-spot-waves.sh` | Spot | Cost optimization, non-critical batches |
| `launch-campaign-instances.sh` | On-Demand | Single batch testing |
