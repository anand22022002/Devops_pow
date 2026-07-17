# 🚀 kubeinfra — Master Plan & Progress Tracker

> **Goal:** Production-shaped GitOps-driven EKS platform on AWS. End-to-end DevOps lifecycle: IaC → CI/CD → GitOps → Security → Observability → DR.

---

## 📁 Repository Layout (all files written ✅)

```
Devops_pow/
├── .gitignore
├── README.md
├── terraform/
│   ├── modules/
│   │   ├── s3-backend/       ✅
│   │   ├── vpc/              ✅
│   │   ├── bastion/          ✅
│   │   ├── eks/              ✅
│   │   ├── iam/              ✅ (+ policies/alb-controller-policy.json)
│   │   └── route53/          ✅
│   └── envs/dev/
│       ├── provider.tf       ✅ (S3 backend block ready to uncomment)
│       ├── main.tf           ✅ wires all 6 modules
│       ├── variables.tf      ✅
│       ├── terraform.tfvars  ✅ (EDIT YOUR VALUES HERE)
│       └── outputs.tf        ✅
│
├── ci/.github/workflows/
│   ├── ci.yaml               ✅ SonarQube → Trivy → Push to GHCR
│   └── pr-checks.yaml        ✅ Terraform fmt/validate + k8s lint
│
├── k8s-manifests/
│   ├── gateway-api/          ✅ GatewayClass + Gateway + 5 HTTPRoutes
│   ├── boutique-app/         ✅ frontend, cart, redis + NetworkPolicies + HPA
│   ├── argocd/               ✅ Application CR + Image Updater config
│   ├── logging/              ✅ ECK: ES + Kibana + Filebeat DaemonSet + RBAC
│   ├── monitoring/           ✅ kube-prometheus-stack + Grafana + Slack alerts
│   └── networking/           ✅ AWS LBC + External DNS Helm values
│
└── scripts/
    ├── bootstrap.sh          ✅ one-shot stand-up
    ├── kubeconfig.sh         ✅ bastion SSH tunnel guide
    └── destroy.sh            ✅ ordered tear-down
```

---

## 📋 Phase-by-Phase Checklist

### 🔲 Phase 0 — Pre-requisites (do first, costs nothing)

- [ ] Push repo to GitHub: `git init && git remote add origin <URL> && git push`
- [ ] Generate SSH key: `ssh-keygen -t rsa -b 4096 -f ~/.ssh/kubeinfra-bastion`
- [ ] Set env var: `export TF_VAR_bastion_public_key=$(cat ~/.ssh/kubeinfra-bastion.pub)`
- [ ] Edit `terraform/envs/dev/terraform.tfvars`:
  - Replace `kubeinfra-tfstate-123456789012` with your AWS account ID
  - Confirm `aws_region` (default: `ap-south-1`)
- [ ] Add GitHub Secrets: `SONAR_TOKEN`, `SONAR_HOST_URL`

---

### 🔲 Phase 1 — S3 Remote State Bootstrap

```bash
cd terraform/envs/dev
terraform init
terraform apply -target=module.s3_backend
# Then uncomment backend block in provider.tf:
terraform init -migrate-state
```

- [ ] S3 bucket created
- [ ] State migrated to S3

---

### 🔲 Phase 2 — Full Infrastructure Apply (~20 min)

```bash
terraform apply
```

- [ ] VPC + 2-AZ subnets in AWS console
- [ ] Bastion EC2 running, EIP assigned
- [ ] EKS cluster ACTIVE (private endpoint)

---

### 🔲 Phase 3 — Cluster Access via Bastion

```bash
ssh -i ~/.ssh/kubeinfra-bastion ec2-user@$(terraform output -raw bastion_public_ip)
# On bastion:
aws eks update-kubeconfig --name kubeinfra --region ap-south-1
kubectl get nodes        # 2 nodes Ready
kubectl get pods -n kube-system  # coredns, kube-proxy, vpc-cni, ebs-csi all running
```

---

### 🔲 Phase 4 — Install In-Cluster Components

```bash
# AWS LBC (update role ARN in values.yaml first)
helm repo add eks https://aws.github.io/eks-charts && helm repo update
helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system -f k8s-manifests/networking/aws-lb-controller/values.yaml

# External DNS (optional — skipped for now)
# helm repo add bitnami https://charts.bitnami.com/bitnami
# helm upgrade --install external-dns bitnami/external-dns \
#   -n kube-system -f k8s-manifests/networking/external-dns/values.yaml

# ArgoCD
helm repo add argo https://argoproj.github.io/argo-helm
kubectl create ns argocd
helm upgrade --install argocd argo/argo-cd -n argocd --set server.insecure=true

# Monitoring
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
kubectl create ns monitoring
helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  -n monitoring -f k8s-manifests/monitoring/prometheus/values.yaml

# ECK Logging
kubectl create ns logging
kubectl apply -f https://download.elastic.co/downloads/eck/2.12.1/crds.yaml
kubectl apply -f https://download.elastic.co/downloads/eck/2.12.1/operator.yaml
sleep 30
kubectl apply -f k8s-manifests/logging/eck-stack.yaml
```

- [ ] ALB controller running
- [ ] ArgoCD UI accessible (via port-forward or ALB hostname)
- [ ] Grafana accessible (via port-forward or ALB hostname)
- [ ] Kibana accessible (via port-forward or ALB hostname)

---

### 🔲 Phase 5 — Gateway API + App Deployment

```bash
kubectl apply -f k8s-manifests/gateway-api/
kubectl apply -f k8s-manifests/argocd/apps/
```

- [ ] Boutique frontend loads (via port-forward or ALB hostname)
- [ ] ArgoCD shows boutique-app as Healthy + Synced
- [ ] Kibana shows pod logs
- [ ] Grafana shows metrics

---

### 🔲 Phase 6 — CI Pipeline Test

- [ ] Push a code change to `app/` → GitHub Actions triggers
- [ ] SonarQube gate passes
- [ ] Trivy scan passes (no HIGH/CRITICAL)
- [ ] Image pushed to GHCR
- [ ] ArgoCD Image Updater detects tag → ArgoCD syncs → pods roll out

---

### 🔲 Phase 7 — HPA + Alerting Demo

```bash
# Load generator
kubectl run load-gen --image=busybox -n boutique -- \
  /bin/sh -c "while true; do wget -q -O- http://frontend; done"
kubectl get hpa -n boutique -w
```

- [ ] HPA scales frontend replicas under load
- [ ] Slack receives Alertmanager notification

---

### 🔲 Phase 8 — DR: Velero + MinIO (planned next)

- [ ] Install MinIO in cluster
- [ ] Install Velero with MinIO backend
- [ ] Schedule daily namespace backups
- [ ] Test restore from backup

---

### 🔲 Phase 9 — Secrets Management: ESO (planned next)

- [ ] Install External Secrets Operator
- [ ] Store secrets in AWS Secrets Manager
- [ ] Create `SecretStore` + `ExternalSecret` CRs
- [ ] Verify secrets sync to K8s `Secret` objects

---

## 💰 Cost Control

| Resource | ~$/mo |
|---|---|
| EKS Control Plane | $72 |
| 2× t3.medium nodes | $60 |
| NAT Gateway (single) | $32 |
| Bastion t2.micro | $8 |
| **Total** | **~$172** |

```bash
bash scripts/destroy.sh   # pause everything, state preserved in S3
bash scripts/bootstrap.sh # recreate from scratch in ~20 min
```

---

## 🎯 Interview Talking Points

| Topic | What to Say |
|---|---|
| Private EKS | "API server has public access disabled. Only way in is bastion → kubectl from inside VPC. Real zero-trust production pattern." |
| Gateway API | "Used Gateway API (not Ingress-NGINX) — the modern replacement. One shared ALB fans out to all subdomains/routes via HTTPRoute rules." |
| IRSA | "Each pod controller gets a scoped IAM role via IRSA. ALB controller can create ALBs, External DNS can edit Route53 (when wired up) — nothing else." |
| Image Updater | "ArgoCD Image Updater polls GHCR, detects new digest, commits updated tag to git. ArgoCD reconciles. Zero manual intervention." |
| Trivy gate | "Trivy runs before the push step. HIGH or CRITICAL CVEs = workflow fails. Image cannot reach GHCR until clean." |
| ECK logging | "Filebeat DaemonSet runs on every node, captures all container stdout/stderr. Indexed in Elasticsearch, visualized in Kibana." |
| NetworkPolicies | "Default-deny in boutique namespace. Only: internet→frontend, frontend→cartservice, cartservice→redis. Frontend→redis is blocked at CNI level." |

---

*Last updated: 2026-07-16 | Project: kubeinfra*
