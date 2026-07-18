# Atmos Dogfood Bugs

This file tracks bugs and dogfood gaps encountered while wiring this repository
to Atmos 1.223 native CI, emulator fixtures, source-provisioned components, and
Terraform test variables.

The point of this branch is to dogfood Atmos. Workarounds below should not be
treated as final design decisions; they identify places Atmos or the Atmos
GitHub Actions integration needs to be fixed.

## Status checked against Atmos 1.223.0

Checked on 2026-07-18 with local `atmos version` reporting `1.223.0`.
Docker was not available locally, so emulator-backed Terraform execution still
needs GitHub Actions validation.

Atmos PR `cloudposse/atmos#2681` explicitly fixes the native CI dogfood
regressions for `atmos git clone` bootstrap, local backend `path` state reads,
source-provisioned lock persistence, Aqua latest lookup fallback, and emulator
job-container networking. That covers bugs 1, 2, 4, 7, and 8, and likely covers
the local-backend portion of bug 3.

Current status:

| Bug | Status in 1.223.0 | Evidence |
|-----|-------------------|----------|
| 1 | Fixed upstream | `cloudposse/atmos#2681` says native CI bootstrap now allows `atmos git clone` before repo-local profile/config files exist. |
| 2 | Fixed upstream, needs repo e2e confirmation | `cloudposse/atmos#2681` says local backend `path` state reads were fixed; local emulator test could not run without Docker. |
| 3 | Likely fixed upstream, needs workaround-removal test | `cloudposse/atmos#2681` covers local backend `path` state reads, but this repo still uses the absolute-path workaround. |
| 4 | Fixed upstream | `cloudposse/atmos#2681` says remote source-provisioned lock persistence was fixed. |
| 5 | Fixed in repo configuration | GitHub repository variable `ATMOS_VERSION` is `1.223.0`. |
| 6 | Not confirmed fixed | The `1.223.0` release notes do not call out complete `test.vars` output lookup logging. |
| 7 | Fixed upstream | `cloudposse/atmos#2681` says Aqua latest lookup fallback was fixed. |
| 8 | Fixed upstream, needs CI confirmation | `cloudposse/atmos#2681` says emulator containers now attach to the current GitHub job container network with aliases. |
| 9 | Not confirmed fixed | The `1.223.0` release notes do not call out `terraform clean` preserving emulator identity resolution. |
| 10 | Not confirmed fixed | `cloudposse/atmos#2663` implemented Terraform test job summaries, but this still needs checking in the GitHub job summary UI. |
| 11 | Not fixed in `v1`/`v1.223.0` action refs | `cloudposse/atmos/actions/cache@v1` resolves to `v1.223.0-rc.11`, and `v1.223.0` also has the dangling `.claude/skills/atmos-gitops` symlink. |

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

The intended Atmos-core dogfood flow was to use `atmos git clone` in CI. That
does not belong in this app repository's workflows while the selected profile
lives in the repository being cloned.

**Current workaround**

Use `actions/checkout@v6` for initial checkout in this repository, then allow
subsequent Atmos commands to use `ATMOS_PROFILE=github` once
`profiles/github/atmos.yaml` exists in the workspace.

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

## 5. CI is not actually dogfooding Atmos 1.223 when `vars.ATMOS_VERSION` is old

**Observed behavior**

The failing GitHub Actions run installed Atmos `1.216.0`:

```text
Setup atmos version spec 1.216.0
Successfully set up Atmos version 1.216.0
```

This branch is specifically dogfooding Atmos 1.223 features, including emulator
fixtures and Terraform `test.vars`.

**Why this blocks dogfooding**

If the repository or organization variable remains on `1.216.0`, CI will fail
or skip the very features this branch is meant to validate.

**Current workaround**

Local validation should use Atmos `1.223.0`. The repository `ATMOS_VERSION`
variable must remain at `1.223.0` so workflows can keep using a centralized version
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

**Desired use case**

An app repository should be able to run Atmos from
`ghcr.io/cloudposse/atmos:<version>` in GitHub Actions, mount the host Docker
socket so Atmos can start emulator containers, and then run:

```text
atmos terraform test app -s fixtures --ci
```

That should work without wrapping the command in `docker run --network host`.
Terraform/OpenTofu should be able to reach the emulator endpoint that Atmos
injects into auth/profile/provider configuration.

**Minimal reproduction shape**

1. Run a GitHub Actions job from an Atmos container image.
2. Install or provide a Docker CLI inside that job container.
3. Mount the host Docker socket into the job container.
4. Run `atmos terraform test app -s fixtures --ci`.
5. Atmos starts the AWS emulator through the host Docker daemon.
6. Atmos injects `http://127.0.0.1:<published-port>` as the emulator endpoint.
7. Terraform fails because `127.0.0.1` resolves to the job container, not the
   Docker host where the emulator port was published.

**Current workaround**

Run the Atmos image explicitly from the host runner with `docker run --network
host` and the host Docker socket mounted. This keeps the Atmos image approach
while making the injected `127.0.0.1:<port>` endpoint resolve to the same host
network namespace where the emulator publishes its port.

**Expected fix**

Atmos should make emulator endpoints container-context aware so the injected
endpoint is reachable from the process running Terraform:

- Host-native Atmos should keep using `127.0.0.1:<published-host-port>`.
- Containerized Atmos should prefer connecting emulator containers to the
  current Atmos/job container network, then inject a network alias plus the
  emulator container port.
- If sharing the current container network is not possible, Atmos should fall
  back to a host-gateway reachable address plus the published host port.

Once Atmos core handles this, app repositories should not need `--network host`
for emulator-backed Terraform tests.

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

## 10. `terraform test --ci` summary is too sparse on passing runs

**Observed behavior**

The successful GitHub Actions run `28612339269` ran:

```text
atmos terraform test app -s fixtures --ci
```

The raw job log included the OpenTofu test result:

```text
Success! 1 passed, 0 failed, 0 skipped.
```

The current dogfood target is `ghcr.io/cloudposse/atmos:1.223.0`. Atmos PR
`cloudposse/atmos#2663` says it added native-CI job step summaries for
`terraform test`: pass/fail/skip badges and a per-run results table. The
workflow passed `GITHUB_ACTIONS`, `GITHUB_STEP_SUMMARY`, `GITHUB_OUTPUT`, and
mounted `$RUNNER_TEMP`, which is where GitHub normally places the step summary
file.

GitHub commit status for the merge commit only recorded
`atmos/test/fixtures/app` with description `1 passed`. The GitHub check/status
API surface had no output body, no assertion table, no artifact, and no PR
comment with the `.tftest.hcl` run name or assertion details.

**Why this blocks dogfooding**

Atmos documentation and PR `#2663` say `terraform test` native CI should write a
GitHub job step summary with per-run pass/fail/skip results and inline failing
assertions. The current evidence proves CI mode and commit-status updates are
enabled, but the visible status surface still collapses to a count-only
description that does not show `applies_ecs_service_against_emulator` or the
assertions that were exercised.

This may not be the same surface that PR `#2663` implemented. Atmos writes
`$GITHUB_STEP_SUMMARY` for the job summary, while the commit status/check API
description is limited to short status text such as `1 passed`. If the GitHub
job page did contain the rich step summary, this is not an Atmos summary bug;
it is an expectation mismatch between job summaries and commit/check status
output.

**Current workaround**

Do not add a repository wrapper script for this. The desired workflow is to run
Atmos native CI directly and let Atmos own the summary behavior.

**Expected fix**

First verify the actual GitHub job summary UI for run `28612339269`. If the rich
summary is present there, the missing piece is documentation/expectation: Atmos
should make clear that `terraform test --ci` rich output is a job summary, not a
GitHub commit-status/check-run output body, artifact, or PR comment.

If the rich job summary is absent, Atmos should make the failure diagnosable:
when `ci.summary.enabled` is true and `GITHUB_ACTIONS=true`,
`atmos terraform test --ci` should log or warn whether it detected
`GITHUB_STEP_SUMMARY`, whether the path was writable, and whether the summary
was rendered. The native summary should remain sufficient without a repository
wrapper.

## 11. `cloudposse/atmos/actions/cache@v1` resolves to a broken action package

**Observed behavior**

GitHub Actions failed while preparing the `build` job before any repository
commands ran:

```text
Could not find file '/home/runner/work/_actions/_temp_734e84cf-bd27-41c7-a729-573be4aebf94/_staging/atmos-1c00575b4be0393764fd202c4f0fb8efaf2411a0/.claude/skills/atmos-gitops'.
```

The workflow used:

```yaml
uses: cloudposse/atmos/actions/cache@v1
```

At the time of failure, `v1` resolved to commit
`1c00575b4be0393764fd202c4f0fb8efaf2411a0`, the same commit as
`v1.223.0-rc.11`. That tag contains `.claude/skills/atmos-gitops` as a symlink,
but the symlink target `agent-skills/skills/atmos-gitops` is missing.

**Why this blocks dogfooding**

The Atmos cache action is part of the native CI path this repository is
dogfooding. A broken moving `v1` ref prevents GitHub Actions from even starting
the job, so the workflow cannot reach Atmos, Docker build, or Terraform test
execution.

**Current workaround**

Pin `cloudposse/atmos/actions/cache` to `v1.223.0-rc.6`, the newest 1.223 RC
where `agent-skills/skills/atmos-gitops` still exists.

**Expected fix**

Atmos should not publish or advance action tags to commits with dangling
symlinks in the action archive. The moving `v1` ref and the final `v1.223.0`
tag should point to an action package that GitHub Actions can download without
missing-file errors.
