variable "project_name" {
  type = string
}

variable "public_subnet_id" {
  description = "Public subnet to place the bastion in"
  type        = string
}

variable "bastion_sg_id" {
  description = "Security group for the bastion host"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type for bastion (t2.micro is plenty)"
  type        = string
  default     = "t2.micro"
}

variable "bastion_public_key" {
  description = "SSH public key content (paste the value of ~/.ssh/id_rsa.pub)"
  type        = string
  sensitive   = true
}
