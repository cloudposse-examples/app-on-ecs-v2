# IAM role for the task
locals {
  account_id = one(data.aws_caller_identity.current[*].account_id)

  efs_volume_resources = [for name, volume in var.task.volumes :
    format("arn:aws:elasticfilesystem:%s:%s:file-system/%s", var.region, local.account_id, volume.efs_volume_configuration.file_system_id)
    if volume.efs_volume_configuration != null
  ]
}

data "aws_caller_identity" "current" {
  count = module.this.enabled ? 1 : 0
}

resource "aws_iam_role" "ecs_task" {
  count = module.this.enabled ? 1 : 0

  name               = module.task_label.id
  assume_role_policy = one(data.aws_iam_policy_document.ecs_task[*]["json"])
  tags               = module.task_label.tags
}

data "aws_iam_policy_document" "ecs_task" {
  count = module.this.enabled ? 1 : 0

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "ecs_task" {
  for_each = toset(
    module.this.enabled ? [
      "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
      "arn:aws:iam::aws:policy/AmazonSSMReadOnlyAccess"
    ] : []
  )
  role       = one(aws_iam_role.ecs_task[*].id)
  policy_arn = each.value
}

locals {
}

data "aws_iam_policy_document" "ecs_task_policy" {
  count = module.this.enabled ? 1 : 0

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

resource "aws_iam_role_policy" "ecs_task" {
  count  = module.this.enabled ? 1 : 0
  name   = module.task_label.id
  policy = one(data.aws_iam_policy_document.ecs_task_policy[*].json)
  role   = one(aws_iam_role.ecs_task[*].id)
}
