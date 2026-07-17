output "zone_id" {
  description = "Route53 hosted zone ID"
  value       = aws_route53_zone.main.zone_id
}

output "name_servers" {
  description = "NS records — point your domain registrar to these"
  value       = aws_route53_zone.main.name_servers
}

output "certificate_arn" {
  description = "ACM certificate ARN (use in ALB annotation)"
  value       = aws_acm_certificate_validation.this.certificate_arn
}
