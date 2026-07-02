# Stacks

Atmos stack configurations for each deployment environment.

- `dev.yaml` - Development environment
- `staging.yaml` - Staging environment
- `prod.yaml` - Production environment
- `preview.yaml` - Preview environments for pull requests
- `local.yaml` - Atmos native container runtime for local app development
- `fixtures.yaml` - Local AWS emulator fixtures for Terraform E2E tests
- `defaults/` - Shared configuration imported by all stacks
- `deps/` - Infrastructure dependencies (VPC, ECS cluster, EFS)

## Fixtures

The `fixtures` stack dogfoods Atmos 1.222 native features:

- AWS emulator identity and `components.emulator.aws`
- source-provisioned remote VPC and ECS cluster components
- lifecycle hooks that provision dependencies before `terraform test`
- local Terraform state under `.context/tfstate`

Run the E2E test from the repository root:

```bash
atmos terraform test app -s fixtures
```
