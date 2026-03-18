# =============================================================================
# K8s Node IAM Role — SSM 접속 + ECR Pull + Parameter Store 읽기
# =============================================================================
resource "aws_iam_role" "k8s_node" {
  name = "${var.project}-${var.app_version}-${var.environment}-k8s-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = merge(var.common_tags, {
    Name = "${var.project}-${var.app_version}-${var.environment}-k8s-node-role"
  })

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.k8s_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "ecr_readonly" {
  role       = aws_iam_role.k8s_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy" "ssm_parameters" {
  name = "${var.project}-${var.app_version}-${var.environment}-k8s-ssm-params"
  role = aws_iam_role.k8s_node.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath",
          "ssm:PutParameter"
        ]
        Resource = "arn:aws:ssm:${var.region}:${var.account_id}:parameter/moyeobab/*"
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:Encrypt",
          "kms:GenerateDataKey"
        ]
        Resource = "arn:aws:kms:${var.region}:${var.account_id}:key/*"
      }
    ]
  })
}

# CP에서 ASG 스케일인 시 drain 스크립트가 사용하는 권한
resource "aws_iam_role_policy" "drain_permissions" {
  name = "${var.project}-${var.app_version}-${var.environment}-k8s-drain"
  role = aws_iam_role.k8s_node.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "ec2:DescribeInstances"
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = "autoscaling:CompleteLifecycleAction"
        Resource = "arn:aws:autoscaling:${var.region}:${var.account_id}:autoScalingGroup:*"
      }
    ]
  })
}

# S3 접근 권한 (presign URL 생성 + 채팅 이미지)
resource "aws_iam_role_policy" "s3_access" {
  name = "${var.project}-${var.app_version}-${var.environment}-k8s-s3"
  role = aws_iam_role.k8s_node.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "s3:PutObject",
        "s3:GetObject",
        "s3:DeleteObject"
      ]
      Resource = [
        "arn:aws:s3:::${var.project}-${var.environment}-receipt-images/*",
        "arn:aws:s3:::${var.project}-${var.environment}-chat-images/*"
      ]
    }]
  })
}

# EBS CSI Driver — EBS 볼륨 동적 프로비저닝 (Prometheus PVC 등)
resource "aws_iam_role_policy_attachment" "ebs_csi" {
  role       = aws_iam_role.k8s_node.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

resource "aws_iam_instance_profile" "k8s_node" {
  name = "${var.project}-${var.app_version}-${var.environment}-k8s-node-profile"
  role = aws_iam_role.k8s_node.name
}
