module "exec_label" {
  source     = "cloudposse/label/null"
  version    = "0.25.0"
  enabled    = module.this.enabled
  attributes = ["exec"]

  context = module.this.context
}

resource "aws_iam_role" "ecs_exec" {
  count              = module.this.enabled ? 1 : 0
  name               = module.exec_label.id
  assume_role_policy = data.aws_iam_policy_document.ecs_task_exec[0].json
  tags               = module.this.tags
}

data "aws_iam_policy_document" "ecs_task_exec" {
  count = module.this.enabled ? 1 : 0

  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "ecs_exec" {
  count = module.this.enabled ? 1 : 0

  statement {
    effect    = "Allow"
    resources = ["*"]

    actions = [
      "ssm:GetParameters",
      "ecr:GetAuthorizationToken",
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
  }
}

resource "aws_iam_role_policy" "ecs_exec" {
  count  = module.this.enabled ? 1 : 0
  name   = module.exec_label.id
  policy = data.aws_iam_policy_document.ecs_exec[0].json
  role   = aws_iam_role.ecs_exec[0].id
}
