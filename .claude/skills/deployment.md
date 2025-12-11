# Deployment

## Prerequisites

Before deploying, you must have the following infrastructure deployed:

1. **VPC** - With public/private subnets
2. **ECS Cluster** - With ALB and DNS records configured
3. **EFS** (optional) - For persistent storage volumes

Then configure dependencies using one of two approaches:

**Option 1: Use `!terraform.state`** - Update `terraform/stacks/deps/*.yaml` to point to your infrastructure's remote state

**Option 2: Hardcode values** - Replace `!terraform.state` lookups in `defaults/app.yaml` with hardcoded values (see `terraform/stacks/defaults/README.md`)

## Dependencies

The app component depends on external infrastructure via `!terraform.state` lookups in `defaults/app.yaml`:

| Dependency | Source | Provides |
|------------|--------|----------|
| `vpc` | `deps/vpc.yaml` | VPC configuration |
| `ecs/cluster` | `deps/ecs.yaml` | ECS cluster, ALB, DNS records |
| `efs` | `deps/efs.yaml` | EFS filesystem ID for volumes |

## Troubleshooting

If deployments fail, check that:
1. The `deps_stage` variable matches the environment where dependencies exist
2. Remote state is accessible (S3 bucket configured in `deps/*.yaml`)
3. IAM role for state access has appropriate permissions
4. The prerequisite components are deployed and their outputs match what `defaults/app.yaml` expects

## CI/CD Pipeline

- Push to `main` → build, deploy to dev, draft release
- Publish release → promote image, deploy to staging/prod
- PR with `deploy` label → preview environment
- PR close → cleanup preview

## Naming Convention

Labels: `namespace-tenant-environment-stage-name`
Example: `cplive-plat-ue2-dev-app`
