# IMPLEMENTATION_SEQUENCE — Valencia Nutracare Decision Platform (VNDP)

**Authority:** CTO
**Status:** Execution planning · v1.0 · 2026-06-19
**Companion to:** TASK_GRAPH · DEPENDENCY_MAP · SPRINT_PLAN · EXECUTION_BACKLOG
**Purpose:** The exact ordered sequence in which work is executed, with the gate that must be green before the next step starts. This is the "what to do next" oracle for autonomous execution.

> Effort in person-days (pd) assumes 1 dev + Claude Code pairing (03 §0). Total ≈ **97 pd**. `★` marks critical-path steps.

---

## 0. Pre-flight (must clear before Step 1)

These are environment gates, not build tasks. All from 08_INFRASTRUCTURE_SETUP §11.

1. `git --version`, GitHub remote reachable, PAT issued → **resolves R-01 (current BLOCKER)**.
2. `(Get-Command python).Source` → `C:\Python3xx\python.exe` (NOT WindowsApps stub). Store aliases off (08 §3.4).
3. `uv --version`, `node --version` (v20+).
4. `docker run --rm hello-world` → "Hello from Docker!"; `docker compose version`.
5. Decisions resolved or defaulted: ORM=**SQLAlchemy+Alembic** (R-03, decided), event-bus (R-06), embedding model (R-05).

> If any pre-flight item fails, **stop and escalate** (see EXECUTION_BACKLOG §Blockers) — do not scaffold on a broken base.

---

## 1. Phase 0 — Foundation (5 pd)

| Step | Task | Gate before next |
|---|---|---|
| 1.1 ★ | T0.1 repo bootstrap (git/remote/branch-protection) | `main` protected, PRs required |
| 1.2 ★ | T0.2 scaffold uv-workspace tree + root tooling | `uv sync` resolves; ruff/mypy/pytest configured |
| 1.3 | T0.3 docker-compose.yml (PG/Neo4j/Qdrant/n8n) + `.env.example` | file lints; `.env` gitignored+denied |
| 1.4 | T0.4 move docs → `docs/`; CONTRIBUTING.md | docs/ populated; `python` rule documented |
| 1.5 | T0.5 `workbook/verify.py` (0-error assert) | runs locally → 0 errors |
| 1.6 ★ | T0.6 CI (`ci.yml`) + gitleaks | CI green on empty repo |
| 1.7 | T0.7 `docker compose up` → 4 services healthy | `docker compose ps` all healthy |

**Phase gate (P0 DoD):** monorepo builds · compose healthy · CI green · workbook verify=0 · branch protection on.

---

## 2. Phase 1 — Data Layer (12 pd)

Order: schema → constraints → verify → domain → seed → validate.

| Step | Task | Gate |
|---|---|---|
| 2.1 ★ | T1.1 SQLAlchemy models (24 tables, 5 schemas, enums) | `mypy --strict` clean |
| 2.2 ★ | T1.2 Alembic migrations (extensions→ref→core→plan→proj→audit) + downgrades | `alembic upgrade head` + `downgrade base` idempotent |
| 2.3 | T1.3 EXCLUDE/CHECK/RLS/triggers (hand-written SQL) | constraints enforce on bad inputs |
| 2.4 | T1.4 introspection verify (`\d`) | all FKs + indexes present |
| 2.5 | T1.5 domain VOs (immutable, invariants) | hypothesis property tests pass |
| 2.6 | T1.6 repositories (ports + adapters) | integration tests on testcontainers PG |
| 2.7 | T1.7 `load_workbook.py` seed (Year-1 + ref only) | seed loads with **no constraint violations** |
| 2.8 | T1.8 validation gate + tests | ≥90% coverage; rejects overlap/pct>1/mix≠1 |

**Phase gate (P1 DoD):** all 24 tables+constraints live · EXCLUDE/CHECK/RLS enforced · seed clean · validate ≥90% · VOs tested.

> **After P1 green, fork into two parallel tracks (Track A = P2, Track B = P3).** Single-dev teams do P3 first (critical path), then P2.

---

## 3. Phase 3 — Simulation Engine ★ (18 pd, long pole) — Track B

| Step | Task | Gate |
|---|---|---|
| 3.1 ★ | T3.1 ports + M-BOM + M-CAPEX (acyclic) | unit tests vs workbook cost/box (PP 178.59 etc.) |
| 3.2 ★ | T3.2 DAG + fixpoint solver | convergence test passes; divergence fails closed |
| 3.3 ★ | T3.3 M-DEMAND/COMP/PNL/WC/FUND/RET wired | each module unit-tested |
| 3.4 ★ | T3.4 **golden-master** Year-1 (88.41/13.50/10.12, tol 0.5%) | **HARD GATE — must pass to proceed** |
| 3.5 | T3.5 Monte Carlo (P10/P50/P90, tornado) | same seed+snapshot → identical distribution |
| 3.6 | T3.6 optimization (constraints incl. IMS-Act, M-COMP bounds) | toy problem solves |
| 3.7 ★ | T3.7 `services/simulation` API + `SimulationCompleted` | API run writes `proj.*`; event observed |

**Phase gate (P3 DoD):** 8 modules · DAG converges · golden-master passes · 0-error gate · MC reproducible · optimizer runs · API emits event.

---

## 4. Phase 2 — Knowledge Layer (10 pd) — Track A (∥ P3)

| Step | Task | Gate |
|---|---|---|
| 4.1 | T2.1 cypher constraints + idempotent runner | constraints applied |
| 4.2 | T2.2 graph sync (PG→Neo4j MERGE per snapshot) | run-twice → identical graph |
| 4.3 | T2.3 5 signature queries | correct blast-radius/lineage on seed |
| 4.4 | T2.4 Qdrant collections (×5) | collections live |
| 4.5 | T2.5 embed + upsert + backfill | upsert→search round-trip returns same doc |

**Phase gate (P2 DoD):** constraints applied · sync reproducible · 5 queries correct · 5 collections backfilled · scenario isolation verified.

---

## 5. Phase 4 — MCP Integrations (10 pd)

(Starts when P1+P2 green; tail overlaps P3.)

| Step | Task | Gate |
|---|---|---|
| 5.1 | T4.1 configure 8 MCP servers (exact scopes 07 §2) | each connects |
| 5.2 | T4.2 ACL sanitize (required on untrusted sources) | injection string neutralized |
| 5.3 | T4.3 access-matrix policy (07 §3) | out-of-scope call denied |
| 5.4 | T4.4 smoke tests (connect/read/denied-write/inject/audit) | all pass |

**Phase gate (P4 DoD):** 8 MCPs connect · scopes enforced · ACL strips directives · matrix denies out-of-scope · calls audited.

---

## 6. Phase 5 — n8n Ingestion (12 pd)

(Starts when P2+P4 green.) Order: intel (∥) → research → sync → errors.

| Step | Task | Gate |
|---|---|---|
| 6.1 | T5.1–T5.3 Competitor ∥ Market ∥ Financial workflows | each e2e on fixture; events emitted |
| 6.2 | T5.4 Research Ingestion | chunks embedded; entity-linked |
| 6.3 | T5.5 Workbook Sync (#REF! gate, fail-closed) | injected `#REF!` → halt, no write |
| 6.4 | T5.6 Error Trigger + export workflows | logs+alerts; JSON exported |

**Phase gate (P5 DoD):** 5 workflows e2e · 3-store writes · events · sync error-gate verified · no dup rows on re-run.

---

## 7. Phase 6 — Agent Boardroom ★ (16 pd)

(Starts when P3+P4+P5 green.) Order: definitions → protocol → records → cycle → smoke.

| Step | Task | Gate |
|---|---|---|
| 7.1 ★ | T6.1 7 agents (PydanticAI, typed, tool-whitelisted) | each agent unit-tested (mocked LLM+tools) |
| 7.2 ★ | T6.2 consensus + binding vetoes + human escalation | veto blocks insolvent/sub-hurdle plan |
| 7.3 | T6.3 decision-of-record persistence | reproducible by (scenario, snapshot) |
| 7.4 ★ | T6.4 board cycle wired (05 §7) | e2e produces recommendation + dissent |
| 7.5 | T6.5 spawn manifest + smoke + safety tests | no agent commits capital; injection can't redirect |

**Phase gate (P6 DoD):** agents defined · consensus+vetoes work · decisions reproducible · cycle e2e · no-capital-move · writes validated.

---

## 8. Phase 7 — Executive + Hardening ★ (14 pd)

Order: API → web → export → observability → scale → deploy.

| Step | Task | Gate |
|---|---|---|
| 8.1 ★ | T7.1 GraphQL BFF + CQRS read models | dashboard query <500ms |
| 8.2 ★ | T7.2 web (control panel, what-if, dashboards, compare) | levers trigger a run; renders |
| 8.3 | T7.3 board-pack export (xlsx/pptx/pdf) | exports narrative+statements+comparison |
| 8.4 | T7.4 OpenTelemetry observability | traces/metrics/logs visible |
| 8.5 | T7.5 partition `proj.*` + replicas + load test | MC 1k <60s |
| 8.6 ★ | T7.6 k8s deploy + NFR suite | all NFRs met; staging green; security review passed |

**Phase gate (P7 DoD):** dashboard+what-if live · board-pack · NFR met · observability · partition+replicas · staging green · security passed.

---

## 9. Sequencing summary (Gantt-style, 03 §Sequencing)

```
P0 ██
P1   ████████
P2           █████            (Track A, ∥ P3)
P3           ████████████ ★   (Track B, critical path)
P4                █████
P5                     ██████
P6                           ████████ ★
P7                                   ███████ ★
     ──────────────── ~97 person-days ────────────►
```

**Golden rule on every step:** ship with **zero calculation errors** and a `(scenario_id, snapshot_id)` reproducibility key; human-merged PR; docs updated in the same change.

---

*End of IMPLEMENTATION_SEQUENCE.md*
