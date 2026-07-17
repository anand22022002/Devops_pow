variable "cluster_name" {
  description = "EKS cluster name (reuses project_name)"
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.30"
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for EKS nodes (from VPC module output)"
  type        = list(string)
}

variable "node_security_group_id" {
  description = "Security group ID for worker nodes (from VPC module output)"
  type        = string
}

variable "node_capacity_type" {
  description = "ON_DEMAND or SPOT"
  type        = string
  default     = "ON_DEMAND"
}

variable "node_instance_types" {
  description = "EC2 instance types for node group"
  type        = list(string)
  default     = ["t3.medium"]
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


variable "ebs_csi_irsa_role_arn" {
  description = "IRSA role ARN for the EBS CSI driver (from iam module output)"
  type        = string
  default     = ""
}
