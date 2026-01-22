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
