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

Local validation used Atmos `1.222.0`.

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

