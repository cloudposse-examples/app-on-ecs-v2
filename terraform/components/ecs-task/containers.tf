locals {
  enabled = module.this.enabled
}

module "container_definition" {
  source  = "cloudposse/ecs-container-definition/aws"
  version = "0.61.2"

  for_each = { for k, v in var.containers : k => v if local.enabled }

  container_name = each.key

  container_image = each.value["image"]

  container_memory             = each.value["memory"]
  container_memory_reservation = each.value["memory_reservation"]
  container_cpu                = each.value["cpu"]
  essential                    = each.value["essential"]
  readonly_root_filesystem     = each.value["readonly_root_filesystem"]
  mount_points                 = each.value["mount_points"]

  map_environment = {}

  map_secrets = {}

  port_mappings        = each.value["port_mappings"]
  command              = each.value["command"]
  entrypoint           = each.value["entrypoint"]
  healthcheck          = each.value["healthcheck"]
  ulimits              = each.value["ulimits"]
  volumes_from         = each.value["volumes_from"]
  docker_labels        = each.value["docker_labels"]
  container_depends_on = each.value["container_depends_on"]
  privileged           = each.value["privileged"]
  user                 = each.value["user"]

  log_configuration = each.value["log_configuration"]

  # firelens_configuration = each.value["firelens_configuration"]
}

locals {
  container_definitions = jsonencode(
    concat([for k, v in module.container_definition : v.json_map_object])
  )
}
