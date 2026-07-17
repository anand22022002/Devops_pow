output "bastion_ssh" {
  description = "SSH command to connect to the bastion host"
  value       = module.bastion.ssh_command
}

output "bastion_public_ip" {
  description = "Bastion host public IP (Elastic IP — stable)"
  value       = module.bastion.bastion_public_ip
}

output "eks_cluster_name" {
  value = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "Private API endpoint — only reachable from inside the VPC (via bastion)"
  value       = module.eks.cluster_endpoint
}

output "oidc_provider_arn" {
  description = "Use this to wire additional IRSA roles"
  value       = module.eks.oidc_provider_arn
}

output "alb_controller_role_arn" {
  value = module.iam.alb_controller_role_arn
}

output "external_dns_role_arn" {
  value = module.iam.external_dns_role_arn
}

output "route53_zone_id" {
  value = module.route53.zone_id
}

output "route53_name_servers" {
  description = "Add these NS records to your domain registrar"
  value       = module.route53.name_servers
}

output "acm_certificate_arn" {
  description = "Use in ALB annotations for TLS termination"
  value       = module.route53.certificate_arn
}

output "tfstate_bucket" {
  value = module.s3_backend.bucket_name
}
