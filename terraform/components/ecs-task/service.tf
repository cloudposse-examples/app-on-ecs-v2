variable "ecs_cluster_arn" {
  type        = string
  description = "The ARN of the ECS cluster"
}

variable "subnet_ids" {
  type        = list(string)
  description = "The IDs of the subnets"
}

variable "security_group_ids" {
  type        = list(string)
  description = "The IDs of the security groups"
}

variable "assign_public_ip" {
  type        = bool
  description = "Whether to assign a public IP address to the service"
  default     = false
}

variable "vpc_id" {
  type        = string
  description = "The ID of the VPC"
}

variable "ecs_load_balancers" {
  type = list(object({
    container_name   = string
    container_port   = number
    elb_name         = optional(string)
    target_group_arn = string
  }))
  description = "A list of load balancer config objects for the ECS service; see [ecs_service#load_balancer](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_service#load_balancer) docs"
  default     = []
}

resource "aws_security_group" "ecs_service" {
  count       = module.this.enabled ? 1 : 0
  vpc_id      = var.vpc_id
  name        = module.service_label.id
  description = "Allow ALL egress from ECS service"
  tags        = module.service_label.tags

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "allow_all_egress" {
  count             = module.this.enabled ? 1 : 0
  description       = "Allow all outbound traffic to any IPv4 address"
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = one(aws_security_group.ecs_service[*]["id"])
}

resource "aws_ecs_service" "default" {
  count                              = module.this.enabled ? 1 : 0
  cluster                            = var.ecs_cluster_arn
  name                               = module.this.id
  task_definition                    = aws_ecs_task_definition.default[0].arn
  desired_count                      = var.task.desired_count
  deployment_maximum_percent         = var.task.deployment_maximum_percent
  deployment_minimum_healthy_percent = var.task.deployment_minimum_healthy_percent
  # availability_zone_rebalancing      = var.task.availability_zone_rebalancing
  # health_check_grace_period_seconds  = var.task.health_check_grace_period_seconds
  launch_type                        = length(var.task.capacity_provider_strategies) > 0 ? null : var.task.launch_type
  # platform_version                   = var.task.launch_type == "FARGATE" ? var.task.platform_version : null
  scheduling_strategy                = var.task.launch_type == "FARGATE" ? "REPLICA" : var.task.scheduling_strategy
  # enable_ecs_managed_tags            = var.task.enable_ecs_managed_tags
  # iam_role                           = var.task.enable_ecs_service_role ? coalesce(var.task.service_role_arn, one(aws_iam_role.ecs_service[*]["arn"])) : null
  wait_for_steady_state              = var.task.wait_for_steady_state
  # force_new_deployment               = var.task.force_new_deployment
  # enable_execute_command             = var.task.enable_execute_command

#   dynamic "capacity_provider_strategy" {
#     for_each = var.capacity_provider_strategies
#     content {
#       capacity_provider = capacity_provider_strategy.value.capacity_provider
#       weight            = capacity_provider_strategy.value.weight
#       base              = lookup(capacity_provider_strategy.value, "base", null)
#     }
#   }

#   dynamic "service_registries" {
#     for_each = var.service_registries
#     content {
#       registry_arn   = service_registries.value.registry_arn
#       port           = lookup(service_registries.value, "port", null)
#       container_name = lookup(service_registries.value, "container_name", null)
#       container_port = lookup(service_registries.value, "container_port", null)
#     }
#   }

#   dynamic "service_connect_configuration" {
#     for_each = var.service_connect_configurations
#     content {
#       enabled   = service_connect_configuration.value.enabled
#       namespace = service_connect_configuration.value.namespace
#       dynamic "log_configuration" {
#         for_each = try(service_connect_configuration.value.log_configuration, null) == null ? [] : [service_connect_configuration.value.log_configuration]
#         content {
#           log_driver = log_configuration.value.log_driver
#           options    = log_configuration.value.options
#           dynamic "secret_option" {
#             for_each = length(log_configuration.value.secret_option) == 0 ? [] : [log_configuration.value.secret_option]
#             content {
#               name       = secret_option.value.name
#               value_from = secret_option.value.value_from
#             }
#           }
#         }
#       }
#       dynamic "service" {
#         for_each = length(service_connect_configuration.value.service) == 0 ? [] : service_connect_configuration.value.service
#         content {
#           discovery_name        = service.value.discovery_name
#           ingress_port_override = service.value.ingress_port_override
#           port_name             = service.value.port_name
#           dynamic "client_alias" {
#             for_each = service.value.client_alias
#             content {
#               dns_name = client_alias.value.dns_name
#               port     = client_alias.value.port
#             }
#           }
#           dynamic "timeout" {
#             for_each = length(service.value.timeout) == 0 ? [] : service.value.timeout
#             content {
#               idle_timeout_seconds        = timeout.value.idle_timeout_seconds
#               per_request_timeout_seconds = timeout.value.per_request_timeout_seconds
#             }
#           }
#           dynamic "tls" {
#             for_each = length(service.value.tls) == 0 ? [] : service.value.tls
#             content {
#               kms_key  = tls.value.kms_key
#               role_arn = tls.value.role_arn != null ? tls.value.role_arn : one(aws_iam_role.ecs_service_connect_tls[*].arn)
#               issuer_cert_authority {
#                 aws_pca_authority_arn = tls.value.issuer_cert_authority.aws_pca_authority_arn
#               }
#             }
#           }
#         }
#       }
#     }
#   }

#   dynamic "ordered_placement_strategy" {
#     for_each = var.ordered_placement_strategy
#     content {
#       type  = ordered_placement_strategy.value.type
#       field = lookup(ordered_placement_strategy.value, "field", null)
#     }
#   }

#   dynamic "placement_constraints" {
#     for_each = var.service_placement_constraints
#     content {
#       type       = placement_constraints.value.type
#       expression = lookup(placement_constraints.value, "expression", null)
#     }
#   }

#   dynamic "load_balancer" {
#     for_each = var.ecs_load_balancers
#     content {
#       container_name   = load_balancer.value.container_name
#       container_port   = load_balancer.value.container_port
#       elb_name         = lookup(load_balancer.value, "elb_name", null)
#       target_group_arn = lookup(load_balancer.value, "target_group_arn", null)
#     }
#   }


#   propagate_tags = var.propagate_tags
#   tags           = var.use_old_arn ? null : module.this.tags

#   deployment_controller {
#     type = var.deployment_controller_type
#   }

#   # https://www.terraform.io/docs/providers/aws/r/ecs_service.html#network_configuration
  dynamic "network_configuration" {
    for_each = var.task.network_mode == "awsvpc" ? ["true"] : []
    content {
      security_groups  = compact(concat(var.security_group_ids, aws_security_group.ecs_service[*]["id"]))
      subnets          = var.subnet_ids
      assign_public_ip = var.task.assign_public_ip
    }
  }

#   dynamic "deployment_circuit_breaker" {
#     for_each = var.deployment_controller_type == "ECS" ? ["true"] : []
#     content {
#       enable   = var.circuit_breaker_deployment_enabled
#       rollback = var.circuit_breaker_rollback_enabled
#     }
#   }

#   triggers = local.redeployment_trigger

  # Avoid race condition on destroy.
  # See https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_service
  # depends_on = [aws_iam_role.ecs_service, aws_iam_role_policy.ecs_service]

}