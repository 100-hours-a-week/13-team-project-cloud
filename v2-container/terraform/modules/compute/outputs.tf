output "ec2_role_id"               { value = aws_iam_role.ec2.id }
output "ec2_role_name"             { value = aws_iam_role.ec2.name }
output "ec2_instance_profile_name" { value = aws_iam_instance_profile.ec2.name }

output "postgresql_ids"         { value = { for k, v in aws_instance.postgresql : k => v.id } }
output "postgresql_private_ips" { value = { for k, v in aws_instance.postgresql : k => v.private_ip } }
output "redis_ids"              { value = { for k, v in aws_instance.redis : k => v.id } }
output "redis_private_ips"      { value = { for k, v in aws_instance.redis : k => v.private_ip } }
output "qdrant_ids"             { value = { for k, v in aws_instance.qdrant : k => v.id } }
output "qdrant_private_ips"     { value = { for k, v in aws_instance.qdrant : k => v.private_ip } }
