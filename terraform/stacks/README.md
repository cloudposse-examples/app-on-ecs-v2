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
- Atmos secrets declarations backed by SSM and ECS runtime secret injection
- source-provisioned remote VPC and ECS cluster components
- lifecycle hooks that provision dependencies before `terraform test`
- local Terraform state under `.context/tfstate`

Run the E2E test from the repository root:

```bash
atmos terraform test app -s fixtures
```

## Secrets

`atmos.yaml` defines the `secrets/ssm` store as an AWS SSM SecureString backend.
The `app` component declares `API_KEY` under `secrets.vars` so
`atmos secret list` and `atmos secret init` can discover it. The ECS task
definition receives the SSM parameter name through `containers.app.secrets`, so
the secret value is fetched by ECS at task startup instead of being resolved by
Atmos into Terraform input.
