output "nlb_dns_name" { value = aws_lb.k8s.dns_name }
output "nlb_arn"      { value = aws_lb.k8s.arn }

output "http_target_group_arn" { value = aws_lb_target_group.http.arn }
