variable "monitoring_name" {
  description = "Name prefix for monitoring resources"
  type        = string
}

variable "monitoring_tags" {
  description = "Tags to apply to monitoring resources"
  type        = map(string)
  default     = {}
}

variable "monitoring_instance_type" {
  description = "EC2 instance type for monitoring"
  type        = string
  default     = "t3.small"
}

variable "monitoring_root_volume_size" {
  description = "Root EBS volume size in GiB"
  type        = number
  default     = 20
}

variable "monitoring_root_volume_type" {
  description = "Root EBS volume type"
  type        = string
  default     = "gp3"
}

variable "monitoring_associate_public_ip_address" {
  description = "Whether to associate a public IP"
  type        = bool
  default     = true
}

variable "monitoring_ami_id" {
  description = "AMI ID for the monitoring instance"
  type        = string
}

variable "monitoring_key_name" {
  description = "EC2 key pair name for SSH"
  type        = string
}

variable "monitoring_subnet_index" {
  description = "Subnet index to place the monitoring instance"
  type        = number
}

variable "monitoring_ssh_cidrs" {
  description = "CIDR blocks allowed to access SSH"
  type        = list(string)
}

variable "monitoring_loki_cidrs" {
  description = "CIDR blocks allowed to access Loki (3100)"
  type        = list(string)
}
