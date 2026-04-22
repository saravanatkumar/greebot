#!/bin/bash

set -e

AWS_REGION="ap-south-1"
UPTIME_THRESHOLD=57

echo "Checking actual system uptime via SSM in Mumbai (ap-south-1)..."
echo "================================================================"

RUNNING_INSTANCES=$(aws ec2 describe-instances \
    --region "${AWS_REGION}" \
    --filters "Name=instance-state-name,Values=running" \
    --query 'Reservations[*].Instances[*].[InstanceId,Tags[?Key==`Name`].Value|[0]]' \
    --output text)

if [ -z "$RUNNING_INSTANCES" ]; then
    echo "No running instances found."
    exit 0
fi

echo ""
printf "%-20s %-50s %-15s\n" "INSTANCE ID" "NAME" "UPTIME (min)"
echo "---------------------------------------------------------------------------------------------"

INSTANCES_TO_TERMINATE=()

while IFS=$'\t' read -r INSTANCE_ID INSTANCE_NAME; do
    if [ -z "$INSTANCE_ID" ]; then
        continue
    fi
    
    INSTANCE_NAME="${INSTANCE_NAME:-N/A}"
    
    # Get uptime via SSM
    UPTIME_OUTPUT=$(aws ssm send-command \
        --region "${AWS_REGION}" \
        --instance-ids "$INSTANCE_ID" \
        --document-name "AWS-RunShellScript" \
        --parameters 'commands=["cat /proc/uptime | cut -d\" \" -f1"]' \
        --output text \
        --query 'Command.CommandId' 2>/dev/null || echo "")
    
    if [ -z "$UPTIME_OUTPUT" ]; then
        printf "%-20s %-50s %-15s\n" "$INSTANCE_ID" "$INSTANCE_NAME" "SSM N/A"
        continue
    fi
    
    # Wait for command to complete
    sleep 2
    
    # Get command result
    UPTIME_SECONDS=$(aws ssm get-command-invocation \
        --region "${AWS_REGION}" \
        --command-id "$UPTIME_OUTPUT" \
        --instance-id "$INSTANCE_ID" \
        --query 'StandardOutputContent' \
        --output text 2>/dev/null | tr -d '\n' || echo "0")
    
    if [ -z "$UPTIME_SECONDS" ] || [ "$UPTIME_SECONDS" == "0" ]; then
        printf "%-20s %-50s %-15s\n" "$INSTANCE_ID" "$INSTANCE_NAME" "Error"
        continue
    fi
    
    # Convert to minutes (uptime is in seconds with decimals)
    UPTIME_MINUTES=$(echo "$UPTIME_SECONDS / 60" | bc)
    
    printf "%-20s %-50s %-15s\n" "$INSTANCE_ID" "$INSTANCE_NAME" "${UPTIME_MINUTES} min"
    
    if [ "$UPTIME_MINUTES" -gt "$UPTIME_THRESHOLD" ]; then
        INSTANCES_TO_TERMINATE+=("$INSTANCE_ID")
    fi
    
done <<< "$RUNNING_INSTANCES"

echo ""
echo "================================================================"

if [ ${#INSTANCES_TO_TERMINATE[@]} -eq 0 ]; then
    echo "✓ No instances exceed the ${UPTIME_THRESHOLD} minute threshold."
    exit 0
fi

echo "⚠️  Found ${#INSTANCES_TO_TERMINATE[@]} instance(s) exceeding ${UPTIME_THRESHOLD} minutes:"
for INSTANCE_ID in "${INSTANCES_TO_TERMINATE[@]}"; do
    echo "  - $INSTANCE_ID"
done

echo ""
read -p "Terminate these instances? (yes/no): " CONFIRM

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

echo "✓ Done"
