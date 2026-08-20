# Test

Local development testing using Atmos native containers.

## Quick Start

```bash
# Start the app locally
atmos app up

# Stream logs
atmos app logs

# Stop the app
atmos app down
```

The app will be available at http://localhost:8080.

## Terraform E2E

Run the ECS task Terraform component against the local AWS emulator:

```bash
atmos terraform test app -s fixtures
```

The fixture stack source-provisions the VPC and ECS cluster components, starts
the AWS emulator, applies those dependencies, runs `ecs_task.tftest.hcl`, and
then tears the dependencies and emulator down.
