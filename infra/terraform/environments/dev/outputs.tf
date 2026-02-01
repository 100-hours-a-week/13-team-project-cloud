output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "subnet_ids" {
  description = "Subnet IDs"
  value       = module.vpc.subnet_ids
}

output "app_instance_id" {
  description = "App EC2 instance ID"
  value       = module.app_instance.instance_id
}

output "app_security_group_id" {
  description = "App security group ID"
  value       = module.app_instance.security_group_id
}
