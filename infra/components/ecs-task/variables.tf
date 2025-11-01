variable "region" {
  type        = string
  description = "AWS Region"
}

variable "cluster_attributes" {
  type        = list(string)
  description = "The attributes of the cluster name e.g. if the full name is `namespace-tenant-environment-dev-ecs-b2b` then the `cluster_name` is `ecs` and this value should be `b2b`."
  default     = []
}

variable "logs" {
  type        = any
  description = "Feed inputs into cloudwatch logs module"
  default     = {}
}

variable "ecs_cluster_name" {
  type        = any
  description = "The name of the ECS Cluster this belongs to"
  default     = "ecs"
}

variable "alb_name" {
  type        = string
  description = "The name of the ALB this service should attach to"
  default     = null
}

variable "nlb_name" {
  type        = string
  description = "The name of the NLB this service should attach to"
  default     = null
}

variable "s3_mirror_name" {
  type        = string
  description = "The name of the S3 mirror component"
  default     = null
}

variable "rds_name" {
  type        = any
  description = "The name of the RDS database this service should allow access to"
  default     = null
}

variable "containers" {
  type = map(object({
    ecr_image                = optional(string)
    image                    = optional(string)
    memory                   = optional(number)
    memory_reservation       = optional(number)
    cpu                      = optional(number)
    essential                = optional(bool, true)
    readonly_root_filesystem = optional(bool, null)
    privileged               = optional(bool, null)
    user                     = optional(string, null)
    container_depends_on = optional(list(object({
      containerName = string
      condition     = string # START, COMPLETE, SUCCESS, HEALTHY
    })), null)

    port_mappings = optional(list(object({
      containerPort = number
      hostPort      = optional(number)
      protocol      = optional(string)
      name          = optional(string)
      appProtocol   = optional(string)
    })), [])
    command    = optional(list(string), null)
    entrypoint = optional(list(string), null)
    healthcheck = optional(object({
      command     = list(string)
      interval    = number
      retries     = number
      startPeriod = number
      timeout     = number
    }), null)
    ulimits = optional(list(object({
      name      = string
      softLimit = number
      hardLimit = number
    })), null)
    log_configuration = optional(object({
      logDriver = string
      options   = optional(map(string), {})
    }))
    docker_labels   = optional(map(string), null)
    map_environment = optional(map(string), {})
    map_secrets     = optional(map(string), {})
    volumes_from = optional(list(object({
      sourceContainer = string
      readOnly        = bool
    })), null)
    mount_points = optional(list(object({
      sourceVolume  = optional(string)
      containerPath = optional(string)
      readOnly      = optional(bool)
    })), [])
  }))
  description = <<EOT
Inputs for the container definition module.
`user`: The user to run as inside the container. Can be any of these formats: user, user:group, uid, uid:gid, user:gid, uid:group. The default (null) will use the container's configured `USER` directive or root if not set."
EOT
  default     = {}

  validation {
    condition = alltrue([
      for k, v in var.containers : (
        (
          lookup(v, "memory", null) != null || lookup(v, "memory_reservation", null) != null
        )
      )
    ])
    error_message = "Each container definition must have at least one of 'memory' or 'memory_reservation' set."
  }
}

variable "task" {
  type = object({
    task_cpu                = optional(number)
    task_memory             = optional(number)
    task_role_arn           = optional(string, "")
    pid_mode                = optional(string, null)
    ipc_mode                = optional(string, null)
    network_mode            = optional(string, "awsvpc")
    propagate_tags          = optional(string)
    assign_public_ip        = optional(bool, false)
    use_alb_security_groups = optional(bool, true)
    launch_type             = optional(string, "FARGATE")
    scheduling_strategy     = optional(string, "REPLICA")
    capacity_provider_strategies = optional(list(object({
      capacity_provider = string
      weight            = number
      base              = number
    })), [])

    deployment_minimum_healthy_percent = optional(number, null)
    deployment_maximum_percent         = optional(number, null)
    desired_count                      = optional(number, 0)
    min_capacity                       = optional(number, 1)
    max_capacity                       = optional(number, 2)
    wait_for_steady_state              = optional(bool, true)
    circuit_breaker_deployment_enabled = optional(bool, true)
    circuit_breaker_rollback_enabled   = optional(bool, true)

    ignore_changes_task_definition = optional(bool, true)
    ignore_changes_desired_count   = optional(bool, false)

    ecs_service_enabled = optional(bool, true)
    bind_mount_volumes = optional(list(object({
      name      = string
      host_path = string
    })), [])
    efs_volumes = optional(list(object({
      host_path = string
      name      = string
      efs_volume_configuration = list(object({
        file_system_id          = string
        root_directory          = string
        transit_encryption      = string
        transit_encryption_port = string
        authorization_config = list(object({
          access_point_id = string
          iam             = string
        }))
      }))
    })), [])
    efs_component_volumes = optional(list(object({
      host_path = string
      name      = string
      efs_volume_configuration = list(object({
        component   = optional(string, "efs")
        tenant      = optional(string, null)
        environment = optional(string, null)
        stage       = optional(string, null)

        root_directory          = string
        transit_encryption      = string
        transit_encryption_port = string
        authorization_config = list(object({
          access_point_id = string
          iam             = string
        }))
      }))
    })), [])
    docker_volumes = optional(list(object({
      host_path = string
      name      = string
      docker_volume_configuration = list(object({
        autoprovision = bool
        driver        = string
        driver_opts   = map(string)
        labels        = map(string)
        scope         = string
      }))
    })), [])
    fsx_volumes = optional(list(object({
      host_path = string
      name      = string
      fsx_windows_file_server_volume_configuration = list(object({
        file_system_id = string
        root_directory = string
        authorization_config = list(object({
          credentials_parameter = string
          domain                = string
        }))
      }))
    })), [])
  })
  description = "Feed inputs into ecs_alb_service_task module"
  default     = {}
}

variable "task_policy_arns" {
  type        = list(string)
  description = "The IAM policy ARNs to attach to the ECS task IAM role"
  default = [
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
    "arn:aws:iam::aws:policy/AmazonSSMReadOnlyAccess",
  ]
}

variable "unauthenticated_paths" {
  type        = list(string)
  description = "Unauthenticated path pattern to match"
  default     = []
}

variable "unauthenticated_priority" {
  type        = string
  description = "The priority for the rules without authentication, between 1 and 50000 (1 being highest priority). Must be different from `authenticated_priority` since a listener can't have multiple rules with the same priority	"
  default     = 0
}

variable "task_enabled" {
  type        = bool
  description = "Whether or not to use the ECS task module"
  default     = true
}

variable "ecr_stage_name" {
  type        = string
  description = "The ecr stage (account) name to use for the fully qualified ECR image URL."
  default     = "auto"
}

variable "ecr_region" {
  type        = string
  description = "The region to use for the fully qualified ECR image URL. Defaults to the current region."
  default     = ""
}

variable "iam_policy_statements" {
  type        = any
  description = "Map of IAM policy statements to use in the policy. This can be used with or instead of the `var.iam_source_json_url`."
  default     = {}
}

variable "iam_policy_enabled" {
  type        = bool
  description = "If set to true will create IAM policy in AWS"
  default     = false
}

variable "vanity_alias" {
  type        = list(string)
  description = "The vanity aliases to use for the public LB."
  default     = []
}

variable "additional_targets" {
  type        = list(string)
  description = "Additional target routes to add to the ALB that point to this service. The only difference between this and `var.vanity_alias` is `var.vanity_alias` will create an alias record in Route 53 in the hosted zone in this account as well. `var.additional_targets` only adds the listener route to this service's target group."
  default     = []
}

variable "kinesis_enabled" {
  type        = bool
  description = "Enable Kinesis"
  default     = false
}

variable "shard_count" {
  description = "Number of shards that the stream will use"
  type        = number
  default     = 1
}

variable "retention_period" {
  description = "Length of time data records are accessible after they are added to the stream"
  type        = number
  default     = 48
}

variable "shard_level_metrics" {
  description = "List of shard-level CloudWatch metrics which can be enabled for the stream"
  type        = list(string)
  default = [
    "IncomingBytes",
    "IncomingRecords",
    "IteratorAgeMilliseconds",
    "OutgoingBytes",
    "OutgoingRecords",
    "ReadProvisionedThroughputExceeded",
    "WriteProvisionedThroughputExceeded",
  ]
}

variable "kms_key_alias" {
  description = "ID of KMS key"
  type        = string
  default     = "default"
}

variable "use_lb" {
  description = "Whether use load balancer for the service"
  default     = false
  type        = bool
}

variable "http_protocol" {
  description = "Which http protocol to use in outputs and SSM url params. This value is ignored if a load balancer is not used. If it is `null`, the redirect value from the ALB determines the protocol."
  default     = null
  type        = string

  validation {
    condition     = anytrue([var.http_protocol == null, try(contains(["https", "http"], var.http_protocol), false)])
    error_message = "Allowed values: `http`, `https`, and `null`."
  }
}

variable "stream_mode" {
  description = "Stream mode details for the Kinesis stream"
  default     = "PROVISIONED"
  type        = string
}

variable "use_rds_client_sg" {
  type        = bool
  description = "Use the RDS client security group"
  default     = false
}

variable "chamber_service" {
  default     = "ecs-service"
  type        = string
  description = "SSM parameter service name for use with chamber. This is used in chamber_format where /$chamber_service/$name/$container_name/$parameter would be the default."
}

variable "zone_component" {
  type        = string
  description = "The component name to look up service domain remote-state on"
  default     = "dns-delegated"
}

variable "zone_component_output" {
  type        = string
  description = "A json query to use to get the zone domain from the remote state. See "
  default     = ".default_domain_name"
}

variable "vanity_domain" {
  default     = null
  type        = string
  description = "Whether to use the vanity domain alias for the service"
}

variable "alb_configuration" {
  type        = string
  description = "The configuration to use for the ALB, specifying which cluster alb configuration to use"
  default     = "default"
}

variable "health_check_path" {
  type        = string
  description = "The destination for the health check request"
  default     = "/health"
}

variable "health_check_port" {
  type        = string
  default     = "traffic-port"
  description = "The port to use to connect with the target. Valid values are either ports 1-65536, or `traffic-port`. Defaults to `traffic-port`"
}

variable "health_check_timeout" {
  type        = number
  default     = 10
  description = "The amount of time to wait in seconds before failing a health check request"
}

variable "health_check_healthy_threshold" {
  type        = number
  default     = 2
  description = "The number of consecutive health checks successes required before healthy"
}

variable "health_check_unhealthy_threshold" {
  type        = number
  default     = 2
  description = "The number of consecutive health check failures required before unhealthy"
}

variable "health_check_interval" {
  type        = number
  default     = 15
  description = "The duration in seconds in between health checks"
}

variable "health_check_matcher" {
  type        = string
  default     = "200-404"
  description = "The HTTP response codes to indicate a healthy check"
}

variable "health_check_protocol" {
  type        = string
  default     = "HTTP"
  description = "The protocol to use to connect with the target. Defaults to HTTP. Not applicable when target_type is lambda"
  validation {
    condition     = contains(["HTTP", "HTTPS", "TCP", "TLS", "UDP", "TCP_UDP", "GENEVE"], var.health_check_protocol)
    error_message = "Allowed values for health_check_protocol are HTTP, HTTPS, TCP, TLS, UDP, TCP_UDP, and GENEVE."
  }
}

variable "protocol" {
  type        = string
  default     = "HTTP"
  description = "The protocol for the created ALB target group. Defaults to HTTP"
  validation {
    condition     = contains(["HTTP", "HTTPS", "TCP", "TLS", "UDP", "TCP_UDP", "GENEVE"], var.protocol)
    error_message = "Allowed values for protocol are HTTP, HTTPS, TCP, TLS, UDP, TCP_UDP, and GENEVE."
  }
}

variable "port" {
  type        = number
  default     = 80
  description = "The port for the created ALB target group. Defaults to 80"
  validation {
    condition     = var.port >= 1 && var.port <= 65535
    error_message = "Port must be between 1 and 65535."
  }
}


variable "lb_catch_all" {
  type        = bool
  description = "Should this service act as catch all for all subdomain hosts of the vanity domain"
  default     = false
}

variable "stickiness_type" {
  type        = string
  default     = "lb_cookie"
  description = "The type of sticky sessions. The only current possible value is `lb_cookie`"
}

variable "stickiness_cookie_duration" {
  type        = number
  default     = 86400
  description = "The time period, in seconds, during which requests from a client should be routed to the same target. After this time period expires, the load balancer-generated cookie is considered stale. The range is 1 second to 1 week (604800 seconds). The default value is 1 day (86400 seconds)"
}

variable "stickiness_enabled" {
  type        = bool
  default     = true
  description = "Boolean to enable / disable `stickiness`. Default is `true`"
}

variable "autoscaling_enabled" {
  type        = bool
  default     = true
  description = "Should this service autoscale using SNS alarams"
}

variable "autoscaling_dimension" {
  type        = string
  description = "The dimension to use to decide to autoscale"
  default     = "cpu"

  validation {
    condition     = contains(["cpu", "memory"], var.autoscaling_dimension)
    error_message = "Allowed values for autoscaling_dimension are \"cpu\" or \"memory\"."
  }
}

variable "cpu_utilization_high_threshold" {
  type        = number
  description = "The maximum percentage of CPU utilization average"
  default     = 80
}

variable "cpu_utilization_high_evaluation_periods" {
  type        = number
  description = "Number of periods to evaluate for the alarm"
  default     = 1
}

variable "cpu_utilization_high_period" {
  type        = number
  description = "Duration in seconds to evaluate for the alarm"
  default     = 300
}

variable "cpu_utilization_high_alarm_actions" {
  type        = list(string)
  description = "A list of ARNs (i.e. SNS Topic ARN) to notify on CPU Utilization High Alarm action"
  default     = []
}

variable "cpu_utilization_high_ok_actions" {
  type        = list(string)
  description = "A list of ARNs (i.e. SNS Topic ARN) to notify on CPU Utilization High OK action"
  default     = []
}

variable "cpu_utilization_low_threshold" {
  type        = number
  description = "The minimum percentage of CPU utilization average"
  default     = 20
}

variable "cpu_utilization_low_evaluation_periods" {
  type        = number
  description = "Number of periods to evaluate for the alarm"
  default     = 1
}

variable "cpu_utilization_low_period" {
  type        = number
  description = "Duration in seconds to evaluate for the alarm"
  default     = 300
}

variable "cpu_utilization_low_alarm_actions" {
  type        = list(string)
  description = "A list of ARNs (i.e. SNS Topic ARN) to notify on CPU Utilization Low Alarm action"
  default     = []
}

variable "cpu_utilization_low_ok_actions" {
  type        = list(string)
  description = "A list of ARNs (i.e. SNS Topic ARN) to notify on CPU Utilization Low OK action"
  default     = []
}

variable "memory_utilization_high_threshold" {
  type        = number
  description = "The maximum percentage of Memory utilization average"
  default     = 80
}

variable "memory_utilization_high_evaluation_periods" {
  type        = number
  description = "Number of periods to evaluate for the alarm"
  default     = 1
}

variable "memory_utilization_high_period" {
  type        = number
  description = "Duration in seconds to evaluate for the alarm"
  default     = 300
}

variable "memory_utilization_high_alarm_actions" {
  type        = list(string)
  description = "A list of ARNs (i.e. SNS Topic ARN) to notify on Memory Utilization High Alarm action"
  default     = []
}

variable "memory_utilization_high_ok_actions" {
  type        = list(string)
  description = "A list of ARNs (i.e. SNS Topic ARN) to notify on Memory Utilization High OK action"
  default     = []
}

variable "memory_utilization_low_threshold" {
  type        = number
  description = "The minimum percentage of Memory utilization average"
  default     = 20
}

variable "memory_utilization_low_evaluation_periods" {
  type        = number
  description = "Number of periods to evaluate for the alarm"
  default     = 1
}

variable "memory_utilization_low_period" {
  type        = number
  description = "Duration in seconds to evaluate for the alarm"
  default     = 300
}

variable "memory_utilization_low_alarm_actions" {
  type        = list(string)
  description = "A list of ARNs (i.e. SNS Topic ARN) to notify on Memory Utilization Low Alarm action"
  default     = []
}

variable "memory_utilization_low_ok_actions" {
  type        = list(string)
  description = "A list of ARNs (i.e. SNS Topic ARN) to notify on Memory Utilization Low OK action"
  default     = []
}

variable "task_security_group_component" {
  type        = string
  description = "A component that outputs security_group_id for adding to the service as a whole."
  default     = null
}

variable "task_iam_role_component" {
  type        = string
  description = "A component that outputs an iam_role module as 'role' for adding to the service as a whole."
  default     = null
}

variable "task_exec_policy_arns_map" {
  type        = map(string)
  description = <<-EOT
    A map of name to IAM Policy ARNs to attach to the generated task execution role.
    The names are arbitrary, but must be known at plan time. The purpose of the name
    is so that changes to one ARN do not cause a ripple effect on the other ARNs.
    If you cannot provide unique names known at plan time, use `task_exec_policy_arns` instead.
    EOT
  default     = {}
}

variable "task_exec_iam_policy" {
  type = list(object({
    policy_id = optional(string, null)
    version   = optional(string, null)
    statements = list(object({
      sid           = optional(string, null)
      effect        = optional(string, null)
      actions       = optional(list(string), null)
      not_actions   = optional(list(string), null)
      resources     = optional(list(string), null)
      not_resources = optional(list(string), null)
      conditions = optional(list(object({
        test     = string
        variable = string
        values   = list(string)
      })), [])
      principals = optional(list(object({
        type        = string
        identifiers = list(string)
      })), [])
      not_principals = optional(list(object({
        type        = string
        identifiers = list(string)
      })), [])
    }))
  }))
  description = <<-EOT
    IAM policy as list of Terraform objects, compatible with Terraform `aws_iam_policy_document` data source
    except that `source_policy_documents` and `override_policy_documents` are not included.
    Use inputs `iam_source_policy_documents` and `iam_override_policy_documents` for that.
    EOT
  default     = []
  nullable    = false
}

variable "exec_enabled" {
  type        = bool
  description = "Specifies whether to enable Amazon ECS Exec for the tasks within the service"
  default     = false
}

variable "enable_all_egress_rule" {
  type        = bool
  description = "A flag to enable/disable adding the all ports egress rule to the service security group"
  default     = true
}

variable "service_connect_configurations" {
  type = list(object({
    enabled   = bool
    namespace = optional(string, null)
    log_configuration = optional(object({
      log_driver = string
      options    = optional(map(string), null)
      secret_option = optional(list(object({
        name       = string
        value_from = string
      })), [])
    }), null)
    service = optional(list(object({
      client_alias = list(object({
        dns_name = string
        port     = number
      }))
      discovery_name        = optional(string, null)
      ingress_port_override = optional(number, null)
      port_name             = string
    })), [])
  }))
  description = <<-EOT
    The list of Service Connect configurations.
    See `service_connect_configuration` docs https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_service#service_connect_configuration
    EOT
  default     = []
}

variable "service_registries" {
  type = list(object({
    namespace      = string
    registry_arn   = optional(string)
    port           = optional(number)
    container_name = optional(string)
    container_port = optional(number)
  }))
  description = <<-EOT
    The list of Service Registries.
    See `service_registries` docs https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_service#service_registries
    EOT
  default     = []
}

variable "custom_security_group_rules" {
  type = list(object({
    type                     = string
    from_port                = number
    to_port                  = number
    protocol                 = string
    cidr_blocks              = optional(list(string))
    description              = optional(string)
    source_security_group_id = optional(string)
    prefix_list_ids          = optional(list(string))
    security_group_id        = optional(string)
  }))
  description = "The list of custom security group rules to add to the service security group"
  default     = []
}

variable "scale_up_step_adjustments" {
  type = list(object({
    metric_interval_lower_bound = optional(number)
    metric_interval_upper_bound = optional(number)
    scaling_adjustment          = number
  }))
  description = "List of step adjustments for scale up policy"
  default = [{
    metric_interval_lower_bound = 0
    metric_interval_upper_bound = null
    scaling_adjustment          = 1
  }]
}

variable "scale_down_step_adjustments" {
  type = list(object({
    metric_interval_lower_bound = optional(number)
    metric_interval_upper_bound = optional(number)
    scaling_adjustment          = number
  }))
  description = "List of step adjustments for scale down policy"
  default = [{
    metric_interval_lower_bound = null
    metric_interval_upper_bound = 0
    scaling_adjustment          = -1
  }]
}

variable "vpc_component_name" {
  type        = string
  description = "The name of a VPC component"
  default     = "vpc"
}

variable "additional_security_groups" {
  type        = list(string)
  description = "A list of additional security group IDs to add to the service"
  default     = []
}

variable "additional_lb_target_groups" {
  type = list(object({
    container_name   = string
    container_port   = number
    target_group_arn = string
  }))
  description = <<-EOT
    Additional load balancer target group configurations for registering multiple container ports.
    This allows you to register sidecar containers to separate target groups.
    Each entry requires:
    - container_name: Name of the container to register
    - container_port: Port on the container to register
    - target_group_arn: ARN of the target group. Each additional port must specify a unique target group ARN
  EOT
  default     = []

  validation {
    condition = alltrue([
      for config in var.additional_lb_target_groups :
      can(regex("^arn:aws[a-z-]*:elasticloadbalancing:[a-z0-9-]+:[0-9]{12}:targetgroup/.+$", config.target_group_arn))
    ])
    error_message = "Each additional_lb_target_groups entry must specify a valid target_group_arn in the format: arn:aws:elasticloadbalancing:region:account-id:targetgroup/name/id"
  }
}
