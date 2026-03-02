output "ec2_role_id"               { value = aws_iam_role.ec2.id }
output "ec2_role_name"             { value = aws_iam_role.ec2.name }
output "ec2_instance_profile_name" { value = aws_iam_instance_profile.ec2.name }

output "backend_1_id"         { value = var.enable_backend ? aws_instance.backend_1[0].id : null }
output "backend_2_id"         { value = var.enable_backend && var.enable_backend_2 ? aws_instance.backend_2[0].id : null }
output "recommend_id"         { value = aws_instance.recommend.id }

output "backend_1_private_ip"  { value = var.enable_backend ? aws_instance.backend_1[0].private_ip : null }
output "backend_2_private_ip"  { value = var.enable_backend && var.enable_backend_2 ? aws_instance.backend_2[0].private_ip : null }
output "recommend_private_ip"  { value = aws_instance.recommend.private_ip }

output "postgresql_ids"         { value = { for k, v in aws_instance.postgresql : k => v.id } }
output "postgresql_private_ips" { value = { for k, v in aws_instance.postgresql : k => v.private_ip } }
output "redis_ids"              { value = { for k, v in aws_instance.redis : k => v.id } }
output "redis_private_ips"      { value = { for k, v in aws_instance.redis : k => v.private_ip } }
output "qdrant_ids"             { value = { for k, v in aws_instance.qdrant : k => v.id } }
output "qdrant_private_ips"     { value = { for k, v in aws_instance.qdrant : k => v.private_ip } }
