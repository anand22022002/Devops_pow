##############################################
# Route53 Hosted Zone
##############################################
resource "aws_route53_zone" "main" {
  name = var.domain_name

  tags = {
    Name    = var.domain_name
    Project = var.project_name
  }
}

##############################################
# ACM Certificate — wildcard + apex
# Covers: kubeinfra.site, *.kubeinfra.site
# (app, argocd, grafana, kibana, prometheus)
##############################################
resource "aws_acm_certificate" "this" {
  domain_name               = var.domain_name
  subject_alternative_names = ["*.${var.domain_name}"]
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name    = "${var.project_name}-cert"
    Project = var.project_name
  }
}

##############################################
# DNS Validation Records
##############################################
resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.this.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = aws_route53_zone.main.zone_id
}

resource "aws_acm_certificate_validation" "this" {
  certificate_arn         = aws_acm_certificate.this.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}
