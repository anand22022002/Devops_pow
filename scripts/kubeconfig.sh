#!/usr/bin/env bash
# =============================================================================
# kubeconfig.sh — Configure kubectl to reach the private EKS cluster
# via an SSH tunnel through the bastion host.
#
# Usage: bash scripts/kubeconfig.sh
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TF_DIR="$REPO_ROOT/terraform/envs/dev"
REGION="ap-south-1"
KEY="$HOME/.ssh/kubeinfra-bastion"
if [ ! -f "$KEY" ]; then
  if [ -f "$HOME/.ssh/devopsdock-bastion" ]; then
    KEY="$HOME/.ssh/devopsdock-bastion"
  fi
fi

# ─── Get outputs from Terraform ───────────────────────────────────────────────
cd "$TF_DIR"
BASTION_IP=$(terraform output -raw bastion_public_ip)
CLUSTER_NAME=$(terraform output -raw eks_cluster_name)
cd - > /dev/null

echo "Bastion IP  : $BASTION_IP"
echo "Cluster     : $CLUSTER_NAME"

echo ""
echo ">>> Automated Local Access Setup via Bastion Tunnel..."

# Get EKS Endpoint and extract Hostname
cd "$TF_DIR"
ENDPOINT=$(terraform output -raw eks_cluster_endpoint)
cd - > /dev/null
ENDPOINT_HOST=$(echo "$ENDPOINT" | sed 's|https://||')

echo "EKS Endpoint: $ENDPOINT_HOST"

# 1. Kill any existing tunnel running on port 6443
echo "Cleaning up any old SSH tunnels..."
pkill -f "6443:${ENDPOINT_HOST}" || true
sleep 1

# 2. Establish the SSH tunnel in background
echo "Starting new SSH tunnel in the background..."
ssh -i "$KEY" -o StrictHostKeyChecking=no -N -f -L 6443:"${ENDPOINT_HOST}":443 ec2-user@"$BASTION_IP"

# 3. Update local kubeconfig
echo "Updating local kubeconfig..."
aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$REGION"

# 4. Point the kubeconfig cluster server to localhost:6443 and skip verification
echo "Redirecting kubeconfig to use tunnel on localhost:6443..."
CONTEXT=$(kubectl config current-context)
CLUSTER_ARN=$(kubectl config view -o jsonpath="{.contexts[?(@.name=='$CONTEXT')].context.cluster}")
kubectl config set-cluster "$CLUSTER_ARN" --server="https://localhost:6443" --insecure-skip-tls-verify=true

echo "Kubectl tunnel setup complete! Testing connection..."
kubectl get nodes
