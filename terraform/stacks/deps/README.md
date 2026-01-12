# Dependencies

Remote state references for infrastructure dependencies that must exist before deploying this application.

These files define abstract components that tell Atmos where to find the Terraform state for each dependency. The `!terraform.state` function in `defaults/app.yaml` uses these to fetch outputs.

## Files

- `ecs.yaml` - ECS cluster configuration
- `vpc.yaml` - VPC and networking
- `efs.yaml` - EFS filesystem for persistent storage

## Expected Outputs

The dependency components must provide these outputs (see `terraform/components/ecs-task/variables.tf` for full type definitions):

### vpc

```hcl
vpc_id                 = string       # VPC ID
vpc_cidr               = string       # VPC CIDR block
private_subnet_ids     = list(string) # Private subnet IDs
public_subnet_ids      = list(string) # Public subnet IDs
availability_zones     = list(string) # Availability zones
az_private_subnets_map = map(list(string))
az_public_subnets_map  = map(list(string))
```

### ecs/cluster

```hcl
cluster_arn  = string  # ECS cluster ARN
cluster_name = string  # ECS cluster name
alb.public = {         # ALB configuration (accessed via .alb.public)
  alb_arn            = string
  alb_arn_suffix     = string
  alb_dns_name       = string
  alb_name           = string
  alb_zone_id        = string
  http_listener_arn  = string
  https_listener_arn = string
  security_group_id  = string
}
records = {            # DNS records (accessed via .records)
  public  = string     # Public base domain
  private = string     # Private base domain
}
```

### efs

```hcl
efs_id = string  # EFS filesystem ID
```

## Configuration

Each dependency file defines:

| Setting | Description |
|---------|-------------|
| `metadata.component` | The Terraform component name in the remote state |
| `metadata.type` | Set to `abstract` (not deployed directly, just referenced) |
| `metadata.terraform_workspace` | Workspace name pattern for the remote state |
| `backend_type` | Backend type (e.g., `s3`) |
| `backend.s3.bucket` | S3 bucket containing the Terraform state |
| `backend.s3.key` | State file key (usually `terraform.tfstate`) |
| `backend.s3.region` | AWS region of the state bucket |
| `backend.s3.assume_role.role_arn` | IAM role to assume for reading state (needs read access) |

Note: Authentication is inherited from the stack-level `terraform.auth` configuration (e.g., in `dev.yaml`).

## Example

```yaml
components:
  terraform:
    vpc:
      metadata:
        component: vpc
        type: abstract
        terraform_workspace: "{{ .vars.tenant }}-{{ .vars.environment }}-{{ .vars.deps_stage }}"
      backend_type: s3
      backend:
        s3:
          bucket: my-tfstate-bucket
          encrypt: true
          key: terraform.tfstate
          region: us-east-2
          assume_role:
            role_arn: arn:aws:iam::123456789012:role/tfstate-reader
```

## Workspace Templating

The `terraform_workspace` uses Go templates with variables from the stack:
- `{{ .vars.tenant }}` - Tenant name (e.g., `plat`)
- `{{ .vars.environment }}` - Environment code (e.g., `ue2`)
- `{{ .vars.deps_stage }}` - Stage where dependencies live (e.g., `dev`)

This allows the same dependency config to work across environments by changing `deps_stage` in each stack file.
