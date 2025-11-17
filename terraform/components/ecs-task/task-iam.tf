# IAM role for the task
locals {
  account_id = one(data.aws_caller_identity.current[*].account_id)

  efs_volume_resources = [for name, volume in var.task.volumes :
    format("arn:aws:elasticfilesystem:%s:%s:file-system/%s", var.region, local.account_id, volume.efs_volume_configuration.file_system_id)
    if volume.efs_volume_configuration != null
  ]
}

data "aws_caller_identity" "current" {}

// Define the IAM role for the ECS task
resource "aws_iam_role" "ecs_task" {
  name               = module.task_label.id
  assume_role_policy = data.aws_iam_policy_document.ecs_task.json
  tags               = module.task_label.tags
}

data "aws_iam_policy_document" "ecs_task" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

// Attach managed IAM policies to the ECS task role
resource "aws_iam_role_policy_attachment" "ecs_task" {
  for_each = toset([
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
    "arn:aws:iam::aws:policy/AmazonSSMReadOnlyAccess"
  ])
  role       = aws_iam_role.ecs_task.id
  policy_arn = each.value
}

locals {
}

data "aws_iam_policy_document" "ecs_task_policy" {
  dynamic "statement" {
    for_each = local.efs_volume_resources != [] ? [local.efs_volume_resources] : []
    content {
      effect = "Allow"
      resources = local.efs_volume_resources
      actions = [
        "elasticfilesystem:ClientMount",
        "elasticfilesystem:ClientWrite",
        "elasticfilesystem:ClientRootAccess"
      ]
    }
  }

  statement {
    effect    = "Allow"
    resources = ["*"]

    actions = [
      "ssmmessages:CreateControlChannel",
      "ssmmessages:CreateDataChannel",
      "ssmmessages:OpenControlChannel",
      "ssmmessages:OpenDataChannel"
    ]
  }
}

// Define and attach the IAM policy to the ECS task role
// Uses the IAM policy document defined earlier
resource "aws_iam_role_policy" "ecs_task" {
  name   = module.task_label.id
  policy = data.aws_iam_policy_document.ecs_task_policy.json
  role   = aws_iam_role.ecs_task.id
}
