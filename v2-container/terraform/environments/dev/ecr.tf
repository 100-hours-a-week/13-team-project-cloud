# =============================================================================
# ECR Repositories (Docker 이미지 저장소)
# =============================================================================
resource "aws_ecr_repository" "backend" {
  name                 = "${local.project}/backend"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = merge(local.common_tags, {
    Name    = "${local.project}/backend"
    Service = "backend"
  })

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_ecr_repository" "recommend" {
  name                 = "${local.project}/recommend"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = merge(local.common_tags, {
    Name    = "${local.project}/recommend"
    Service = "recommend"
  })

  lifecycle {
    prevent_destroy = true
  }
}

# =============================================================================
# ECR Lifecycle Policy (오래된 이미지 자동 정리)
# =============================================================================
resource "aws_ecr_lifecycle_policy" "backend" {
  repository = aws_ecr_repository.backend.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 10 images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 10
      }
      action = {
        type = "expire"
      }
    }]
  })
}

resource "aws_ecr_lifecycle_policy" "recommend" {
  repository = aws_ecr_repository.recommend.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 10 images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 10
      }
      action = {
        type = "expire"
      }
    }]
  })
}
