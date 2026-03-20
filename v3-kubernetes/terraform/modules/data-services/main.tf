# =============================================================================
# RabbitMQ EC2 — 메시지 큐 (1대, 추후 3대 확장)
# =============================================================================
resource "aws_instance" "rabbitmq" {
  ami                    = var.ec2_ami_id
  instance_type          = var.rabbitmq_instance_type
  subnet_id              = var.subnet_id
  iam_instance_profile   = var.instance_profile_name
  vpc_security_group_ids = [var.data_sg_id]

  user_data = base64encode(templatefile("${path.module}/templates/install-rabbitmq.sh", {
    rabbitmq_user     = var.rabbitmq_user
    rabbitmq_password = var.rabbitmq_password
    hostname          = "${var.project}-${var.environment}-rabbitmq"
  }))

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.rabbitmq_volume_size
    iops                  = 3000
    throughput            = 125
    delete_on_termination = true
  }

  tags = merge(var.common_tags, {
    Name    = "${var.project}-${var.environment}-rabbitmq"
    Service = "rabbitmq"
    Tier    = "data"
  })

  lifecycle {
    ignore_changes = [ami, user_data]
  }
}

# =============================================================================
# MongoDB EC2 — 도큐먼트 DB (1대, 추후 3대 확장)
# =============================================================================
resource "aws_instance" "mongodb" {
  ami                    = var.ec2_ami_id
  instance_type          = var.mongodb_instance_type
  subnet_id              = var.subnet_id
  iam_instance_profile   = var.instance_profile_name
  vpc_security_group_ids = [var.data_sg_id]

  user_data = base64encode(templatefile("${path.module}/templates/install-mongodb.sh", {
    mongodb_admin_user     = var.mongodb_admin_user
    mongodb_admin_password = var.mongodb_admin_password
    hostname               = "${var.project}-${var.environment}-mongodb"
  }))

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.mongodb_volume_size
    iops                  = 3000
    throughput            = 125
    delete_on_termination = true
  }

  tags = merge(var.common_tags, {
    Name    = "${var.project}-${var.environment}-mongodb"
    Service = "mongodb"
    Tier    = "data"
  })

  lifecycle {
    ignore_changes = [ami, user_data]
  }
}
