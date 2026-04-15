# Wave Orchestration Guide

Simple guide for running 20 batches in 4 waves with automatic instance termination.

## Quick Start

### 1. Setup Cron for Auto-Termination

Add this to your crontab to run the terminator every 5 minutes:

```bash
crontab -e
```

Add this line:
```
*/5 * * * * /Users/apple/CascadeProjects/windsurf-project-2/scripts/terminate-instances.sh >> /Users/apple/CascadeProjects/windsurf-project-2/logs/terminator.log 2>&1
```

### 2. Start Wave Execution

```bash
./scripts/launch-campaign-waves.sh
```

That's it! The script will:
- Launch 4 waves of 5 batches each
- Log all instances to `logs/wave-state.log`
- Wait for terminator to clean up each wave
- Take ~4.5 hours total

### 3. Monitor Progress (Optional)

In a separate terminal:
```bash
./scripts/monitor-wave-progress.sh
```

## How It Works

### Two Independent Scripts

**1. Wave Launcher** (`launch-campaign-waves.sh`)
- Launches batches sequentially (10 min apart)
- Logs instances to state file
- Waits for wave to complete
- Moves to next wave

**2. Instance Terminator** (`terminate-instances.sh`)
- Runs every 5 minutes via cron
- Checks each instance's runtime
- Terminates instances after 55 minutes
- Rotates log when wave completes

### State File Format

`logs/wave-state.log` contains:
```
wave_id|batch_id|job_id|instance_id|start_time|status
1|01|job-001|i-0abc123def|1713182400|running
1|01|job-002|i-0def456ghi|1713182400|running
```

### Timeline Example

```
12:00 - Wave 1, Batch 01 starts (42 instances)
12:10 - Wave 1, Batch 02 starts (84 total)
12:20 - Wave 1, Batch 03 starts (126 total)
12:30 - Wave 1, Batch 04 starts (168 total)
12:40 - Wave 1, Batch 05 starts (210 total - PEAK)
12:55 - Batch 01 instances terminated (168 remaining)
13:05 - Batch 02 instances terminated (126 remaining)
13:15 - Batch 03 instances terminated (84 remaining)
13:25 - Batch 04 instances terminated (42 remaining)
13:35 - Batch 05 instances terminated (0 remaining)
13:35 - State file rotated
13:40 - Wave 2 starts
```

## Emergency Stop

If you need to stop everything immediately:

```bash
./scripts/emergency-stop-waves.sh
```

This will terminate ALL running instances.

## Logs

- `logs/wave-state.log` - Current state (active instances)
- `logs/wave-state-*.log` - Archived states (completed waves)
- `logs/wave-execution.log` - Wave launcher log
- `logs/terminator.log` - Terminator script log
- `logs/emergency-stop.log` - Emergency stop log

## Configuration

Edit `config/wave-config.json`:

```json
{
  "batchesPerWave": 5,           // Batches per wave (3-7)
  "batchStaggerInterval": 600,   // Seconds between batches (10 min)
  "cooldownPeriod": 300,         // Seconds between waves (5 min)
  "timeout": 3300,               // Instance timeout (55 min)
  "stateFile": "logs/wave-state.log",
  "region": "ap-south-1"
}
```

## Troubleshooting

### Instances not terminating?

Check if cron is running:
```bash
crontab -l
tail -f logs/terminator.log
```

### Want to see what's happening?

```bash
# Watch state file
watch -n 5 'cat logs/wave-state.log | tail -20'

# Or use monitor
./scripts/monitor-wave-progress.sh
```

### Need to restart a wave?

1. Stop current execution (Ctrl+C on wave launcher)
2. Run emergency stop if needed
3. Clear or archive state file
4. Restart wave launcher

## Tips

- **Don't interrupt** the wave launcher - let it complete
- **Terminator runs automatically** - no manual intervention needed
- **State file is your source of truth** - check it anytime
- **Archived files** are kept for auditing - don't delete them
- **Monitor script** doesn't affect execution - safe to run anytime

## Total Time Estimate

- Wave 1: ~65 minutes (40 min stagger + 55 min last batch)
- Cooldown: 5 minutes
- Wave 2: ~65 minutes
- Cooldown: 5 minutes
- Wave 3: ~65 minutes
- Cooldown: 5 minutes
- Wave 4: ~65 minutes
- **Total: ~4.5 hours**

Much better than 10 hours with 2-batch parallel execution!
