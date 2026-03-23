# =============================================================================
# Redis Replica + Sentinel — AZ-c (3 AZ 분산)
# user_data로 Redis + Sentinel 자동 설치
# =============================================================================

resource "aws_instance" "redis_c" {
  ami                    = data.aws_ami.ubuntu_arm.id
  instance_type          = "t4g.small"
  subnet_id              = aws_subnet.data_c.id
  iam_instance_profile   = module.iam.k8s_node_instance_profile_name
  vpc_security_group_ids = [data.aws_security_group.data.id]

  user_data = base64encode(templatefile("../../modules/data-services/templates/install-redis.sh", {
    redis_password       = var.redis_password
    redis_master_ip      = "10.0.7.20"
    sentinel_master_name = "mymaster"
    hostname             = "${local.project}-${local.environment}-redis-c"
    loki_url             = "http://loki.monitoring.svc.cluster.local:3100/loki/api/v1/push"
  }))

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 20
    iops                  = 3000
    throughput            = 125
    delete_on_termination = true
  }

  tags = merge(local.common_tags, {
    Name    = "${local.project}-${local.environment}-redis-c"
    Service = "redis"
    Tier    = "data"
  })

  lifecycle {
    ignore_changes = [ami, user_data]
  }
}

# EC2 Auto Recovery — 하드웨어 장애 시 자동 복구
resource "aws_cloudwatch_metric_alarm" "redis_c_recovery" {
  alarm_name          = "${local.project}-${local.environment}-redis-c-recovery"
  alarm_description   = "Redis AZ-c EC2 auto recovery"
  namespace           = "AWS/EC2"
  metric_name         = "StatusCheckFailed_System"
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 2
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  alarm_actions       = ["arn:aws:automate:ap-northeast-2:ec2:recover"]

  dimensions = {
    InstanceId = aws_instance.redis_c.id
  }

  tags = local.common_tags
}

output "redis_c_private_ip" {
  value = aws_instance.redis_c.private_ip
}
