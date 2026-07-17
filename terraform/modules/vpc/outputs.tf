output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.this.id
}

output "public_subnet_ids" {
  description = "IDs of public subnets (ALB, Bastion, NAT)"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs of private subnets (EKS nodes)"
  value       = aws_subnet.private[*].id
}

output "alb_sg_id" {
  description = "Security group ID for the ALB"
  value       = aws_security_group.alb.id
}

output "bastion_sg_id" {
  description = "Security group ID for the bastion host"
  value       = aws_security_group.bastion.id
}

output "eks_nodes_sg_id" {
  description = "Security group ID for EKS worker nodes"
  value       = aws_security_group.eks_nodes.id
}
