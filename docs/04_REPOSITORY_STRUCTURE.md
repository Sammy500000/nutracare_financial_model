# 04 — REPOSITORY STRUCTURE
## Valencia Nutracare Decision Platform (VNDP)

**Authority:** Chief Technical Officer
**Inputs:** 01_SYSTEM_ARCHITECTURE · 02_DOMAIN_MODEL · 03_IMPLEMENTATION_ROADMAP · DATABASE_SCHEMA · KNOWLEDGE_GRAPH · AGENTS · 05_SIMULATION_ENGINE · 06_N8N_ARCHITECTURE · 07_MCP_ARCHITECTURE
**Confirmed stack:** Python 3.11+ · FastAPI · PostgreSQL · Neo4j · Qdrant · n8n · PydanticAI · Docker
**Status:** Repository specification · v1.0 · *no code — structure, conventions, and strategy only*

> **Supersedes** the language-neutral package sketch in 03 §"Repository". The confirmed stack is **Python-first**: services are FastAPI apps, agents are **PydanticAI**, migrations are **Alembic** (not Prisma), packaging is a **uv workspace** monorepo.

---

## 1. Repository Structure (strategy)

**One monorepo, `vndp`**, managed as a **uv workspace** (PEP 621 `pyproject.toml` per package). Rationale: shared domain types (02) and the simulation engine (05) are consumed by many services; a monorepo keeps them version-locked and lets CI test only what changed via path filters.

| Decision | Choice | Why |
|---|---|---|
| Layout | monorepo, uv workspace | shared domain/engine, atomic cross-cutting changes |
| Packaging | one installable package per workspace member | clean imports `import vndp_domain` |
| Service style | FastAPI app per bounded context (01 §4-5) | independent deploy, clear ownership |
| Agents | PydanticAI agents in one package, orchestrated by ruflo | typed, testable agent contracts |
| DB access | SQLAlchemy 2.0 (async) + repositories | clean architecture, testable |
| Migrations | Alembic (PG) + cypher runner (Neo4j) + collection config (Qdrant) | per-store, versioned |
| Containers | one Dockerfile per service + root compose | parity local↔prod |

Top-level layout:
```
vndp/
├─ pyproject.toml              # workspace root: tool config (ruff, mypy, pytest, coverage)
├─ uv.lock
├─ justfile                    # task runner (no logic, just commands)
├─ README.md  CONTRIBUTING.md
├─ .env.example                # non-secret defaults only
├─ .pre-commit-config.yaml
├─ .github/workflows/          # CI/CD (§7)
├─ docs/                       # this design set (.md)
├─ workbook/                   # repaired xlsx + verify.py (golden-master source of truth)
├─ apps/
│  └─ api_gateway/             # FastAPI BFF / GraphQL-or-REST gateway (01 §5)
├─ services/                   # FastAPI microservices, one per bounded context
│  ├─ finance/  pricing/  demand/  manufacturing/  marketing/
│  ├─ financing/ valuation/ intelligence/ simulation/ decision/
├─ libs/                       # shared installable packages (the "packages/" of 03)
│  ├─ vndp_domain/             # PydanticAI/Pydantic models: VOs, entities, aggregates (02)
│  ├─ vndp_db/                 # SQLAlchemy models + Alembic env (DATABASE_SCHEMA)
│  ├─ vndp_graph/              # Neo4j driver + cypher (KNOWLEDGE_GRAPH)
│  ├─ vndp_vectors/            # Qdrant client + collection defs (06)
│  ├─ vndp_sim/                # deterministic core + Monte Carlo + optimization (05)
│  ├─ vndp_agents/             # PydanticAI boardroom + workers (AGENTS)
│  ├─ vndp_mcp/                # MCP server configs/wrappers + ACL (07)
│  ├─ vndp_events/             # event contracts + bus adapter (01 §8)
│  └─ vndp_shared/             # settings, logging, telemetry, errors, types
├─ workflows_n8n/              # n8n workflow JSON exports + custom nodes (06)
├─ migrations/                 # alembic/ (PG)  +  neo4j/  +  qdrant/  runners (§5)
├─ infra/
│  ├─ docker/                  # Dockerfiles + docker-compose.yml + overrides
│  ├─ k8s/                     # manifests + HPA (Phase 7)
│  └─ terraform/               # cloud infra (later)
├─ tests/                      # cross-cutting: e2e/ , golden_master/ , contract/
└─ scripts/                    # one-off ops scripts (use `python`, never `python3`)
```

---

## 2. Folder Structure (inside a service & a lib)

### 2.1 Service (clean architecture, DDD layering) — e.g. `services/finance/`
```
services/finance/
├─ pyproject.toml              # depends on vndp_domain, vndp_db, vndp_events, vndp_shared
├─ Dockerfile
├─ src/finance/
│  ├─ api/                     # FastAPI layer
│  │  ├─ routers/              # endpoints (HTTP only, thin)
│  │  ├─ schemas/              # Pydantic request/response DTOs (suffix Request/Response)
│  │  └─ dependencies.py       # DI: db session, auth, current scenario
│  ├─ application/             # use-cases / orchestration (no framework code)
│  │  └─ services/             # e.g. consolidate_pnl, size_working_capital
│  ├─ domain/                  # aggregates/VOs specific to context (re-exports vndp_domain)
│  ├─ infrastructure/          # adapters
│  │  ├─ repositories/         # SQLAlchemy repos (implements domain ports)
│  │  ├─ graph/                # Neo4j read adapters
│  │  └─ vectors/              # Qdrant adapters
│  ├─ events/                  # publishers + subscribers (vndp_events contracts)
│  ├─ config.py                # pydantic-settings (env-prefixed)
│  └─ main.py                  # FastAPI app factory + lifespan
└─ tests/
   ├─ unit/                    # domain + application, no IO
   └─ integration/             # repos against testcontainers PG/Neo4j/Qdrant
```
**Layering rule:** `api → application → domain ← infrastructure`. Domain depends on nothing; infrastructure implements domain *ports*; the API never touches a repository directly. This keeps the simulation/finance logic testable without a database.

### 2.2 Shared lib — e.g. `libs/vndp_sim/`
```
libs/vndp_sim/
├─ pyproject.toml
├─ src/vndp_sim/
│  ├─ modules/   m_bom.py m_capex.py m_demand.py m_comp.py m_pnl.py m_wc.py m_fund.py m_ret.py
│  ├─ core/      dag.py fixpoint.py run.py          # 05 §3 ordered solve + cycles
│  ├─ montecarlo/ sampler.py runner.py
│  ├─ optimize/  objective.py search.py constraints.py
│  └─ ports.py                                       # data-access protocol (no DB import)
└─ tests/  unit/  golden_master/                     # Year-1 fixtures (Rev 88.41 / EBITDA 13.50 / PAT 10.12)
```

### 2.3 Agents — `libs/vndp_agents/` (PydanticAI)
```
libs/vndp_agents/
├─ src/vndp_agents/
│  ├─ executive/  cfo.py cmo.py coo.py investor.py market.py competitor.py chairman.py
│  ├─ workers/    cost_engineer.py pricing.py demand.py compliance.py validator.py …
│  ├─ tools/      mcp_tools.py        # typed PydanticAI tools wrapping MCP calls (07 §3)
│  ├─ protocol/   consensus.py escalation.py decision_record.py
│  └─ deps.py                          # AgentDeps: scenario, mcp clients, memory
└─ tests/  unit/  (mocked LLM + tools)
```
Each agent is a **PydanticAI `Agent`** with a typed result model (the agent's Output from AGENTS), typed `deps`, and tools whitelisted per the 07 §3 access matrix.

---

## 3. Naming Conventions

| Element | Convention | Example |
|---|---|---|
| Distribution package | `vndp-<name>` (PEP 503) | `vndp-domain` |
| Import package / module | `snake_case`, `vndp_` prefix for libs | `import vndp_sim.core.dag` |
| Class | `PascalCase` | `RevenueProjection`, `MoneyVO` |
| Value object | `PascalCase` + `VO` suffix optional | `Money`, `TierLevel` |
| Pydantic DTO | suffix `Request` / `Response` / `DTO` | `RunScenarioRequest` |
| SQLAlchemy model | `PascalCase`, table = schema-qualified snake plural | `class Sku` → `core.skus` |
| Function / variable | `snake_case` | `consolidate_pnl()` |
| Constant | `UPPER_SNAKE_CASE` | `DEFAULT_TAX_RATE` |
| FastAPI route | plural nouns, kebab in path | `GET /scenarios/{id}/returns` |
| Event (vndp_events) | `PascalCase`, past tense | `IngredientPriceChanged` |
| PostgreSQL | schemas `ref/core/plan/proj/audit`; tables snake plural; FKs `<singular>_id` | `core.bom_lines` |
| Neo4j | labels `PascalCase`, rels `UPPER_SNAKE` | `(:Product)-[:COMPOSED_OF]->` |
| Qdrant collection | `snake_case` singular-domain | `competitor`, `market` |
| n8n workflow | `kebab-case` | `workbook-sync` |
| Docker image | `vndp/<service>:<semver>-<gitsha>` | `vndp/finance:0.3.0-a1b2c3d` |
| Git branch | `feat/ fix/ chore/ docs/` + kebab | `feat/sim-fixpoint` |
| Commits | Conventional Commits | `feat(sim): add fixpoint solver` |
| Test file | `test_*.py`; markers `unit/integration/e2e/golden` | `test_m_pnl.py` |
| Env var | `VNDP_<AREA>_<KEY>` UPPER_SNAKE | `VNDP_DB_URL` |
| Alembic revision | timestamped slug | `2026_..._create_core.py` |

**Linters enforce this:** `ruff` (style + import order), `mypy --strict` (types), `codespell`, and a naming-rule lint in CI.

---

## 4. Environment Structure

**Config = `pydantic-settings`** (`BaseSettings`) per service, prefix `VNDP_`, layered: defaults → `.env.<environment>` → real environment variables → secrets manager. No config logic in code beyond the settings class.

| Environment | Purpose | Stores | Secrets source |
|---|---|---|---|
| `local` | dev laptop | docker-compose PG/Neo4j/Qdrant/n8n | `.env` (gitignored) |
| `test` | CI | ephemeral testcontainers | injected by CI |
| `dev` | shared integration | managed dev instances | vault |
| `staging` | pre-prod, NFR/load | prod-like | vault |
| `prod` | live | HA PG (or CockroachDB), Neo4j, Qdrant | vault / cloud secrets |

```
env layout
├─ .env.example          # committed: every key, dummy non-secret values
├─ .env                  # local only, GITIGNORED
├─ infra/docker/docker-compose.yml
├─ infra/docker/compose.override.<env>.yml
└─ libs/vndp_shared/config.py   # Settings base class (imported by all services)
```

**Secret policy (hard rules):** secrets never in repo, prompts, or logs; `.env*` is gitignored **and** denied by project settings; services receive scoped credentials via env/secret mounts; MCP servers get scoped tokens (07 S4), not raw secrets.

**Required env keys (illustrative names, not values):** `VNDP_DB_URL`, `VNDP_NEO4J_URI/_USER/_PASSWORD`, `VNDP_QDRANT_URL/_API_KEY`, `VNDP_N8N_URL/_API_KEY`, `VNDP_LLM_API_KEY`, `VNDP_EVENT_BUS_URL`, `VNDP_ENV`.

---

## 5. Migration Strategy

Per-store, versioned, forward-only, reviewed. Ordering mirrors DATABASE_SCHEMA dependencies.

### 5.1 PostgreSQL — Alembic (`migrations/alembic/`)
- SQLAlchemy 2.0 models in `libs/vndp_db` are the source; Alembic **autogenerates** diffs.
- **Hand-write** what autogen can't express: `btree_gist` + `EXCLUDE` on `core.ingredient_prices` & `plan.prices`; `CHECK` constraints (tiers 1-3, pct≥0, financing splits = 1, net_price ≤ MRP); RLS policies scoped by `scenario_id`; multi-schema creation (`ref/core/plan/proj/audit`).
- **Order:** `extensions → ref → core → plan → proj → audit` (matches DATABASE_SCHEMA §App A).
- **Process:** PR includes the migration; review the autogen SQL; apply via a CI/deploy job (`alembic upgrade head`); **expand-contract** for backward-compatible rollouts; every migration has a tested `downgrade`.

### 5.2 Neo4j — versioned cypher (`migrations/neo4j/`)
- Schema migrations = idempotent cypher for constraints/indexes (KNOWLEDGE_GRAPH §5), applied by a migration runner that records applied versions in a `:_Migration` node.
- **Data is not migrated** — it is **rebuilt per snapshot** from PostgreSQL by the graph-sync job (Phase 2/5). This keeps the graph a derived projection, never a divergent master.

### 5.3 Qdrant — collection config (`migrations/qdrant/`)
- Collections (`competitor, market, research, financial, decisions`) defined as versioned config; a create-if-absent migration sets vector size + payload schema + indexes.
- **Re-embedding** is a separate, idempotent job (triggered by n8n on source change), not a schema migration.

### 5.4 n8n — workflow versioning (`workflows_n8n/`)
- Workflows exported as JSON and committed; imported per environment via the n8n CLI in deploy; credentials injected from vault (never in the JSON).

### 5.5 Data seed & snapshots
- `scripts/load_workbook.py` seeds reference + verified entities from the repaired workbook; every simulation run is pinned to an immutable `plan.data_snapshots` row for reproducibility.

---

## 6. Testing Structure

```
tests/                        # cross-cutting
├─ e2e/                       # full stack via docker-compose
├─ golden_master/             # engine vs workbook Year-1 (acceptance gate)
├─ contract/                  # FastAPI schema / event-contract tests
└─ conftest.py                # shared fixtures (compose-up, seeded scenario)
<each service|lib>/tests/
├─ unit/                      # fast, no IO (domain, application, sim modules)
└─ integration/               # testcontainers PG/Neo4j/Qdrant
```

| Layer | Tooling | Gate |
|---|---|---|
| Unit | `pytest`, `pytest-asyncio`, `hypothesis` (property tests for VOs & engine) | fast, runs on every PR |
| Integration | `testcontainers-python` (PG, Neo4j, Qdrant), `httpx` for FastAPI | runs on PR |
| **Golden-master** | engine vs workbook Year-1 (Rev 88.41 / EBITDA 13.50 / PAT 10.12, tol 0.5%) | **must pass to merge sim changes** |
| Contract | `pydantic` schema snapshots, event-shape tests | API/event changes |
| Security | RLS isolation, ACL injection (07 S6), denied-write, no-capital-move | PR for affected areas |
| NFR/load | latency + Monte Carlo throughput (locust/pytest-bench) | staging gate |

**Conventions:** markers (`@pytest.mark.unit|integration|e2e|golden`); coverage gate (e.g., ≥85% on `domain`/`sim`); deterministic seeds; fixtures via factory helpers; no network in unit tests (enforced).

---

## 7. CI/CD Structure

**GitHub Actions**, path-filtered, uv-cached. Pipelines:

```
.github/workflows/
├─ ci.yml            # PR: lint → typecheck → unit → integration → golden-master → security
├─ build.yml         # main: build + push Docker images (per changed service)
├─ deploy.yml        # tag/env: alembic upgrade → deploy → smoke → NFR (staging)
└─ scheduled.yml     # nightly: full e2e + dependency/security audit
```

| Stage | Tools | Fails build on |
|---|---|---|
| Pre-commit (local) | ruff, mypy, codespell, secrets scan (gitleaks) | style/type/secret |
| Lint & types | `ruff`, `mypy --strict` | any error |
| Unit | pytest (markers: unit) | failure / coverage < gate |
| Integration | testcontainers | failure |
| **Golden-master** | sim vs workbook | mismatch > tolerance |
| Security | `bandit`, `pip-audit`, `trivy` (image), RLS/ACL tests | high severity |
| Build | Docker buildx, SBOM (syft) | build error |
| Deploy | Alembic job → k8s/compose → smoke | migration or smoke failure |

**Flow:** PR → `ci.yml` (must be green, human review via GitHub MCP, no auto-merge) → merge to `main` → `build.yml` pushes images → `deploy.yml` to **staging** (runs migrations, smoke, NFR) → **manual approval** → promote to **prod** (expand-contract migration, canary). Path filters ensure only changed services rebuild/test. Observability (OpenTelemetry) wired at deploy; releases tagged semver.

**Guardrails baked into CI:** zero-error gate (workbook verify + golden-master), secret scanning, no force-push / no direct push to `main` (branch protection), migration `downgrade` presence check.

---

## 8. Mapping — repo ↔ platform

| Repo location | Bounded context (01) | Domain (02) | Other docs |
|---|---|---|---|
| `services/finance` | Finance & P&L | RevenueProjection, ExpensePlan, WorkingCapital | 05 M-PNL/M-WC |
| `services/pricing` | Pricing | ProductCatalog price | 05 (price inputs) |
| `services/demand` | Demand & Market | Market | 05 M-DEMAND, 06 Market |
| `services/manufacturing` | Manufacturing & Capacity | Capex, Strategy | 05 M-CAPEX |
| `services/marketing` | Marketing & Compliance | ExpensePlan, HCPEngagement | 06 |
| `services/financing` | Capital & Financing | FundingRound | 05 M-FUND |
| `services/valuation` | Valuation & Returns | Valuation | 05 M-RET |
| `services/intelligence` | Competitive Intelligence | Competitor | 05 M-COMP, 06 Competitor |
| `services/simulation` | Scenario & Simulation | Scenario | 05 (engine API) |
| `services/decision` | Decision & Governance | (cross-cutting) | AGENTS |
| `libs/vndp_db` | — | all aggregates ↔ tables | DATABASE_SCHEMA |
| `libs/vndp_graph` | — | — | KNOWLEDGE_GRAPH |
| `libs/vndp_vectors` | — | — | 06 (Qdrant) |
| `libs/vndp_agents` | — | — | AGENTS (PydanticAI) |
| `libs/vndp_mcp` | — | — | 07 |
| `workflows_n8n` | — | — | 06 |

---

*End of 04_REPOSITORY_STRUCTURE.md — the repository specification for the Valencia Nutracare Decision Platform, governed by BUSINESS_ONTOLOGY.md.*
