output "ec2_role_id"           { value = aws_iam_role.ec2.id }
output "ec2_role_name"         { value = aws_iam_role.ec2.name }

output "backend_1_id"         { value = aws_instance.backend_1.id }
output "backend_2_id"         { value = var.enable_backend_2 ? aws_instance.backend_2[0].id : null }
output "recommend_id"         { value = aws_instance.recommend.id }
output "postgresql_id"        { value = aws_instance.postgresql.id }
output "redis_id"             { value = aws_instance.redis.id }

output "backend_1_private_ip"  { value = aws_instance.backend_1.private_ip }
output "backend_2_private_ip"  { value = var.enable_backend_2 ? aws_instance.backend_2[0].private_ip : null }
output "recommend_private_ip"  { value = aws_instance.recommend.private_ip }
output "postgresql_private_ip" { value = aws_instance.postgresql.private_ip }
output "redis_private_ip"      { value = aws_instance.redis.private_ip }
