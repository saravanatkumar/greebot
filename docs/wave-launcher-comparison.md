# Wave Launcher Scripts Comparison

## Available Scripts

### 1. `launch-campaign-waves.sh` (Original)
**Default Mode:** On-Demand Instances

**Usage:**
```bash
bash scripts/launch-campaign-waves.sh
```

**Features:**
- Stable, production-ready
- Uses on-demand EC2 instances by default
- No interruption risk
- Can enable spot with `USE_SPOT=true` flag

**Best For:**
- Production campaigns
- Critical workloads
- When reliability > cost

---

### 2. `launch-campaign-spot-waves.sh` (New - Cost Optimized)
**Default Mode:** Spot Instances

**Usage:**
```bash
bash scripts/launch-campaign-spot-waves.sh
```

**Features:**
- **70-90% cost savings** compared to on-demand
- Spot instances enabled by default
- Clear spot instance indicators in output
- Shows estimated savings
- Same functionality as regular wave launcher

**Best For:**
- Cost optimization
- Non-critical batches
- Large-scale campaigns where interruption is acceptable
- Testing and development

**Customization:**
```bash
# Custom max price
export SPOT_MAX_PRICE=0.03
bash scripts/launch-campaign-spot-waves.sh
```

---

## Quick Decision Guide

```
Need guaranteed completion? → launch-campaign-waves.sh
Want to save 70-90% on costs? → launch-campaign-spot-waves.sh
Testing single batch? → launch-campaign-instances.sh (with USE_SPOT=y if desired)
```

## Cost Comparison Example

**Scenario:** 35 batches × 42 jobs = 1,470 instances × 55 minutes

| Script | Instance Type | Cost per Hour | Total Cost | Savings |
|--------|--------------|---------------|------------|---------|
| `launch-campaign-waves.sh` | On-Demand | $0.0208 | ~$28.00 | - |
| `launch-campaign-spot-waves.sh` | Spot | $0.006-0.01 | ~$8.40 | **70%** |

*Note: Actual spot prices vary by availability. Savings can be up to 90%.*

## Spot Instance Considerations

### ✅ Advantages
- Massive cost savings (70-90%)
- Same performance as on-demand
- Auto-retry logic can handle interruptions
- Perfect for batch workloads

### ⚠️ Considerations
- Can be interrupted with 2-minute notice
- Availability depends on AWS capacity
- Best for fault-tolerant workloads
- Set appropriate max price to control costs

## Configuration

Both scripts share the same configuration at the top:

```bash
TOTAL_BATCHES_INPUT=35     # Total number of batches to process
BATCHES_PER_WAVE=3         # Number of batches per wave
BATCH_STAGGER_INTERVAL=600 # 10 minutes between batches
COOLDOWN_PERIOD=1800       # 30 minutes between waves
```

For spot script, additionally:
```bash
SPOT_MAX_PRICE=0.05        # Max price per hour (default: $0.05)
```

## Monitoring

Both scripts log to the same state file:
```bash
cat logs/wave-state.log
./scripts/monitor-wave-progress.sh
```

Instance type (spot vs on-demand) is tracked in the logs.
