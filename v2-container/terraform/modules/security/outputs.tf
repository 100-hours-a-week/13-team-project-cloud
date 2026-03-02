output "alb_sg_id"             { value = aws_security_group.alb.id }
output "app_sg_id"             { value = aws_security_group.app.id }
output "app_monitoring_sg_id"  { value = aws_security_group.app_monitoring.id }
output "data_sg_id"            { value = aws_security_group.data.id }
output "data_monitoring_sg_id" { value = aws_security_group.data_monitoring.id }
