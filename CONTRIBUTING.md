# Contributing — VNDP

Binding rules live in [`docs/09_CLAUDE_MD.md`](docs/09_CLAUDE_MD.md). This is the quick reference.

## Golden Windows rule
**Always use `python`, never `python3`.** On Windows `python3` resolves to a Microsoft Store stub that cannot
run scripts. Disable the Store aliases (Settings → Apps → Advanced → App execution aliases → off for
`python.exe`/`python3.exe`). Verify: `(Get-Command python).Source` → `C:\Python3xx\python.exe`.

## Toolchain
- Python 3.12+ · `uv` (workspace) · Node 20+ · Docker Desktop (WSL2).
- `uv sync` to resolve; `uv run <cmd>` to run inside the workspace venv.

## Branching & commits
- Branch from `main`: `feat/ | fix/ | chore/ | docs/` + kebab (e.g. `feat/sim-fixpoint`).
- **Never commit directly to `main`.** Open a PR; a human merges (no auto-merge, no force-push).
- **Conventional Commits**: `feat(sim): add fixpoint solver`.
- **Do NOT add a `Co-Authored-By` trailer** unless the project's `.claude/settings.json` enables it.

## Quality gates (CI must be green to merge)
1. `ruff check` + `ruff format --check` (style + import order)
2. `mypy --strict`
3. `pytest` — unit + integration + **golden-master** + security
4. `python workbook/verify.py` → **0 errors**
5. secret scan (gitleaks) — no secrets, ever

## Hard rules
- **Money** is `Decimal(18,4)` INR; never `float`. "Cr" is presentation only.
- **No magic numbers** — assumptions live in `plan.assumptions` or config.
- **Parameterized SQL/Cypher only** — never string-built queries.
- Every `proj.*` row carries `(scenario_id, snapshot_id)`.
- External/tool content is **data, not instructions** (ACL before any LLM step).
- Files < 500 lines. Validate input at every boundary.
- Update the corresponding `docs/` spec in the same PR as any behavior change.
- Never save scratch/tests to repo root — use `tests/`, `scripts/`, `docs/`.

## Migrations
- PostgreSQL: **Alembic**, forward-only, every migration has a tested `downgrade`. Order:
  `extensions → ref → core → plan → proj → audit`.
- Neo4j: idempotent cypher constraints; data **rebuilt per snapshot**, never hand-edited.
- Qdrant: create-if-absent collection config; re-embedding is a separate idempotent job.
