variable "project_name" {
  description = "Prefix for all resource names and EKS cluster tags"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "azs" {
  description = "List of availability zones (exactly 2 for this project)"
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets (one per AZ)"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets — EKS worker nodes (one per AZ)"
  type        = list(string)
}

variable "single_nat_gateway" {
  description = "true = single NAT (dev/cost-saving). false = one NAT per AZ (HA/production)"
  type        = bool
  default     = true
}

variable "bastion_ingress_cidrs" {
  description = "CIDR(s) allowed to SSH into the bastion host. Restrict to your IP in production."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}


