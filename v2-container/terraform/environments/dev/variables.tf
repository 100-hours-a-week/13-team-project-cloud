variable "region" {
  description = "AWS region"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
}

variable "availability_zones" {
  description = "Availability zones"
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDR blocks"
  type        = list(string)
}

variable "private_app_subnet_cidrs" {
  description = "Private app tier subnet CIDR blocks"
  type        = list(string)
}

variable "private_data_subnet_cidrs" {
  description = "Private data tier subnet CIDR blocks"
  type        = list(string)
}

variable "ec2_ami_id" {
  description = "AMI ID for EC2 instances"
  type        = string
}

variable "ec2_instance_type" {
  description = "EC2 instance type"
  type        = string
}

variable "ec2_key_name" {
  description = "SSH key pair name"
  type        = string
}

variable "enable_path_blocking" {
  description = "ALB에서 /actuator, /swagger 경로 차단 (prod용)"
  type        = bool
  default     = false
}

variable "v1_loki_ip" {
  description = "v1 Loki 서버 내부 IP (모니터링 연동)"
  type        = string
}
