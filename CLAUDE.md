# CLAUDE.md

Example containerized Go web application deployed to AWS ECS Fargate using Atmos and OpenTofu. Demonstrates Cloud Posse best practices for containerized application deployment with CI/CD pipelines.

## Quick Reference

```bash
# Local development
atmos up                                # Start app locally with Podman Compose
atmos down                              # Stop local app

# Deploy with Atmos
atmos terraform plan app -s dev         # Plan changes for dev
atmos terraform deploy app -s dev       # Deploy to dev
atmos terraform deploy app -s staging   # Deploy to staging
atmos terraform deploy app -s prod      # Deploy to production

# Get deployment URL
atmos terraform output app -s dev --skip-init -- -raw url

# List components
atmos list components                   # Shows app component per stack
```

## Project Structure

- `app/` - Go web application (see `app/README.md`)
  - `main.go` - Go web server serving static HTML
  - `Dockerfile` - Multi-stage Docker build (Alpine)
  - `public/` - Static HTML assets
  - `rootfs/` - Container filesystem overlay
- `atmos.yaml` - Atmos CLI configuration
- `.atmos.d/commands.yaml` - Custom Atmos commands (`atmos up`, `atmos down`)
- `terraform/components/ecs-task/` - Main Terraform component
- `terraform/stacks/` - Environment configurations
- `test/docker-compose.yml` - Local dev environment

## Stack Configuration

Atmos stack configuration is in `terraform/stacks/`:
- `_default.yaml` - Shared defaults (backend, labels, namespace/tenant/region)
- `defaults/app.yaml` - App component config with container definitions
- `deps/` - External dependency references (vpc, ecs/cluster, efs)
- `dev.yaml`, `staging.yaml`, `prod.yaml`, `preview.yaml` - Environment-specific settings

### Atmos YAML Functions

Used in stack configs (see `defaults/app.yaml` for examples):

| Function | Usage | Docs |
|----------|-------|------|
| `!terraform.state` | `!terraform.state <component> <output>` | [terraform.state](https://atmos.tools/core-concepts/stacks/yaml-functions/terraform.state) |
| `!env` | `!env VAR_NAME default_value` | [env](https://atmos.tools/core-concepts/stacks/yaml-functions/env) |
| `!include` | `!include path/to/file.json` | [include](https://atmos.tools/core-concepts/stacks/yaml-functions/include) |

See [Atmos YAML Functions](https://atmos.tools/core-concepts/stacks/yaml-functions) for full documentation.

Examples from this repo:
```yaml
ecs: !terraform.state ecs/cluster .           # Get all outputs from ecs/cluster
vpc: !terraform.state vpc .                   # Get all outputs from vpc
file_system_id: !terraform.state efs .efs_id  # Get specific output
image: !env APP_IMAGE default-image:tag       # Override image via env var
nginx: !include ../../components/ecs-task/sidecars/nginx.json
```

## Prerequisites

Before deploying, you must have the following infrastructure deployed:

1. **VPC** - With public/private subnets
2. **ECS Cluster** - With ALB and DNS records configured
3. **EFS** (optional) - For persistent storage volumes

Then configure dependencies using one of two approaches:

**Option 1: Use `!terraform.state`** - Update `terraform/stacks/deps/*.yaml` to point to your infrastructure's remote state

**Option 2: Hardcode values** - Replace `!terraform.state` lookups in `defaults/app.yaml` with hardcoded values

## Dependencies

The app component depends on external infrastructure via `!terraform.state` lookups in `defaults/app.yaml`:

| Dependency | Source | Provides |
|------------|--------|----------|
| `vpc` | `deps/vpc.yaml` | VPC configuration |
| `ecs/cluster` | `deps/ecs.yaml` | ECS cluster, ALB, DNS records |
| `efs` | `deps/efs.yaml` | EFS filesystem ID for volumes |

**Troubleshooting:** If deployments fail, check that:
1. The `deps_stage` variable matches the environment where dependencies exist
2. Remote state is accessible (S3 bucket configured in `deps/*.yaml`)
3. IAM role for state access has appropriate permissions
4. The prerequisite components are deployed and their outputs match what `defaults/app.yaml` expects

## Environment Variables (Go App)

See `app/README.md` for application environment variables.

## CI/CD Pipeline

- Push to `main` → build, deploy to dev, draft release
- Publish release → promote image, deploy to staging/prod
- PR with `deploy` label → preview environment
- PR close → cleanup preview

## Naming Convention

Labels: `namespace-tenant-environment-stage-name`
Example: `cplive-plat-ue2-dev-app`
