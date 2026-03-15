output "asg_name" { value = aws_autoscaling_group.wp.name }
output "asg_arn"  { value = aws_autoscaling_group.wp.arn }

output "launch_template_id" { value = aws_launch_template.wp.id }
