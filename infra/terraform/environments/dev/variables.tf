variable "vpc_cidr" {
  description = "The CIDR block for the VPC"
  type        = string
}

variable "vpc_name" {
  description = "The name of the VPC"
  type        = string
}

variable "vpc_tags" {
  description = "A map of tags to assign to the VPC"
  type        = map(string)
  default     = {}
}

variable "availability_zones" {
  description = "A list of availability zones for the VPC"
  type        = list(string)
}

variable "vpc_subnet_cidrs" {
  description = "A list of CIDR blocks for the VPC subnets"
  type        = list(string)
}

variable "ec2_instance_type" {
  description = "EC2 instance type for the single host"
  type        = string
  default     = "t4g.small"
}

variable "ec2_root_volume_size" {
  description = "Root EBS volume size in GiB"
  type        = number
  default     = 30
}

variable "ec2_root_volume_type" {
  description = "Root EBS volume type"
  type        = string
  default     = "gp3"
}

variable "ec2_ami_id" {
  description = "Override AMI ID (optional)"
  type        = string
  default     = null
}

variable "ec2_key_name" {
  description = "EC2 key pair name for SSH (optional)"
  type        = string
  default     = null
}

variable "ec2_subnet_index" {
  description = "Subnet index to place the instance"
  type        = number
  default     = 0
}

variable "ec2_ssh_cidrs" {
  description = "CIDR blocks allowed to access SSH"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "ec2_http_cidrs" {
  description = "CIDR blocks allowed to access HTTP/HTTPS"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}
