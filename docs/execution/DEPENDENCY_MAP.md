# DEPENDENCY_MAP — Valencia Nutracare Decision Platform (VNDP)

**Authority:** CTO / Chief Systems Architect
**Status:** Execution planning · v1.0 · 2026-06-19
**Derives from:** 01_SYSTEM_ARCHITECTURE · 03_IMPLEMENTATION_ROADMAP · 04_REPOSITORY_STRUCTURE · 05_SIMULATION_ENGINE · 06/07/08 · DATABASE_SCHEMA · KNOWLEDGE_GRAPH · AGENTS · 02_DOMAIN_MODEL
**Purpose:** The single authoritative dependency graph for the build — phase-level, module-level, and store-level — so no task starts before its inputs are green.

> **Reading rule:** an arrow `A → B` means "B requires A complete (DoD green) before it can start." Critical-path edges are marked **★**.

---

## 1. Phase-level dependency graph

```
                 ┌──────────────────────────────────────────────┐
   P0 Foundation ★├─► P1 Data (PostgreSQL) ★─┬─► P2 Knowledge (Neo4j+Qdrant) ─┬─► P4 MCP ─┬─► P5 n8n ─┐
   (repo, infra,  │                          │                                │           │          │
    compose, CI)  │                          └─► P3 Simulation Engine ★───────┴───────────┴──► P6 ★──► P7 ★
                 └──────────────────────────────────────────────┘            Agent Boardroom   Executive
   Critical path (long pole): P0 → P1 → P3 → P6 → P7   (simulation engine is the long pole)
```

| Phase | Depends on | Can parallelize with | Blocks |
|---|---|---|---|
| **P0** Foundation & Repo | — | — | everything |
| **P1** Data Layer (PG) | P0 | — | P2, P3, P4 |
| **P2** Knowledge (Neo4j+Qdrant) | P1 | **P3** | P4, P5 |
| **P3** Simulation Engine ★ | P1 | **P2** | P6 |
| **P4** MCP Integrations | P1, P2 | P3 (tail) | P5, P6 |
| **P5** n8n Ingestion | P2, P4 | — | P6 |
| **P6** Agent Boardroom ★ | P3, P4, P5 | — | P7 |
| **P7** Executive + Hardening ★ | P6 | — | (ship) |

**Concurrency windows (two-track team):**
- Window A: P2 (Knowledge) ∥ P3 (Simulation) once P1 is green — the biggest schedule win.
- Window B: P4 (MCP) tail overlaps P3 tail; P5 starts as soon as P2+P4 green.

---

## 2. Cross-cutting prerequisites (block multiple phases)

| Prerequisite | Needed by | Type | Owner | Status |
|---|---|---|---|---|
| Git repository + GitHub remote + branch protection | P0 (CI, PR flow), all "commit progress" | **BLOCKER** — env is *not* a git repo | DevOps | ❌ open (see RISK_REGISTER R-01) |
| Docker Desktop + WSL2 running | P0 (compose up), P1–P7 integration tests | external machine state | DevOps | ⚠ unverified (08 §6) |
| `python` (not `python3`) on PATH; Store alias off | all Python work, CI | env config | DevOps | ⚠ verify (08 §3.4) |
| uv workspace tooling | P0 onward | install | DevOps | ⚠ (08 §3.3) |
| `VNDP_LLM_API_KEY` + embedding model choice | P2 (embeddings), P5 (LLM extract), P6 (agents) | secret + decision | Platform | ❌ open (R-05) |
| GitHub fine-grained PAT | P4 (GitHub MCP), P0 CI | secret | DevOps | ❌ open |
| n8n API key | P4 (n8n MCP), P5 | secret (post-infra) | DevOps | ❌ open |
| Event-bus technology decision (NATS/Redpanda/in-proc) | P3 (emits events), P5, P6 | **decision** | Architect | ❌ open (R-06) |
| Workbook → entity seed mapping (Year-1 + ref only) | P1 (seed), P3 (golden-master) | data scoping | Data Eng | ⚠ Y2–5 are `#REF!`-broken in source (ontology §8) |

---

## 3. Module-level dependency DAG (Simulation Engine — P3, the long pole)

From 05_SIMULATION_ENGINE §3. Two intentional cycles resolved by fixpoint.

```
   Strategy ─► M-CAPEX ─┬─► installedCapacity ─► M-DEMAND ─► boxes ─┐
                        └─► D&A ──────────────────────────┐        │
   ingredient rates ─► M-BOM ─► costPerBox ───────┐       │        │
   Competitor ─► M-COMP ─► expensePriors ──┐       │       │        │
                                           ▼       ▼       ▼        ▼
                                    ┌──────────── M-PNL ───────────┐
                                    │  revenue ⇄ opex   (fixpoint)  │   ← cycle 1
                                    │  PBT ⇄ interest   (fixpoint)  │   ← cycle 2
                                    └──────┬──────────────┬─────────┘
                            PAT+D&A ▼      │ monthly       │ retained
                                M-WC ◄─────┘ inputs        ▼
                                  │ wcReq               M-FUND ─► interest (back to M-PNL)
                                  └────────► M-FUND ─► capitalBase ─► M-RET ─► returns
```

| Module | Inputs (modules) | Cycle? | Build order |
|---|---|---|---|
| M-BOM | ingredient rates (exogenous) | no | **1** (acyclic root) |
| M-CAPEX | Strategy (exogenous) | no | **1** (acyclic root) |
| M-COMP | Competitor (exogenous) | no | 2 |
| M-DEMAND | M-CAPEX, Market, Strategy | no | 3 |
| M-PNL | M-DEMAND, M-BOM, M-CAPEX, M-COMP, **M-FUND** | ⇄ M-FUND, ⇄ opex | 4 (needs fixpoint) |
| M-WC | M-DEMAND, M-BOM, M-PNL | no | 5 |
| M-FUND | M-CAPEX, M-WC, M-PNL | ⇄ M-PNL | 5 (co-solved with M-PNL) |
| M-RET | M-PNL, M-FUND | no (terminal) | 6 |
| DAG solver + fixpoint | declares edges above | — | between 1 and 3 |
| Monte Carlo | wraps full core | — | 7 |
| Optimization | wraps full core + M-COMP bounds | — | 8 |

**Acceptance oracle (gate before any layer above P3):** golden-master Year-1 — Revenue ≈ ₹88.41 Cr, EBITDA ≈ ₹13.50 Cr, PAT ≈ ₹10.12 Cr (tol 0.5%).

---

## 4. Store / migration ordering (P1, P2)

**PostgreSQL (Alembic, forward-only)** — DATABASE_SCHEMA §App A:
```
extensions (btree_gist, pgcrypto) ─► ref ─► core ─► plan ─► proj ─► audit
        │
        └─ hand-written: EXCLUDE (ingredient_prices, plan.prices) · CHECK (tiers 1-3, pct≥0,
           financing splits=1, net_price≤MRP) · RLS by scenario_id · enums · touch triggers
```
24 tables: `ref`(3) · `core`(13) · `plan`(8) · `proj`(5) · `audit`(1). FK rule: every FK indexed; dimensions RESTRICT, owned detail CASCADE.

**Neo4j (cypher migrations, idempotent; data rebuilt per snapshot — never hand-edited):**
```
constraints (7 unique/node-key) ─► indexes (4 traversal anchors) ─► graph-sync(snapshot) [reads PG]
```
21 node labels, 22 relationship types (KNOWLEDGE_GRAPH §App A).

**Qdrant (create-if-absent collection config):**
```
collections: competitor · market · research · financial · decisions   (then idempotent re-embed jobs)
```

---

## 5. Layer ↔ data-store consumption matrix

| Layer / phase | PostgreSQL | Neo4j | Qdrant | n8n | Event bus |
|---|---|---|---|---|---|
| P1 Data | **owns** (write) | — | — | — | — |
| P2 Knowledge | read | **owns** (sync-write) | **owns** (upsert) | — | — |
| P3 Simulation | read `core/plan`, write `proj.*` | write derivation nodes (via sync) | — | — | emits `SimulationCompleted` |
| P4 MCP | scoped roles + RLS | read + sync-write | read + ingest | trigger allow-list | — |
| P5 n8n | upsert `core/plan` + snapshots | rebuild subgraph | re-embed | **owns workflows** | emits domain events |
| P6 Agents | read (RLS role) | read (lineage/impact) | read + write `decisions` | trigger | sub/pub |
| P7 Executive | read (CQRS models), partition `proj.*` | read replica | read | scheduled | consume |

---

## 6. Domain-event dependency chain (01 §8, 02 §8, 06)

```
IngredientPriceChanged ─► M-BOM recompute ─► BOMRecomputed ─► COGS refresh
SamShareUpdated ───────► M-DEMAND volume ─► PriceUpdated ─► revenue recompute
CapacityPlanChanged ───► capex/volume shift
AssumptionUpdated / SnapshotCreated ─► Simulation (freeze baseline) ─► SimulationCompleted
   ─► ReturnsComputed ─► Investor agent ─► (board cycle) ─► DecisionApproved ─► commit assumptions
ComplianceVerdictIssued ─► blocks/allows marketing spend (IMS Act)
```
Events first appear at P3; the full bus is exercised at P5/P6. **Decision needed before P3 ships** (R-06).

---

## 7. Build-vs-resolve summary

| Edge | Resolution mechanism | Where |
|---|---|---|
| revenue ⇄ opex | iterative fixpoint, `|Δ|<ε`, fail-closed | M-PNL (P3) |
| PBT ⇄ interest | iterative fixpoint, co-solve M-PNL/M-FUND | P3 |
| graph drift vs PG | rebuild-per-snapshot (no incremental edits) | P2/P5 |
| #REF!-class break | validation gate at every write; Workbook Sync fails closed | P1, P5 |
| cross-aggregate consistency | domain events (eventual), never one transaction | all |

---

*End of DEPENDENCY_MAP.md — governs task start-gates for the VNDP build.*
