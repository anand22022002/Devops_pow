output "cluster_name" {
  description = "EKS cluster name"
  value       = aws_eks_cluster.this.name
}

output "cluster_endpoint" {
  description = "EKS API server endpoint (private)"
  value       = aws_eks_cluster.this.endpoint
}

output "cluster_ca_data" {
  description = "EKS cluster certificate authority data"
  value       = aws_eks_cluster.this.certificate_authority[0].data
}

output "oidc_provider_arn" {
  description = "OIDC provider ARN for IRSA"
  value       = aws_iam_openid_connect_provider.this.arn
}

output "oidc_provider_url" {
  description = "OIDC provider URL (without https://)"
  value       = replace(aws_eks_cluster.this.identity[0].oidc[0].issuer, "https://", "")
}

output "node_group_role_arn" {
  description = "IAM role ARN for the node group"
  value       = aws_iam_role.node_group.arn
}
