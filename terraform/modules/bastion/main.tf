##############################################
# Bastion Host EC2
# Only entry point into the private EKS cluster.
# All kubectl/helm ops tunnel through this host.
##############################################

data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

resource "aws_key_pair" "bastion" {
  key_name   = "${var.project_name}-bastion-key"
  public_key = var.bastion_public_key

  tags = { Name = "${var.project_name}-bastion-key" }
}

resource "aws_instance" "bastion" {
  ami                    = data.aws_ami.amazon_linux_2.id
  instance_type          = var.instance_type
  subnet_id              = var.public_subnet_id
  key_name               = aws_key_pair.bastion.key_name
  vpc_security_group_ids = [var.bastion_sg_id]

  # Install kubectl, helm, aws cli on first boot
  user_data = base64encode(<<-EOF
    #!/bin/bash
    set -e
    yum update -y

    # AWS CLI v2
    curl -sSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
    unzip -q /tmp/awscliv2.zip -d /tmp && /tmp/aws/install

    # kubectl
    KUBECTL_VERSION=$(curl -s https://dl.k8s.io/release/stable.txt)
    curl -sSLO "https://dl.k8s.io/release/$${KUBECTL_VERSION}/bin/linux/amd64/kubectl"
    install -m 0755 kubectl /usr/local/bin/kubectl

    # Helm
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

    # ArgoCD CLI
    VERSION=$(curl --silent "https://api.github.com/repos/argoproj/argo-cd/releases/latest" | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')
    curl -sSL -o /usr/local/bin/argocd "https://github.com/argoproj/argo-cd/releases/download/$${VERSION}/argocd-linux-amd64"
    chmod +x /usr/local/bin/argocd

    echo "Bastion bootstrap complete" >> /var/log/bastion-bootstrap.log
  EOF
  )

  tags = {
    Name    = "${var.project_name}-bastion"
    Project = var.project_name
    Role    = "bastion"
  }
}

##############################################
# Elastic IP for Bastion — stable IP for SSH config
##############################################
resource "aws_eip" "bastion" {
  instance = aws_instance.bastion.id
  domain   = "vpc"

  tags = {
    Name    = "${var.project_name}-bastion-eip"
    Project = var.project_name
  }
}
