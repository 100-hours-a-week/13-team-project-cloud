output "spring_parameter_names" {
  value = { for k, v in aws_ssm_parameter.spring : k => v.name }
}

output "recommend_parameter_names" {
  value = { for k, v in aws_ssm_parameter.recommend : k => v.name }
}
