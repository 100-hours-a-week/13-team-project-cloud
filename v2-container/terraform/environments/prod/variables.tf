variable "region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-2"
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

variable "enable_path_blocking" {
  description = "ALB에서 /actuator, /swagger 경로 차단"
  type        = bool
  default     = true
}

variable "monitoring_sg_id" {
  description = "prod-monitoring SG ID (prod-monitoring 배포 후 설정, 빈 문자열이면 모니터링 룰 미적용)"
  type        = string
  default     = ""
}

variable "vpc_peering_id" {
  description = "dev-prod VPC 피어링 연결 ID"
  type        = string
  default     = ""
}
