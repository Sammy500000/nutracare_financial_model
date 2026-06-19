# 06 — N8N WORKFLOW ARCHITECTURE
## Valencia Nutracare Decision Platform (VNDP)

**Authority:** Chief Enterprise Architect
**Source of truth:** [BUSINESS_ONTOLOGY.md](BUSINESS_ONTOLOGY.md)
**Aligns with:** [01_SYSTEM_ARCHITECTURE.md](01_SYSTEM_ARCHITECTURE.md) (events §8) · [07_MCP_ARCHITECTURE.md](07_MCP_ARCHITECTURE.md) (n8n MCP §2.8) · [DATABASE_SCHEMA.md](DATABASE_SCHEMA.md) · [KNOWLEDGE_GRAPH.md](KNOWLEDGE_GRAPH.md)
**Status:** Automation/ingestion spec · v1.0

---

## 1. Role of n8n in the platform

n8n is the **ingestion & integration tier** — the scheduled/triggered pipelines that keep the platform's three stores fresh and feed the agents. It sits *below* the Agent and Simulation layers: it gathers and normalizes facts, embeds them, links them, and emits domain events that wake the rest of the platform.

```
   EXTERNAL WORLD                 n8n WORKFLOWS                    PLATFORM STORES
   web · feeds · docs ──►  [trigger → fetch → extract →     ──►  PostgreSQL (facts)
   workbook · APIs          normalize → validate → embed →       Qdrant (vectors)
                            link → load → emit event]            Neo4j (graph)
                                                                       │
                                                                 domain events ──► agents / simulation
```

### Shared storage targets (used by every workflow)
| Store | Holds | Written via |
|---|---|---|
| **PostgreSQL** | structured facts & projections (the system of record — `ref/core/plan/proj`) | n8n Postgres node (parameterized, scoped role) |
| **Qdrant** | vector embeddings for semantic recall (collections: `competitor`, `market`, `research`, `financial`, `decisions`) | n8n HTTP node → Qdrant REST (upsert) |
| **Neo4j** | relationship graph (entities + edges, KNOWLEDGE_GRAPH) | n8n HTTP/Neo4j node (parameterized Cypher MERGE) |

### Cross-cutting conventions
- **Untrusted-source ACL (07 S1/S6):** all externally fetched content is treated as *data*; an "ACL / sanitize" Code node strips embedded instructions before any LLM-extraction step.
- **Idempotency:** every load uses upsert/`MERGE` keyed on a natural id → re-runs don't duplicate.
- **Validation gate:** a Code node validates schema/range before any write (the systemic cure for the `#REF!`-class defect).
- **Provenance:** every record stores `source`, `fetchedAt`, `confidence`; embeddings carry the same metadata.
- **Events:** each workflow ends by emitting a domain event (01 §8) so agents/simulation react.
- **Error path:** an `Error Trigger` workflow logs to `audit.change_log` and alerts; no partial commits.

---

## 2. Workflow 1 — Competitor Monitoring

| Facet | Design |
|---|---|
| **Triggers** | `Schedule Trigger` (daily 06:00) · `Webhook` (on-demand from Competitor agent / n8n MCP) |
| **Nodes** | Schedule/Webhook → HTTP Request (competitor sites, marketplaces, public filings) → **Code: ACL sanitize** → AI/LLM Extract (margins, pricing, launches, spend ratios) → Set (normalize to `metricKey`/`valuePct`) → **Code: validate** → IF (changed vs last?) → [Postgres upsert] + [Embeddings → Qdrant upsert] + [Neo4j MERGE] → Emit `CompetitorBenchmarkUpdated` |
| **Data Flow** | raw HTML/JSON → sanitized text → structured competitor metrics → embeddings + graph edges; change-detection branch raises alerts |
| **Outputs** | refreshed competitor benchmarks; **alerts** on material moves (e.g., peer price cut); plausibility inputs for M-COMP (05) |
| **Storage Targets** | **PostgreSQL** `core.competitors` / `core.competitor_metrics` · **Qdrant** `competitor` collection (doc/snippet embeddings) · **Neo4j** `(:Competitor)-[:BENCHMARKS]->(:ProductFamily)` |

```
Schedule/Webhook → HTTP fetch → ACL → LLM extract → normalize → validate → IF changed
   ├─► Postgres: competitor_metrics (upsert)
   ├─► Qdrant: competitor collection (upsert embeddings)
   └─► Neo4j: BENCHMARKS edges (MERGE)  → emit CompetitorBenchmarkUpdated
```

---

## 3. Workflow 2 — Market Intelligence

| Facet | Design |
|---|---|
| **Triggers** | `Schedule Trigger` (weekly) · `Webhook` (Market agent / pre-board-cycle refresh) |
| **Nodes** | Trigger → HTTP Request (market reports, category news, demographic/penetration sources) → **ACL sanitize** → LLM Extract (TAM/SAM signals, category growth, tier demand cues) → Set (map to family×tier×year) → **validate** → Merge with prior SAM → [Postgres upsert] + [Qdrant upsert] + [Neo4j MERGE] → Emit `SamShareUpdated` |
| **Data Flow** | reports/news → sanitized → market signals → SAM-share updates + demand cues; feeds the M-DEMAND TAM→SAM→SOM front-end (05) |
| **Outputs** | updated SAM shares & demand signals; tier-attractiveness inputs for DP-2 (tier sequencing) |
| **Storage Targets** | **PostgreSQL** `core.markets` · **Qdrant** `market` collection · **Neo4j** `(:Market)-[:HAS_SAM]->(:ProductFamily)` |

```
Trigger → HTTP fetch → ACL → LLM extract → map family×tier×year → validate
   ├─► Postgres: core.markets (upsert SAM)
   ├─► Qdrant: market collection
   └─► Neo4j: HAS_SAM edges → emit SamShareUpdated → wakes M-DEMAND
```

---

## 4. Workflow 3 — Financial Intelligence

| Facet | Design |
|---|---|
| **Triggers** | `Schedule Trigger` (daily) · `Webhook` (commodity-price feed / regulatory bulletin) |
| **Nodes** | Trigger → HTTP Request (commodity/ingredient rates, GST & FSSAI/IMS updates, interest-rate references) → **ACL sanitize** → LLM/Parse Extract (rate, effective date, rule change) → Set → **validate (temporal no-overlap)** → [Postgres upsert ingredient_prices / assumptions] + [Qdrant upsert regulatory docs] + [Neo4j refresh] → Emit `IngredientPriceChanged` / `AssumptionUpdated` |
| **Data Flow** | rate feeds & bulletins → sanitized → effective-dated rates / rule deltas → updates that **trigger downstream recompute** (the deliberate event cascade, opposite of `#REF!`) |
| **Outputs** | updated ingredient rates, tax/WACC/regulatory assumptions; **recompute trigger** for the simulation engine; compliance-rule updates for the Marketing&Compliance context |
| **Storage Targets** | **PostgreSQL** `core.ingredient_prices` / `plan.assumptions` · **Qdrant** `financial` collection (regulatory/source docs) · **Neo4j** `(:Commodity)-[:DRIVES]->(:Cost)` refresh |

```
Trigger → HTTP fetch → ACL → parse → validate temporal
   ├─► Postgres: ingredient_prices / assumptions (effective-dated upsert)
   ├─► Qdrant: financial collection
   └─► Neo4j: Commodity→Cost refresh → emit IngredientPriceChanged → M-BOM recompute
```

---

## 5. Workflow 4 — Research Ingestion

| Facet | Design |
|---|---|
| **Triggers** | `Webhook` (drop a URL/PDF) · `Local File Trigger` (watch `/research` folder) · manual |
| **Nodes** | Trigger → Read/Download (PDF/HTML) → Extract Text → **ACL sanitize** → Split/Chunk (token-aware) → Embeddings → Set (metadata: type, source, entities) → LLM Classify & entity-link → [Qdrant upsert chunks] + [Postgres doc metadata] + [Neo4j MERGE doc↔entity] → Emit `ResearchIngested` |
| **Data Flow** | document → text → sanitized → chunks → embeddings + classification → entity links into the graph (so research is discoverable by the entities it mentions) |
| **Outputs** | searchable research corpus for agent RAG; entity-linked evidence backing assumptions/decisions |
| **Storage Targets** | **Qdrant** `research` collection (chunk embeddings) · **PostgreSQL** document/source registry · **Neo4j** `(:Document)-[:MENTIONS]->(:Entity)` |

```
Webhook/Folder → extract text → ACL → chunk → embed → classify/link
   ├─► Qdrant: research collection (chunks)
   ├─► Postgres: doc registry (metadata + provenance)
   └─► Neo4j: Document-[:MENTIONS]->Entity → emit ResearchIngested
```

---

## 6. Workflow 5 — Workbook Synchronization

> The loop-closer between the live workbook (Google Sheets / xlsx) and the platform. Carries the **`#REF!`-prevention validation gate** as its core step.

| Facet | Design |
|---|---|
| **Triggers** | `Schedule Trigger` (hourly) · `Webhook` (Google Sheets change notification) · manual after edits |
| **Nodes** | Trigger → Read workbook (Google Sheets MCP / xlsx read) → **Code: validate** (schema, ranges, **scan for `#REF!`/`#VALUE!`/`#DIV-0!`**, units) → IF (errors? → alert + halt, no commit) → Diff vs PostgreSQL → upsert changed entities → Rebuild affected Neo4j subgraph → Re-embed changed records to Qdrant → Snapshot → Emit `SnapshotCreated` / `WorkbookSynced` |
| **Data Flow** | workbook cells → **validated** (fail-closed on errors) → diffed → relational upserts → graph rebuild → re-embed → immutable snapshot for reproducible simulation |
| **Outputs** | synced system of record; rebuilt knowledge graph; refreshed embeddings; **validation report**; a new `(snapshot)` the Simulation engine can run against |
| **Storage Targets** | **PostgreSQL** all `core`/`plan` entities (system of record) · **Neo4j** full graph rebuild (scenario-scoped) · **Qdrant** re-embed changed records |

```
Trigger → read workbook → VALIDATE (error-scan, fail closed) → IF clean
   ├─► Postgres: upsert changed entities (core/plan)
   ├─► Neo4j: rebuild affected subgraph
   ├─► Qdrant: re-embed changed records
   └─► Snapshot → emit SnapshotCreated → simulation can run reproducibly
   (IF errors → alert + audit, NO write — the #REF! gate)
```

---

## 7. Orchestration & cross-workflow flow

```
   Chairman/agent ──(n8n MCP trigger)──► [Competitor] [Market] [Financial] run in parallel
                                              │ events: BenchmarkUpdated, SamShareUpdated, PriceChanged
                                              ▼
                          Simulation engine (05) recomputes on those events
   Analyst drops doc ──► [Research Ingestion] ──► corpus for agent RAG
   Workbook edited ──► [Workbook Sync] ──► validated snapshot ──► reproducible run
                                              │
                                    all events ──► Agent Debate Layer (next board cycle)
```

- **Parallelism:** the three intelligence workflows are independent → run concurrently (n8n queue mode).
- **Event-driven recompute:** `IngredientPriceChanged`/`SamShareUpdated` wake the simulation engine deliberately (01 §8) — the controlled inverse of the spreadsheet cascade.
- **n8n MCP boundary (07 §2.8):** agents may only *trigger* this allow-list of workflows and read status; they cannot edit workflow definitions (those are versioned via GitHub).

---

## 8. Reliability, security & governance

| Concern | Approach |
|---|---|
| **Untrusted content** | ACL sanitize node before any LLM/extraction (07 S1/S6); fetched directives never executed |
| **Idempotency** | upsert / `MERGE` on natural keys; safe re-runs |
| **Validation** | per-workflow gate; Workbook Sync fails closed on any formula error |
| **Secrets** | n8n credential store (scoped, least-privilege per source); never in node parameters or logs (07 S4) |
| **Provenance & audit** | `source`/`fetchedAt`/`confidence` on every record; runs logged to `audit.change_log` (07 S5) |
| **Error handling** | `Error Trigger` workflow → alert + audit; no partial commits |
| **Backpressure** | queue mode + `Split In Batches` for large fetches; rate-limit external HTTP |

---

## 9. Mapping — workflow → stores → consumers

| Workflow | PostgreSQL | Qdrant | Neo4j | Wakes (consumer) |
|---|---|---|---|---|
| Competitor Monitoring | `core.competitors/_metrics` | `competitor` | `:Competitor-[:BENCHMARKS]` | M-COMP, Competitor agent |
| Market Intelligence | `core.markets` | `market` | `:Market-[:HAS_SAM]` | M-DEMAND, Market agent |
| Financial Intelligence | `core.ingredient_prices`,`plan.assumptions` | `financial` | `:Commodity-[:DRIVES]->:Cost` | M-BOM/M-PNL, CFO agent |
| Research Ingestion | doc registry | `research` | `:Document-[:MENTIONS]->:Entity` | agent RAG (all) |
| Workbook Synchronization | all `core`/`plan` | re-embed changed | full graph rebuild | Simulation engine |

---

*End of 06_N8N_ARCHITECTURE.md — the ingestion & automation tier for the Valencia Nutracare Decision Platform, governed by BUSINESS_ONTOLOGY.md.*
