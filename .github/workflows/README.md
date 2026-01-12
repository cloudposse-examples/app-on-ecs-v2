# Workflows

GitHub Actions CI/CD pipelines.

| Workflow | Trigger | Action |
|----------|---------|--------|
| `main-branch.yaml` | Push to `main` | Build image → Deploy to dev → Create draft release |
| `release.yaml` | Published release | Promote image → Deploy to staging and prod |
| `feature-branch.yml` | PR with `deploy` label | Build image → Deploy to preview environment |
| `preview-cleanup.yml` | PR closed | Destroy preview environment |
| `validate.yml` | Pull request | Run validation checks |
| `labeler.yaml` | Pull request | Auto-label based on changed files |

## Main Branch Workflow

```mermaid
sequenceDiagram
    participant Dev as Developer
    participant GH as GitHub
    participant GA as GitHub Actions
    participant ECR as AWS ECR
    participant Atmos as Atmos CLI
    participant TF as OpenTofu
    participant ECS as AWS ECS

    Dev->>GH: Push to main
    GH->>GA: Trigger main-branch workflow
    GA->>ECR: Build & push Docker image
    ECR-->>GA: Image pushed (sha-xxx)
    GA->>Atmos: atmos terraform deploy app -s dev
    Atmos->>TF: tofu apply
    TF->>ECS: Update ECS service
    ECS-->>GA: Deployment complete
    GA->>GH: Create draft release
```

## Release Workflow

```mermaid
sequenceDiagram
    participant Dev as Developer
    participant GH as GitHub
    participant GA as GitHub Actions
    participant ECR as AWS ECR
    participant Atmos as Atmos CLI
    participant TF as OpenTofu
    participant ECS as AWS ECS

    Dev->>GH: Publish release (v1.0.0)
    GH->>GA: Trigger release workflow
    GA->>ECR: Promote image tag (sha-xxx → v1.0.0)
    GA->>Atmos: atmos terraform deploy app -s staging
    Atmos->>TF: tofu apply
    TF->>ECS: Update staging ECS service
    ECS-->>GA: Staging deployed
    GA->>Atmos: atmos terraform deploy app -s prod
    Atmos->>TF: tofu apply
    TF->>ECS: Update prod ECS service
    ECS-->>GA: Production deployed
```

## Feature Branch Workflow (Preview Environments)

```mermaid
sequenceDiagram
    participant Dev as Developer
    participant GH as GitHub
    participant GA as GitHub Actions
    participant ECR as AWS ECR
    participant Atmos as Atmos CLI
    participant TF as OpenTofu
    participant ECS as AWS ECS

    Dev->>GH: Open PR with 'deploy' label
    GH->>GA: Trigger feature-branch workflow
    GA->>ECR: Build & push Docker image
    ECR-->>GA: Image pushed
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

## Environment Promotion Flow

```mermaid
graph LR
    A[Push to main] --> B[Build Image]
    B --> C[Deploy to Dev]
    C --> D[Draft Release]
    D --> E{Publish Release}
    E --> F[Promote Image Tag]
    F --> G[Deploy to Staging]
    G --> H[Deploy to Production]

    I[PR with 'deploy' label] --> J[Build Image]
    J --> K[Deploy to Preview]
    K --> L{PR Merged/Closed}
    L --> M[Cleanup Preview]
```
