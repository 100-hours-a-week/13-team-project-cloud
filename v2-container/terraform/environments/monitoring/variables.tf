variable "project" {
  description = "Project name"
  type        = string
}

variable "ec2_ami_id" {
  description = "AMI ID for monitoring instance"
  type        = string
}

variable "ec2_instance_type" {
  description = "EC2 instance type for monitoring"
  type        = string
}

variable "ec2_key_name" {
  description = "SSH key pair name"
  type        = string
}

variable "root_volume_size" {
  description = "Root EBS volume size in GiB"
  type        = number
}

variable "grafana_cidrs" {
  description = "CIDR blocks allowed to access Grafana (3000)"
  type        = list(string)
}
