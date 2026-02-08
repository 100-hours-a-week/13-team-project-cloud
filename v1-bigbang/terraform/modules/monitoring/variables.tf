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
  default     = {}
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.small"
}

variable "ami_id" {
  description = "AMI ID for the instance"
  type        = string
}

variable "root_volume_size" {
  description = "Root EBS volume size in GiB"
  type        = number
  default     = 20
}

variable "root_volume_type" {
  description = "Root EBS volume type"
  type        = string
  default     = "gp3"
}

variable "key_name" {
  description = "EC2 key pair name for SSH"
  type        = string
}

variable "ssh_cidrs" {
  description = "CIDR blocks allowed to access SSH"
  type        = list(string)
  default     = []
}

variable "app_security_group_id" {
  description = "App server security group ID for Grafana access"
  type        = string
}

variable "loki_cidrs" {
  description = "CIDR blocks allowed to access Loki (3100)"
  type        = list(string)
}

variable "associate_public_ip_address" {
  description = "Whether to associate a public IP"
  type        = bool
  default     = true
}
