##############################################################
# Global
##############################################################
project_name = "kubeinfra"
aws_region   = "ap-south-1" # Mumbai — change to your preferred region

##############################################################
# Remote State S3 Bucket
##############################################################
tfstate_bucket_name = "devopsdock-tfstate-222634375010"

##############################################################
# VPC — 2 AZ for HA
##############################################################
azs                  = ["ap-south-1a", "ap-south-1b"]
public_subnet_cidrs  = ["10.0.0.0/24", "10.0.1.0/24"]
private_subnet_cidrs = ["10.0.10.0/24", "10.0.11.0/24"]
single_nat_gateway   = true # Set false for production HA

# IMPORTANT: Lock this to your actual IP for production
# bastion_ingress_cidrs = ["<YOUR_PUBLIC_IP>/32"]

##############################################################
# Bastion Host
##############################################################
bastion_instance_type = "t3.micro"
# Set before apply: export TF_VAR_bastion_public_key=$(cat ~/.ssh/kubeinfra-bastion.pub)

##############################################################
# EKS
##############################################################
eks_cluster_version = "1.31"
node_capacity_type  = "ON_DEMAND"
node_instance_types = ["t3.medium"]
node_desired_size   = 2
node_min_size       = 1
node_max_size       = 4
node_disk_size_gb   = 20

##############################################################
# DNS / TLS
##############################################################
domain_name = "kubeinfra.site"
