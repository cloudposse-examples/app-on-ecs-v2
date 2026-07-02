# Workflows

GitHub Actions pipelines for building, validating, and deploying the application.

| Workflow | Trigger | Action |
|----------|---------|--------|
| `feature-branch.yml` | Pull request, merge queue | Build image, run Go tests, run Terraform emulator E2E, deploy preview (PR with `deploy` label), deploy dev (merge queue gate) |
| `validate.yml` | Pull request, merge queue | Lint CODEOWNERS |
| `main-branch.yaml` | Push to `main` | Update draft release notes |
| `release.yaml` | Published release, manual dispatch | Promote image, deploy to staging and/or prod |
| `preview-cleanup.yml` | PR closed | Destroy preview environment |
| `labeler.yaml` | Pull request | Auto-label based on changed files |

## Conventions

### Workflows are named by trigger context

Workflow files are named for *where they fire from* (a feature branch, the main branch, a release event), not for what they do (CI/CD). Functions blur as workflows evolve — the dev deploy is technically "CD" but lives in the file that gates feature-branch merges. The trigger context, however, is fixed and unambiguous: each workflow has exactly one trigger origin. That makes trigger-based names durable.

### Dev deploy runs in the merge queue, not on push to `main`

The merge queue runs the full `build` + `test` + `deploy-dev` chain on a temporary commit (the PR rebased on top of `main`). If `atmos terraform deploy` fails, the PR is rejected from the queue and never lands on `main`. This catches a broken Terraform apply *before* it breaks dev — a stronger guarantee than deploying after merge and noticing the failure.

The `push: main` event then fires on a commit that has already been built, tested, and deployed. `main-branch.yaml` therefore only updates the draft release; it does not redo the work the queue already did.

### Staging and prod deploys do NOT run in the merge queue

GitHub environments support required reviewers (manual approval gates). If the prod environment requires approval and a queued PR is paused waiting for a human, every PR queued behind it is also blocked — head-of-line blocking. For high-PR-volume teams this collapses queue throughput.

To preserve queue throughput while keeping a human gate on production, staging/prod deploys run from `release.yaml` instead of from the queue. Releases are explicitly triggered (or manually dispatched), so any approval delay only blocks that release, not other PRs.

### `release.yaml` supports `workflow_dispatch` for rollback and out-of-band deploys

Triggering on `release: published` is great for "deploy the new version," but useless for "redeploy v1.2.3 to prod because v1.2.4 broke." `release.yaml` accepts a `tag` input (any image tag in ECR) and an `environment` input (`staging`, `prod`, or `both`), so you can roll back, hotfix, or selectively redeploy without cutting a new release. The `promote` job is skipped on dispatch (the image already exists at that tag).

### Trade-off: queue bypass

If a maintainer force-merges a PR (bypassing the queue), `main-branch.yaml` will only draft a release — it will not auto-deploy to dev. This is a deliberate trade-off: the queue is the single source of truth for dev deploys, and bypassing the queue means accepting that you are skipping the deploy gate too. Use `release.yaml` workflow_dispatch to redeploy dev (or any environment) if needed.

## Pull Request → Merge Queue → Dev

```mermaid
sequenceDiagram
    participant Dev as Developer
    participant GH as GitHub
    participant GA as GitHub Actions
    participant ECR as AWS ECR
    participant Atmos as Atmos CLI
    participant TF as OpenTofu
    participant ECS as AWS ECS

    Dev->>GH: Open PR
    GH->>GA: Trigger feature-branch workflow (pull_request)
    GA->>ECR: Build & push Docker image (sha-xxx)
    GA->>GA: Run Go tests
    GA->>Atmos: atmos terraform test app -s fixtures --ci
    Atmos->>TF: Apply VPC/ECS fixtures against AWS emulator
    TF-->>Atmos: Run ECS task Terraform test
    GA-->>GH: Required checks pass
    Dev->>GH: Click "Merge when ready"
    GH->>GH: Place PR on queue ref (gh-readonly-queue/main/...)
    GH->>GA: Trigger feature-branch workflow (merge_group)
    GA->>ECR: Build & push Docker image
    GA->>GA: Run Go tests
    GA->>Atmos: atmos terraform test app -s fixtures --ci
    GA->>Atmos: atmos terraform deploy app -s dev
    Atmos->>TF: tofu apply
    TF->>ECS: Update dev ECS service
    ECS-->>GA: Deployment complete
    GA-->>GH: Required checks pass
    GH->>GH: Fast-forward main to queue commit
    GH->>GA: Trigger main-branch workflow (push)
    GA->>GH: Update draft release notes
```

## Pull Request → Preview Environment (label-gated)

```mermaid
sequenceDiagram
    participant Dev as Developer
    participant GH as GitHub
    participant GA as GitHub Actions
    participant ECR as AWS ECR
    participant Atmos as Atmos CLI
    participant TF as OpenTofu
    participant ECS as AWS ECS

    Dev->>GH: Open PR with `deploy` label
    GH->>GA: Trigger feature-branch workflow (pull_request)
    GA->>ECR: Build & push Docker image
    GA->>GA: Run Go tests
    GA->>Atmos: atmos terraform deploy app -s preview
    Atmos->>TF: tofu apply
    TF->>ECS: Create preview ECS service
    ECS-->>GA: Preview URL
    GA->>GH: Post preview URL to PR
    Note over Dev,GH: PR closed
    GH->>GA: Trigger preview-cleanup workflow
    GA->>Atmos: atmos terraform destroy app -s preview
    Atmos->>TF: tofu destroy
    TF->>ECS: Delete preview ECS service
```

## Release → Staging → Prod

```mermaid
sequenceDiagram
    participant Dev as Developer
    participant GH as GitHub
    participant GA as GitHub Actions
    participant ECR as AWS ECR
    participant Atmos as Atmos CLI
    participant TF as OpenTofu
    participant ECS as AWS ECS

    Dev->>GH: Publish release (v1.2.3)
    GH->>GA: Trigger release workflow (release)
    GA->>ECR: Promote image tag (sha-xxx → v1.2.3)
    GA->>Atmos: atmos terraform deploy app -s staging
    Atmos->>TF: tofu apply
    TF->>ECS: Update staging ECS service
    ECS-->>GA: Staging deployed
    GA->>Atmos: atmos terraform deploy app -s prod
    Atmos->>TF: tofu apply
    TF->>ECS: Update prod ECS service
    ECS-->>GA: Production deployed
```

## Manual Dispatch (rollback / hotfix)

```mermaid
sequenceDiagram
    participant Op as Operator
    participant GH as GitHub
    participant GA as GitHub Actions
    participant Atmos as Atmos CLI
    participant TF as OpenTofu
    participant ECS as AWS ECS

    Op->>GH: Run release workflow (workflow_dispatch)<br/>tag=1.2.3, environment=prod
    GH->>GA: Trigger release workflow
    Note over GA: promote job skipped (image already in ECR)
    GA->>Atmos: atmos terraform deploy app -s prod<br/>APP_IMAGE=...:1.2.3
    Atmos->>TF: tofu apply
    TF->>ECS: Update prod ECS service to v1.2.3
    ECS-->>GA: Rollback complete
```

## Environment Promotion Flow

```mermaid
graph LR
    A[Open PR] --> B[Build & Test]
    B --> B2[Terraform Emulator E2E]
    B2 --> C{PR has<br/>`deploy` label?}
    C -->|Yes| D[Deploy Preview]
    C -->|No| E[Approve]
    D --> E
    E --> F[Click<br/>Merge when ready]
    F --> G[Merge Queue:<br/>Build, Test, Deploy Dev]
    G -->|Success| H[Fast-forward main]
    G -->|Failure| A
    H --> I[Update Draft Release]
    I --> J{Publish Release?}
    J -->|Yes| K[Promote Image]
    K --> L[Deploy Staging]
    L --> M[Deploy Production]
    J -->|Manual Dispatch| N[Deploy selected env<br/>at specified tag]
```
