# =============================================================================
# SSM Parameter Store — MongoDB / RabbitMQ 접속 정보
# 기존 ExternalSecret (path: /moyeobab/spring/prod/) 이 자동 수집
# =============================================================================

# --- MongoDB ---
resource "aws_ssm_parameter" "mongodb_uri" {
  name  = "/moyeobab/spring/prod/MONGODB_URI"
  type  = "SecureString"
  value = "mongodb://${var.mongodb_admin_user}:${var.mongodb_admin_password}@mongo.internal.moyeobab.com:27017/matchimban_chat?authSource=admin"

  tags = local.common_tags
}

# --- RabbitMQ ---
resource "aws_ssm_parameter" "rabbitmq_host" {
  name  = "/moyeobab/spring/prod/RABBITMQ_HOST"
  type  = "String"
  value = "rabbitmq.internal.moyeobab.com"

  tags = local.common_tags
}

resource "aws_ssm_parameter" "rabbitmq_port" {
  name  = "/moyeobab/spring/prod/RABBITMQ_PORT"
  type  = "String"
  value = "5672"

  tags = local.common_tags
}

resource "aws_ssm_parameter" "rabbitmq_username" {
  name  = "/moyeobab/spring/prod/RABBITMQ_USERNAME" # pragma: allowlist secret
  type  = "String"
  value = var.rabbitmq_user

  tags = local.common_tags
}

resource "aws_ssm_parameter" "rabbitmq_password" {
  name  = "/moyeobab/spring/prod/RABBITMQ_PASSWORD" # pragma: allowlist secret
  type  = "SecureString"
  value = var.rabbitmq_password

  tags = local.common_tags
}

resource "aws_ssm_parameter" "rabbitmq_vhost" {
  name  = "/moyeobab/spring/prod/RABBITMQ_VHOST" # pragma: allowlist secret
  type  = "String"
  value = "matchimban"

  tags = local.common_tags
}
