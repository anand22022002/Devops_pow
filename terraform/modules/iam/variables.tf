variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "oidc_provider_arn" {
  description = "OIDC provider ARN from EKS module output"
  type        = string
}

variable "oidc_provider_url" {
  description = "OIDC provider URL (without https://) from EKS module output"
  type        = string
}
