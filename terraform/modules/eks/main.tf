##############################################
# IAM Role — EKS Control Plane
##############################################
resource "aws_iam_role" "cluster" {
  name = "${var.cluster_name}-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "eks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = { Name = "${var.cluster_name}-cluster-role" }
}

resource "aws_iam_role_policy_attachment" "cluster_policy" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role_policy_attachment" "cluster_vpc_controller" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
}

##############################################
# EKS Cluster — PRIVATE endpoint only
# All kubectl access must go through the bastion host.
# This matches a real enterprise zero-trust setup.
##############################################
resource "aws_eks_cluster" "this" {
  name     = var.cluster_name
  version  = var.cluster_version
  role_arn = aws_iam_role.cluster.arn

  vpc_config {
    subnet_ids              = var.private_subnet_ids
    security_group_ids      = [var.node_security_group_id]
    endpoint_private_access = true
    endpoint_public_access  = false  # No direct kubectl from internet — bastion only
  }

  # All 5 log types for audit trail + debugging
  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  tags = { Name = var.cluster_name }

  depends_on = [
    aws_iam_role_policy_attachment.cluster_policy,
    aws_iam_role_policy_attachment.cluster_vpc_controller,
  ]
}

##############################################
# OIDC Provider — IRSA
# Allows pods to assume scoped IAM roles via
# service account token exchange. No node-level
# IAM role sprawl.
##############################################
data "tls_certificate" "cluster" {
  url = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "this" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.cluster.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.this.identity[0].oidc[0].issuer

  tags = { Name = "${var.cluster_name}-oidc" }
}

##############################################
# IAM Role — Managed Node Group (worker nodes)
##############################################
resource "aws_iam_role" "node_group" {
  name = "${var.cluster_name}-node-group-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = { Name = "${var.cluster_name}-node-group-role" }
}

resource "aws_iam_role_policy_attachment" "node_worker" {
  role       = aws_iam_role.node_group.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "node_cni" {
  role       = aws_iam_role.node_group.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "node_ecr_readonly" {
  role       = aws_iam_role.node_group.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "node_ebs_csi" {
  role       = aws_iam_role.node_group.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

##############################################
# EKS Managed Node Group
# Nodes in private subnets only — never directly
# internet-accessible.
##############################################
resource "aws_eks_node_group" "this" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${var.cluster_name}-ng"
  node_role_arn   = aws_iam_role.node_group.arn
  subnet_ids      = var.private_subnet_ids

  capacity_type  = var.node_capacity_type
  instance_types = var.node_instance_types

  scaling_config {
    desired_size = var.node_desired_size
    min_size     = var.node_min_size
    max_size     = var.node_max_size
  }

  ami_type  = "AL2_x86_64"
  disk_size = var.node_disk_size_gb

  update_config {
    max_unavailable = 1
  }

  labels = {
    role = "worker"
  }

  tags = {
    Name                                          = "${var.cluster_name}-ng"
    # Tags required for Cluster Autoscaler autodiscovery
    "k8s.io/cluster-autoscaler/${var.cluster_name}" = "owned"
    "k8s.io/cluster-autoscaler/enabled"             = "true"
  }

  depends_on = [
    aws_iam_role_policy_attachment.node_worker,
    aws_iam_role_policy_attachment.node_cni,
    aws_iam_role_policy_attachment.node_ecr_readonly,
    aws_iam_role_policy_attachment.node_ebs_csi,
  ]
}

##############################################
# EKS Managed Add-ons
##############################################

resource "aws_eks_addon" "coredns" {
  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "coredns"
  resolve_conflicts_on_update = "OVERWRITE"
  depends_on                  = [aws_eks_node_group.this]
  tags                        = { Name = "${var.cluster_name}-coredns" }
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "kube-proxy"
  resolve_conflicts_on_update = "OVERWRITE"
  depends_on                  = [aws_eks_node_group.this]
  tags                        = { Name = "${var.cluster_name}-kube-proxy" }
}

resource "aws_eks_addon" "vpc_cni" {
  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "vpc-cni"
  resolve_conflicts_on_update = "OVERWRITE"
  depends_on                  = [aws_eks_node_group.this]
  tags                        = { Name = "${var.cluster_name}-vpc-cni" }
}

resource "aws_eks_addon" "ebs_csi" {
  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "aws-ebs-csi-driver"
  resolve_conflicts_on_update = "OVERWRITE"
  # Attach IRSA role so the add-on can manage EBS volumes
  service_account_role_arn    = var.ebs_csi_irsa_role_arn
  depends_on                  = [aws_eks_node_group.this]
  tags                        = { Name = "${var.cluster_name}-ebs-csi" }
}

# Pod Identity Agent — newer alternative to IRSA for pod-level AWS identity
resource "aws_eks_addon" "pod_identity_agent" {
  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "eks-pod-identity-agent"
  resolve_conflicts_on_update = "OVERWRITE"
  depends_on                  = [aws_eks_node_group.this]
  tags                        = { Name = "${var.cluster_name}-pod-identity-agent" }
}
