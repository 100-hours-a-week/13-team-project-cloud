# =============================================================================
# ASG Lifecycle Hook — 종료 시 K8s 노드 drain + delete
# =============================================================================
# 흐름: ASG 스케일인 → Lifecycle Hook → EventBridge → SSM Run Command (CP)
#       → kubectl drain + delete node → complete-lifecycle-action → 인스턴스 종료
# =============================================================================

resource "aws_autoscaling_lifecycle_hook" "wp_terminating" {
  name                   = "${var.project}-${var.environment}-${var.app_version}-wp-terminating"
  autoscaling_group_name = aws_autoscaling_group.wp.name
  lifecycle_transition   = "autoscaling:EC2_INSTANCE_TERMINATING"
  default_result         = "ABANDON"
  heartbeat_timeout      = 300
}

# =============================================================================
# SSM Document — CP에서 실행될 drain 스크립트
# =============================================================================
resource "aws_ssm_document" "k8s_drain_node" {
  name            = "${var.project}-${var.environment}-${var.app_version}-k8s-drain-node"
  document_type   = "Command"
  document_format = "YAML"

  content = yamlencode({
    schemaVersion = "2.2"
    description   = "K8s 노드 drain + delete (ASG 스케일인 시 자동 실행)"
    parameters = {
      InstanceId  = { type = "String", description = "종료되는 EC2 인스턴스 ID" }
      AsgName     = { type = "String", description = "ASG 이름" }
      HookName    = { type = "String", description = "Lifecycle Hook 이름" }
      ActionToken = { type = "String", description = "Lifecycle Action 토큰" }
    }
    mainSteps = [{
      action = "aws:runShellScript"
      name   = "drainAndDeleteNode"
      inputs = {
        runCommand = [
          "#!/bin/bash",
          "set -euo pipefail",
          "",
          "INSTANCE_ID='{{ InstanceId }}'",
          "ASG_NAME='{{ AsgName }}'",
          "HOOK_NAME='{{ HookName }}'",
          "TOKEN='{{ ActionToken }}'",
          "REGION='${var.region}'",
          "export KUBECONFIG=/home/ubuntu/.kube/config",
          "",
          "echo \"[drain] 시작: instance=$INSTANCE_ID\"",
          "",
          "# 1. EC2 인스턴스 ID → Private IP → K8s 노드명",
          "PRIVATE_IP=$(aws ec2 describe-instances --region $REGION --instance-ids $INSTANCE_ID --query 'Reservations[0].Instances[0].PrivateIpAddress' --output text)",
          "NODE_NAME=$(echo $PRIVATE_IP | sed 's/\\./-/g' | sed 's/^/ip-/')",
          "echo \"[drain] 노드: $NODE_NAME ($PRIVATE_IP)\"",
          "",
          "# 2. drain + delete",
          "kubectl drain $NODE_NAME --ignore-daemonsets --delete-emptydir-data --timeout=120s || true",
          "kubectl delete node $NODE_NAME || true",
          "echo \"[drain] 노드 제거 완료\"",
          "",
          "# 3. Lifecycle Action 완료 → 인스턴스 종료 허용",
          "aws autoscaling complete-lifecycle-action --lifecycle-action-result CONTINUE --lifecycle-hook-name $HOOK_NAME --auto-scaling-group-name $ASG_NAME --lifecycle-action-token $TOKEN --region $REGION",
          "echo \"[drain] 완료\""
        ]
      }
    }]
  })

  tags = merge(var.common_tags, {
    Name = "${var.project}-${var.environment}-${var.app_version}-k8s-drain-node"
  })
}

# =============================================================================
# EventBridge — ASG 종료 이벤트 감지 → SSM Run Command
# =============================================================================
resource "aws_cloudwatch_event_rule" "asg_terminating" {
  name        = "${var.project}-${var.environment}-${var.app_version}-asg-wp-terminating"
  description = "ASG Worker 종료 시 K8s 노드 drain 트리거"

  event_pattern = jsonencode({
    source      = ["aws.autoscaling"]
    detail-type = ["EC2 Instance-terminate Lifecycle Action"]
    detail = {
      AutoScalingGroupName = [aws_autoscaling_group.wp.name]
    }
  })

  tags = var.common_tags
}

resource "aws_cloudwatch_event_target" "ssm_drain" {
  rule     = aws_cloudwatch_event_rule.asg_terminating.name
  arn      = aws_ssm_document.k8s_drain_node.arn
  role_arn = aws_iam_role.eventbridge_ssm.arn

  run_command_targets {
    key    = "tag:KubernetesRole"
    values = ["control-plane"]
  }

  input_transformer {
    input_paths = {
      instance_id = "$.detail.EC2InstanceId"
      asg_name    = "$.detail.AutoScalingGroupName"
      hook_name   = "$.detail.LifecycleHookName"
      token       = "$.detail.LifecycleActionToken"
    }

    input_template = <<-EOT
      {
        "InstanceId": ["<instance_id>"],
        "AsgName": ["<asg_name>"],
        "HookName": ["<hook_name>"],
        "ActionToken": ["<token>"]
      }
    EOT
  }
}

# =============================================================================
# IAM — EventBridge → SSM Run Command 실행 권한
# =============================================================================
resource "aws_iam_role" "eventbridge_ssm" {
  name = "${var.project}-${var.environment}-${var.app_version}-eventbridge-ssm"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "events.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.common_tags
}

resource "aws_iam_role_policy" "eventbridge_ssm" {
  name = "${var.project}-${var.environment}-${var.app_version}-eventbridge-ssm"
  role = aws_iam_role.eventbridge_ssm.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "ssm:SendCommand"
        Resource = [
          aws_ssm_document.k8s_drain_node.arn,
          "arn:aws:ec2:${var.region}:${var.account_id}:instance/*"
        ]
      }
    ]
  })
}
