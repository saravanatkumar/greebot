# Wave Execution - Quick Start

Run 20 phone batches (840 EC2 instances) in ~4.5 hours instead of 10 hours.

## Setup (One Time)

### 1. Add Cron Job

```bash
crontab -e
```

Add this line (runs terminator every 5 minutes):
```
*/5 * * * * /Users/apple/CascadeProjects/windsurf-project-2/scripts/terminate-instances.sh >> /Users/apple/CascadeProjects/windsurf-project-2/logs/terminator.log 2>&1
```

Save and exit.

### 2. Verify Cron

```bash
crontab -l
```

You should see the terminator job listed.

## Run Waves

### Start Execution

```bash
cd /Users/apple/CascadeProjects/windsurf-project-2
./scripts/launch-campaign-waves.sh
```

The script will run for ~4.5 hours and process all 20 batches automatically.

### Monitor (Optional)

Open a second terminal:
```bash
./scripts/monitor-wave-progress.sh
```

## What Happens

1. **Wave 1** (Batches 01-05)
   - Batch 01 starts at 12:00, terminates at 12:55
   - Batch 02 starts at 12:10, terminates at 13:05
   - Batch 03 starts at 12:20, terminates at 13:15
   - Batch 04 starts at 12:30, terminates at 13:25
   - Batch 05 starts at 12:40, terminates at 13:35
   - 5-minute cooldown

2. **Wave 2** (Batches 06-10) - Same pattern
3. **Wave 3** (Batches 11-15) - Same pattern
4. **Wave 4** (Batches 16-19) - Same pattern

## Files Created

- `logs/wave-state.log` - Current instances (auto-rotated)
- `logs/wave-state-*.log` - Archived waves
- `logs/wave-execution.log` - Launcher log
- `logs/terminator.log` - Terminator log

## Emergency Stop

If something goes wrong:
```bash
./scripts/emergency-stop-waves.sh
```

## Full Documentation

See `WAVE_ORCHESTRATION_GUIDE.md` for complete details.

## Architecture

```
┌─────────────────────────────────────┐
│  Wave Launcher                      │
│  (launch-campaign-waves.sh)         │
│                                     │
│  1. Launch batches sequentially     │
│  2. Log to state file               │
│  3. Wait for wave completion        │
└──────────────┬──────────────────────┘
               │
               │ writes to
               ▼
┌─────────────────────────────────────┐
│  State File                         │
│  (logs/wave-state.log)              │
│                                     │
│  wave|batch|job|instance|time|status│
└──────────────┬──────────────────────┘
               │
               │ reads from
               ▼
┌─────────────────────────────────────┐
│  Instance Terminator                │
│  (terminate-instances.sh)           │
│                                     │
│  1. Runs every 5 min (cron)         │
│  2. Terminates 55+ min instances    │
│  3. Rotates log when done           │
└─────────────────────────────────────┘
```

Simple, reliable, automated!
