# Workflows

GitHub Actions CI/CD pipelines.

| Workflow | Description |
|----------|-------------|
| `main-branch.yaml` | Build, deploy to dev, and create draft release on push to main |
| `release.yaml` | Deploy to staging and prod on published release |
| `feature-branch.yml` | Deploy preview environment for PRs with `deploy` label |
| `preview-cleanup.yml` | Destroy preview environment when PR is closed |
| `validate.yml` | Run validation checks on pull requests |
| `labeler.yaml` | Auto-label PRs based on changed files |
