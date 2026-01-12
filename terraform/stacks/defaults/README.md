# Defaults

Shared configuration imported by all environment stacks.

- `app.yaml` - Default container and task configuration for the application

## Brownfield Configuration

If you're not using Cloud Posse's reference architecture or don't want to use `!terraform.state` lookups, you can hardcode your infrastructure values directly. Replace the `!terraform.state` calls in `app.yaml` with your own values.

### Required Variables

| Variable | Description | Used By |
|----------|-------------|---------|
| `ecs.cluster_arn` | ECS cluster ARN | `service.tf` |
| `ecs.cluster_name` | ECS cluster name | `autoscaling.tf` |
| `vpc.vpc_id` | VPC ID | `service.tf` (security groups) |
| `vpc.private_subnet_ids` | Private subnet IDs for ECS tasks | `service.tf` (network config) |
| `lb.security_group_id` | ALB security group ID | `service.tf` (ingress rules) |
| `lb.https_listener_arn` | ALB HTTPS listener ARN | `service.tf` (target group attachment) |
| `base_domains.public` | Wildcard domain (e.g., `*.example.com`) | `service.tf` (Route53 alias) |
| `base_domains.private` | Private wildcard domain | Required by type but not used |

### Example Configuration

```yaml
# terraform/stacks/defaults/app.yaml (brownfield version)
components:
  terraform:
    app:
      metadata:
        component: ecs-task
      vars:
        name: app

        # ECS Cluster
        ecs:
          cluster_arn: arn:aws:ecs:us-east-2:123456789012:cluster/my-cluster
          cluster_name: my-cluster

        # VPC
        vpc:
          vpc_id: vpc-0123456789abcdef0
          private_subnet_ids:
            - subnet-aaaaaaaaaaaaa
            - subnet-bbbbbbbbbbbbb

        # ALB
        lb:
          security_group_id: sg-0123456789abcdef0
          https_listener_arn: arn:aws:elasticloadbalancing:us-east-2:123456789012:listener/app/my-alb/abc123/def456

        # DNS
        base_domains:
          public: "*.example.com"
          private: "*.internal.example.com"

        # Container configuration
        containers:
          app:
            image: 123456789012.dkr.ecr.us-east-2.amazonaws.com/my-app:latest
            memory: 256
            portMappings:
              - containerPort: 8080
            healthCheck:
              command: ["CMD-SHELL", "curl -f http://localhost:8080/healthz || exit 1"]
              interval: 30
              retries: 3
              startPeriod: 0
              timeout: 5
```

### Notes

- The variable types in `variables.tf` require more fields than are actually used. This is for compatibility with Cloud Posse's component outputs.
- If you're not using EFS volumes, remove the `task.volumes` configuration entirely.
- The `base_domains.private` field is required by the type definition but not actually used in the component.
