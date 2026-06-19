# ADR-0001 — ORM & migrations: SQLAlchemy 2.0 + Alembic (not Prisma)

- **Status:** Accepted · 2026-06-19
- **Deciders:** CTO
- **Resolves:** RISK_REGISTER R-03

## Context

The architecture set contains a conflict. `03_IMPLEMENTATION_ROADMAP` (Phase 1 tasks) and `01_SYSTEM_ARCHITECTURE`
§10 mention **Prisma** for schema/migrations. However `04_REPOSITORY_STRUCTURE` §0 explicitly **supersedes** the
language-neutral sketch in 03 with a Python-first stack — *"migrations are Alembic (not Prisma)"* — and
`09_CLAUDE_MD` §4 (binding policy) and `08_INFRASTRUCTURE_SETUP` §14 both mandate Alembic. The master directive's
own Phase 1 lists "SQLAlchemy Models, Alembic Migrations." The schema needs PostgreSQL features Prisma cannot
cleanly express: multi-schema (`ref/core/plan/proj/audit`), `btree_gist` + `EXCLUDE` temporal constraints, rich
`CHECK`s, and RLS by `scenario_id`.

## Decision

Use **SQLAlchemy 2.0 (async) + Alembic** for the relational layer (`libs/vndp_db`). Models are the source;
Alembic autogenerates diffs; hand-write what autogen can't (EXCLUDE, CHECK, RLS, enums, triggers). Forward-only,
every migration with a tested `downgrade`, order `extensions → ref → core → plan → proj → audit`.

## Consequences

- **+** Full PostgreSQL feature access (EXCLUDE/RLS/multi-schema), strict typing via SQLAlchemy 2.0 + mypy.
- **+** Single Python toolchain end-to-end (no Node/Prisma engine in the data path).
- **−** Less "batteries-included" client codegen than Prisma; mitigated by repositories + Pydantic DTOs.
- Prisma references in 03/01 are treated as superseded; docs updated when touched.
