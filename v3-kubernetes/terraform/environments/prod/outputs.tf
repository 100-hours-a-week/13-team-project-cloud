output "vpc_id"         { value = data.aws_vpc.existing.id }
output "app_subnet_ids" { value = data.aws_subnets.app.ids }
output "k8s_node_sg_id" { value = module.security.k8s_node_sg_id }
output "k8s_cp_sg_id"   { value = module.security.k8s_cp_sg_id }

output "control_plane_instances" { value = module.compute.control_plane_instances }

output "asg_name" { value = module.asg.asg_name }

output "nlb_dns_name" { value = module.nlb.nlb_dns_name }

output "rabbitmq_private_ip" { value = module.data_services.rabbitmq_private_ip }
output "mongodb_private_ip"  { value = module.data_services.mongodb_private_ip }

# DNS
output "internal_zone_id" { value = data.aws_route53_zone.internal.zone_id }
output "internal_dns_records" {
  value = {
    mongo      = aws_route53_record.mongodb.fqdn
    rabbitmq   = aws_route53_record.rabbitmq.fqdn
    postgresql = aws_route53_record.postgresql.fqdn
    redis      = aws_route53_record.redis.fqdn
    qdrant     = aws_route53_record.qdrant.fqdn
  }
}
