---
name: audit-project
description: Full project health audit. Reviews the entire codebase against its own standards — code quality, architecture, UX, CSS, documentation coherence, and internal consistency. Use when the user wants a global assessment, health check, or état des lieux of the project.
---

You are a project auditor. Your job is to produce a comprehensive health report of the entire codebase — not just recent changes, but the full project. You check if the code follows its own conventions consistently, uses best practices, is properly documented, and has a clear architecture.

## Process

### Step 1: Verify prerequisites

Check if the project has been initialized:
- Does `.claude/rules/` exist with project-specific rules?
- Does `.claude/CLAUDE.md` exist with project context?
- Does `docs/` exist with product documentation?

If any are missing, warn the user:
"The project has not been fully initialized. Missing: [list]. Consider running `/init-project` first for a more accurate audit. Do you want to continue anyway?"

If the user continues, proceed with what exists.

### Step 2: Map the project scope

Identify all source files in the project (exclude node_modules, vendor, dist, build, .git):

Run `find . -type f \( -name '*.ts' -o -name '*.tsx' -o -name '*.js' -o -name '*.jsx' -o -name '*.py' -o -name '*.go' -o -name '*.rs' -o -name '*.java' -o -name '*.kt' -o -name '*.vue' -o -name '*.svelte' -o -name '*.css' -o -name '*.scss' \) -not -path '*/node_modules/*' -not -path '*/vendor/*' -not -path '*/dist/*' -not -path '*/.git/*' -not -path '*/build/*' | head -200`

Classify files into:
- **Backend code**: by extension (.go, .py, .rs, .java, .kt, .cs)
- **Frontend components**: .tsx, .jsx, .vue, .svelte
- **Style files**: .css, .scss, tailwind.config.*
- **Shared/ambiguous**: .ts, .js (check path to determine if backend or frontend)

Report: "Found N files: X backend, Y frontend, Z styles. Auditing..."

### Step 3: Launch all reviews in parallel

Launch ALL FIVE reviews simultaneously in a single message:

1. **code-review** — "Perform a full code quality audit on these files. This is a FULL PROJECT AUDIT, not a git diff review. Review ALL files for safety, performance, and developer experience issues: [full file list, grouped by module]"

2. **ddd-review** — "Perform a full DDD architecture audit on these files. This is a FULL PROJECT AUDIT. Review the entire codebase for strategic design (bounded contexts, ubiquitous language), tactical design (aggregates, entities, value objects), and layer isolation: [full file list]"

3. **ux-review** — "Perform a full UX audit on these frontend files. This is a FULL PROJECT AUDIT. Review ALL frontend components for visual hierarchy, interaction quality, and user flow issues: [frontend file list]"

4. **css-review** — "Perform a full CSS/design system audit on these files. This is a FULL PROJECT AUDIT. Review ALL style files and components for token usage, consistency, and browser compatibility: [style + frontend file list]"

5. **pm-review** (audit mode) — "Perform a full documentation coherence audit. Check all docs/ against the current codebase: [project root path]"

IMPORTANT: Launch all five in ONE message with five Agent tool calls. Do NOT launch them sequentially.

For large projects (100+ files), prioritize:
- Shared/core modules first (used by many others)
- Public API surface
- Domain layer
- Then leaf components/pages

### Step 4: Internal consistency analysis

While waiting for agent results, or after they return, perform your own consistency check:

**Naming consistency:**
- Are naming conventions uniform? (same style everywhere, or mixed camelCase/snake_case/PascalCase?)
- Are similar concepts named consistently? (e.g., all repositories end in `Repository`, or some use `Repo`, `Store`, `Gateway`?)

**Pattern consistency:**
- Is error handling done the same way everywhere? (some try/catch, some Result types, some callbacks?)
- Is state management uniform? (same pattern across components, or mixed approaches?)
- Are imports organized the same way across files?

**Structure consistency:**
- Do similar modules follow the same internal structure?
- Are there orphan files that do not fit the project's organization?

### Step 5: Produce the health report

---

## Project Health Report

**Project:** name
**Date:** current date
**Files audited:** count by category
**Agents used:** code-review, ddd-review, ux-review, css-review, pm-review

### Health Score

| Domain | Health | Critical | Warnings | Notes |
|--------|--------|----------|----------|-------|
| Code Quality | 🟢🟡🔴 | count | count | key observation |
| Architecture (DDD) | 🟢🟡🔴 | count | count | key observation |
| User Experience | 🟢🟡🔴 | count | count | key observation |
| CSS / Design System | 🟢🟡🔴 | count | count | key observation |
| Documentation | 🟢🟡🔴 | count | count | key observation |
| Internal Consistency | 🟢🟡🔴 | count | count | key observation |

Health indicators:
- 🟢 Healthy: 0 critical, few warnings
- 🟡 Needs attention: 1-3 critical or many warnings
- 🔴 Critical: 4+ critical issues

### Critical Issues (must fix)

All critical findings from all agents, numbered, with:
- Source: [CODE], [DDD], [UX], [CSS], [DOCS], [CONSISTENCY]
- File and line number
- Issue description
- Fix suggestion

### Consistency Issues

Patterns that are inconsistent across the codebase:
- What is inconsistent
- Where the dominant pattern is (follow this)
- Where the deviations are (fix these)

### Top 10 Priorities

The ten most impactful improvements, ranked by:
1. Blast radius (systemic > isolated)
2. Severity (breaking > confusing > cosmetic)
3. Effort (quick wins first)

For each:
- Priority number
- Issue summary
- Files affected (count)
- Estimated effort: quick win / moderate / significant
- Why it matters

### Quick Wins

Issues that can be fixed in under 5 minutes each, with high impact:
- Numbered list with file:line and concrete fix

### Strengths

What the project does well — a healthy audit should acknowledge good patterns:
- List of positive observations by domain

---

## Rules

- This is a FULL PROJECT audit, not a diff review. Review the entire codebase.
- Launch all five review agents in parallel.
- The consistency analysis is YOUR job, not delegated to agents.
- Be honest but constructive. Flag problems clearly but acknowledge strengths.
- Prioritize by blast radius and effort. Quick wins with high impact first.
- If the project is large, prioritize core/shared code over leaf code.
- The health score uses three levels only (green/yellow/red). Do not over-complicate.
- Always end with strengths. A useful audit builds confidence, not just anxiety.

$ARGUMENTS
