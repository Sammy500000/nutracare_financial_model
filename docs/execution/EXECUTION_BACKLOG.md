# EXECUTION_BACKLOG — Valencia Nutracare Decision Platform (VNDP)

**Authority:** CTO / Chief Systems Architect
**Status:** Master execution backlog · v1.0 · 2026-06-19
**Source of truth (meaning):** BUSINESS_ONTOLOGY.md
**Architecture package (specs):** ARCHITECTURE · 01–09 · DATABASE_SCHEMA · KNOWLEDGE_GRAPH · AGENTS · 02_DOMAIN_MODEL
**Companions:** DEPENDENCY_MAP · TASK_GRAPH · IMPLEMENTATION_SEQUENCE · SPRINT_PLAN · RISK_REGISTER

---

## 1. Architecture review — outcome

All 14 architecture documents were read in full and cross-checked. The platform is internally **coherent and buildable as specified**. Target shape:

```
Workbook → Data Platform → Knowledge Graph → Simulation Engine → Agent Boardroom → Executive Copilot
   (xlsx)    PostgreSQL      Neo4j + Qdrant     8 pure modules      7 PydanticAI agents   FastAPI + web
```

**Confirmed stack (04 supersedes 03's sketch; 09 is binding policy):** Python 3.12 · FastAPI · PostgreSQL 15 · Neo4j 5 · Qdrant · n8n · **SQLAlchemy 2.0 + Alembic** · PydanticAI · Docker · uv-workspace monorepo. Agent orchestration on ruflo/claude-flow (hierarchical-mesh, max 15).

**Scale inventory (what "100% coverage" means):**
- **24 PostgreSQL tables** across 5 schemas (`ref` 3 · `core` 13 · `plan` 8 · `proj` 5 · `audit` 1) — DATABASE_SCHEMA §App A.
- **21 Neo4j node labels + 22 relationship types** — KNOWLEDGE_GRAPH §App A.
- **5 Qdrant collections** — competitor, market, research, financial, decisions.
- **8 simulation modules** — M-BOM, M-CAPEX, M-DEMAND, M-COMP, M-PNL, M-WC, M-FUND, M-RET + DAG/fixpoint + Monte Carlo + optimization.
- **8 MCP servers** — Filesystem, GitHub, Postgres, Browser, Google Sheets, Neo4j, Qdrant, n8n.
- **5 n8n workflows** — Competitor, Market, Financial, Research, Workbook Sync (+ Error Trigger).
- **7 executive agents** — CFO, CMO, COO, Investor, Market, Competitor, Chairman + 8 worker agents.
- **14 ontology entities · 11 BP · 8 DP · 8 FP processes.**

**Acceptance oracle (the one set of real numbers):** Year-1 — Revenue ≈ ₹88.41 Cr · EBITDA ≈ ₹13.50 Cr · PAT ≈ ₹10.12 Cr (tol 0.5%). Years 2–5 are `#REF!`-broken in the source workbook → **mock-data discipline: validate flow/relationships, not Y2–5 values** (ontology §8, principle P6).

**Two structural cures the platform encodes** (the inverse of the workbook's failure):
1. Separate the 5 concerns into layers → a break is localized, not a model-wide `#REF!` storm.
2. Make dependencies first-class: explicit calc DAG (sim) + queryable graph edges (Neo4j) + validation gate at every write.

---

## 2. Conflicts found & resolutions

| # | Conflict | Resolution |
|---|---|---|
| C1 | **ORM:** 03/01 say Prisma; 04/09/08 say SQLAlchemy+Alembic | **SQLAlchemy 2.0 + Alembic** (04 explicitly supersedes 03; 09 binding; directive Phase 1 agrees). RISK R-03 ✅. |
| C2 | **MCP count:** directive Phase 5 lists 7; 07 defines 8 (adds Google Sheets); 08 wires 7 | Build all 8 per 07; Google Sheets MCP optional/deferrable (R-08). |
| C3 | **API style:** 01 "GraphQL+REST"; 04 "FastAPI BFF GraphQL-or-REST" | FastAPI BFF; GraphQL for dashboard reads, REST for mutations (P7 decision, non-blocking). |
| C4 | **Event bus:** "Target", tech unchosen (Kafka/Redpanda/NATS) | Decision R-06 — default NATS/in-proc until P5. |

No conflict redesigns the architecture; all resolve by documented precedence. **The architecture is executed as specified.**

---

## 3. Phase backlog (epics → tasks)

Full task detail in TASK_GRAPH; ordering in IMPLEMENTATION_SEQUENCE; schedule in SPRINT_PLAN.

| Phase | Epic | Tasks | Effort | DoD (gate) |
|---|---|---|---|---|
| **P0** | Foundation & repo | T0.1–T0.7 | 5 pd | builds · compose healthy · CI green · workbook 0-errors · branch protection |
| **P1** | Data layer (PG) | T1.1–T1.8 | 12 pd | 24 tables+constraints · EXCLUDE/CHECK/RLS · seed clean · validate ≥90% · VOs tested |
| **P2** | Knowledge (Neo4j+Qdrant) | T2.1–T2.5 | 10 pd | sync reproducible · 5 queries correct · 5 collections backfilled · scenario isolation |
| **P3** ★ | Simulation engine | T3.1–T3.7 | 18 pd | 8 modules · DAG converges · **golden-master passes** · 0-error · MC reproducible · API emits event |
| **P4** | MCP integrations | T4.1–T4.4 | 10 pd | 8 MCPs connect · scopes enforced · ACL strips directives · matrix denies · audited |
| **P5** | n8n ingestion | T5.1–T5.6 | 12 pd | 5 workflows e2e · 3-store writes · events · sync fails-closed on `#REF!` · idempotent |
| **P6** ★ | Agent boardroom | T6.1–T6.5 | 16 pd | consensus+binding vetoes · decisions reproducible · cycle e2e · no-capital-move |
| **P7** ★ | Executive + hardening | T7.1–T7.6 | 14 pd | dashboard+what-if · board-pack · NFR met · observability · staging green · security passed |
| | **Total** | | **~97 pd** | |

**Critical path:** P0 → P1 → P3 → P6 → P7. **Parallelize** P2 ∥ P3 after P1.

---

## 4. Data Acquisition System (mandatory deliverable)

Per directive. The Market Intelligence Platform = the **n8n ingestion tier (06) + Browser/Sheets MCP (07) + Qdrant/Neo4j/PG stores**. A `DATA_ACQUISITION_STRATEGY.md` is to be authored **before P5 implementation** (it is a P4/P5 prerequisite, not part of this planning set). Target sources → workflow mapping:

| Source category | Collected via | Lands in | Workflow |
|---|---|---|---|
| Commodity / ingredient prices | Browser MCP + feeds → ACL → parse | `core.ingredient_prices` · Qdrant `financial` · Neo4j `Commodity-[:DRIVES]->Cost` | Financial Intelligence (T5.3) |
| Competitor pricing / products | Browser MCP → ACL → LLM extract | `core.competitor_metrics` · Qdrant `competitor` · Neo4j `BENCHMARKS` | Competitor Monitoring (T5.1) |
| Maternal / infant / child nutrition market data | Browser MCP → ACL → map family×tier×year | `core.markets` · Qdrant `market` · Neo4j `HAS_SAM` | Market Intelligence (T5.2) |
| Hospital / doctor data | Browser + research drops | `core.channels` · Qdrant `research` | Market Intel + Research (T5.2/T5.4) |
| Government / birth / FSSAI / GST data | feeds + bulletins → ACL → parse | `plan.assumptions` (rules) · Qdrant `financial` | Financial Intelligence (T5.3) |

All external content is **untrusted data** (S1/S6): ACL-sanitized before any LLM step; idempotent upsert; provenance (`source`, `fetchedAt`, `confidence`); fail-closed validation. **DATA_ACQUISITION_STRATEGY.md is gated behind R-05 (LLM/embedding) + source/domain allow-list decisions.**

---

## 5. Definition of Done — global (every PR, 09 §16)

☐ Human-reviewed PR (GitHub MCP, no auto-merge, no force-push) · ☐ CI green (ruff → mypy --strict → unit → integration → **golden-master** → security) · ☐ **zero calculation errors** · ☐ `(scenario_id, snapshot_id)` on every output · ☐ secrets vaulted, none in repo · ☐ parameterized SQL/Cypher · ☐ external content treated as data · ☐ Money is `Decimal` INR · ☐ files <500 lines · ☐ corresponding `docs/` spec updated in the same PR · ☐ migration has tested `downgrade`.

---

## 6. Blockers & next step (autonomous-CTO protocol)

Planning is complete (this document set). The next step in IMPLEMENTATION_SEQUENCE is **Phase 0 / pre-flight**, which hits hard blockers requiring user authorization before execution:

| Blocker | Why it stops autonomous execution | Recommended option |
|---|---|---|
| **R-01 — not a git repo** | "Commit progress", PR flow, CI, branch protection all need a repo + GitHub remote + PAT, which only the user can authorize/create. | `git init` in place + create private `vndp` remote + PAT; protect `main`. |
| **R-02 — in-place monorepo scaffold** | 08 §10 reshapes *this* folder (≈30 dirs) and relocates the 14 design docs into `docs/`. Structurally significant; confirm before moving the user's files. | Scaffold in place per 08 §10 (alt: `vndp/` subfolder). |
| **R-09 — Docker/WSL2 unverified** | P0 `docker compose up` + all integration tests need Docker running; cannot verify from here. | User runs 08 §11 checklist. |
| **R-05 / R-06 — open decisions** | LLM/embedding provider (gates P2/P5/P6) and event-bus tech (gates P3 tail) | defaults proposed in RISK_REGISTER; confirm. |
| **R-18 — misconfigured Write hook** | A project PostToolUse hook runs `python3 .../check-sql-files.py` (missing path, Store stub) and errors on every file write. Non-blocking (writes succeed) but noisy. | Repoint hook to `python` + valid path, or remove from settings. |

**Recommendation:** approve **R-01 + R-02** (repo bootstrap + in-place scaffold) and confirm **R-05/R-06** defaults, so Phase 0 can execute end-to-end. Everything authorable **without** those (compose file, `.env.example`, pyproject, verify script, CI yaml) can be staged immediately on approval of the scaffold.

> Per the operating principle, execution pauses here for these user-owned, partly-irreversible decisions — not for routine build steps. Once unblocked, work proceeds autonomously through the phase gates above.

---

*End of EXECUTION_BACKLOG.md — the master backlog for the Valencia Nutracare Decision Platform, governed by BUSINESS_ONTOLOGY.md.*
