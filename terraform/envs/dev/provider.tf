##############################################
# Terraform + Provider Configuration
##############################################
terraform {
  required_version = ">= 1.7.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }

  # ─── Remote State Backend ───────────────────────────────────────────────────
  # After running: terraform apply -target=module.s3_backend
  # Uncomment this block and run: terraform init -migrate-state
  # ─────────────────────────────────────────────────────────────────────────────
  backend "s3" {
    bucket         = "devopsdock-tfstate-222634375010"
    key            = "envs/dev/terraform.tfstate"
    region         = "ap-south-1"
    encrypt        = true
    use_lockfile   = true
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = "dev"
      ManagedBy   = "Terraform"
    }
  }
}
