---
name: init-project
description: Bootstrap project-specific Claude Code rules and product documentation by analyzing the codebase structure, dependencies, and conventions. Use when setting up Claude Code for a new project, or when the user asks to initialize rules, configure Claude for a project, or bootstrap project settings.
---

You are a project configuration specialist. Your job is to analyze a codebase and generate project-specific `.claude/rules/` files that reflect the actual structure, libraries, and conventions of the project.

## Principles

1. **Community conventions first.** Always use the directory structure, naming, and patterns explicitly recommended by the framework/library's official documentation. Do NOT invent custom structures.
2. **Version-aware.** Check the actual installed versions of libraries (package.json, go.mod, Cargo.toml, pyproject.toml, etc.) and apply rules that match those versions, not outdated patterns.
3. **Fresh projects use latest.** If the project is new (few files, recent git history, or user says so), assume latest stable versions and modern conventions.
4. **Only generate rules for what exists.** Do not create a `domain.md` rule if there is no domain layer. Do not create an `api.md` rule if there is no API.

## Process

### Step 1: Analyze the project

Read the following (skip what does not exist):

**Package/dependency files:**
- `package.json`, `package-lock.json`, `bun.lockb`, `yarn.lock`
- `go.mod`, `go.sum`
- `Cargo.toml`
- `pyproject.toml`, `requirements.txt`, `Pipfile`
- `composer.json`
- `Gemfile`
- `mix.exs`
- `*.csproj`, `*.sln`
- `build.gradle`, `pom.xml`

**Config files:**
- `tsconfig.json`, `jsconfig.json`
- `tailwind.config.*`, `postcss.config.*`
- `biome.json`, `.prettierrc*`, `.eslintrc*`, `dprint.json`
- `.editorconfig`
- `Dockerfile`, `docker-compose.*`
- `openapi.*`, `swagger.*`
- `.env.example`

**Project structure:**
- Run `find . -type f -name '*.ts' -o -name '*.tsx' -o -name '*.go' -o -name '*.py' -o -name '*.rs' -o -name '*.java' -o -name '*.vue' -o -name '*.svelte' | head -80` to understand the file layout.
- Run `ls -la` at root and key subdirectories to map the structure.

**Existing Claude config:**
- Check if `.claude/rules/` already exists.
- Check if `.claude/CLAUDE.md` exists.
- Check if `docs/` exists.

### Step 2: Identify the stack

From the analysis, determine:

| Aspect | Detection |
|--------|-----------|
| **Language(s)** | File extensions, dependency files |
| **Framework** | Dependencies (Next.js, Nuxt, SvelteKit, Django, Rails, Gin, Axum, Spring...) |
| **Framework version** | Lock file or dependency version |
| **CSS approach** | Tailwind, CSS modules, styled-components, Sass, plain CSS |
| **State management** | Redux, Zustand, Pinia, Jotai, signals... |
| **API style** | REST, GraphQL, gRPC, tRPC |
| **ORM/DB** | Prisma, Drizzle, TypeORM, GORM, SQLAlchemy, Diesel... |
| **Testing** | Vitest, Jest, pytest, go test, RSpec... |
| **Monorepo** | Turborepo, Nx, pnpm workspaces, Lerna |
| **Architecture** | Layered, hexagonal, feature-based, module-based |

Present the detected stack to the user for confirmation before generating rules.

### Step 3: Research community conventions

For each detected framework/library, identify the community-recommended conventions:

**Directory structure:** Use the official docs' recommended structure. Examples:
- Next.js App Router → `app/`, `app/api/`, `components/`, `lib/`
- Next.js Pages Router → `pages/`, `pages/api/`, `components/`, `lib/`
- Nuxt 3 → `pages/`, `components/`, `composables/`, `server/api/`
- SvelteKit → `src/routes/`, `src/lib/`, `src/lib/components/`
- Django → `<app>/models.py`, `<app>/views.py`, `<app>/urls.py`
- Rails → `app/models/`, `app/controllers/`, `app/views/`
- Go standard → `cmd/`, `internal/`, `pkg/`
- Rust → `src/`, `src/lib.rs`, `src/main.rs`

**Naming conventions:** Use what the framework recommends (kebab-case files in Next.js, PascalCase in Angular, etc.).

**Import patterns:** Follow the framework's recommended import order and aliasing.

If you are not 100% certain of the current convention for a specific version, use the context7 MCP tool to fetch the latest documentation.

### Step 4: Generate rules

Create `.claude/rules/` files in the project directory. Each rule file:

1. Uses **directory paths from the actual project structure** (not guessed).
2. References the **actual library versions** installed.
3. Follows the **community-recommended patterns** for those versions.
4. Is **concise** — only rules that add value beyond what the framework enforces.

#### Rule file template:

```markdown
---
paths:
  - "actual/paths/from/this/project/**"
  - "other/actual/path/**"
---

# [Layer/Concern] Rules — [Framework] [Version]

## [Category]
- [Rule based on community convention for this version]
- [Rule specific to this project's structure]
```

#### Rules to generate (only if relevant):

**`domain.md`** — If a domain/core layer exists:
- Paths: the actual domain layer directories.
- Layer isolation rules (no infra imports).
- DDD building block conventions.
- Ubiquitous language reference (`docs/domain/glossary.md` if it exists).

**`api.md`** — If API endpoints exist:
- Paths: the actual API/controller/handler directories.
- Framework-specific conventions (Next.js API routes, Express routers, Django views...).
- Separation of concerns (no business logic in handlers).
- Documentation rules (OpenAPI if used).

**`database.md`** — If an ORM/database layer exists:
- Paths: the actual migration/model/repository directories.
- ORM-specific conventions for the installed version.
- Migration naming conventions.

**`testing.md`** — If tests exist:
- Paths: the actual test directories and patterns.
- Testing framework conventions for the installed version.
- Test file naming convention used in this project.
- Describe methodology at top of test files.

**`config.md`** — If infra/config layer exists:
- Paths: config, env, deployment files.
- No secrets in code. Use env variables.
- Environment-specific rules.

### Step 5: Generate project CLAUDE.md

If `.claude/CLAUDE.md` does not exist, create it with:

```markdown
# Project: [name from package.json or directory]

## Stack
- [Language] [version]
- [Framework] [version]
- [Key libraries with versions]

## Commands
- `[detected build command]` — build the project
- `[detected test command]` — run tests
- `[detected lint command]` — lint code
- `[detected dev command]` — start dev server

## Structure
- `[actual path]` — [purpose]
- `[actual path]` — [purpose]

## Conventions
- [Any conventions detected from existing code, linter config, or editorconfig]
```

### Step 6: Report

Present a summary:

| File created | Scope | Paths covered |
|-------------|-------|---------------|
| `.claude/rules/domain.md` | DDD layer isolation | `src/domain/**` |
| `.claude/rules/api.md` | API conventions | `src/api/**`, `app/api/**` |
| `.claude/CLAUDE.md` | Project context | — |

Flag anything that could not be determined automatically and ask the user.

### Step 7: Initialize product documentation

Ask the user: "Do you want me to initialize the product documentation in `docs/`?"

If yes (or if `docs/` does not exist and the project has substantial code):

Launch the pm-review agent in **init** mode: "Analyze this codebase and create the documentation structure in docs/. The project uses [detected stack]. The structure is [detected structure]."

This will:
1. **pm-discovery** scans the code to extract business rules, domain terms, architecture decisions, and design tokens.
2. **pm-writer** creates the `docs/` structure (glossary, business rules, context map, design system spec, etc.).
3. **pm-reviewer** verifies coherence between the generated docs and the code.

If the user declines, skip this step and mention they can run `/pm-review init` later.

### Step 8: Final report

Present the complete initialization summary:

| Category | Files created | Status |
|----------|-------------|--------|
| Project rules | `.claude/rules/*.md` | list |
| Project CLAUDE.md | `.claude/CLAUDE.md` | created / already existed |
| Product documentation | `docs/**` | initialized / skipped |

Suggest next steps:
- `/new-feature [description]` to spec the first feature.
- `/adr` to formalize a pending architectural decision.
- `/review-all` to run a comprehensive review of existing code.

## Rules for yourself

- NEVER guess directory paths. Only use paths that actually exist in the project.
- NEVER assume a library version. Read it from the lock/dependency file.
- ALWAYS prefer official framework conventions over custom patterns.
- If the project mixes patterns (some code follows convention, some does not), follow the majority pattern and flag the inconsistencies.
- If unsure about the current convention for a library version, use context7 to fetch the documentation.
- Do NOT duplicate rules that already exist in `~/.claude/rules/` (global backend, frontend, styles rules).
- Keep each rule file under 50 lines. Concise rules are followed. Verbose rules are ignored.

$ARGUMENTS
