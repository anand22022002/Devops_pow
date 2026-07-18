#!/usr/bin/env bash
# =============================================================================
# destroy.sh — Tear down in correct reverse dependency order
# IMPORTANT: This deletes real AWS resources and incurs no further charges
#            after completion. Terraform state is preserved in S3.
# =============================================================================
set -euo pipefail

TF_DIR="terraform/envs/dev"

echo "=============================="
echo " kubeinfra — DESTROY"
echo "=============================="
echo "This will delete: EKS, Bastion, VPC, Route53, ACM, NAT Gateways"
echo "State is preserved in S3. You can recreate by running bootstrap.sh"
echo ""
read -rp "Type 'yes' to confirm: " confirm
[ "$confirm" = "yes" ] || { echo "Aborted."; exit 0; }

# ─── Establish SSH Tunnel for access ──────────────────────────────────────────
bash "$(dirname "$0")/kubeconfig.sh"

# ─── Clean up in-cluster resources first (otherwise VPC deletion fails) ───────
echo ""
echo ">>> Deleting K8s LoadBalancer Services (release ALB before terraform destroy)..."
kubectl delete svc -A -l "kubernetes.io/created-by=aws-load-balancer-controller" || true

echo ">>> Uninstalling Helm releases..."
for ns_release in \
  "monitoring/kube-prometheus-stack" \
  "kube-system/aws-load-balancer-controller" \
  "kube-system/external-dns" \
  "argocd/argocd"; do
  ns="${ns_release%%/*}"
  rel="${ns_release##*/}"
  helm uninstall "$rel" -n "$ns" 2>/dev/null || true
done

# ─── Destroy infrastructure ───────────────────────────────────────────────────
echo ""
echo ">>> Running terraform destroy..."
cd "$TF_DIR"

# Destroy in order to avoid dependency errors
terraform destroy \
  -target=module.eks \
  -target=module.bastion \
  -target=module.iam \
  -target=module.route53 \
  -auto-approve

terraform destroy \
  -target=module.vpc \
  -auto-approve

echo ""
echo ">>> Infrastructure destroyed."
echo "S3 state bucket preserved. Run bootstrap.sh to recreate."
