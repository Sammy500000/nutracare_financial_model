# 03 — IMPLEMENTATION ROADMAP
## Valencia Nutracare Decision Platform (VNDP)

**Authority:** Chief Technical Officer
**Inputs:** BUSINESS_ONTOLOGY · ARCHITECTURE · 01_SYSTEM_ARCHITECTURE · 02_DOMAIN_MODEL · DATABASE_SCHEMA · KNOWLEDGE_GRAPH · AGENTS · 05_SIMULATION_ENGINE · 06_N8N_ARCHITECTURE · 07_MCP_ARCHITECTURE
**Status:** Build plan · v1.0
**Audience:** a junior developer should be able to execute each phase step-by-step.

---

## 0. How to use this roadmap

- Phases are **sequential by default**; the **Dependencies** field says what must finish first.
- **Claude Code Tasks** are written as prompts/commands you run *inside Claude Code* in the repo. Run them in the listed order; do not start a task until its dependencies are green.
- A phase is not "done" until its **Definition of Done (DoD)** checklist is fully ticked and tests pass.
- Effort is in **person-days (pd)**, assuming one developer + Claude Code pair-programming. Multiply by ~0.6 if two devs run parallel tracks.
- **Golden rule (inherited from the workbook repair):** every artifact ships with **zero formula/calculation errors** and a reproducibility key `(scenario_id, snapshot_id)`.

### Global prerequisites (install once, before Phase 0)
| Tool | Min version | Purpose |
|---|---|---|
| Node.js + pnpm | 20 / 9 | monorepo, services, API, n8n nodes |
| Python | 3.11+ (`python`, **not** the Store `python3` stub) | simulation engine, scripts |
| Docker + Docker Compose | latest | local PostgreSQL, Neo4j, Qdrant, n8n |
| PostgreSQL | 15 (or CockroachDB) | system of record |
| Neo4j | 5.x | knowledge graph |
| Qdrant | latest | vector store |
| n8n | latest | ingestion workflows |
| Prisma CLI | latest | schema + migrations |
| ruflo / claude-flow | v3 | agent orchestration (already configured) |

> **Environment note:** on this machine the working Python is `python` (C:\Python313). Use `python`, never `python3`, in scripts and hooks.

---

## Repository & top-level structure (created in Phase 0, filled across phases)

**Strategy:** single **monorepo** (`vndp`) with pnpm workspaces — simplest for a small team, matches the bounded contexts of 01 §4/§5.

```
vndp/
├─ apps/
│  ├─ api/              # GraphQL/BFF gateway (01 §5)
│  ├─ web/              # Executive dashboard + what-if console (Executive Layer)
│  └─ n8n/              # workflow JSON exports + custom nodes (06)
├─ services/            # one per bounded context (01 §5)
│  ├─ finance/ pricing/ demand/ manufacturing/ marketing/
│  ├─ financing/ valuation/ intelligence/ simulation/ decision/
├─ packages/
│  ├─ domain/           # DDD aggregates, entities, value objects (02)
│  ├─ db/               # Prisma schema + migrations + seed (DATABASE_SCHEMA)
│  ├─ graph/            # Neo4j cypher constraints + sync (KNOWLEDGE_GRAPH)
│  ├─ vectors/          # Qdrant collections + client (06)
│  ├─ sim-engine/       # deterministic core + Monte Carlo + optimization (05)
│  ├─ agents/           # ruflo agent definitions + boardroom (AGENTS)
│  ├─ mcp/              # MCP server configs/wrappers (07)
│  └─ shared/           # config, logging, event bus, telemetry
├─ infra/
│  ├─ docker/           # docker-compose.yml for PG/Neo4j/Qdrant/n8n
│  ├─ k8s/  terraform/  # later phases
├─ workbook/            # repaired xlsx + recalc/verify scripts (baseline truth)
├─ docs/                # all .md design docs (this set)
└─ tests/               # cross-cutting e2e + golden-master fixtures
```

---

## Phase overview & critical path

| Phase | Name | Depends on | Effort (pd) |
|---|---|---|---|
| **0** | Foundation & Repo Setup | — | 5 |
| **1** | Data Layer (PostgreSQL) | 0 | 12 |
| **2** | Knowledge Layer (Neo4j + Qdrant) | 1 | 10 |
| **3** | Simulation Engine | 1 | 18 |
| **4** | MCP Integrations | 1, 2 | 10 |
| **5** | n8n Ingestion | 2, 4 | 12 |
| **6** | Agent Layer (boardroom + MC + optimization) | 3, 4, 5 | 16 |
| **7** | Executive Layer + Hardening/Scale | 6 | 14 |
| | **Total** | | **~97 pd** |

```
0 ──► 1 ──┬──► 2 ──┬──► 4 ──┬──► 5 ──┐
          │        │        │        ├──► 6 ──► 7
          └──► 3 ──┴────────┴────────┘
Critical path: 0 → 1 → 3 → 6 → 7  (simulation is the long pole)
```

---

## PHASE 0 — Foundation & Repository Setup

**Objectives:** stand up the monorepo, local infra, CI, and lock the workbook as the baseline "truth" for later golden-master tests.

**Deliverables:** initialized `vndp` monorepo; `docker-compose` bringing up PostgreSQL+Neo4j+Qdrant+n8n; CI pipeline (lint+test); the repaired workbook + verify script committed; `.env.example` + secrets policy.

**Repositories:** `vndp` (monorepo) on GitHub, branch protection on `main`.

**Folder Structure:** the full tree above scaffolded with empty package stubs + `README` per package.

**Claude Code Tasks:**
1. `Task: scaffold a pnpm monorepo named vndp with the folder tree in 03 §"Repository". Add pnpm-workspace.yaml, tsconfig base, eslint+prettier, .gitignore (exclude .env, *.xlsx temp).`
2. `Task: write infra/docker/docker-compose.yml with services postgres:15, neo4j:5, qdrant, n8n — each with named volumes, healthchecks, and ports; add .env.example with non-secret defaults.`
3. `Task: copy the repaired workbook into workbook/ and add workbook/verify.py (using the 'formulas' lib) that recalculates and asserts 0 errors; wire as a CI check.`
4. `Task: add GitHub Actions CI: install, lint, typecheck, run tests, run workbook/verify.py. Fail on any error.`
5. `Task: write CONTRIBUTING.md documenting: use 'python' not 'python3'; commit convention; no secrets in repo.`

**MCP Requirements:** Filesystem MCP (repo scope), GitHub MCP (repo, PR-only). (07 §2.1, §2.2.)

**n8n Requirements:** n8n container up (no workflows yet); admin account created.

**Database Tables:** none yet (containers only).

**Neo4j Nodes:** none (container only).

**Qdrant Collections:** none (container only).

**Testing Requirements:** CI green on empty repo; `docker compose up` healthchecks pass; `workbook/verify.py` returns 0 errors.

**Definition of Done:** ☐ monorepo builds ☐ `docker compose up` healthy ☐ CI passes ☐ workbook verify = 0 errors ☐ branch protection on.

**Implementation Order:** 1 → 2 → 3 → 4 → 5.

**Dependencies:** none.

**Risk Assessment:** *Low.* Risk: `python3` stub confusion → mitigate by pinning `python` in scripts/CI. Risk: Windows path issues in Docker volumes → use named volumes.

**Effort Estimate:** 5 pd.

---

## PHASE 1 — Data Layer (PostgreSQL system of record)

**Objectives:** implement DATABASE_SCHEMA exactly; load the workbook's entities as seed; enforce constraints + RLS.

**Deliverables:** Prisma schema mirroring `ref/core/plan/proj` + `audit`; migrations; seed loader from the workbook; validation gate library.

**Repositories:** `vndp` → `packages/db`, `packages/domain`.

**Folder Structure:**
```
packages/db/
├─ prisma/schema.prisma     # all tables (DATABASE_SCHEMA §2-6)
├─ migrations/              # 001_extensions, 002_ref, 003_core, 004_plan, 005_proj, 006_audit
├─ seed/load_workbook.py    # read repaired xlsx → upsert entities
├─ src/validate.ts          # schema/range/temporal-overlap gate
└─ src/client.ts            # typed Prisma client export
packages/domain/
├─ value-objects/  entities/  aggregates/   # from 02_DOMAIN_MODEL
```

**Claude Code Tasks:**
1. `Task: from DATABASE_SCHEMA.md, generate prisma/schema.prisma covering schemas ref/core/plan/proj/audit, all 24 tables, enums, PKs/FKs, unique constraints. Use multiSchema. Map money→Decimal(18,4), pct→Decimal(9,6).`
2. `Task: author SQL migrations for what Prisma can't express: btree_gist + EXCLUDE constraints on core.ingredient_prices and plan.prices; CHECK constraints (tiers 1-3, pct≥0, financing splits=1, net_price≤mrp); RLS policies scoped by scenario_id.`
3. `Task: run prisma migrate dev; verify with prisma validate and a psql \d introspection that all FKs and indexes exist.`
4. `Task: implement packages/domain value objects (Money, Percentage, TierLevel, FundingMix, BoxSize, SAMShare…) with invariants and equality, per 02 §3.`
5. `Task: write seed/load_workbook.py — read the repaired xlsx, map sheets→entities (Product Line→skus, BOMs→boms/bom_lines/ingredients, Competitor Brands→competitors, etc.), upsert into PostgreSQL. Use 'python'.`
6. `Task: implement src/validate.ts (schema + range + temporal no-overlap) and unit-test it against bad inputs.`

**MCP Requirements:** Postgres MCP (read-write, scoped roles + RLS — 07 §2.3); Filesystem MCP (read workbook).

**n8n Requirements:** none.

**Database Tables (all of DATABASE_SCHEMA):**
- `ref`: tiers, product_families, fiscal_years
- `core`: brands, product_variants, skus, ingredients, ingredient_prices, boms, bom_lines, plants, markets, channels, competitors, competitor_metrics, funding_rounds
- `plan`: scenarios, data_snapshots, assumptions, prices, expense_assumptions, capex_items, capex_plan, financing_plan
- `proj`: revenue_projection, pnl_lines, working_capital, debt_schedule, returns
- `audit`: change_log

**Neo4j Nodes:** none (Phase 2).

**Qdrant Collections:** none (Phase 2).

**Testing Requirements:** migration up/down idempotent; seed loads without constraint violations; **validation gate unit tests** (reject overlapping prices, pct>1 where bounded, mix≠1); RLS test (a scenario role cannot read another scenario's rows).

**Definition of Done:** ☐ all 24 tables + constraints live ☐ EXCLUDE/CHECK/RLS enforced ☐ workbook seed loads clean ☐ validate.ts ≥90% covered ☐ domain VOs implemented & tested.

**Implementation Order:** 1→2→3 (schema) then 4 (domain) then 5→6 (seed+validate).

**Dependencies:** Phase 0.

**Risk Assessment:** *Medium.* Risk: Prisma multiSchema/EXCLUDE gaps → write raw SQL migrations for those. Risk: workbook→entity mapping ambiguity (mock data, some `#REF!` history) → seed only the verified Year-1 + reference data first, flag the rest.

**Effort Estimate:** 12 pd.

---

## PHASE 2 — Knowledge Layer (Neo4j graph + Qdrant vectors)

**Objectives:** build the reasoning graph and vector store; one-way sync PostgreSQL → Neo4j/Qdrant per snapshot.

**Deliverables:** Neo4j constraints/indexes; graph-sync job; Qdrant collections + embedding pipeline.

**Repositories:** `vndp` → `packages/graph`, `packages/vectors`.

**Folder Structure:**
```
packages/graph/
├─ cypher/constraints.cypher   # KNOWLEDGE_GRAPH §5
├─ src/sync.ts                 # PostgreSQL → Neo4j MERGE per snapshot
└─ src/queries.ts              # impact/lineage queries (§7 A-E)
packages/vectors/
├─ src/collections.ts          # competitor, market, research, financial, decisions
├─ src/embed.ts                # embedding client
└─ src/upsert.ts
```

**Claude Code Tasks:**
1. `Task: from KNOWLEDGE_GRAPH.md §5, create cypher/constraints.cypher (unique constraints + indexes for all 21 node labels); apply to Neo4j.`
2. `Task: implement graph sync (packages/graph/src/sync.ts): read PostgreSQL entities for a snapshot, MERGE nodes + 22 relationship types (KNOWLEDGE_GRAPH §3); idempotent.`
3. `Task: implement the 5 signature queries from KNOWLEDGE_GRAPH §7 (impact, lineage, commodity→products, competitive gap, SAM) as parameterized functions in queries.ts.`
4. `Task: create Qdrant collections (competitor, market, research, financial, decisions) with appropriate vector size + payload schema (source, fetchedAt, scenarioId, entityRefs).`
5. `Task: implement embed.ts + upsert.ts; write a backfill that embeds existing competitor/market reference text.`

**MCP Requirements:** Neo4j MCP (read for queries, write via sync service — 07 §2.6); Qdrant MCP (read/search; upsert via ingest — 07 §2.7); Postgres MCP (read source).

**n8n Requirements:** none yet (workflows in Phase 5 will call these).

**Database Tables:** reads all `core`/`plan`; no new tables.

**Neo4j Nodes (KNOWLEDGE_GRAPH §App A):** Competitor, ProductFamily, Product, Brand, Ingredient, Commodity, BOM, Tier, Market, Plant, Channel, FundingRound, Scenario, Cost, Revenue, Expense, Capex, WorkingCapital, Margin, EBITDA, Valuation.

**Qdrant Collections:** `competitor`, `market`, `research`, `financial`, `decisions`.

**Testing Requirements:** sync idempotency (run twice → identical graph); impact query returns correct blast-radius on a seeded commodity; embedding round-trip (upsert→search returns the same doc); scenario isolation in both stores.

**Definition of Done:** ☐ constraints applied ☐ sync reproducible ☐ 5 queries return correct results on seed ☐ 5 Qdrant collections live + backfilled ☐ scenario-scoped isolation verified.

**Implementation Order:** 1→2→3 (graph) ∥ 4→5 (vectors).

**Dependencies:** Phase 1.

**Risk Assessment:** *Medium.* Risk: graph drift vs PostgreSQL → rebuild-per-snapshot (no incremental edits). Risk: embedding model choice/cost → start with a small local model; make it swappable.

**Effort Estimate:** 10 pd.

---

## PHASE 3 — Simulation Engine (the long pole)

**Objectives:** implement the 8 deterministic core modules + fixpoint solver; reproduce the workbook exactly (golden-master); then Monte Carlo + Optimization scaffolding.

**Deliverables:** `sim-engine` with M-BOM, M-CAPEX, M-DEMAND, M-COMP, M-PNL, M-WC, M-FUND, M-RET; DAG solver with cycle resolution; Monte Carlo runner; optimization interface.

**Repositories:** `vndp` → `packages/sim-engine`, `services/simulation`.

**Folder Structure:**
```
packages/sim-engine/
├─ modules/  m_bom.py m_capex.py m_demand.py m_comp.py m_pnl.py m_wc.py m_fund.py m_ret.py
├─ core/     dag.py fixpoint.py run.py     # ordered solve + cycle convergence (05 §3)
├─ montecarlo/ sampler.py runner.py
├─ optimize/ objective.py search.py constraints.py
└─ tests/    golden_master/   # expected Year-1 numbers from the workbook
```

**Claude Code Tasks:**
1. `Task: implement each module in 05 §2 as a pure function (inputs→outputs) reading from PostgreSQL for a (scenario, snapshot). Start with M-BOM and M-CAPEX (no cycles).`
2. `Task: implement core/dag.py declaring module dependency edges (05 §3) and a topological solver; core/fixpoint.py for the revenue⇄expense and PBT⇄interest cycles (iterate to |Δ|<ε, fail closed if not converged).`
3. `Task: implement M-DEMAND, M-COMP, M-PNL, M-WC, M-FUND, M-RET; wire into the DAG.`
4. `Task: build the golden-master test: run the engine for the Year-1 scenario and assert Revenue≈88.41, EBITDA≈13.50, PAT≈10.12 Cr (from the repaired workbook). Tolerance 0.5%.`
5. `Task: implement montecarlo/ (sample uncertain assumptions, run core N times, output P10/P50/P90 + tornado). Parallelize with a worker pool.`
6. `Task: implement optimize/ interface (decision vars, objective, constraints incl. M-COMP bounds + IMS-Act) using a pluggable solver (start: grid/Bayesian).`
7. `Task: expose services/simulation as an API (run scenario → write proj.* → emit SimulationCompleted).`

**MCP Requirements:** Postgres MCP (read inputs, write `proj.*`).

**n8n Requirements:** none (n8n triggers it later via events).

**Database Tables (writes):** `proj.revenue_projection`, `proj.pnl_lines`, `proj.working_capital`, `proj.debt_schedule`, `proj.returns`; reads all `core`/`plan`.

**Neo4j Nodes:** writes the derivation nodes on completion (Cost, Margin, EBITDA, Valuation) via the graph-sync.

**Qdrant Collections:** none (simulation runs may be embedded into `decisions` in Phase 6).

**Testing Requirements:** **golden-master** (Year-1 numbers match workbook within tolerance — the acceptance gate); fixpoint convergence test (cycles converge, divergence fails closed); zero-error assertion on every run; Monte Carlo determinism (same seed+snapshot → identical distribution); module unit tests.

**Definition of Done:** ☐ 8 modules implemented ☐ DAG solves with cycles converging ☐ **golden-master passes** ☐ 0-error gate enforced ☐ Monte Carlo reproducible ☐ optimization runs a toy problem ☐ simulation API emits events.

**Implementation Order:** 1 (acyclic modules) → 2 (DAG+fixpoint) → 3 (remaining modules) → 4 (golden-master) → 5 (MC) → 6 (optimize) → 7 (API).

**Dependencies:** Phase 1 (data). (Can run parallel to Phase 2.)

**Risk Assessment:** *High* (long pole, correctness-critical). Risk: fixpoint non-convergence → cap iterations, fail closed, log. Risk: golden-master mismatch → diff module-by-module vs workbook cells. Risk: mock-data sensitivity → assert on relationships/flow, not absolute values beyond the verified Year-1.

**Effort Estimate:** 18 pd.

---

## PHASE 4 — MCP Integrations

**Objectives:** stand up all 8 MCP servers with least-privilege scopes and the security model of 07.

**Deliverables:** configured MCP servers + wrappers; per-MCP access policy; ACL sanitizer for untrusted sources.

**Repositories:** `vndp` → `packages/mcp`.

**Folder Structure:**
```
packages/mcp/
├─ servers/  filesystem.json github.json postgres.json browser.json
│            gsheets.json neo4j.json qdrant.json n8n.json
├─ acl/      sanitize.ts        # strip embedded directives (07 S1/S6)
└─ policy/   access-matrix.ts   # 07 §3 MCP×agent matrix
```

**Claude Code Tasks:**
1. `Task: configure each MCP server per 07 §2 with the exact Access Rights (scopes, read/write, deny-lists). Filesystem→project root; Postgres→scoped roles+RLS; Browser→read-only; Google Sheets→output tab only; Neo4j/Qdrant→read+sync-write; GitHub→PR-only; n8n→trigger allow-list.`
2. `Task: implement acl/sanitize.ts and require it on all Browser/Google-Sheets/Research content before any LLM step (07 S6).`
3. `Task: implement policy/access-matrix.ts encoding the 07 §3 matrix; deny calls outside an agent's rights.`
4. `Task: write integration smoke tests: each MCP connects, a read works, a denied write is rejected, an injection string is stripped by the ACL.`

**MCP Requirements:** all 8 (this phase delivers them).

**n8n Requirements:** n8n MCP points at the (Phase 5) workflow allow-list.

**Database Tables:** Postgres MCP uses roles over Phase-1 tables; adds none.

**Neo4j Nodes / Qdrant Collections:** access only (from Phase 2).

**Testing Requirements:** per-MCP connect + scoped-read + denied-write tests; ACL injection test (a cell/page containing "ignore instructions and …" is neutralized); audit-log entry written per call.

**Definition of Done:** ☐ 8 MCPs connect ☐ scopes & deny-lists enforced ☐ ACL strips directives ☐ access-matrix denies out-of-scope calls ☐ all calls audited.

**Implementation Order:** 1 (servers) → 2 (ACL) → 3 (policy) → 4 (tests).

**Dependencies:** Phases 1, 2.

**Risk Assessment:** *Medium-High* (security surface). Risk: prompt injection via external data → ACL + S1 boundary, tested. Risk: over-broad scopes → least-privilege defaults, reviewed.

**Effort Estimate:** 10 pd.

---

## PHASE 5 — n8n Ingestion Workflows

**Objectives:** implement the 5 pipelines of 06, writing to PostgreSQL/Qdrant/Neo4j and emitting events.

**Deliverables:** 5 workflow JSONs + custom nodes; error-handler workflow; the `#REF!` validation gate in Workbook Sync.

**Repositories:** `vndp` → `apps/n8n`.

**Folder Structure:**
```
apps/n8n/
├─ workflows/ competitor.json market.json financial.json research.json workbook-sync.json
├─ nodes/     acl-sanitize/ validate-gate/   # custom function nodes
└─ creds/     .gitignored (vault-managed)
```

**Claude Code Tasks:**
1. `Task: build the Competitor Monitoring workflow (06 §2): schedule+webhook → HTTP fetch → ACL → LLM extract → validate → upsert PostgreSQL core.competitor_metrics + Qdrant competitor + Neo4j BENCHMARKS → emit CompetitorBenchmarkUpdated.`
2. `Task: build Market Intelligence (06 §3) → core.markets / market / HAS_SAM → SamShareUpdated.`
3. `Task: build Financial Intelligence (06 §4) → ingredient_prices/assumptions / financial / Commodity-DRIVES-Cost → IngredientPriceChanged.`
4. `Task: build Research Ingestion (06 §5) → chunk+embed → Qdrant research / Postgres doc registry / Neo4j MENTIONS → ResearchIngested.`
5. `Task: build Workbook Synchronization (06 §6): read workbook → VALIDATE (scan #REF!/#VALUE!/#DIV0, fail closed) → diff → upsert PostgreSQL → rebuild Neo4j subgraph → re-embed Qdrant → snapshot → SnapshotCreated.`
6. `Task: build the Error Trigger workflow → audit.change_log + alert; export all workflows to apps/n8n/workflows.`

**MCP Requirements:** n8n MCP (trigger allow-list); Browser, Google Sheets, Postgres, Neo4j, Qdrant MCPs used inside workflows.

**n8n Requirements:** queue mode enabled (parallel intel workflows); credentials in vault (07 S4); webhooks registered.

**Database Tables (writes):** `core.competitors/_metrics`, `core.markets`, `core.ingredient_prices`, `plan.assumptions`, doc registry; Workbook Sync writes all `core`/`plan` + `plan.data_snapshots`.

**Neo4j Nodes:** edges `BENCHMARKS`, `HAS_SAM`, `DRIVES`, `MENTIONS`; Workbook Sync rebuilds the subgraph.

**Qdrant Collections:** `competitor`, `market`, `financial`, `research` (upserts).

**Testing Requirements:** each workflow e2e on a fixture source; ACL applied (injection fixture neutralized); idempotent re-run (no dupes); **Workbook Sync fails closed** on a workbook with an injected `#REF!`; events emitted and observed.

**Definition of Done:** ☐ 5 workflows run e2e ☐ writes land in all 3 stores ☐ events emitted ☐ Workbook Sync error-gate verified ☐ error workflow logs+alerts ☐ no duplicate rows on re-run.

**Implementation Order:** 1∥2∥3 (intel) → 4 (research) → 5 (sync) → 6 (errors).

**Dependencies:** Phases 2, 4.

**Risk Assessment:** *Medium.* Risk: flaky external sources → retries + backoff + provenance. Risk: LLM extraction errors → validate gate + confidence scoring + human review queue.

**Effort Estimate:** 12 pd.

---

## PHASE 6 — Agent Layer (Boardroom + MC + Optimization in the loop)

**Objectives:** implement the 7 executive agents + workers on ruflo; wire the board cycle (05 §7) with binding vetoes, consensus, and human escalation.

**Deliverables:** agent definitions; SendMessage comms; consensus/escalation protocol; decision-of-record persistence; the closed board-cycle loop.

**Repositories:** `vndp` → `packages/agents`, `services/decision`.

**Folder Structure:**
```
packages/agents/
├─ executive/  cfo.md cmo.md coo.md investor.md market.md competitor.md chairman.md
├─ workers/    cost-engineer.md pricing.md demand.md capacity.md finance-modeler.md
│              compliance.md scenario-runner.md validator.md
├─ protocol/   consensus.ts escalation.ts decision-record.ts
└─ spawn/      manifest.ts    # AGENTS §11
```

**Claude Code Tasks:**
1. `Task: author each agent (AGENTS §1-7) as a ruflo agent definition with Mission/Inputs/Outputs/Tools/DecisionRights/KPIs and the MCPs it may call (07 §3 matrix).`
2. `Task: implement protocol/consensus.ts (hive-mind_consensus) and escalation.ts (CFO solvency-veto, Investor hurdle-veto binding; capital/dilution → human).`
3. `Task: implement decision-record.ts: persist decisions + dissent to memory + Qdrant 'decisions' + audit, keyed to (scenario, snapshot).`
4. `Task: wire the board cycle (05 §7): agents set decisions → optimization → Monte Carlo stress-test → debate → Chairman synthesize → human approve → re-run.`
5. `Task: implement the spawn manifest (AGENTS §11) and a smoke test running one full board cycle on the Year-1 scenario.`

**MCP Requirements:** all per the 07 §3 matrix (Postgres/Neo4j/Qdrant read; n8n trigger; Filesystem/GitHub for records).

**n8n Requirements:** Chairman triggers intel refresh (Phase 5 workflows) at cycle start.

**Database Tables:** reads `proj.*`/`core`/`plan`; writes decision records (audit + a `decision` table if added) under gating.

**Neo4j Nodes:** reads for impact/lineage (CFO/Chairman).

**Qdrant Collections:** `decisions` (read prior, write new).

**Testing Requirements:** board-cycle e2e produces a recommendation + dissent; veto tests (insolvent plan blocked by CFO; sub-hurdle blocked by Investor); human-escalation test (capital commitment is *not* auto-executed); injection test (external intel cannot redirect an agent).

**Definition of Done:** ☐ 7 exec + worker agents defined ☐ consensus + binding vetoes work ☐ decisions persisted & reproducible ☐ board cycle runs e2e ☐ no agent commits capital ☐ all agent writes validated.

**Implementation Order:** 1 (definitions) → 2 (protocol) → 3 (records) → 4 (cycle) → 5 (smoke).

**Dependencies:** Phases 3, 4, 5.

**Risk Assessment:** *High.* Risk: agent over-reach / unsafe action → human-in-loop guardrail + validator gate + decision-rights enforcement. Risk: non-determinism → pin to (scenario, snapshot, seed); log rationale.

**Effort Estimate:** 16 pd.

---

## PHASE 7 — Executive Layer + Hardening & Scale

**Objectives:** deliver the dashboard + what-if console; meet the NFRs (01 §12.1); productionize (observability, RLS, partitioning, deploy).

**Deliverables:** Strategy control panel + what-if console; CQRS read models; board-pack export (xlsx/pptx/pdf); observability; k8s deploy; scale tests.

**Repositories:** `vndp` → `apps/web`, `apps/api`, `infra/k8s`.

**Folder Structure:**
```
apps/web/   pages/ (dashboard, what-if, scenario-compare)  components/  api-client/
apps/api/   graphql schema + resolvers (BFF)  read-models/
infra/k8s/  deployments, services, hpa; infra/terraform/
```

**Claude Code Tasks:**
1. `Task: build the GraphQL BFF (apps/api) exposing scenarios, projections, returns, and a run-scenario mutation; add CQRS read models for dashboard queries (<500ms).`
2. `Task: build apps/web: Strategy control panel (editable levers → run), what-if console, dashboards (revenue mix, margin bridge, returns, WC rotation), scenario compare.`
3. `Task: implement board-pack export using the xlsx/pptx/pdf skills (narrative + statements + scenario comparison).`
4. `Task: add observability (OpenTelemetry traces/metrics/logs) across services; dashboards for latency + error rate.`
5. `Task: partition proj.* by scenario_id; add read replicas; load-test Monte Carlo (1k paths) to meet <60s parallel.`
6. `Task: write k8s manifests + HPA; deploy to a staging cluster; run the NFR acceptance suite.`

**MCP Requirements:** Filesystem (exports), GitHub (deploy PRs); others read-only for dashboards.

**n8n Requirements:** scheduled intel refresh enabled in staging.

**Database Tables:** partition `proj.*`; read-replica config; no new business tables.

**Neo4j Nodes / Qdrant Collections:** read-replica/scale config only.

**Testing Requirements:** NFR suite (scenario run <5s; MC 1k <60s; dashboard <500ms; impact query <1s; 0-error gate; reproducibility 100%); load test; security review (RLS, ACL, secrets); accessibility smoke on web.

**Definition of Done:** ☐ dashboard + what-if live ☐ board-pack exports ☐ NFR targets met ☐ observability in place ☐ partitioning + replicas ☐ staging deploy green ☐ security review passed.

**Implementation Order:** 1 (API) → 2 (web) → 3 (export) → 4 (observability) → 5 (scale) → 6 (deploy).

**Dependencies:** Phase 6.

**Risk Assessment:** *Medium.* Risk: NFR misses under load → CQRS + partitioning + parallel MC; profile early. Risk: scope creep on UI → ship the control panel + 4 core dashboards first.

**Effort Estimate:** 14 pd.

---

## Cross-cutting: testing strategy

| Level | What | Where |
|---|---|---|
| Unit | VOs, validate gate, each sim module, ACL | every package |
| Integration | DB constraints, graph sync, MCP scopes, workflow e2e | phases 1-5 |
| **Golden-master** | engine reproduces workbook Year-1 (Rev 88.41 / EBITDA 13.50 / PAT 10.12) | phase 3 (gate) |
| Reproducibility | same (scenario, snapshot, seed) → identical output | phases 3, 6 |
| Security | RLS, ACL injection, denied writes, no-capital-move | phases 4, 6 |
| NFR/load | latency + Monte Carlo throughput | phase 7 |

## Cross-cutting: risk register (top)

| Risk | Phase | Severity | Mitigation |
|---|---|---|---|
| Simulation correctness drift | 3 | High | golden-master gate + module diff vs workbook |
| Fixpoint non-convergence | 3 | High | iteration cap, fail closed, log |
| Prompt injection via external data | 4,5,6 | High | ACL + S1 boundary, tested |
| Agent unsafe/irreversible action | 6 | High | human-in-loop, validator gate, decision rights |
| `python3` stub vs `python` | all | Low | pin `python`; CI check |
| Graph/store drift vs PostgreSQL | 2,5 | Medium | rebuild-per-snapshot, idempotent sync |
| Mock-data over-fitting | 3,6 | Medium | assert on relationships/flow, not values |

## Definition of Done — global (every phase)

☐ code reviewed via PR (GitHub MCP, human merge) ☐ tests green in CI ☐ **zero calculation/formula errors** ☐ reproducibility key present on outputs ☐ secrets vaulted, none in repo ☐ docs updated ☐ DoD checklist of the phase fully ticked.

---

## Sequencing summary (Gantt-style)

```
Phase 0 ██
Phase 1   ████████
Phase 2           █████        (∥ may overlap Phase 3 start)
Phase 3           ████████████ (critical path)
Phase 4                █████
Phase 5                     ██████
Phase 6                           ████████
Phase 7                                   ███████
            ──────────── ~97 person-days ────────────►
```

---

*End of 03_IMPLEMENTATION_ROADMAP.md — the build plan for the Valencia Nutracare Decision Platform, governed by BUSINESS_ONTOLOGY.md.*
