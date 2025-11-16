locals {
  hostname = replace(var.base_domains.public, "*", module.this.id)
}

module "service_label" {
  source     = "cloudposse/label/null"
  version    = "0.25.0"
  attributes = ["service"]

  context = module.this.context
}

resource "aws_security_group" "ecs_service" {
  count       = module.this.enabled ? 1 : 0
  vpc_id      = var.vpc.vpc_id
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

resource "aws_security_group_rule" "allow_alb_ingress" {
  count                    = module.this.enabled ? 1 : 0
  description              = "Allow all outbound traffic to any IPv4 address"
  type                     = "ingress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  source_security_group_id = var.lb.security_group_id
  security_group_id        = one(aws_security_group.ecs_service[*].id)
}

module "alb_ingress" {
  source  = "cloudposse/alb-ingress/aws"
  version = "0.31.0"

  count = module.this.enabled ? 1 : 0

  vpc_id                        = var.vpc.vpc_id
  unauthenticated_listener_arns = [var.lb.https_listener_arn]
  unauthenticated_hosts = [local.hostname]
  unauthenticated_paths = []
  # When set to catch-all, make priority super high to make sure last to match
  unauthenticated_priority     = -1
  default_target_group_enabled = true

  health_check_matcher             = "200-404"
  health_check_path                = "/healthz"
  health_check_port                = "traffic-port"
  health_check_protocol            = "HTTP"
  health_check_healthy_threshold   = 2
  health_check_unhealthy_threshold = 2
  health_check_interval            = 5
  health_check_timeout             = 2
  protocol                         = "HTTP"
  port                             = 80

  stickiness_enabled         = false
  stickiness_type            = "lb_cookie"
  stickiness_cookie_duration = 86400

  context = module.service_label.context
}

resource "aws_ecs_service" "default" {
  count   = module.this.enabled ? 1 : 0
  cluster = var.ecs.cluster_arn
  name    = module.this.id

  task_definition = one(aws_ecs_task_definition.default[*].arn)

  scheduling_strategy = "REPLICA"

  deployment_controller {
    type = "ECS"
  }
  deployment_configuration {
    strategy = "ROLLING"
    # bake_time_in_minutes = 1
    # Read more about lifecycle hooks here: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_service#lifecycle_hook
    # lifecycle_hook {
    # }
  }
  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }
  sigint_rollback       = true
  wait_for_steady_state = true

  deployment_maximum_percent         = var.service.deployment_maximum_percent
  deployment_minimum_healthy_percent = var.service.deployment_minimum_healthy_percent

  availability_zone_rebalancing = "ENABLED"

  capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 1
    base              = 1
  }

  # placement_constraints {
  #   type = "distinctInstance"
  #   expression = ""
  # }

  # ordered_placement_strategy {
  #   type = "random"
  #   # field = "attribute:ecs.availability-zone"
  # }

  enable_ecs_managed_tags = true
  propagate_tags          = "TASK_DEFINITION"

  enable_execute_command = var.service.enable_execute_command
  force_new_deployment   = var.service.force_new_deployment

  # https://www.terraform.io/docs/providers/aws/r/ecs_service.html#network_configuration
  network_configuration {
      security_groups  = compact(aws_security_group.ecs_service[*].id)
      subnets          = var.vpc.private_subnet_ids
      assign_public_ip = false
  }

  iam_role = one(aws_iam_role.ecs_service[*].arn)

  load_balancer {
    container_name   = "app"
    container_port   = one(local.container_definitions["app"].portMappings[*].containerPort)
    target_group_arn = one(module.alb_ingress[*].target_group_arn)
  }
  
  # health_check_grace_period_seconds  = 10

  tags = module.this.tags

  # Avoid race condition on destroy.
  # See https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_service
  depends_on = [aws_iam_role.ecs_service, aws_iam_role_policy.ecs_service]

  # Ignore changes to desired count as we use autoscaling instead
  lifecycle {
    ignore_changes = [desired_count]
  }
}
