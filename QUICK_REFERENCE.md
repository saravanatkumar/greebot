# Wave Orchestration - Quick Reference Card

## Setup (One Time Only)

```bash
./scripts/setup-wave-cron.sh
```

## Run All 20 Batches

```bash
./scripts/launch-campaign-waves.sh
```

## Monitor Progress

```bash
./scripts/monitor-wave-progress.sh
```

## Emergency Stop

```bash
./scripts/emergency-stop-waves.sh
```

## Check Logs

```bash
# Terminator log
tail -f logs/terminator.log

# Wave launcher log
tail -f logs/wave-execution.log

# Current state
cat logs/wave-state.log

# Archived waves
ls -lh logs/wave-state-*.log
```

## Verify Cron

```bash
crontab -l
```

## Key Files

| File | Purpose |
|------|---------|
| `scripts/launch-campaign-waves.sh` | Main launcher |
| `scripts/terminate-instances.sh` | Auto-terminator (cron) |
| `scripts/monitor-wave-progress.sh` | Real-time monitor |
| `scripts/emergency-stop-waves.sh` | Emergency stop |
| `logs/wave-state.log` | Current state |
| `logs/wave-state-*.log` | Archived waves |

## Timeline

- **Wave 1**: Batches 01-05 (~65 min)
- **Cooldown**: 5 min
- **Wave 2**: Batches 06-10 (~65 min)
- **Cooldown**: 5 min
- **Wave 3**: Batches 11-15 (~65 min)
- **Cooldown**: 5 min
- **Wave 4**: Batches 16-19 (~65 min)
- **Total**: ~4.5 hours

## State File Format

```
wave_id|batch_id|job_id|instance_id|start_time|status
1|01|job-001|i-0abc123def|1713182400|running
```

## Configuration

Edit `config/wave-config.json`:
- `batchesPerWave`: 5 (batches per wave)
- `batchStaggerInterval`: 600 (10 min between batches)
- `cooldownPeriod`: 300 (5 min between waves)
- `timeout`: 3300 (55 min instance timeout)

## Troubleshooting

**Cron not working?**
```bash
crontab -l
tail -f logs/terminator.log
```

**Want to see what's happening?**
```bash
watch -n 5 'cat logs/wave-state.log | tail -20'
```

**Need to restart?**
1. Ctrl+C on wave launcher
2. Run emergency stop if needed
3. Clear state file
4. Restart launcher

---

**For full details, see:**
- `README_WAVE_EXECUTION.md` - Quick start
- `WAVE_ORCHESTRATION_GUIDE.md` - Complete guide
- `IMPLEMENTATION_SUMMARY.md` - Overview
