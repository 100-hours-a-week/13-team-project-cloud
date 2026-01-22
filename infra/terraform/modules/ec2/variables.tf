variable "name" {
  description = "Name prefix for resources"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID for security group"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID for the instance"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
}

variable "root_volume_size" {
  description = "Root EBS volume size in GiB"
  type        = number
}

variable "root_volume_type" {
  description = "Root EBS volume type"
  type        = string
}

variable "key_name" {
  description = "EC2 key pair name for SSH (optional)"
  type        = string
}

variable "ssh_cidrs" {
  description = "CIDR blocks allowed to access SSH"
  type        = list(string)
}

variable "http_cidrs" {
  description = "CIDR blocks allowed to access HTTP/HTTPS"
  type        = list(string)
}

variable "associate_public_ip_address" {
  description = "Whether to associate a public IP"
  type        = bool
}

variable "eip_allocation_id" {
  description = "Elastic IP allocation ID to associate"
  type        = string
}

variable "ami_id" {
  description = "Override AMI ID (optional)"
  type        = string
}
