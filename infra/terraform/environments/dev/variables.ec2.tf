variable "ec2_instance_type" {
  description = "EC2 instance type for the single host"
  type        = string
}

variable "ec2_root_volume_size" {
  description = "Root EBS volume size in GiB"
  type        = number
}

variable "ec2_root_volume_type" {
  description = "Root EBS volume type"
  type        = string
}

variable "ec2_associate_public_ip_address" {
  description = "Whether to associate a public IP"
  type        = bool
}

variable "ec2_eip_allocation_id" {
  description = "Allocation ID for the Elastic IP to associate"
  type        = string
}

variable "ec2_ami_id" {
  description = "Override AMI ID (optional)"
  type        = string
}

variable "ec2_key_name" {
  description = "EC2 key pair name for SSH (optional)"
  type        = string
}

variable "ec2_subnet_index" {
  description = "Subnet index to place the instance"
  type        = number
}

variable "ec2_ssh_cidrs" {
  description = "CIDR blocks allowed to access SSH"
  type        = list(string)
}

variable "ec2_http_cidrs" {
  description = "CIDR blocks allowed to access HTTP/HTTPS"
  type        = list(string)
}
