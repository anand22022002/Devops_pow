##############################################
# IAM Module
# IRSA roles for in-cluster controllers:
#   - AWS Load Balancer Controller
#   - External DNS
#   - EBS CSI Driver
#   - ArgoCD Image Updater (GHCR pull)
##############################################

data "aws_caller_identity" "current" {}

locals {
  oidc_url = var.oidc_provider_url
  oidc_arn = var.oidc_provider_arn
}

##############################################
# AWS Load Balancer Controller — IRSA Role
# Needs to create/manage ALBs on behalf of Gateway/Ingress resources
##############################################
resource "aws_iam_role" "alb_controller" {
  name = "${var.cluster_name}-alb-controller-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = local.oidc_arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${local.oidc_url}:sub" = "system:serviceaccount:kube-system:aws-load-balancer-controller"
          "${local.oidc_url}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })

  tags = { Name = "${var.cluster_name}-alb-controller-role" }
}

resource "aws_iam_policy" "alb_controller" {
  name        = "${var.cluster_name}-alb-controller-policy"
  description = "AWS Load Balancer Controller IAM policy"

  # Full policy from the AWS LBC docs
  policy = file("${path.module}/policies/alb-controller-policy.json")
}

resource "aws_iam_role_policy_attachment" "alb_controller" {
  role       = aws_iam_role.alb_controller.name
  policy_arn = aws_iam_policy.alb_controller.arn
}

##############################################
# External DNS — IRSA Role
# Manages Route53 records automatically as
# Gateway/Service resources change.
##############################################
resource "aws_iam_role" "external_dns" {
  name = "${var.cluster_name}-external-dns-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = local.oidc_arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${local.oidc_url}:sub" = "system:serviceaccount:kube-system:external-dns"
          "${local.oidc_url}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })

  tags = { Name = "${var.cluster_name}-external-dns-role" }
}

resource "aws_iam_policy" "external_dns" {
  name        = "${var.cluster_name}-external-dns-policy"
  description = "External DNS: manage Route53 records"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["route53:ChangeResourceRecordSets"]
        Resource = ["arn:aws:route53:::hostedzone/*"]
      },
      {
        Effect   = "Allow"
        Action   = ["route53:ListHostedZones", "route53:ListResourceRecordSets"]
        Resource = ["*"]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "external_dns" {
  role       = aws_iam_role.external_dns.name
  policy_arn = aws_iam_policy.external_dns.arn
}

##############################################
# EBS CSI Driver — IRSA Role
##############################################
resource "aws_iam_role" "ebs_csi" {
  name = "${var.cluster_name}-ebs-csi-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = local.oidc_arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${local.oidc_url}:sub" = "system:serviceaccount:kube-system:ebs-csi-controller-sa"
          "${local.oidc_url}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })

  tags = { Name = "${var.cluster_name}-ebs-csi-role" }
}

resource "aws_iam_role_policy_attachment" "ebs_csi" {
  role       = aws_iam_role.ebs_csi.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}
