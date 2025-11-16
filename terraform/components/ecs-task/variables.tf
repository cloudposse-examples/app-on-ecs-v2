variable "region" {
  type        = string
  description = "AWS Region"
}

variable "github_repo_name" {
  type        = string
  description = "The GitHub repository name"
}

# https://docs.aws.amazon.com/AmazonECS/latest/APIReference/API_ContainerDefinition.html
variable "containers" {
  type = map(object({
    command = optional(list(string))
    cpu     = optional(number)
    dependsOn = optional(list(object({
      condition     = string
      containerName = string
    })))
    disableNetworking     = optional(bool)
    dnsSearchDomains      = optional(list(string))
    dnsServers            = optional(list(string))
    dockerLabels          = optional(map(string))
    dockerSecurityOptions = optional(list(string))
    entryPoint            = optional(list(string))
    environment = optional(list(object({
      name  = string
      value = string
    })))
    environmentFiles = optional(list(object({
      type  = string
      value = string
    })))
    essential = optional(bool)
    extraHosts = optional(list(object({
      hostname  = string
      ipAddress = string
    })))
    firelensConfiguration = optional(object({
      options = optional(map(string))
      type    = string
    }))
    healthCheck = optional(object({
      command     = list(string)
      interval    = optional(number)
      retries     = optional(number)
      startPeriod = optional(number)
      timeout     = optional(number)
    }))
    hostname    = optional(string)
    image       = optional(string)
    interactive = optional(bool)
    links       = optional(list(string))
    linuxParameters = optional(object({
      capabilities = optional(object({
        add  = optional(list(string))
        drop = optional(list(string))
      }))
      devices = optional(list(object({
        containerPath = string
        hostPath      = string
        permissions   = optional(list(string))
      })))
      initProcessEnabled = optional(bool)
      maxSwap            = optional(number)
      sharedMemorySize   = optional(number)
      swappiness         = optional(number)
      tmpfs = optional(list(object({
        containerPath = string
        mountOptions  = optional(list(string))
        size          = number
      })))
    }))
    logConfiguration = optional(object({
      logDriver = string
      options   = optional(map(string))
      secretOptions = optional(list(object({
        name      = string
        valueFrom = string
      })))
    }))
    memory            = optional(number)
    memoryReservation = optional(number)
    mountPoints = optional(list(object({
      containerPath = optional(string)
      readOnly      = optional(bool)
      sourceVolume  = optional(string)
    })))
    name = optional(string)
    portMappings = optional(list(object({
      containerPort = number
      hostPort      = optional(number)
      protocol      = optional(string)
      name          = optional(string)
      appProtocol   = optional(string)
    })))
    privileged             = optional(bool)
    pseudoTerminal         = optional(bool)
    readonlyRootFilesystem = optional(bool)
    repositoryCredentials = optional(object({
      credentialsParameter = string
    }))
    resourceRequirements = optional(list(object({
      type  = string
      value = string
    })))
    restartPolicy = optional(object({
      enabled              = bool
      ignoredExitCodes     = optional(list(number))
      restartAttemptPeriod = optional(number)
    }))
    secrets = optional(list(object({
      name      = string
      valueFrom = string
    })))
    startTimeout = optional(number)
    stopTimeout  = optional(number)
    systemControls = optional(list(object({
      namespace = string
      value     = string
    })))
    ulimits = optional(list(object({
      hardLimit = number
      name      = string
      softLimit = number
    })))
    user               = optional(string)
    versionConsistency = optional(string)
    volumesFrom = optional(list(object({
      readOnly        = optional(bool)
      sourceContainer = string
    })))
    workingDirectory = optional(string)
  }))
  description = "Container definition overrides which allows for extra keys or overriding existing keys."
  default     = {}

  validation {
    condition = alltrue([
      for k, v in var.containers : (
        (
          lookup(v, "memory", null) != null || lookup(v, "memoryReservation", null) != null
        )
      )
    ])
    error_message = "Each container definition must have at least one of 'memory' or 'memoryReservation' set."
  }
}

variable "service" {
  type = object({
    deployment_maximum_percent         = optional(number, null)
    deployment_minimum_healthy_percent = optional(number, null)
    force_new_deployment               = optional(bool, false)
    enable_execute_command             = optional(bool, false)
  })
  description = "The service configuration"
  default     = {}
}

variable "autoscaling" {
  type = object({
    min_capacity          = optional(number, 1)
    max_capacity          = optional(number, 2)
    scale_down_cooldown   = optional(number, 300)
    scale_up_cooldown     = optional(number, 60)
    scale_up_step_adjustments   = optional(object({
      metric_interval_lower_bound = optional(number, 0)
      metric_interval_upper_bound = optional(number, null)
      scaling_adjustment          = optional(number, 1)
    }), {})
    scale_down_step_adjustments = optional(object({
      metric_interval_lower_bound = optional(number, null)
      metric_interval_upper_bound = optional(number, 0)
      scaling_adjustment          = optional(number, -1)
    }), {})
    rule = optional(object({
      low = optional(object({
        threshold = optional(number, 20)
        evaluation_periods = optional(number, 1)
        period = optional(number, 300)
      }), {})
      high = optional(object({
        threshold = optional(number, 80)
        evaluation_periods = optional(number, 1)
        period = optional(number, 300)
      }), {})
    }), {})
  })
  description = "The autoscaling configuration by CPU utilization"
  default     = {}
}

variable "task" {
  type = object({
    cpu      = optional(number, 256)
    memory   = optional(number, 512)
    ephemeral_storage_size = optional(number, 0)
    volumes = optional(map(object({
      host_path = optional(string, null)
      efs_volume_configuration = optional(object({
        file_system_id          = string
        root_directory          = string
        transit_encryption      = optional(bool, true)
        transit_encryption_port = optional(string, null)
        authorization_config = optional(object({
          access_point_id = optional(string, null)
          iam             = optional(bool, false)
        }), null)
      }), null)
    })), {})
  })
  description = "Feed inputs into ecs_alb_service_task module"
  default     = {}
}

variable "ecs" {
  type = object({
    cluster_arn : string,
    cluster_name : string,
  })
  description = "The ECS cluster configuration"
}

variable "vpc" {
  type = object({
    availability_zones     = list(string)
    az_private_subnets_map = map(list(string))
    az_public_subnets_map  = map(list(string))
    flow_log_destination   = any
    flow_log_id            = list(any)
    private_subnet_ids     = list(string)
    public_subnet_ids      = list(string)
    vpc_cidr               = string
    vpc_id                 = string
  })
  description = "The VPC configuration"
}

variable "lb" {
  type = object({
    alb_arn : string,
    alb_arn_suffix : string,
    alb_dns_name : string,
    alb_name : string,
    alb_zone_id : string,
    http_listener_arn : string,
    https_listener_arn : string,
    security_group_id : string
  })
  description = "The ALB listener and target group configuration"
  default     = null
}

variable "base_domains" {
  type = object({
    public : string,
    private : string
  })
  description = "The base domain to use for the service"
}
