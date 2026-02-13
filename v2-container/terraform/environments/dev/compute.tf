# =============================================================================
# API Server (Spring Boot 메인 백엔드)
# =============================================================================
resource "aws_instance" "api" {
  ami                    = var.ec2_ami_id
  instance_type          = var.ec2_instance_type
  subnet_id              = aws_subnet.private_app[0].id
  private_ip             = "10.1.1.235"
  key_name               = var.ec2_key_name
  vpc_security_group_ids = [aws_security_group.app.id, aws_security_group.app_monitoring.id]
  iam_instance_profile   = aws_iam_instance_profile.v2_ec2.name

  root_block_device {
    volume_size           = 20
    volume_type           = "gp3"
    iops                  = 3000
    throughput            = 125
    delete_on_termination = false
  }

  tags = merge(local.common_tags, local.service_tags.api, {
    Name = "${local.project}-${local.environment}-api-v2"
  })

  lifecycle {
    prevent_destroy = true
    ignore_changes  = [ami]
  }
}

# =============================================================================
# Recommend Server (FastAPI 추천 서비스)
# =============================================================================
resource "aws_instance" "recommend" {
  ami                    = var.ec2_ami_id
  instance_type          = var.ec2_instance_type
  subnet_id              = aws_subnet.private_app[0].id
  private_ip             = "10.1.1.196"
  key_name               = var.ec2_key_name
  vpc_security_group_ids = [aws_security_group.app.id, aws_security_group.app_monitoring.id]
  iam_instance_profile   = aws_iam_instance_profile.v2_ec2.name

  root_block_device {
    volume_size           = 20
    volume_type           = "gp3"
    iops                  = 3000
    throughput            = 125
    delete_on_termination = false
  }

  tags = merge(local.common_tags, local.service_tags.recommend, {
    Name = "${local.project}-${local.environment}-recommend-v2"
  })

  lifecycle {
    prevent_destroy = true
    ignore_changes  = [ami]
  }
}

# =============================================================================
# PostgreSQL Server
# =============================================================================
resource "aws_instance" "postgresql" {
  ami                    = var.ec2_ami_id
  instance_type          = var.ec2_instance_type
  subnet_id              = aws_subnet.private_data[0].id
  private_ip             = "10.1.2.202"
  key_name               = var.ec2_key_name
  vpc_security_group_ids = [aws_security_group.data.id, aws_security_group.data_monitoring.id]
  iam_instance_profile   = aws_iam_instance_profile.v2_ec2.name

  root_block_device {
    volume_size           = 50
    volume_type           = "gp3"
    iops                  = 3000
    throughput            = 125
    delete_on_termination = false
  }

  tags = merge(local.common_tags, local.service_tags.postgresql, {
    Name = "${local.project}-${local.environment}-postgresql-v2"
  })

  lifecycle {
    prevent_destroy = true
    ignore_changes  = [ami]
  }
}

# =============================================================================
# Redis Server
# =============================================================================
resource "aws_instance" "redis" {
  ami                    = var.ec2_ami_id
  instance_type          = var.ec2_instance_type
  subnet_id              = aws_subnet.private_data[0].id
  private_ip             = "10.1.2.240"
  key_name               = var.ec2_key_name
  vpc_security_group_ids = [aws_security_group.data.id, aws_security_group.data_monitoring.id]
  iam_instance_profile   = aws_iam_instance_profile.v2_ec2.name

  root_block_device {
    volume_size           = 20
    volume_type           = "gp3"
    iops                  = 3000
    throughput            = 125
    delete_on_termination = false
  }

  tags = merge(local.common_tags, local.service_tags.redis, {
    Name = "${local.project}-${local.environment}-redis-v2"
  })

  lifecycle {
    prevent_destroy = true
    ignore_changes  = [ami]
  }
}

# =============================================================================
# IAM Role (통합 — SSM + ECR pull)
# =============================================================================
resource "aws_iam_role" "v2_ec2" {
  name = "${local.project}-v2-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "v2_ec2_ssm" {
  role       = aws_iam_role.v2_ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "v2_ec2_ecr" {
  role       = aws_iam_role.v2_ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_instance_profile" "v2_ec2" {
  name = "${local.project}-v2-ec2-profile"
  role = aws_iam_role.v2_ec2.name
}
