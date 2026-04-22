#!/bin/bash

set -e

UPTIME_THRESHOLD=57
AWS_REGION="${AWS_REGION:-us-east-1}"

echo "Checking for instances running longer than ${UPTIME_THRESHOLD} minutes..."
echo "Region: ${AWS_REGION}"
echo "----------------------------------------"

CURRENT_TIME=$(date +%s)

RUNNING_INSTANCES=$(aws ec2 describe-instances \
    --region "${AWS_REGION}" \
    --filters "Name=instance-state-name,Values=running" \
    --query 'Reservations[*].Instances[*].[InstanceId,LaunchTime,Tags[?Key==`Name`].Value|[0]]' \
    --output text)

if [ -z "$RUNNING_INSTANCES" ]; then
    echo "No running instances found."
    exit 0
fi

INSTANCES_TO_TERMINATE=()

while IFS=$'\t' read -r INSTANCE_ID LAUNCH_TIME INSTANCE_NAME; do
    if [ -z "$INSTANCE_ID" ]; then
        continue
    fi
    
    LAUNCH_TIMESTAMP=$(date -j -f "%Y-%m-%dT%H:%M:%S" "$(echo $LAUNCH_TIME | cut -d'.' -f1 | sed 's/+.*//')" +%s 2>/dev/null || date -d "$LAUNCH_TIME" +%s 2>/dev/null)
    
    UPTIME_SECONDS=$((CURRENT_TIME - LAUNCH_TIMESTAMP))
    UPTIME_MINUTES=$((UPTIME_SECONDS / 60))
    
    INSTANCE_NAME="${INSTANCE_NAME:-N/A}"
    
    echo "Instance: $INSTANCE_ID | Name: $INSTANCE_NAME | Uptime: ${UPTIME_MINUTES} minutes"
    
    if [ "$UPTIME_MINUTES" -gt "$UPTIME_THRESHOLD" ]; then
        echo "  ⚠️  EXCEEDS THRESHOLD - Marking for termination"
        INSTANCES_TO_TERMINATE+=("$INSTANCE_ID")
    fi
done <<< "$RUNNING_INSTANCES"

echo "----------------------------------------"

if [ ${#INSTANCES_TO_TERMINATE[@]} -eq 0 ]; then
    echo "✓ No instances exceed the ${UPTIME_THRESHOLD} minute threshold."
    exit 0
fi

echo "Found ${#INSTANCES_TO_TERMINATE[@]} instance(s) to terminate:"
for INSTANCE_ID in "${INSTANCES_TO_TERMINATE[@]}"; do
    echo "  - $INSTANCE_ID"
done

read -p "Proceed with termination? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "Termination cancelled."
    exit 0
fi

echo "Terminating instances..."
for INSTANCE_ID in "${INSTANCES_TO_TERMINATE[@]}"; do
    echo "Terminating $INSTANCE_ID..."
    aws ec2 terminate-instances \
        --region "${AWS_REGION}" \
        --instance-ids "$INSTANCE_ID" \
        --output text
    echo "  ✓ Terminated"
done

echo "----------------------------------------"
echo "✓ All instances terminated successfully."
