##############################################
# VPC
##############################################
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true # Required for EKS

  tags = {
    Name    = "${var.project_name}-vpc"
    Project = var.project_name
  }
}

##############################################
# Internet Gateway
##############################################
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name    = "${var.project_name}-igw"
    Project = var.project_name
  }
}

##############################################
# Public Subnets — 2 AZs (ALB + Bastion + NAT)
##############################################
resource "aws_subnet" "public" {
  count                   = length(var.azs)
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.azs[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name                                        = "${var.project_name}-public-${var.azs[count.index]}"
    Project                                     = var.project_name
    "kubernetes.io/role/elb"                    = "1"        # ALB controller discovers these
    "kubernetes.io/cluster/${var.project_name}" = "shared"
  }
}

##############################################
# Private Subnets — 2 AZs (EKS worker nodes)
##############################################
resource "aws_subnet" "private" {
  count             = length(var.azs)
  vpc_id            = aws_vpc.this.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.azs[count.index]

  tags = {
    Name                                        = "${var.project_name}-private-${var.azs[count.index]}"
    Project                                     = var.project_name
    "kubernetes.io/role/internal-elb"           = "1"        # Internal LB discovery
    "kubernetes.io/cluster/${var.project_name}" = "shared"
  }
}

##############################################
# NAT Gateway — single for dev (cost-optimised)
# For production: one NAT per AZ (high-availability)
##############################################
resource "aws_eip" "nat" {
  count  = var.single_nat_gateway ? 1 : length(var.azs)
  domain = "vpc"

  tags = {
    Name    = "${var.project_name}-nat-eip-${count.index}"
    Project = var.project_name
  }

  depends_on = [aws_internet_gateway.this]
}

resource "aws_nat_gateway" "this" {
  count         = var.single_nat_gateway ? 1 : length(var.azs)
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = {
    Name    = "${var.project_name}-nat-${count.index}"
    Project = var.project_name
  }

  depends_on = [aws_internet_gateway.this]
}

##############################################
# Route Tables
##############################################

# Public — route all traffic to IGW
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = {
    Name    = "${var.project_name}-public-rt"
    Project = var.project_name
  }
}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Private — egress only via NAT (nodes can pull images, no inbound from internet)
resource "aws_route_table" "private" {
  count  = var.single_nat_gateway ? 1 : length(var.azs)
  vpc_id = aws_vpc.this.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = var.single_nat_gateway ? aws_nat_gateway.this[0].id : aws_nat_gateway.this[count.index].id
  }

  tags = {
    Name    = "${var.project_name}-private-rt-${count.index}"
    Project = var.project_name
  }
}

resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = var.single_nat_gateway ? aws_route_table.private[0].id : aws_route_table.private[count.index].id
}

##############################################
# Security Groups
##############################################

# ALB — inbound 80/443 from internet
resource "aws_security_group" "alb" {
  name        = "${var.project_name}-alb-sg"
  description = "ALB: inbound HTTP/HTTPS from internet"
  vpc_id      = aws_vpc.this.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.project_name}-alb-sg"
    Project = var.project_name
  }
}

# Bastion — SSH from operator IP only
resource "aws_security_group" "bastion" {
  name        = "${var.project_name}-bastion-sg"
  description = "Bastion: SSH from operator CIDR only"
  vpc_id      = aws_vpc.this.id

  ingress {
    description = "SSH from operator"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.bastion_ingress_cidrs
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.project_name}-bastion-sg"
    Project = var.project_name
  }
}

# EKS Nodes — from ALB + bastion + node-to-node
resource "aws_security_group" "eks_nodes" {
  name        = "${var.project_name}-eks-node-sg"
  description = "EKS nodes: from ALB, bastion, and self"
  vpc_id      = aws_vpc.this.id

  ingress {
    description     = "From ALB"
    from_port       = 0
    to_port         = 65535
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  # Bastion needs to reach EKS API server (443) and nodes (kubectl exec)
  ingress {
    description     = "From Bastion"
    from_port       = 0
    to_port         = 65535
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }

  ingress {
    description = "Node to node (pod networking)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.project_name}-eks-node-sg"
    Project = var.project_name
  }
}
