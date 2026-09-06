#!/usr/bin/env bash
# scripts/get_broker_ip.sh
set -euo pipefail

CLUSTER="cost"
SERVICE="broker"

task_arn=$(aws ecs list-tasks --cluster "$CLUSTER" --service-name "$SERVICE" \
  --no-cli-pager --query 'taskArns[0]' --output text)

if [ "$task_arn" == "None" ] || [ -z "$task_arn" ]; then
  echo "No running broker task found (service may be scaled to 0, or crash-looping between attempts)." >&2
  exit 1
fi

eni_id=$(aws ecs describe-tasks --cluster "$CLUSTER" --tasks "$task_arn" \
  --no-cli-pager --query "tasks[0].attachments[?type=='ElasticNetworkInterface']|[0].details[?name=='networkInterfaceId'].value" --output text)

public_ip=$(aws ec2 describe-network-interfaces --network-interface-ids "$eni_id" \
  --no-cli-pager --query 'NetworkInterfaces[0].Association.PublicIp' --output text)

if [ "$public_ip" == "None" ] || [ -z "$public_ip" ]; then
  echo "Broker task found but no public IP assigned yet (still provisioning, or already stopped) — try again." >&2
  exit 1
fi

echo "$public_ip"