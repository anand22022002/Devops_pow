# kubeinfra — GitOps-Driven EKS Platform

> Production-shaped Kubernetes platform on AWS: IaC → CI/CD → GitOps → Security → Observability → DR

## Architecture

```mermaid
graph TD
    %% Styling
    classDef default fill:#f9f9f9,stroke:#333,stroke-width:1px;
    classDef aws fill:#FF9900,stroke:#232F3E,stroke-width:2px,color:white;
    classDef k8s fill:#326CE5,stroke:#fff,stroke-width:2px,color:white;
    classDef ext fill:#2ea44f,stroke:#fff,stroke-width:2px,color:white;

    %% External & Local
    Dev((Developer)) -->|1. Push Code| GH(GitHub Repository):::ext
    Dev -->|Infrastructure as Code| TF(Terraform)
    TF -.->|State Backup| S3(AWS S3 Backend):::aws
    User((End User)) -->|HTTPS Traffic| R53(Amazon Route 53):::aws
    
    %% CI Pipeline
    subgraph "Continuous Integration (GitHub Actions)"
        direction LR
        GH --> Checkout[Checkout Code]
        Checkout --> SonarQube[SonarQube Code Analysis]
        SonarQube --> Build[Build Docker Image]
        Build --> Trivy[Trivy Security Scan]
        Trivy --> PushImage[Push to Registry]
    end
    PushImage --> GHCR(GitHub Container Registry):::ext
    SonarQube -.->|Quality Gate Alerts| Slack(Slack Notifications)

    %% AWS Infrastructure
    TF -->|Provisions| VPC

    subgraph "AWS Environment"
        R53 -->|DNS Resolution| ACM(ACM Certificates):::aws
        R53 -->|Routes to| ALB(Application Load Balancer / LBC):::aws
        
        subgraph VPC ["AWS VPC"]
            direction TB
            subgraph PublicSubnet ["Public Subnet"]
                IGW[Internet Gateway]
                NAT[NAT Gateway]
                Bastion[Bastion Host]
                ALB
            end

            subgraph PrivateSubnet ["Private Subnet (Amazon EKS)"]
                direction TB
                
                %% CD Pipeline
                subgraph CD ["Continuous Delivery"]
                    ArgoCD(ArgoCD):::k8s
                end
                
                %% Core Application
                subgraph AppEnv ["Boutique Application"]
                    GatewayAPI[Gateway API / Ingress]
                    AppPods[Application Pods]
                    DBPods[Database Pods]
                    GatewayAPI --> AppPods
                    AppPods --> DBPods
                end
                
                %% Observability Stack
                subgraph Observability ["Logging & Monitoring"]
                    Prometheus(Prometheus) --> Grafana(Grafana)
                    Prometheus --> AlertManager(AlertManager)
                    ECK[ECK Operator / ElasticSearch]
                    FluentBit[FluentBit / Fluentd]
                end
            end
        end
    end

    %% Deployment flow
    GHCR -.->|Pulls New Image| ArgoCD
    GH -.->|Pulls K8s Manifests| ArgoCD
    ArgoCD -->|Syncs State| AppEnv
    
    %% Traffic & Alerts
    ALB --> GatewayAPI
    AlertManager -.->|Triggers Alerts| Slack
```

## Repository Layout

```
Devops_pow/
├── terraform/
│   ├── modules/
│   │   ├── vpc/          # VPC, subnets (2 AZ), NAT, SGs, bastion SG
│   │   ├── eks/          # EKS cluster, OIDC/IRSA, node group, add-ons
│   │   ├── bastion/      # Bastion host EC2 + key pair
│   │   ├── iam/          # IRSA roles: ALB controller, External DNS, ArgoCD
│   │   ├── s3-backend/   # Remote state bucket + DynamoDB lock table
│   │   └── route53/      # Hosted zone + ACM cert + DNS validation
│   └── envs/dev/         # Root module wiring all modules together
│
├── ci/
│   └── .github/workflows/
│       ├── ci.yaml           # Build → SonarQube → Trivy → Push to GHCR
│       └── pr-checks.yaml    # Lint + format checks on PRs
│
├── k8s-manifests/
│   ├── boutique-app/         # Online Boutique app (Kustomize base + dev overlay)
│   ├── argocd/               # ArgoCD Application CRs + Image Updater config
│   ├── gateway-api/          # GatewayClass, Gateway, HTTPRoute manifests
│   ├── logging/              # ECK operator, Elasticsearch, Kibana, Filebeat
│   ├── monitoring/           # Prometheus, Grafana, Alertmanager Helm values
│   ├── networking/           # AWS LB Controller + External DNS Helm values
│   ├── autoscaling/          # HPA manifests + load generator
│   └── dr/                   # Velero + MinIO for backup/restore
│
├── scripts/
│   ├── bootstrap.sh          # One-shot: init remote state → apply all Terraform
│   ├── kubeconfig.sh         # Configure kubectl via bastion tunnel
│   └── destroy.sh            # Tear-down in correct dependency order
│
└── docs/
    └── architecture-diagram.svg
```

## Quick Start

### Prerequisites
- AWS CLI configured (`aws configure`)
- Terraform ≥ 1.7
- kubectl, helm, argocd CLI

### Step 1 — Bootstrap Remote State
```bash
cd terraform/envs/dev
terraform init
terraform apply -target=module.s3_backend
```

### Step 2 — Provision Infrastructure
```bash
terraform apply   # VPC → Bastion → EKS → IAM → Route53 (~20 min)
```

### Step 3 — Configure kubectl (via bastion tunnel)
```bash
bash scripts/kubeconfig.sh
kubectl get nodes
```

### Step 4 — Install in-cluster components (via Helm through bastion)
```bash
# AWS Load Balancer Controller
helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system -f k8s-manifests/networking/aws-lb-controller/values.yaml

# External DNS
helm upgrade --install external-dns bitnami/external-dns \
  -n kube-system -f k8s-manifests/networking/external-dns/values.yaml

# ArgoCD
helm upgrade --install argocd argo/argo-cd \
  -n argocd --create-namespace -f k8s-manifests/argocd/values.yaml

# Monitoring stack
helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  -n monitoring --create-namespace -f k8s-manifests/monitoring/prometheus/values.yaml

# ECK Operator + stack
kubectl apply -f k8s-manifests/logging/
```

### Step 5 — Deploy App via ArgoCD
```bash
kubectl apply -f k8s-manifests/argocd/apps/
# ArgoCD auto-syncs boutique-app from this repo
```

## CI/CD Flow

1. `git push` → GitHub Actions triggers
2. **SonarQube** quality gate (fail = pipeline stops)
3. **Trivy** image scan (HIGH/CRITICAL = pipeline stops)
4. Push to **GHCR**
5. **GitHub Actions** automatically updates `kustomization.yaml` in Git with the new image tag (short commit SHA).
6. **ArgoCD** detects the git commit, reconciles the cluster, and triggers a rolling update of the new pods.

## Observability URLs (post-apply)

| Service | URL |
|---|---|
| App | `https://app.kubeinfra.site` |
| ArgoCD | `https://argocd.kubeinfra.site` |
| Grafana | `https://grafana.kubeinfra.site` |
| Kibana | `https://kibana.kubeinfra.site` |
| Prometheus | `https://prometheus.kubeinfra.site` |

## Proof of Work / Visual Flow

The following screenshots demonstrate the end-to-end working state of the platform: from infrastructure provisioning to CI/CD, GitOps deployment, and observability.

### 1. Infrastructure & Networking
![VPC Dashboard](docs/Images/vpc_dashboard.png)
*AWS VPC Dashboard showing the underlying network architecture (Subnets, NAT Gateways, Route Tables).*

![Route53 Hosted Zone](docs/Images/aws_hosted_zone.png)
*AWS Route53 Hosted Zone automatically configured for custom domain routing and ACM TLS validation.*

### 2. Kubernetes Cluster (Amazon EKS)
![EKS Nodes and Pods](docs/Images/K8s_nodes_pods.png)
*Kubernetes nodes and pods successfully provisioned and running the microservices stack.*

### 3. CI/CD & GitOps
![SonarQube Code Quality](docs/Images/sonarqube.png)
*SonarQube enforcing strict code quality and security gates before the Docker build proceeds.*

![GitHub Actions CI Pipeline](docs/Images/githubaction_ci_pipeline.png)
*GitHub Actions CI pipeline successfully building, scanning via Trivy, and pushing the container image.*

![ArgoCD GitOps Flow](docs/Images/argocd_flow.png)
*ArgoCD automatically detecting Git state changes and reconciling the EKS cluster (GitOps).*

### 4. Application & Routing
![Gateway API HTTPRoutes](docs/Images/all_httproute.png)
*Kubernetes Gateway API HTTPRoutes effectively managing ingress traffic via AWS ALB.*

![Live Application](docs/Images/app_deployed.png)
*The Online Boutique microservices application successfully deployed and accessible over HTTPS.*

### 5. Observability (Logging & Monitoring)
![Grafana Dashboard](docs/Images/grafana_dashboard.png)
*Grafana dashboard visualizing real-time cluster metrics pulled from Prometheus.*

![Kibana Logs](docs/Images/kibana_logs.png)
*Kibana interface centralizing and analyzing logs collected by Filebeat via Elasticsearch.*

## Cost Estimate (dev, always-on)

| Resource | ~Cost/mo |
|---|---|
| EKS Control Plane | $72 |
| 2× t3.medium nodes | $60 |
| NAT Gateway (single) | $32 |
| Bastion t3.micro | $8 |
| Route53 + ACM | $1 |
| **Total** | **~$173/mo** |

> 💡 Destroy NAT + EKS when not working. State is in S3 so you can recreate in ~20 min.
