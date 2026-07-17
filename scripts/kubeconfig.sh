#!/usr/bin/env bash
# =============================================================================
# kubeconfig.sh — Configure kubectl to reach the private EKS cluster
# via an SSH tunnel through the bastion host.
#
# Usage: bash scripts/kubeconfig.sh
# =============================================================================
set -euo pipefail

TF_DIR="terraform/envs/dev"
REGION="ap-south-1"
KEY="~/.ssh/kubeinfra-bastion"

# ─── Get outputs from Terraform ───────────────────────────────────────────────
cd "$TF_DIR"
BASTION_IP=$(terraform output -raw bastion_public_ip)
CLUSTER_NAME=$(terraform output -raw eks_cluster_name)
cd - > /dev/null

echo "Bastion IP  : $BASTION_IP"
echo "Cluster     : $CLUSTER_NAME"

# ─── Update kubeconfig (works from inside the VPC — run on the bastion) ───────
# This script can be run ON the bastion directly via:
#   ssh ec2-user@<BASTION_IP> "aws eks update-kubeconfig --name kubeinfra --region ap-south-1"

echo ""
echo "To configure kubectl on the BASTION, run:"
echo "  ssh -i $KEY ec2-user@$BASTION_IP"
echo "  aws eks update-kubeconfig --name $CLUSTER_NAME --region $REGION"
echo "  kubectl get nodes"
echo ""
echo "To run kubectl from your LOCAL machine via SSH tunnel:"
echo "  ssh -i $KEY -L 6443:<CLUSTER_ENDPOINT>:443 ec2-user@$BASTION_IP -N &"
echo "  Then update your kubeconfig to point to localhost:6443"
echo ""
echo "Cluster endpoint (private):"
cd "$TF_DIR" && terraform output -raw eks_cluster_endpoint
