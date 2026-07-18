#!/usr/bin/env bash
# =============================================================================
# bootstrap.sh — One-shot kubeinfra platform stand-up
# Run from the repo root: bash scripts/bootstrap.sh
# =============================================================================
set -euo pipefail

REGION="ap-south-1"
PROJECT="kubeinfra"
TF_DIR="terraform/envs/dev"

echo "=============================="
echo " kubeinfra Bootstrap"
echo "=============================="

# ─── Step 0: Pre-flight checks ────────────────────────────────────────────────
for cmd in terraform aws kubectl helm; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "ERROR: $cmd is not installed or not in PATH"
    exit 1
  fi
done

echo "All CLI tools found."
aws sts get-caller-identity --query 'Account' --output text

# Auto-load or check SSH public key for the bastion
if [ -z "${TF_VAR_bastion_public_key:-}" ]; then
  PUB_KEY_PATH="$HOME/.ssh/kubeinfra-bastion.pub"
  if [ -f "$PUB_KEY_PATH" ]; then
    echo "Found SSH public key at $PUB_KEY_PATH. Exporting..."
    export TF_VAR_bastion_public_key=$(cat "$PUB_KEY_PATH")
  else
    echo "ERROR: No SSH key found at $PUB_KEY_PATH and TF_VAR_bastion_public_key is not set."
    echo "Please generate one: ssh-keygen -t rsa -b 4096 -f ~/.ssh/kubeinfra-bastion"
    exit 1
  fi
fi

# ─── Step 1: Bootstrap S3 remote state ────────────────────────────────────────
cd "$TF_DIR"

if grep -q '^[[:space:]]*backend "s3"' provider.tf; then
  echo ""
  echo ">>> S3 backend is already active in provider.tf. Initializing backend..."
  terraform init
else
  echo ""
  echo ">>> Phase 0: Bootstrap S3 remote state..."
  terraform init
  terraform apply -target=module.s3_backend -auto-approve

  echo ""
  echo ">>> Migrating local state to S3..."
  echo "Uncomment the S3 backend block in provider.tf, then run: terraform init -migrate-state"
  echo "Press ENTER when done, or Ctrl+C to stop here."
  read -r
fi

# ─── Step 2: Full infrastructure apply ────────────────────────────────────────
echo ""
echo ">>> Phase 1-5: Applying full infrastructure (VPC + Bastion + EKS + IAM + Route53)..."
echo "This takes ~20 minutes..."
terraform apply -auto-approve

# ─── Step 3: Configure kubectl via bastion ────────────────────────────────────
echo ""
echo ">>> Configuring kubectl..."
bash ../../../scripts/kubeconfig.sh

echo ">>> Pre-installing Gateway API CRDs..."
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.1.0/standard-install.yaml

# ─── Step 4: Install in-cluster components ────────────────────────────────────
echo ""
echo ">>> Installing AWS Load Balancer Controller..."
helm repo add eks https://aws.github.io/eks-charts
helm repo update
ALB_ROLE=$(terraform output -raw alb_controller_role_arn)
sed -i 's|eks.amazonaws.com/role-arn:.*|eks.amazonaws.com/role-arn: "'"${ALB_ROLE}"'"|g' \
  ../../../k8s-manifests/networking/aws-lb-controller/values.yaml
helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  -f ../../../k8s-manifests/networking/aws-lb-controller/values.yaml

echo ">>> Restarting AWS Load Balancer Controller to load fresh certificates..."
kubectl rollout restart deployment aws-load-balancer-controller -n kube-system
kubectl rollout status deployment/aws-load-balancer-controller -n kube-system --timeout=120s
sleep 15

echo ""
echo ">>> Installing External DNS..."
helm repo add bitnami https://charts.bitnami.com/bitnami
EXTDNS_ROLE=$(terraform output -raw external_dns_role_arn)
ZONE_ID=$(terraform output -raw route53_zone_id)
sed -i 's|eks.amazonaws.com/role-arn:.*|eks.amazonaws.com/role-arn: "'"${EXTDNS_ROLE}"'"|g' \
  ../../../k8s-manifests/networking/external-dns/values.yaml
sed -i "s|REPLACE_WITH_HOSTED_ZONE_ID|${ZONE_ID}|g" ../../../k8s-manifests/networking/external-dns/values.yaml
sed -i 's|- "Z[A-Z0-9]*"|- "'"${ZONE_ID}"'"|g' ../../../k8s-manifests/networking/external-dns/values.yaml
helm upgrade --install external-dns bitnami/external-dns \
  -n kube-system \
  -f ../../../k8s-manifests/networking/external-dns/values.yaml

echo ""
echo ">>> Installing ArgoCD..."
helm repo add argo https://argoproj.github.io/argo-helm
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
helm upgrade --install argocd argo/argo-cd \
  -n argocd \
  --set server.insecure=true   # ALB handles TLS

echo ""
echo ">>> Installing ArgoCD Image Updater..."
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj-labs/argocd-image-updater/stable/config/install.yaml
kubectl apply -f ../../../k8s-manifests/argocd/image-updater/config.yaml

echo ""
echo ">>> Installing Monitoring stack..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  -n monitoring \
  -f ../../../k8s-manifests/monitoring/prometheus/values.yaml

echo ""
echo ">>> Installing ECK Operator..."
kubectl create namespace logging --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f https://download.elastic.co/downloads/eck/2.12.1/crds.yaml
kubectl apply -f https://download.elastic.co/downloads/eck/2.12.1/operator.yaml
sleep 30
kubectl apply -f ../../../k8s-manifests/logging/eck-stack.yaml

echo ""
echo ">>> Deploying Gateway API resources..."
kubectl create namespace boutique --dry-run=client -o yaml | kubectl apply -f -
ACM_CERT=$(terraform output -raw acm_certificate_arn)
sed -i 's|alb.gateway.k8s.aws/certificate-arn:.*|alb.gateway.k8s.aws/certificate-arn: "'"${ACM_CERT}"'"|g' \
  ../../../k8s-manifests/gateway-api/gateway.yaml
kubectl apply -f ../../../k8s-manifests/gateway-api/

echo ""
echo ">>> Deploying ArgoCD Application CRs..."
kubectl apply -f ../../../k8s-manifests/argocd/apps/

echo ""
echo "=============================="
echo " Bootstrap Complete!"
echo "=============================="
echo ""
echo "Key outputs:"
terraform output
# echo ""
# echo "Point your domain registrar NS records to:"
# terraform output route53_name_servers
