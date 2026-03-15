---
paths:
  - "**/*.tf"
  - "**/*.hcl"
  - "**/*.tfvars"
  - "**/Dockerfile"
  - "**/Dockerfile.*"
  - "**/docker-compose.*"
  - "**/Vagrantfile"
  - "**/*.ansible.yml"
  - "**/playbook*.yml"
  - "**/helmfile.*"
  - "**/Chart.yaml"
  - "**/values*.yaml"
  - "**/kustomization.yaml"
  - "**/Pulumi.yaml"
  - "**/*.sh"
---

# Infrastructure as Code Rules

## Immutability
- All infrastructure must be defined in code. No manual changes.
- If it exists in production, it exists in a .tf, Helm chart, or equivalent.
- No imperative scripts for provisioning. Scripts are for automation glue only.

## Security
- No secrets in code. Use secret managers (Vault, AWS Secrets Manager, SOPS).
- No hardcoded IPs, credentials, or tokens.
- Least privilege on all IAM roles and policies. No wildcards (*) on actions or resources.
- All data at rest encrypted. All data in transit encrypted (TLS).
- Security groups and network policies deny by default, allow explicitly.

## Naming and Tagging
- All resources must be tagged: environment, team, service, cost-center.
- Resource names include environment and purpose: `prod-api-db`, not `database1`.
- Consistent naming across all resources in the same project.

## State and Lifecycle
- Remote state with locking (S3+DynamoDB, GCS, Terraform Cloud).
- State files never committed to git.
- Use `prevent_destroy` on critical resources (databases, storage).
- Plan before apply. Never apply without reviewing the plan.

## Modularity
- Reusable modules for repeated patterns. No copy-paste infrastructure.
- Modules have clear inputs (variables) and outputs.
- Pin module versions. No unversioned module references.
- Pin provider versions. No implicit latest.

## Cost Awareness
- Every resource should have a justification for its size/tier.
- Use appropriate instance types. No oversizing "just in case".
- Prefer reserved/committed use for predictable workloads.
- Auto-scaling where applicable. Fixed capacity is a cost smell.
