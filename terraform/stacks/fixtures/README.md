# Fixture Components

These stack files define the minimal Terraform fixtures needed to run the
`ecs-task` component tests against the local AWS emulator.

They are not production component definitions. They are small shims that satisfy
the dependency contracts consumed by `ecs-task`, such as VPC subnet outputs and
ECS cluster outputs, without standing up the full platform dependency stack.

## Why `generate` Is Used

The fixtures source upstream modules and then use Atmos `generate` blocks to
replace or add only the Terraform files needed for emulator-backed tests. This
keeps the fixture surface small:

- `vpc.yaml` creates only a VPC and public/private subnets, then emits the same
  output shape that `ecs-task` expects from the real VPC dependency.
- `ecs-cluster.yaml` uses the ECS cluster module directly, not the repository's
  full ECS component, because the test only needs a cluster ARN and name.
- Generated files disable or stub production-only wiring, such as remote state,
  capacity provider IAM, and unsupported emulator resources.

Using `generate` here is intentional. It lets the test keep the dependency
interface realistic while replacing the implementation with the smallest
emulator-compatible mock.
