# =============================================================================
# EC2 Auto Recovery — Data Layer 전체
# 하드웨어 장애 시 같은 EBS/IP로 자동 복구
# =============================================================================

# MongoDB
resource "aws_cloudwatch_metric_alarm" "mongodb_recovery" {
  alarm_name          = "${local.project}-${local.environment}-mongodb-recovery"
  alarm_description   = "MongoDB EC2 auto recovery"
  namespace           = "AWS/EC2"
  metric_name         = "StatusCheckFailed_System"
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 2
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  alarm_actions       = ["arn:aws:automate:ap-northeast-2:ec2:recover"]

  dimensions = {
    InstanceId = module.data_services.mongodb_instance_id
  }

  tags = local.common_tags
}

# RabbitMQ
resource "aws_cloudwatch_metric_alarm" "rabbitmq_recovery" {
  alarm_name          = "${local.project}-${local.environment}-rabbitmq-recovery"
  alarm_description   = "RabbitMQ EC2 auto recovery"
  namespace           = "AWS/EC2"
  metric_name         = "StatusCheckFailed_System"
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 2
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  alarm_actions       = ["arn:aws:automate:ap-northeast-2:ec2:recover"]

  dimensions = {
    InstanceId = module.data_services.rabbitmq_instance_id
  }

  tags = local.common_tags
}

# PostgreSQL (v2에서 생성, data source 참조)
resource "aws_cloudwatch_metric_alarm" "postgresql_recovery" {
  alarm_name          = "${local.project}-${local.environment}-postgresql-recovery"
  alarm_description   = "PostgreSQL EC2 auto recovery"
  namespace           = "AWS/EC2"
  metric_name         = "StatusCheckFailed_System"
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 2
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  alarm_actions       = ["arn:aws:automate:ap-northeast-2:ec2:recover"]

  dimensions = {
    InstanceId = data.aws_instance.postgresql_primary.id
  }

  tags = local.common_tags
}

# Redis Primary (v2에서 생성, data source 참조)
resource "aws_cloudwatch_metric_alarm" "redis_primary_recovery" {
  alarm_name          = "${local.project}-${local.environment}-redis-primary-recovery"
  alarm_description   = "Redis Primary EC2 auto recovery"
  namespace           = "AWS/EC2"
  metric_name         = "StatusCheckFailed_System"
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 2
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  alarm_actions       = ["arn:aws:automate:ap-northeast-2:ec2:recover"]

  dimensions = {
    InstanceId = data.aws_instance.redis_primary.id
  }

  tags = local.common_tags
}
