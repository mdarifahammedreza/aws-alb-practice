#!/usr/bin/env bash
# Deploys aws-alb-practice to all 3 EC2 instances in one run:
# installs node/npm + pm2 on each, clones/pulls the repo, and starts it under pm2.
#
# Usage:
#   ./deploy.sh                       # uses defaults below
#   PEM_KEY=/path/to/key.pem ./deploy.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

PEM_KEY="${PEM_KEY:-$SCRIPT_DIR/reza-batch-14-office.pem}"
REMOTE_USER="${REMOTE_USER:-ubuntu}"
REPO_URL="${REPO_URL:-https://github.com/mdarifahammedreza/aws-alb-practice.git}"
APP_DIR="${APP_DIR:-aws-alb-practice}"

HOSTS=(
  "ec2-54-254-196-60.ap-southeast-1.compute.amazonaws.com"
  "ec2-13-212-206-197.ap-southeast-1.compute.amazonaws.com"
  "ec2-13-250-24-149.ap-southeast-1.compute.amazonaws.com"
)

REMOTE_SETUP_SCRIPT="$SCRIPT_DIR/scripts/remote-setup.sh"

if [[ ! -f "$PEM_KEY" ]]; then
  echo "ERROR: pem key not found at '$PEM_KEY'. Set PEM_KEY=/path/to/key.pem" >&2
  exit 1
fi
chmod 600 "$PEM_KEY"

SSH_OPTS=(-i "$PEM_KEY" -o StrictHostKeyChecking=accept-new -o ConnectTimeout=15)

FAILED=()
for HOST in "${HOSTS[@]}"; do
  echo "=============================================="
  echo ">>> Deploying to $HOST"
  echo "=============================================="

  if ! scp "${SSH_OPTS[@]}" "$REMOTE_SETUP_SCRIPT" "$REMOTE_USER@$HOST:/tmp/remote-setup.sh"; then
    echo "!!! Failed to copy setup script to $HOST"
    FAILED+=("$HOST")
    continue
  fi

  if ! ssh "${SSH_OPTS[@]}" "$REMOTE_USER@$HOST" \
      "REPO_URL='$REPO_URL' APP_DIR='$APP_DIR' bash /tmp/remote-setup.sh"; then
    echo "!!! Setup failed on $HOST"
    FAILED+=("$HOST")
    continue
  fi

  echo ">>> Done: $HOST"
done

echo
if [[ ${#FAILED[@]} -eq 0 ]]; then
  echo "All instances deployed successfully."
else
  echo "Deployment failed on: ${FAILED[*]}" >&2
  exit 1
fi
