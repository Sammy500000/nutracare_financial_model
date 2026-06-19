# RISK_REGISTER — Valencia Nutracare Decision Platform (VNDP)

**Authority:** CTO
**Status:** Execution planning · v1.0 · 2026-06-19
**Companion to:** EXECUTION_BACKLOG · DEPENDENCY_MAP
**Purpose:** Live register of risks, blockers, and open decisions for the build. Severity × Likelihood drives attention. **BLOCKER** rows gate execution and require resolution/approval before the dependent phase starts.

> Status legend: ❌ open · ⏳ in progress · ✅ resolved · ⚠ monitor.

---

## 1. Blockers (gate execution NOW)

| ID | Blocker | Evidence | Phase blocked | Options | Recommendation | Status |
|---|---|---|---|---|---|---|
| **R-01** | **Not a git repository.** "Commit progress", PR flow, branch protection, CI all require a repo + remote. | Env: *Is a git repository: false* | P0 (T0.1) → all | (a) `git init` in place + new GitHub repo `vndp`; (b) clone existing remote; (c) keep docs-only, defer code | **(a)** — init in place, create private `vndp` remote, protect `main`. Needs the user to create/authorize the GitHub repo + PAT. | ❌ |
| **R-02** | **In-place monorepo scaffold is structurally significant.** 08 §10 turns *this* folder into the `vndp` root and moves the 14 docs into `docs/`. ~30 new dirs beside the user's workbook. | 04 §1, 08 §10 | P0 (T0.2, T0.4) | (a) scaffold in place, move docs; (b) scaffold a `vndp/` subfolder; (c) new sibling repo dir | **(a)** per 08 §10, but **confirm first** — it relocates the user's existing docs and reshapes their folder. | ❌ (await approval) |
| **R-03** | **ORM conflict: Prisma vs SQLAlchemy/Alembic.** 03 §Phase 1 + 01 §10 say Prisma; 04 (explicitly *supersedes* 03's sketch), 09 (binding policy), 08 (infra) say SQLAlchemy 2.0 + Alembic. | 04 §0 "migrations are Alembic (not Prisma)"; 09 §4 | P1 | follow 04/09 (Alembic) vs 03/01 (Prisma) | **SQLAlchemy 2.0 + Alembic** — 04 explicitly supersedes; 09 is binding; directive's own Phase 1 says "SQLAlchemy/Alembic". | ✅ resolved (Alembic) |

---

## 2. Open decisions (needed before the dependent phase)

| ID | Decision | Needed by | Default if unanswered | Status |
|---|---|---|---|---|
| **R-05** | Embedding model + `VNDP_LLM_API_KEY` provider | P2 (T2.5), P5, P6 | small local model, swappable (03 §P2 risk); provider key from vault | ❌ |
| **R-06** | Event-bus technology (Kafka/Redpanda/NATS/in-proc) | P3 (T3.7 emits events), P5, P6 | NATS for local (lighter footprint, 01 §8.2); in-proc bus until P5 | ❌ |
| **R-07** | Optimization solver (LP/MILP vs Bayesian/GA) | P3 (T3.6) | grid + Bayesian to start, pluggable (05 §5) | ⚠ deferrable |
| **R-08** | Google Sheets MCP inclusion (8th MCP) | P4 | defer; use xlsx read (08 sets up 7 MCPs, no Sheets) | ⚠ deferrable |
| **R-09** | Docker Desktop / WSL2 actually installed & running | P0 (T0.7), all integration tests | verify via 08 §11 checklist before integration work | ⚠ verify |

---

## 3. Technical / delivery risks (from 03 + this review)

| ID | Risk | Phase | Severity | Likelihood | Mitigation |
|---|---|---|---|---|---|
| **R-10** | Simulation correctness drift | P3 | High | Med | golden-master gate (88.41/13.50/10.12, tol 0.5%) + module-by-module diff vs workbook cells |
| **R-11** | Fixpoint non-convergence (revenue⇄opex, PBT⇄interest) | P3 | High | Med | cap iterations, **fail closed**, log Δ trace; deterministic seed |
| **R-12** | Prompt injection via external data (web/sheets/research) | P4,5,6 | High | Med | ACL sanitize (S6) + S1 instruction boundary, tested with injection fixtures |
| **R-13** | Agent unsafe/irreversible action (moves capital, signs) | P6 | High | Low | human-in-loop guardrail (P5), validator truth-score gate, decision-rights enforcement; no-capital-move test |
| **R-14** | Mock-data over-fitting (only Year-1 trustworthy; Y2–5 `#REF!` in source) | P1,P3,P6 | Med | High | seed Year-1 + reference only; assert on **relationships/flow**, not absolute Y2–5 values (ontology §8) |
| **R-15** | Graph/store drift vs PostgreSQL | P2,P5 | Med | Med | rebuild-per-snapshot, idempotent sync (run-twice identical) |
| **R-16** | Prisma multiSchema / EXCLUDE gaps (moot under R-03) | P1 | Low | — | superseded — Alembic + hand-written SQL for EXCLUDE/CHECK/RLS |
| **R-17** | `python3` Store stub vs `python` | all | Low | High | pin `python`; disable Store aliases (08 §3.4); CI check. **Already biting:** a project PostToolUse hook (`check-sql-files.py`) is wired to `python3` + a missing path and errors on every Write — fix the hook config (R-18). |
| **R-18** | Misconfigured project hook fires on every Write (`python3 .../check-sql-files.py` → file not found) | all (noise, non-blocking) | Low | High | repoint hook to `python` and a valid script path, or remove it from settings; non-blocking (writes succeed) |
| **R-19** | Windows path issues in Docker volumes | P0 | Low | Med | named volumes (08 compose); avoid host bind mounts |
| **R-20** | NFR misses under load (run<5s, MC 1k<60s, dash<500ms) | P7 | Med | Med | CQRS read models + `proj.*` partitioning + embarrassingly-parallel MC; profile early |
| **R-21** | Over-broad MCP scopes / secrets leakage | P4 | Med | Low | least-privilege defaults, scoped tokens in vault, `.env*` denied, every call audited |
| **R-22** | Scope creep on Executive UI | P7 | Med | Med | ship control panel + 4 core dashboards first; defer extras |
| **R-23** | Seed mapping ambiguity (workbook sheets → 24 tables) | P1 | Med | Med | map verified Year-1 + ref data first; flag the rest; provenance on every value |

---

## 4. Governance / compliance risks

| ID | Risk | Mitigation |
|---|---|---|
| **R-30** | IMS Act violation (Tier-1 infant-formula consumer ads) | encode as enforced rule in Marketing/Compliance; block via `ComplianceVerdictIssued`; compliance test = 0 violations |
| **R-31** | Non-reproducible results | every output keyed `(scenario_id, snapshot_id)`; immutable snapshots; reproducibility test (same seed → identical) |
| **R-32** | Unaudited state change | `audit.change_log` + event-sourced assumptions/decisions; every mutation logged (actor, args, result hash) |
| **R-33** | Secrets in repo/prompt/log | gitleaks in CI; `.env*` gitignored + denied; vault-managed scoped tokens |

---

## 5. Top-5 watchlist (review each sprint)

1. **R-01 / R-02** — repo + scaffold approval (gating P0).
2. **R-10 / R-11** — simulation correctness + convergence (the long pole).
3. **R-12 / R-13** — injection + agent safety (the security surface).
4. **R-06 / R-05** — event bus + LLM/embedding decisions (gate P3/P5/P6).
5. **R-14** — mock-data discipline (validate flow, not Y2–5 numbers).

---

*End of RISK_REGISTER.md — reviewed at each sprint boundary; BLOCKER rows gate execution.*
