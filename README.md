# Valencia Nutracare Decision Platform (VNDP)

> Workbook → Data Platform → Knowledge Graph → Simulation Engine → Agent Boardroom → Executive Copilot

An AI-native, event-driven decision platform for Valencia Nutracare Lifesciences' 5-year, capital-staged
nutrition-powder launch (₹22 → 60 → 220 Cr; 4 product families × 3 tiers). It lifts a fragile 30-sheet
financial workbook into a reproducible, multi-agent platform.

**Source of truth (meaning):** [`docs/BUSINESS_ONTOLOGY.md`](docs/BUSINESS_ONTOLOGY.md)
**Operating policy:** [`docs/09_CLAUDE_MD.md`](docs/09_CLAUDE_MD.md)
**Execution plan:** [`docs/execution/`](docs/execution/) — backlog · sprints · dependency map · task graph · sequence · risks

## Architecture (5 layers)

| # | Layer | Tech | Doc |
|---|---|---|---|
| 1 | Data (system of record) | PostgreSQL 15 + SQLAlchemy 2.0 + Alembic | `docs/DATABASE_SCHEMA.md` |
| 2 | Knowledge (reasoning) | Neo4j 5 + Qdrant | `docs/KNOWLEDGE_GRAPH.md` |
| 3 | Simulation (engine) | Python pure modules + Monte Carlo + optimization | `docs/05_SIMULATION_ENGINE.md` |
| 4 | Agent (boardroom) | PydanticAI on ruflo/claude-flow | `docs/AGENTS.md` |
| 5 | Executive (copilot) | FastAPI BFF + web | `docs/01_SYSTEM_ARCHITECTURE.md` |

Ingestion: **n8n** (`docs/06_N8N_ARCHITECTURE.md`). External access: **MCP** (`docs/07_MCP_ARCHITECTURE.md`).
Event bus: **Redpanda/Kafka**. LLM/embeddings: **open-source, local-first via Ollama** (see `docs/adr/`).

## Repository layout

```
apps/api_gateway      FastAPI BFF
services/<context>    one FastAPI microservice per bounded context
libs/vndp_*           shared installable packages (domain, db, graph, vectors, sim, agents, mcp, events, shared)
workflows_n8n/        n8n workflow JSON exports + custom nodes
migrations/           alembic (PG) + neo4j + qdrant
infra/docker          docker-compose (PG, Neo4j, Qdrant, n8n, Redpanda)
workbook/             repaired xlsx + verify.py (golden-master source of truth)
docs/                 design set (.md) + adr/ + ddd/ + execution/
tests/                cross-cutting e2e / golden_master / contract
scripts/              ops scripts (use `python`, never `python3`)
```

## Quickstart (local)

> Prereqs: Python 3.12+, `uv`, Node 20+, Docker Desktop (WSL2). Full setup: [`docs/08_INFRASTRUCTURE_SETUP.md`](docs/08_INFRASTRUCTURE_SETUP.md).

```powershell
cp .env.example .env            # fill local values
docker compose -f infra/docker/docker-compose.yml up -d
uv sync                         # resolve the workspace
python workbook/verify.py       # must report 0 errors (golden-master gate)
```

## Golden rule

Every artifact ships with **zero calculation errors** and a reproducibility key `(scenario_id, snapshot_id)`.
Year-1 acceptance oracle: Revenue ≈ ₹88.41 Cr · EBITDA ≈ ₹13.50 Cr · PAT ≈ ₹10.12 Cr (tol 0.5%).

## Contributing

See [`CONTRIBUTING.md`](CONTRIBUTING.md). PRs only (no direct push to `main`); humans merge; docs updated in the same PR.
