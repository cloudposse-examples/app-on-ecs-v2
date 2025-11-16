module "ecs_cloudwatch_autoscaling" {
  source  = "cloudposse/ecs-cloudwatch-autoscaling/aws"
  version = "0.7.3"

  count = local.enabled ? 1 : 0

  service_name          = aws_ecs_service.default[0].name
  cluster_name          = var.ecs.cluster_name
  min_capacity          = var.autoscaling.min_capacity
  max_capacity          = var.autoscaling.max_capacity
  scale_up_adjustment   = var.autoscaling.scale_up_adjustment
  scale_up_cooldown     = var.autoscaling.scale_up_cooldown
  scale_down_adjustment = var.autoscaling.scale_down_adjustment
  scale_down_cooldown   = var.autoscaling.scale_down_cooldown

  context = module.this.context

  depends_on = [
    aws_ecs_service.default
  ]
}

module "ecs_cloudwatch_sns_alarms" {
  source  = "cloudposse/ecs-cloudwatch-sns-alarms/aws"
  version = "0.12.3"
  count   = local.enabled ? 1 : 0

  cluster_name = var.ecs.cluster_name
  service_name = one(aws_ecs_service.default[*].name)

  cpu_utilization_high_threshold          = var.autoscaling.rule.high.threshold
  cpu_utilization_high_evaluation_periods = var.autoscaling.rule.high.evaluation_periods
  cpu_utilization_high_period             = var.autoscaling.rule.high.period

  cpu_utilization_high_alarm_actions = module.ecs_cloudwatch_autoscaling[*].scale_up_policy_arn

  cpu_utilization_low_threshold          = var.autoscaling.rule.low.threshold
  cpu_utilization_low_evaluation_periods = var.autoscaling.rule.low.evaluation_periods
  cpu_utilization_low_period             = var.autoscaling.rule.low.period

  cpu_utilization_low_alarm_actions = module.ecs_cloudwatch_autoscaling[*].scale_down_policy_arn

  context = module.this.context

  depends_on = [
    aws_ecs_service.default,
    module.ecs_cloudwatch_autoscaling
  ]
}