locals {
  # Set true to enable the ECS service role. Required for ALB integration with network mode different from "awsvpc"
  ecs_service_enabled = false
}

// IAM role for ECS service integration with ALB
resource "aws_iam_role" "ecs_service" {
  count              = local.ecs_service_enabled ? 1 : 0
  name               = module.service_label.id
  assume_role_policy = one(data.aws_iam_policy_document.ecs_service[*].json)
  tags               = module.service_label.tags
}

data "aws_iam_policy_document" "ecs_service" {
  count = local.ecs_service_enabled ? 1 : 0

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "ecs_service_policy" {
  count = local.ecs_service_enabled ? 1 : 0

  statement {
    effect    = "Allow"
    resources = ["*"]

    actions = [
      "elasticloadbalancing:Describe*",
      "elasticloadbalancing:DeregisterInstancesFromLoadBalancer",
      "elasticloadbalancing:RegisterInstancesWithLoadBalancer",
      "ec2:Describe*",
      "ec2:AuthorizeSecurityGroupIngress",
      "elasticloadbalancing:RegisterTargets",
      "elasticloadbalancing:DeregisterTargets"
    ]
  }
}

resource "aws_iam_role_policy" "ecs_service" {
  count  = local.ecs_service_enabled ? 1 : 0
  name   = module.service_label.id
  policy = one(data.aws_iam_policy_document.ecs_service_policy[*].json)
  role   = one(aws_iam_role.ecs_service[*].id)
}
