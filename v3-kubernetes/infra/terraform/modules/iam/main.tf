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
  name = "${var.project}-${var.app_version}-${var.environment}-k8s-ssm-read"
  role = aws_iam_role.k8s_node.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath"
        ]
        Resource = "arn:aws:ssm:${var.region}:${var.account_id}:parameter/moyeobab/*"
      },
      {
        Effect   = "Allow"
        Action   = "kms:Decrypt"
        Resource = "arn:aws:kms:${var.region}:${var.account_id}:key/*"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "k8s_node" {
  name = "${var.project}-${var.app_version}-${var.environment}-k8s-node-profile"
  role = aws_iam_role.k8s_node.name
}
