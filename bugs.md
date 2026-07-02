# Atmos Dogfood Bugs

This file tracks bugs and dogfood gaps encountered while wiring this repository
to Atmos 1.222 native CI, emulator fixtures, source-provisioned components, and
Terraform test variables.

The point of this branch is to dogfood Atmos. Workarounds below should not be
treated as final design decisions; they identify places Atmos or the Atmos
GitHub Actions integration needs to be fixed.

## 1. `atmos git clone` fails before repo-local profiles are available

**Observed behavior**

GitHub Actions jobs set `ATMOS_PROFILE=github` globally and then run:

```yaml
- name: Checkout
  run: atmos git clone
```

The failing `Feature Branch` workflow died before checkout with:

```text
Error: profile not found
Profile github does not exist in any configured location Available profiles are: ``
```

This also broke `cloudposse/atmos/actions/cache@v1` immediately afterward
because `atmos ci cache paths --format=github` failed, so `actions/cache` was
called without a `key`.

**Why this blocks dogfooding**

The intended dogfood flow was to use `atmos git clone` in CI. That is not
possible when the selected profile lives in the repository being cloned.

**Current workaround**

Use `actions/checkout@v6` for initial checkout, then allow subsequent Atmos
commands to use `ATMOS_PROFILE=github` once `profiles/github/atmos.yaml` exists
in the workspace.

**Expected fix**

One of these should work:

- `atmos git clone` should be able to bootstrap without requiring a repo-local
  profile first.
- `atmos git clone` should defer profile resolution until after clone when the
  missing profile is repo-local.
- `github-action-setup-atmos` should provide a supported way to install or
  point to CI profiles before checkout.
- The cache action should fail with a direct Atmos-profile error instead of
  falling through to `actions/cache` with a missing key.

## 2. `!terraform.state` cannot read source-provisioned local fixture state

**Observed behavior**

The fixture plan expected to use `test.vars` with `!terraform.state`, e.g.:

```yaml
test:
  vars:
    ecs:
      cluster_arn: !terraform.state ecs/cluster fixtures arn
    vpc:
      vpc_id: !terraform.state vpc fixtures vpc_id
```

After the `before.terraform.test` hook applied both fixture components, Atmos
failed before running the test with variants of:

```text
Error: terraform state not provisioned for component vpc in stack fixtures
Error: terraform state not provisioned for component ecs/cluster in stack fixtures
```

Direct inspection showed the state files and outputs existed, and
`atmos terraform output vpc -s fixtures --format json` and
`atmos terraform output ecs/cluster -s fixtures --format json` both worked.

**Why this blocks dogfooding**

Atmos docs and the fixture design say `test.vars` should resolve after setup
hooks and should be able to use `!terraform.state` for fixture outputs. That is
the exact feature this repo is trying to validate.

**Current workaround**

Use `!terraform.output` in `test.vars` instead of `!terraform.state`. This keeps
the configuration declarative and avoids generating `fixtures.auto.tfvars.json`,
but it is slower and not the intended path.

**Expected fix**

`!terraform.state` should resolve outputs for source-provisioned components with
a local backend after `before.terraform.test` hooks apply those fixtures.

## 3. Local backend paths for source-provisioned nested components are fragile

**Observed behavior**

The fixture stack originally used a relative local backend path:

```yaml
path: '../../../.context/tfstate/{{ .atmos_stack }}-{{ .atmos_component | regexp.ReplaceLiteral "\\W" "-" }}.tfstate'
```

For the one-level `vpc` fixture, state landed under repo `.context/tfstate`.
For the nested `ecs/cluster` fixture, state landed under
`.workdir/.context/tfstate` because the relative path was evaluated from the
source-provisioned component workdir depth.

**Why this blocks dogfooding**

Fixture components with slashes in their component name should not silently
write state to a different root than sibling fixtures. That makes cross-fixture
lookups brittle and is hard to diagnose.

**Current workaround**

Use an absolute path based on the current repo working directory:

```yaml
path: '{{ env "PWD" }}/.context/tfstate/{{ .atmos_stack }}-{{ .atmos_component | regexp.ReplaceLiteral "\\W" "-" }}.tfstate'
```

**Expected fix**

Atmos should provide a stable repo-root/base-path value for backend path
templating, or normalize local backend paths for source-provisioned components
so nested component names do not change the effective state root.

## 4. Source-provisioned components report provider-lock persistence errors

**Observed behavior**

During fixture apply/destroy, Atmos repeatedly logged warnings like:

```text
WARN Failed to complete multi-platform provider lock
provisioner failed: persist per-instance lock
"github.com/cloudposse/terraform-aws-ecs-cluster.git/.fixtures-ecs-cluster.terraform.lock.hcl":
open github.com/cloudposse/terraform-aws-ecs-cluster.git/.fixtures-ecs-cluster.terraform.lock.hcl:
no such file or directory
```

The generated source also reported:

```text
Generated .workdir/terraform/fixtures-vpc (3 created, 3 updated, 1 errors)
Generated .workdir/terraform/fixtures-ecs/cluster (3 created, 3 updated, 1 errors)
```

Terraform/OpenTofu continued and the test could pass, but Atmos still recorded
generation errors.

**Why this blocks dogfooding**

Fixture tests should not emit persistent source-provisioning errors on the happy
path. These warnings make it unclear whether the run is genuinely healthy.

**Current workaround**

None. The run proceeds despite the warnings.

**Expected fix**

The provider-lock provisioner should persist per-instance lock files to an
existing path for git source-provisioned components, or skip that persistence
cleanly when no writable source path exists.

## 5. CI is not actually dogfooding Atmos 1.222 when `vars.ATMOS_VERSION` is old

**Observed behavior**

The failing GitHub Actions run installed Atmos `1.216.0`:

```text
Setup atmos version spec 1.216.0
Successfully set up Atmos version 1.216.0
```

This branch is specifically dogfooding Atmos 1.222 features, including emulator
fixtures and Terraform `test.vars`.

**Why this blocks dogfooding**

If the repository or organization variable remains on `1.216.0`, CI will fail
or skip the very features this branch is meant to validate.

**Current workaround**

Local validation used Atmos `1.222.0`. The repository `ATMOS_VERSION` variable
must remain at `1.222.0` so workflows can keep using a centralized version
setting without silently downgrading the dogfood run.

**Expected fix**

The CI workflow should pin or assert an Atmos version that supports the feature
under test, or fail early with a clear message when `vars.ATMOS_VERSION` is too
old.

## 6. `test.vars` output lookup logging is incomplete/noisy

**Observed behavior**

When `test.vars` used multiple `!terraform.output` lookups, Atmos logged only a
subset of the output fetches, for example `arn` and one subnet map, even though
all declared values were resolved and the test passed.

**Why this matters**

When debugging fixture variable resolution, partial logging makes it harder to
know which outputs were resolved, cached, skipped, or failed.

**Current workaround**

Manually run `atmos describe component app -s fixtures --format json` or
`atmos terraform output ...` during fixture debugging.

**Expected fix**

Atmos should make test-var resolution logs either complete or explicitly
summarized, especially when resolving fixture outputs after test setup hooks.

## 7. Toolchain dependency installation can fail CI despite `GITHUB_TOKEN`

**Observed behavior**

GitHub Actions ran `atmos terraform test app -s fixtures --ci` with
`GITHUB_TOKEN` in the step environment. Atmos still failed before Terraform
while installing inherited tool dependencies:

```text
Install failed aquasecurity/trivy@latest: failed to get latest version for aquasecurity/trivy: HTTP request failed: GitHub API returned status 403
```

**Why this blocks dogfooding**

The fixture test only needs OpenTofu, but it inherited repo-wide validation
tools from `_default.yaml`. A rate-limited `latest` lookup for an unrelated
tool can fail an emulator test before the fixture resources are even applied.

**Current workaround**

Pin inherited `tflint` and `trivy` versions in `_default.yaml` so CI does not
perform unauthenticated or token-ignored `latest` lookups.

**Expected fix**

Atmos should either use the GitHub token consistently for toolchain latest
resolution in CI or make `!unset`/component overrides work cleanly for
`terraform.dependencies.tools`.

## 8. Emulator identity loopback endpoints fail inside GitHub job containers

**Observed behavior**

Running the e2e job as a GitHub Actions job container with:

```yaml
container:
  image: ghcr.io/cloudposse/atmos:${{ vars.ATMOS_VERSION }}
```

required installing a Docker CLI in the container so `atmos emulator up aws`
could use the mounted host Docker socket. After that, Atmos started the AWS
emulator successfully, but Terraform failed against the injected endpoint:

```text
Post "http://127.0.0.1:32768/": dial tcp 127.0.0.1:32768: connect: connection refused
```

The emulator container was started through the host Docker daemon and published
its port on the host. Inside the GitHub job container, `127.0.0.1` is the job
container itself, not the host where the emulator port is listening.

**Why this blocks dogfooding**

The intended CI shape was the Atmos container image approach without installing
Atmos on the runner. That works for ordinary Atmos commands, but emulator
identity injection currently produces a host-loopback endpoint that is invalid
from a sibling job container.

**Current workaround**

Run the Atmos image explicitly from the host runner with `docker run --network
host` and the host Docker socket mounted. This keeps the Atmos image approach
while making the injected `127.0.0.1:<port>` endpoint resolve to the same host
network namespace where the emulator publishes its port.

**Expected fix**

Atmos should make emulator endpoints container-context aware, or document and
support a first-class GitHub Actions container mode for emulators so the
injected endpoint is reachable from the process running Terraform.

## 9. `terraform clean` in fixture setup can break emulator resolution

**Observed behavior**

Replacing the fixture setup's manual cleanup with:

```yaml
- type: atmos
  command: terraform clean vpc -s fixtures --everything --force
- type: atmos
  command: terraform clean ecs/cluster -s fixtures --everything --force
```

looked like the right dogfood path, but `atmos terraform test app -s fixtures
--ci` then failed after `emulator up` and source pull:

```text
authentication failed: post-authentication failed: resolve emulator "aws" for
identity "local-aws": emulator is not running: fixtures/emulator/aws
```

The hook had just reported the emulator as up, so the failure appears to be in
how the subsequent Atmos subprocess resolves the emulator instance after the
clean/source-pull sequence.

**Why this blocks dogfooding**

The fixture setup should be able to use Atmos-native cleanup instead of shell
`rm -f`/`rm -rf` shims. Right now the native cleanup path makes the following
fixture applies unable to see the emulator that the same hook started.

**Current workaround**

Keep the explicit shell cleanup for fixture state/workdirs instead of replacing
it with `atmos terraform clean` in the test setup hook.

**Expected fix**

`atmos terraform clean` should not interfere with later emulator identity
resolution in the same `before.terraform.test` hook, or Atmos should document
the cleanup boundary required before `emulator up`.
