# CLAUDE.md

Example containerized Go web application deployed to AWS ECS Fargate using Atmos and OpenTofu.

## Quick Reference

```bash
# Local development
atmos app up                            # Start app locally with Atmos native containers
atmos app down                          # Stop local app
atmos app logs                          # Stream local container logs

# Terraform component E2E against the local AWS emulator
atmos terraform test app -s fixtures

# Deploy with Atmos
atmos terraform plan app -s dev         # Plan changes for dev
atmos terraform deploy app -s dev       # Deploy to dev
atmos terraform deploy app -s staging   # Deploy to staging
atmos terraform deploy app -s prod      # Deploy to production

# Get deployment URL
atmos terraform output app -s dev --skip-init -- -raw url
```

## Project Structure

- `app/` - Go web application (see `app/README.md`)
- `terraform/components/ecs-task/` - Main Terraform component
- `terraform/stacks/` - Environment, local container, and emulator fixture configurations
- `.atmos.d/commands.yaml` - Custom Atmos commands
