#!/bin/bash

set -e

AWS_REGION="ap-south-1"
UPTIME_THRESHOLD=57
SSH_KEY="${SSH_KEY:-~/.ssh/id_rsa}"
SSH_USER="${SSH_USER:-ec2-user}"

echo "Checking actual system uptime via SSH in Mumbai (ap-south-1)..."
echo "================================================================"
echo "SSH Key: $SSH_KEY"
echo "SSH User: $SSH_USER"
echo ""

RUNNING_INSTANCES=$(aws ec2 describe-instances \
    --region "${AWS_REGION}" \
    --filters "Name=instance-state-name,Values=running" \
    --query 'Reservations[*].Instances[*].[InstanceId,PublicIpAddress,PrivateIpAddress,Tags[?Key==`Name`].Value|[0]]' \
    --output text)

if [ -z "$RUNNING_INSTANCES" ]; then
    echo "No running instances found."
    exit 0
fi

echo ""
printf "%-20s %-50s %-15s %-15s\n" "INSTANCE ID" "NAME" "IP ADDRESS" "UPTIME (min)"
echo "------------------------------------------------------------------------------------------------------------"

INSTANCES_TO_TERMINATE=()

while IFS=$'\t' read -r INSTANCE_ID PUBLIC_IP PRIVATE_IP INSTANCE_NAME; do
    if [ -z "$INSTANCE_ID" ]; then
        continue
    fi
    
    INSTANCE_NAME="${INSTANCE_NAME:-N/A}"
    
    # Use public IP if available, otherwise private IP
    if [ -n "$PUBLIC_IP" ] && [ "$PUBLIC_IP" != "None" ]; then
        IP_ADDRESS="$PUBLIC_IP"
    else
        IP_ADDRESS="$PRIVATE_IP"
    fi
    
    if [ -z "$IP_ADDRESS" ] || [ "$IP_ADDRESS" == "None" ]; then
        printf "%-20s %-50s %-15s %-15s\n" "$INSTANCE_ID" "$INSTANCE_NAME" "No IP" "N/A"
        continue
    fi
    
    # Get uptime via SSH (read /proc/uptime which shows seconds)
    UPTIME_SECONDS=$(ssh -i "$SSH_KEY" \
        -o StrictHostKeyChecking=no \
        -o ConnectTimeout=5 \
        -o BatchMode=yes \
        "${SSH_USER}@${IP_ADDRESS}" \
        "cat /proc/uptime | cut -d' ' -f1" 2>/dev/null || echo "")
    
    if [ -z "$UPTIME_SECONDS" ]; then
        printf "%-20s %-50s %-15s %-15s\n" "$INSTANCE_ID" "$INSTANCE_NAME" "$IP_ADDRESS" "SSH Failed"
        continue
    fi
    
    # Convert to minutes (remove decimals)
    UPTIME_MINUTES=$(echo "$UPTIME_SECONDS / 60" | bc 2>/dev/null || echo "0")
    
    printf "%-20s %-50s %-15s %-15s\n" "$INSTANCE_ID" "$INSTANCE_NAME" "$IP_ADDRESS" "${UPTIME_MINUTES} min"
    
    if [ "$UPTIME_MINUTES" -gt "$UPTIME_THRESHOLD" ]; then
        INSTANCES_TO_TERMINATE+=("$INSTANCE_ID")
    fi
    
done <<< "$RUNNING_INSTANCES"

echo ""
echo "============================================================================================================"

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
        --output text > /dev/null
    echo "  ✓ Terminated"
done

echo "✓ Done"
