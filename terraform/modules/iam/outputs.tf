output "alb_controller_role_arn" {
  description = "IRSA role ARN for AWS Load Balancer Controller"
  value       = aws_iam_role.alb_controller.arn
}

output "external_dns_role_arn" {
  description = "IRSA role ARN for External DNS"
  value       = aws_iam_role.external_dns.arn
}

output "ebs_csi_role_arn" {
  description = "IRSA role ARN for EBS CSI Driver"
  value       = aws_iam_role.ebs_csi.arn
}
