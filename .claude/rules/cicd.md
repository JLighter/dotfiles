---
paths:
  - "**/.github/workflows/*.yml"
  - "**/.github/workflows/*.yaml"
  - "**/.gitlab-ci.yml"
  - "**/Jenkinsfile"
  - "**/.circleci/config.yml"
  - "**/bitbucket-pipelines.yml"
  - "**/azure-pipelines.yml"
  - "**/.drone.yml"
  - "**/cloudbuild.yaml"
  - "**/taskfile*.yml"
  - "**/Makefile"
  - "**/Justfile"
---

# CI/CD Pipeline Rules

## Security
- No secrets in pipeline files. Use the platform's secret management.
- Pin all action/image versions to SHA or exact version. No `@latest` or `@main`.
- Scan dependencies for vulnerabilities in the pipeline.
- Least privilege on CI/CD service accounts.

## Reliability
- Pipelines must be idempotent. Running twice produces the same result.
- All steps must have timeouts. No unbounded waits.
- Failures must produce clear error messages. No silent failures.
- Cache dependencies to reduce build times.

## Structure
- Separate build, test, and deploy stages clearly.
- Tests must pass before deploy. No bypassing test failures.
- Deploy to staging before production. No direct-to-prod.
- Rollback mechanism must exist and be documented.

## Maintainability
- Reuse shared workflows/templates. No copy-paste between pipelines.
- Keep pipelines under 100 lines. Extract complex logic into scripts.
- Document non-obvious steps with comments.
- Environment-specific config via variables, not separate pipeline files.
