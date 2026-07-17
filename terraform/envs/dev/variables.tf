##############################################################
# Global
##############################################################
variable "project_name" {
  description = "Short name used as a prefix for all AWS resources"
  type        = string
}

variable "aws_region" {
  description = "AWS region to deploy everything into"
  type        = string
}

##############################################################
# Remote State
##############################################################
variable "tfstate_bucket_name" {
  description = "S3 bucket name for Terraform remote state (globally unique)"
  type        = string
}

##############################################################
# VPC
##############################################################
variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "azs" {
  description = "Exactly 2 availability zones for HA"
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "One public subnet CIDR per AZ"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "One private subnet CIDR per AZ (EKS nodes)"
  type        = list(string)
}

variable "single_nat_gateway" {
  description = "true = one NAT (dev). false = one NAT per AZ (production)"
  type        = bool
  default     = true
}

##############################################################
# Bastion
##############################################################
variable "bastion_instance_type" {
  type    = string
  default = "t3.micro"
}

variable "bastion_public_key" {
  description = "SSH public key content. Set via: export TF_VAR_bastion_public_key=$(cat ~/.ssh/devopsdock-bastion.pub)"
  type        = string
  sensitive   = true
}

variable "bastion_ingress_cidrs" {
  description = "CIDRs allowed to SSH to the bastion. Restrict to your IP in production."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

##############################################################
# EKS
##############################################################
variable "eks_cluster_version" {
  type    = string
  default = "1.30"
}

variable "node_capacity_type" {
  description = "ON_DEMAND or SPOT"
  type        = string
  default     = "ON_DEMAND"
}

variable "node_instance_types" {
  type    = list(string)
  default = ["t3.medium"]
}

variable "node_desired_size" {
  type    = number
  default = 2
}

variable "node_min_size" {
  type    = number
  default = 1
}

variable "node_max_size" {
  type    = number
  default = 4
}

variable "node_disk_size_gb" {
  type    = number
  default = 20
}

##############################################################
# DNS / TLS — optional (enable when you have a real domain)
##############################################################
variable "domain_name" {
  description = "Root domain (e.g. devopsdock.site). Leave empty if using nip.io or raw ALB hostname."
  type        = string
  default     = ""  # Not required until Route53 module is uncommented
}
