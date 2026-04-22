#!/bin/bash

set -e

AWS_REGION="ap-south-1"

echo "Checking running instances in Mumbai (ap-south-1)..."
echo "=========================================="

CURRENT_TIME=$(date +%s)

RUNNING_INSTANCES=$(aws ec2 describe-instances \
    --region "${AWS_REGION}" \
    --filters "Name=instance-state-name,Values=running" \
    --query 'Reservations[*].Instances[*].[InstanceId,UsageOperationUpdateTime,LaunchTime,Tags[?Key==`Name`].Value|[0]]' \
    --output text)

if [ -z "$RUNNING_INSTANCES" ]; then
    echo "No running instances found."
    exit 0
fi

echo ""
printf "%-20s %-30s %-25s %-15s\n" "INSTANCE ID" "NAME" "START TIME" "UPTIME (min)"
echo "--------------------------------------------------------------------------------------------------------"

while IFS=$'\t' read -r INSTANCE_ID USAGE_TIME LAUNCH_TIME INSTANCE_NAME; do
    if [ -z "$INSTANCE_ID" ]; then
        continue
    fi
    
    # Use UsageOperationUpdateTime (when instance started running) instead of LaunchTime
    if [ -n "$USAGE_TIME" ] && [ "$USAGE_TIME" != "None" ]; then
        START_TIME="$USAGE_TIME"
    else
        START_TIME="$LAUNCH_TIME"
    fi
    
    START_TIMESTAMP=$(date -j -f "%Y-%m-%dT%H:%M:%S" "$(echo $START_TIME | cut -d'.' -f1 | sed 's/+.*//')" +%s 2>/dev/null || date -d "$START_TIME" +%s 2>/dev/null)
    
    UPTIME_SECONDS=$((CURRENT_TIME - START_TIMESTAMP))
    UPTIME_MINUTES=$((UPTIME_SECONDS / 60))
    
    INSTANCE_NAME="${INSTANCE_NAME:-N/A}"
    
    FORMATTED_TIME=$(echo $START_TIME | cut -d'.' -f1)
    
    printf "%-20s %-30s %-25s %-15s\n" "$INSTANCE_ID" "$INSTANCE_NAME" "$FORMATTED_TIME" "${UPTIME_MINUTES} min"
    
done <<< "$RUNNING_INSTANCES"

echo ""
echo "✓ Done"
