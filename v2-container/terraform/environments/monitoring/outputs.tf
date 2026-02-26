# =============================================================================
# Monitoring Instance
# =============================================================================
output "monitoring_instance_id" {
  description = "Monitoring EC2 instance ID"
  value       = aws_instance.monitoring.id
}

output "monitoring_private_ip" {
  description = "Monitoring EC2 private IP"
  value       = aws_instance.monitoring.private_ip
}

# =============================================================================
# Security Group (dev 환경에서 참조 — monitoring SG 룰 활성화용)
# =============================================================================
output "monitoring_sg_id" {
  description = "Monitoring security group ID"
  value       = aws_security_group.monitoring.id
}
