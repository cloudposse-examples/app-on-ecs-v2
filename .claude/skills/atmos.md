# Atmos Configuration

## Stack Configuration

Atmos stack configuration is in `terraform/stacks/`:
- `_default.yaml` - Shared defaults (backend, labels, namespace/tenant/region)
- `defaults/app.yaml` - App component config with container definitions
- `deps/` - External dependency references (vpc, ecs/cluster, efs)
- `dev.yaml`, `staging.yaml`, `prod.yaml`, `preview.yaml` - Environment-specific settings

## Atmos YAML Functions

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

## Custom Commands

Defined in `.atmos.d/commands.yaml`:
- `atmos up` - Start app locally with Podman Compose
- `atmos down` - Stop local app
