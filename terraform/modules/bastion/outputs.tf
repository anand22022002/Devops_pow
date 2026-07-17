output "bastion_public_ip" {
  description = "Elastic IP of bastion host — use this in your SSH config"
  value       = aws_eip.bastion.public_ip
}

output "bastion_instance_id" {
  description = "Instance ID (for SSM Session Manager as an alternative to SSH)"
  value       = aws_instance.bastion.id
}

output "ssh_command" {
  description = "Ready-to-use SSH command"
  value       = "ssh -i ~/.ssh/kubeinfra-bastion ec2-user@${aws_eip.bastion.public_ip}"
}
