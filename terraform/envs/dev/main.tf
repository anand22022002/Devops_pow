##############################################
# Root Module — kubeinfra dev environment
# Wires all modules: s3_backend → vpc → eks → iam → route53
##############################################

##############################################
# Phase 0 — Remote State Bootstrap
# Apply this first: terraform apply -target=module.s3_backend
# Then uncomment S3 backend in provider.tf and run:
#   terraform init -migrate-state
##############################################
module "s3_backend" {
  source       = "../../modules/s3-backend"
  project_name = var.project_name
  bucket_name  = var.tfstate_bucket_name
}

##############################################
# Phase 1 — VPC + Networking
##############################################
module "vpc" {
  source = "../../modules/vpc"

  project_name          = var.project_name
  vpc_cidr              = var.vpc_cidr
  azs                   = var.azs
  public_subnet_cidrs   = var.public_subnet_cidrs
  private_subnet_cidrs  = var.private_subnet_cidrs
  single_nat_gateway    = var.single_nat_gateway
  bastion_ingress_cidrs = var.bastion_ingress_cidrs
}

##############################################
# Phase 2 — Bastion Host
# Single entry point into the private cluster.
# SSH to bastion, then kubectl from there.
##############################################
module "bastion" {
  source = "../../modules/bastion"

  project_name       = var.project_name
  public_subnet_id   = module.vpc.public_subnet_ids[0]
  bastion_sg_id      = module.vpc.bastion_sg_id
  instance_type      = var.bastion_instance_type
  bastion_public_key = var.bastion_public_key
}

##############################################
# Phase 3 — EKS Cluster (private, bastion-only access)
##############################################
module "eks" {
  source = "../../modules/eks"

  cluster_name           = var.project_name
  cluster_version        = var.eks_cluster_version
  private_subnet_ids     = module.vpc.private_subnet_ids
  node_security_group_id = module.vpc.eks_nodes_sg_id

  node_capacity_type  = var.node_capacity_type
  node_instance_types = var.node_instance_types
  node_desired_size   = var.node_desired_size
  node_min_size       = var.node_min_size
  node_max_size       = var.node_max_size
  node_disk_size_gb   = var.node_disk_size_gb

  ebs_csi_irsa_role_arn = module.iam.ebs_csi_role_arn
}

##############################################
# Phase 4 — IRSA Roles for in-cluster controllers
# Depends on EKS OIDC provider
##############################################
module "iam" {
  source = "../../modules/iam"

  cluster_name      = var.project_name
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider_url = module.eks.oidc_provider_url
}

##############################################
# Phase 4 — Route53 + ACM (DNS + TLS)
# SKIPPED: Enable when you have a real domain.
# Options:
#   A) Buy a cheap domain (.site/.xyz ~₹100/yr on GoDaddy)
#   B) Use nip.io free DNS: app.<ALB-IP>.nip.io
#   C) Access via raw ALB hostname for now (demo-friendly)
##############################################
module "route53" {
  source       = "../../modules/route53"
  project_name = var.project_name
  domain_name  = var.domain_name
}
