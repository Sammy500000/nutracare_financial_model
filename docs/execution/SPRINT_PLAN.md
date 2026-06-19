# SPRINT_PLAN — Valencia Nutracare Decision Platform (VNDP)

**Authority:** CTO
**Status:** Execution planning · v1.0 · 2026-06-19
**Companion to:** TASK_GRAPH · IMPLEMENTATION_SEQUENCE · EXECUTION_BACKLOG
**Cadence:** 2-week sprints · 1 dev + Claude Code pairing (multiply by ~0.6 if two parallel tracks)
**Total:** ~97 pd ≈ **10 sprints** single-track (≈ 6–7 sprints two-track).

> Each sprint lists its goal, tasks (TASK_GRAPH IDs), the exit gate, and the demo. No sprint closes until its gate is green and a human-merged PR lands.

---

## Sprint 0 — Foundation (P0, ~5 pd)

- **Goal:** repo + local infra + CI + workbook baseline locked.
- **Pre-flight:** clear R-01 (repo), R-09 (Docker), python/uv (08 §11).
- **Tasks:** T0.1 → T0.7.
- **Exit gate:** monorepo builds · `docker compose up` 4 services healthy · CI green · `workbook/verify.py` = 0 errors · branch protection on.
- **Demo:** `claude mcp list` (Filesystem+GitHub) + CI run + compose healthcheck screen.
- **Risks:** R-01, R-02 (scaffold approval), R-17/R-18 (python3 hook), R-19 (Windows volumes).

---

## Sprint 1 — Data Layer I: schema (P1a, ~6 pd)

- **Goal:** all 24 tables + constraints live and verified.
- **Tasks:** T1.1 (models) → T1.2 (migrations) → T1.3 (EXCLUDE/CHECK/RLS/triggers) → T1.4 (introspection).
- **Exit gate:** `alembic upgrade head`/`downgrade base` idempotent · EXCLUDE/CHECK/RLS enforced · `\d` shows all FKs+indexes.
- **Demo:** migrate up/down; reject an overlapping price + a `mix≠1` financing row.
- **Risks:** R-16 (moot under Alembic), R-23 (mapping).

---

## Sprint 2 — Data Layer II: domain + seed (P1b, ~6 pd)

- **Goal:** domain VOs, repositories, workbook seed, validation gate.
- **Tasks:** T1.5 (VOs) → T1.6 (repos) → T1.7 (seed Year-1+ref) → T1.8 (validate).
- **Exit gate (P1 DoD):** seed loads clean · validate ≥90% covered · VOs property-tested · repos pass testcontainers.
- **Demo:** seed the repaired workbook; query cost/box per family; show validation rejects bad input.
- **Risks:** R-14 (mock-data — seed Y1+ref only), R-23.
- **Fork point:** P1 green → start Track A (S3) ∥ Track B (S4–S6). Single-track: do S4–S6 first (critical path).

---

## Sprint 3 — Knowledge Layer (P2, ~10 pd) — Track A

- **Goal:** Neo4j graph + Qdrant vectors, synced from PG per snapshot.
- **Tasks:** T2.1 (constraints) → T2.2 (sync) → T2.3 (5 queries) ∥ T2.4 (collections) → T2.5 (embed+backfill).
- **Exit gate (P2 DoD):** sync run-twice identical · impact/lineage queries correct on seed · 5 collections backfilled · scenario isolation verified.
- **Demo:** "if SMP price moves, which valuations shift?" (blast-radius) returns the spine; semantic search round-trip.
- **Risks:** R-05 (embedding model/key), R-15 (drift → rebuild-per-snapshot).

---

## Sprints 4–6 — Simulation Engine ★ (P3, ~18 pd) — Track B

- **Goal:** the deterministic core reproduces the workbook; MC + optimization + API.
- **S4 (acyclic core):** T3.1 (ports, M-BOM, M-CAPEX) → T3.2 (DAG + fixpoint). Gate: convergence test passes; cost/box matches workbook.
- **S5 (full core + oracle):** T3.3 (6 modules) → **T3.4 golden-master** (88.41/13.50/10.12, tol 0.5%). Gate: **golden-master passes — hard gate.**
- **S6 (search + service):** T3.5 (Monte Carlo) → T3.6 (optimization) → T3.7 (sim API + `SimulationCompleted`).
- **Exit gate (P3 DoD):** 8 modules · DAG converges · golden-master passes · 0-error gate · MC reproducible · optimizer runs · API emits event.
- **Demo:** run Year-1 scenario → projected P&L + returns; MC tornado; one optimization frontier.
- **Risks:** R-10 (drift), R-11 (convergence), R-06 (event bus), R-14.

---

## Sprint 7 — MCP Integrations (P4, ~10 pd)

- **Goal:** 8 MCP servers, least-privilege, ACL, access matrix.
- **Tasks:** T4.1 (servers) → T4.2 (ACL) → T4.3 (policy) → T4.4 (smoke).
- **Exit gate (P4 DoD):** 8 connect · scopes/deny-lists enforced · ACL strips directives · matrix denies out-of-scope · calls audited.
- **Demo:** denied write rejected; injection string in a fetched page neutralized; audit entry per call.
- **Risks:** R-12 (injection), R-21 (scopes/secrets), R-08 (Sheets MCP inclusion).

---

## Sprint 8 — n8n Ingestion (P5, ~12 pd)

- **Goal:** 5 ingestion workflows writing to all 3 stores + the `#REF!` gate.
- **Tasks:** T5.1∥T5.2∥T5.3 (intel) → T5.4 (research) → T5.5 (workbook sync) → T5.6 (errors+export).
- **Exit gate (P5 DoD):** 5 workflows e2e · 3-store writes · events emitted · Workbook Sync fails closed on `#REF!` · no dup rows on re-run.
- **Demo:** drop a competitor page → benchmark updates + `CompetitorBenchmarkUpdated`; inject `#REF!` → sync halts.
- **Risks:** R-12, flaky sources (retries/backoff/provenance).

---

## Sprint 9 — Agent Boardroom ★ (P6, ~16 pd)

- **Goal:** 7 executive agents + workers; closed board cycle with binding vetoes + human escalation.
- **Tasks:** T6.1 (agents) → T6.2 (consensus+vetoes) → T6.3 (decision records) → T6.4 (board cycle) → T6.5 (smoke+safety).
- **Exit gate (P6 DoD):** consensus+binding vetoes work · decisions reproducible · cycle e2e · **no agent commits capital** · writes validated.
- **Demo:** one full board cycle on Year-1 → recommendation + dissent; CFO vetoes insolvent plan; capital decision escalates to human.
- **Risks:** R-13 (agent safety), R-12 (injection can't redirect agent), non-determinism (pin scenario/snapshot/seed).

---

## Sprint 10 — Executive Layer + Hardening ★ (P7, ~14 pd)

- **Goal:** dashboard + what-if console; NFRs met; staging deploy.
- **Tasks:** T7.1 (BFF+CQRS) → T7.2 (web) → T7.3 (board-pack) → T7.4 (observability) → T7.5 (scale) → T7.6 (deploy+NFR).
- **Exit gate (P7 DoD):** dashboard+what-if live · board-pack exports · NFR met (run<5s, MC 1k<60s, dash<500ms, impact<1s, repro 100%) · observability · partition+replicas · staging green · security review passed.
- **Demo:** change a round size / tier mix in the console → P&L + returns shift; export a board pack.
- **Risks:** R-20 (NFR under load), R-22 (UI scope creep — ship 4 core dashboards first).

---

## Capacity & milestones

| Milestone | After sprint | Meaning |
|---|---|---|
| **M1 — Ground truth** | S2 | Data layer live; workbook seeded |
| **M2 — The engine runs** ★ | S6 | Golden-master passes; simulation API live (the analytical core) |
| **M3 — Knowledge + automation** | S8 | Graph/vectors + ingestion feeding the platform |
| **M4 — The boardroom** ★ | S9 | Agents debate a scenario end-to-end |
| **M5 — Decision surface** | S10 | Executives steer; NFRs met; staging |

**Two-track compression:** run Track A (S3) during S4–S6 → saves ~2 sprints. P4/P5/P6/P7 stay sequential (dependency-bound).

---

*End of SPRINT_PLAN.md*
