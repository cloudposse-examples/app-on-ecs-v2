module "task_label" {
  source     = "cloudposse/label/null"
  version    = "0.25.0"
  enabled    = module.this.enabled
  attributes = ["task"]

  context = module.this.context
}

// Define an ECS task definition
resource "aws_ecs_task_definition" "default" {
  family                = module.this.id
  container_definitions = local.container_definitions_json

  task_role_arn      = aws_iam_role.ecs_task.arn
  execution_role_arn = aws_iam_role.ecs_exec.arn

  requires_compatibilities = ["FARGATE", "EC2"]
  network_mode             = "awsvpc"

  cpu    = var.task.cpu
  memory = var.task.memory

  # # https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_task_definition#proxy_configuration
  # proxy_configuration {
  #   type           = "APPMESH"
  #   container_name = "app-mesh-proxy"
  #   properties     = {
  #   }
  # }

  dynamic "ephemeral_storage" {
    for_each = var.task.ephemeral_storage_size > 0 ? [true] : []
    content {
      size_in_gib = var.task.ephemeral_storage_size
    }
  }

  # placement_constraints {
  #   type = "distinctInstance"
  #   expression = ""
  # }

  # runtime_platform {
  #   operating_system_family = "LINUX"
  #   cpu_architecture        = "X86_64"
  # }

  dynamic "volume" {
    for_each = var.task.volumes
    content {
      name      = volume.key
      host_path = volume.value.host_path

      dynamic "efs_volume_configuration" {
        for_each = volume.value.efs_volume_configuration != null ? [
          volume.value.efs_volume_configuration
        ] : []
        content {
          file_system_id          = efs_volume_configuration.value.file_system_id
          root_directory          = efs_volume_configuration.value.root_directory
          transit_encryption      = efs_volume_configuration.value.transit_encryption ? "ENABLED" : "DISABLED"
          transit_encryption_port = efs_volume_configuration.value.transit_encryption_port
          dynamic "authorization_config" {
            for_each = efs_volume_configuration.value.authorization_config != null ? [
              efs_volume_configuration.value.authorization_config
            ] : []
            content {
              access_point_id = authorization_config.value.access_point_id
              iam             = authorization_config.value.iam ? "ENABLED" : "DISABLED"
            }
          }
        }
      }
    }
  }
  tags = module.this.tags
}
