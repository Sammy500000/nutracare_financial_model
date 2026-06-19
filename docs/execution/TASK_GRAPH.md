# TASK_GRAPH — Valencia Nutracare Decision Platform (VNDP)

**Authority:** CTO
**Status:** Execution planning · v1.0 · 2026-06-19
**Companion to:** DEPENDENCY_MAP · EXECUTION_BACKLOG · IMPLEMENTATION_SEQUENCE
**Purpose:** Every build task as a node with explicit predecessors, so work can be scheduled, parallelized, and gated. IDs are stable and referenced by EXECUTION_BACKLOG and SPRINT_PLAN.

> **ID scheme:** `T<phase>.<n>`. `dep:` lists predecessor task IDs (all must be DoD-green). `★` = on the critical path.

---

## Phase 0 — Foundation & Repository

| ID | Task | dep | Output |
|---|---|---|---|
| **T0.1** ★ | Resolve repo bootstrap: `git init` (or clone `vndp`), GitHub remote, branch protection on `main` | — (BLOCKER R-01) | repo |
| **T0.2** ★ | Scaffold uv-workspace monorepo tree (04 §1): `apps/ services/ libs/ workflows_n8n/ infra/ migrations/ tests/ scripts/ docs/`; root `pyproject.toml`, `uv.lock`, `justfile`, `.pre-commit-config.yaml` | T0.1 | tree |
| **T0.3** | Author `infra/docker/docker-compose.yml` (postgres:15, neo4j:5, qdrant, n8n) with volumes + healthchecks; `.env.example` non-secret defaults | T0.2 | compose |
| **T0.4** | Move design docs into `docs/`; write `CONTRIBUTING.md` (use `python` not `python3`; Conventional Commits; no secrets) | T0.2 | docs |
| **T0.5** | `workbook/verify.py` — recalc repaired xlsx via `formulas`, assert 0 errors | T0.2 | verify script |
| **T0.6** ★ | GitHub Actions `ci.yml`: install → ruff → mypy --strict → pytest → workbook verify; gitleaks secret scan | T0.1, T0.5 | CI |
| **T0.7** | `docker compose up` → all 4 services healthy (machine step) | T0.3 (+Docker) | running stack |

**Gate:** monorepo builds · compose healthy · CI green · workbook verify = 0 errors · branch protection on.

---

## Phase 1 — Data Layer (PostgreSQL)

| ID | Task | dep | Output |
|---|---|---|---|
| **T1.1** ★ | SQLAlchemy 2.0 (async) models in `libs/vndp_db` for all 24 tables, 5 schemas, enums, PK/FK/unique (DATABASE_SCHEMA §2–6) | T0.* | models |
| **T1.2** ★ | Alembic env + migrations, order `extensions→ref→core→plan→proj→audit`; each with tested `downgrade` | T1.1 | migrations |
| **T1.3** | Hand-written SQL: `btree_gist`+EXCLUDE (ingredient_prices, plan.prices); CHECK (tiers 1-3, pct≥0, splits=1, net≤MRP); RLS by scenario_id; touch + row-audit triggers | T1.2 | constraints |
| **T1.4** | `alembic upgrade head` → `psql \d` introspection: all FKs + indexes present | T1.2, T1.3 | verified schema |
| **T1.5** | `libs/vndp_domain` value objects (Money, Percentage, Quantity, Rate, BoxSize, TierLevel, FundingMix, SAMShare, CostPerBox, DiscountRate…) immutable, with invariants (02 §3) | T0.* | domain VOs |
| **T1.6** | Repositories (clean-arch ports + SQLAlchemy adapters) per aggregate (02 §4) | T1.1, T1.5 | repos |
| **T1.7** | `scripts/load_workbook.py` seed — map sheets→entities (Product Line→skus, BOMs→boms/lines/ingredients, Competitor Brands→competitors…); **Year-1 + reference only**, flag Y2–5 | T1.4 | seed |
| **T1.8** | `libs/vndp_db` validation gate (schema + range + temporal no-overlap) + unit tests (reject overlaps, pct>1, mix≠1) | T1.1 | validate lib |

**Gate:** 24 tables + constraints live · EXCLUDE/CHECK/RLS enforced · workbook seed clean · validate ≥90% covered · VOs tested.

---

## Phase 2 — Knowledge Layer (Neo4j + Qdrant)  *(∥ P3)*

| ID | Task | dep | Output |
|---|---|---|---|
| **T2.1** | `migrations/neo4j/constraints.cypher` — 7 unique constraints + 4 indexes (KNOWLEDGE_GRAPH §5), idempotent runner records `:_Migration` | T1.4 | graph schema |
| **T2.2** | `libs/vndp_graph/sync.py` — read PG for a snapshot, MERGE 21 nodes + 22 rel types; idempotent (run-twice = identical) | T2.1, T1.6 | graph sync |
| **T2.3** | `libs/vndp_graph/queries.py` — 5 signature queries (impact, lineage, commodity→products, competitive gap, SAM) parameterized | T2.2 | queries |
| **T2.4** | `migrations/qdrant/` — create-if-absent collections (competitor, market, research, financial, decisions) with vector size + payload schema | T1.4 | collections |
| **T2.5** | `libs/vndp_vectors` embed + upsert client; backfill embeds existing competitor/market reference text | T2.4 (+R-05 model) | vectors |

**Gate:** constraints applied · sync reproducible · 5 queries correct on seed · 5 collections live+backfilled · scenario isolation verified.

---

## Phase 3 — Simulation Engine ★ (long pole)  *(∥ P2)*

| ID | Task | dep | Output |
|---|---|---|---|
| **T3.1** ★ | `libs/vndp_sim/ports.py` (data-access protocol, no DB import) + M-BOM, M-CAPEX (acyclic roots) as pure typed functions | T1.6 | 2 modules |
| **T3.2** ★ | `core/dag.py` (declare edges, topo solve) + `core/fixpoint.py` (revenue⇄opex, PBT⇄interest; iterate `|Δ|<ε`, fail-closed) | T3.1 | solver |
| **T3.3** ★ | M-DEMAND, M-COMP, M-PNL, M-WC, M-FUND, M-RET wired into the DAG | T3.2 | 6 modules |
| **T3.4** ★ | Golden-master test: Year-1 → Rev≈88.41 / EBITDA≈13.50 / PAT≈10.12 Cr, tol 0.5% | T3.3, T1.7 | acceptance gate |
| **T3.5** | `montecarlo/` sampler+runner — N runs, P10/P50/P90, tornado; seed-reproducible; worker-pool parallel | T3.4 | MC |
| **T3.6** | `optimize/` objective+search+constraints (capacity≥demand, runway>0, mix policy, IMS-Act, M-COMP bounds); grid/Bayesian | T3.4 | optimizer |
| **T3.7** ★ | `services/simulation` API: run scenario → write `proj.*` → emit `SimulationCompleted` | T3.4 (+R-06 bus) | sim service |

**Gate:** 8 modules · DAG converges · **golden-master passes** · 0-error gate · MC reproducible · optimizer runs toy problem · API emits event.

---

## Phase 4 — MCP Integrations

| ID | Task | dep | Output |
|---|---|---|---|
| **T4.1** | Configure 8 MCP servers per 07 §2 exact scopes (Filesystem→root; PG→roles+RLS; Browser→read-only; Sheets→output-tab; Neo4j/Qdrant→read+sync; GitHub→PR-only; n8n→trigger allow-list) | T1.*, T2.* (+secrets) | server configs |
| **T4.2** | `packages/mcp/acl/sanitize.ts|py` — strip embedded directives; required on Browser/Sheets/Research before any LLM step (S6) | T4.1 | ACL |
| **T4.3** | `policy/access-matrix` encoding 07 §3 matrix; deny out-of-scope calls | T4.1 | policy |
| **T4.4** | Smoke tests: each MCP connects · scoped read works · denied write rejected · injection string stripped · call audited | T4.1–T4.3 | tests |

**Gate:** 8 MCPs connect · scopes/deny-lists enforced · ACL strips directives · matrix denies out-of-scope · all calls audited.

---

## Phase 5 — n8n Ingestion

| ID | Task | dep | Output |
|---|---|---|---|
| **T5.1** | Competitor Monitoring workflow → core.competitor_metrics + Qdrant competitor + Neo4j BENCHMARKS → `CompetitorBenchmarkUpdated` | T2.*, T4.* | wf |
| **T5.2** | Market Intelligence → core.markets / market / HAS_SAM → `SamShareUpdated` | T2.*, T4.* | wf |
| **T5.3** | Financial Intelligence → ingredient_prices/assumptions / financial / DRIVES → `IngredientPriceChanged` | T2.*, T4.* | wf |
| **T5.4** | Research Ingestion → chunk+embed → research / doc registry / MENTIONS → `ResearchIngested` | T5.1–T5.3 | wf |
| **T5.5** | Workbook Synchronization → VALIDATE (#REF! scan, fail-closed) → diff → upsert → rebuild subgraph → re-embed → snapshot → `SnapshotCreated` | T5.4 | wf (the gate) |
| **T5.6** | Error Trigger workflow → audit.change_log + alert; export all to `workflows_n8n/` | T5.5 | wf + export |

**Gate:** 5 workflows e2e · writes land in 3 stores · events emitted · Workbook Sync error-gate verified · no dup rows on re-run.

---

## Phase 6 — Agent Boardroom ★

| ID | Task | dep | Output |
|---|---|---|---|
| **T6.1** ★ | Author 7 executive + worker agents as PydanticAI Agents (typed result + deps + whitelisted tools per 07 §3): CFO, CMO, COO, Investor, Market, Competitor, Chairman | T3.*, T4.* | agents |
| **T6.2** ★ | `protocol/consensus` (hive-mind_consensus) + `escalation` (CFO solvency-veto, Investor hurdle-veto binding; capital/dilution→human) | T6.1 | protocol |
| **T6.3** | `protocol/decision_record` — persist decision+dissent to memory + Qdrant `decisions` + audit, keyed (scenario, snapshot) | T6.1 | records |
| **T6.4** ★ | Wire board cycle (05 §7): set decisions → optimize → MC stress-test → debate → Chairman synthesize → human approve → re-run | T6.2, T6.3, T5.* | cycle |
| **T6.5** | Spawn manifest (AGENTS §11) + smoke test: one full board cycle on Year-1 scenario; veto + no-capital-move + injection tests | T6.4 | smoke |

**Gate:** 7+worker agents defined · consensus+binding vetoes work · decisions reproducible · cycle e2e · no agent commits capital · all writes validated.

---

## Phase 7 — Executive Layer + Hardening ★

| ID | Task | dep | Output |
|---|---|---|---|
| **T7.1** ★ | `apps/api_gateway` BFF (GraphQL/REST): scenarios, projections, returns, run-scenario mutation; CQRS read models (<500ms) | T6.* | API |
| **T7.2** ★ | `apps/web`: Strategy control panel (levers→run), what-if console, dashboards (revenue mix, margin bridge, returns, WC rotation), scenario compare | T7.1 | web |
| **T7.3** | Board-pack export (xlsx/pptx/pdf skills): narrative + statements + scenario comparison | T7.1 | export |
| **T7.4** | OpenTelemetry traces/metrics/logs across services; latency + error dashboards | T7.1 | observability |
| **T7.5** | Partition `proj.*` by scenario_id; read replicas; load-test MC 1k <60s | T7.1 | scale |
| **T7.6** | k8s manifests + HPA; staging deploy; NFR acceptance suite (run<5s, MC 1k<60s, dash<500ms, impact<1s, 0-error, repro 100%) | T7.5 | deploy |

**Gate:** dashboard+what-if live · board-pack exports · NFR met · observability in · partition+replicas · staging green · security review passed.

---

## Cross-cutting tasks (every phase)

| ID | Task |
|---|---|
| **TX.1** | Per-PR: ruff + mypy --strict + unit + integration + golden-master + security; human merge (no auto-merge) |
| **TX.2** | Update the corresponding `docs/` spec in the same PR as any behavior change |
| **TX.3** | Coverage gate ≥85% on `domain`/`sim`; deterministic seeds; no network in unit tests |
| **TX.4** | Every output carries `(scenario_id, snapshot_id)`; every mutation audited |

---

## Critical path (longest chain)

```
T0.1 → T0.2 → T1.1 → T1.2 → T3.1 → T3.2 → T3.3 → T3.4 → T3.7 → T6.1 → T6.2 → T6.4 → T7.1 → T7.2 → T7.6
```
Simulation (P3) and the board cycle (P6) are the long poles; protect them with the two-track parallelization in DEPENDENCY_MAP §1.

---

*End of TASK_GRAPH.md*
