# Global Conventions

## Language
- Always respond in French.
- Technical terms and code identifiers remain in their original form.

## Project Lifecycle
- `/init-project` to bootstrap a new project (rules, CLAUDE.md, docs/).
- `/audit-project` to get a full health report of the codebase.
- `/adr` to reason through architectural decisions before implementing.
- `/new-feature` to spec a feature before implementing.
- `/implement-feature` to code a feature guided by docs/.
- `/review-feature` to review changes (auto-detects the right agents).
- `/review-all` to run all review agents in parallel.
- `/review-docs` to check documentation coherence against code.

## Review Strategy
- After modifying backend/logic code → /code-review
- After modifying frontend components/styles → /ux-review + /css-review
- After modifying CSS/tokens/tailwind config → /css-review
- After modifying domain/architecture code → /ddd-review
- After modifying IaC (Terraform, Docker, Helm) → /infra-review
- After modifying pipelines (CI/CD) → /cicd-review
- After modifying documentation → /review-docs

## Documentation
- Product documentation lives in `docs/` at the project root.
- Always use the ubiquitous language from `docs/domain/glossary.md` when it exists.
- Reference business rule IDs from `docs/domain/business-rules.md` in code comments.
- Keep documentation in sync with code. When in doubt, run `/review-docs`.

## Quality Principles
- Read existing code before modifying. Understand first.
- No hardcoded secrets or credentials in code.
- All errors must be explicitly handled. No silent swallowing.
- Prefer editing existing files over creating new ones.
- Keep solutions simple. Do not over-engineer.
- Always use community-recommended conventions for the framework and version in use.
