# 01 — SYSTEM ARCHITECTURE
## Valencia Nutracare Decision Platform (VNDP)

**Authority:** Chief Enterprise Architect
**Source of truth:** [BUSINESS_ONTOLOGY.md](BUSINESS_ONTOLOGY.md)
**Detailed designs:** [ARCHITECTURE.md](ARCHITECTURE.md) · [DATABASE_SCHEMA.md](DATABASE_SCHEMA.md) · [KNOWLEDGE_GRAPH.md](KNOWLEDGE_GRAPH.md) · [AGENTS.md](AGENTS.md)
**Status:** Canonical platform blueprint · v1.0

---

## 1. Executive Summary

### 1.1 Context
Valencia Nutracare Lifesciences (VNL) plans a 5-year, capital-staged launch of maternal/infant/child nutrition powders — four product families across three market tiers, scaling **₹22 Cr → ₹60 Cr → ₹220 Cr** from contract manufacturing to nine owned plants. Today the entire plan lives in **one 30-sheet spreadsheet** that conflates data, domain knowledge, calculation, scenario analysis, and presentation. That conflation is structurally fragile: two defects (a deleted sheet reference and dead external price links) cascaded into ~2,000 `#REF!` errors and rendered Years 2–5 and every return metric non-functional until repaired.

### 1.2 Vision
Transform the workbook into the **Valencia Nutracare Decision Platform (VNDP)** — an AI-native, event-driven, domain-partitioned system where:
- **facts** are validated and versioned,
- **knowledge** (relationships, rules) is explicit and queryable,
- **agents** reason and recommend as a virtual boardroom,
- **simulations** explore the future reproducibly, and
- **executives** steer with live, traceable insight.

### 1.3 Architectural principles
| # | Principle | Consequence |
|---|---|---|
| P1 | **Separate the five concerns** (data, knowledge, reasoning, simulation, decision) | one defect is contained to one layer, not global |
| P2 | **Domain-Driven Design** — model the business, not the spreadsheet | bounded contexts with explicit ownership |
| P3 | **Event-driven recompute** | changes propagate deliberately (the inverse of the `#REF!` cascade) |
| P4 | **Reproducibility by construction** | every result is keyed to `(scenario, snapshot)` |
| P5 | **Human-in-the-loop for irreversible acts** | agents model & recommend; humans commit capital |
| P6 | **Relationships over values** | with mock data, the platform is validated on flow fidelity, not numbers |
| P7 | **Polyglot persistence** | relational for record, graph for reasoning, vector for memory |

### 1.4 Mock-data stance
Per stakeholder direction, current data is illustrative. The platform's correctness criterion is **relationship fidelity and zero-error flow**, not absolute values — every section below is designed so values can be swapped without breaking structure.

---

## 2. Business Capabilities

A capability map (what the business *does*, independent of org or technology), derived from the ontology's 11 business / 8 decision / 8 forecasting processes (§3–5).

```
┌── STRATEGIC CAPABILITIES ───────────────────────────────────────────┐
│  Decision Governance · Capital & Funding Strategy · Scenario Planning │
├── CORE (DIFFERENTIATING) CAPABILITIES ──────────────────────────────┤
│  Demand & Market Intelligence · Financial Modeling & Simulation       │
│  Pricing Strategy · Valuation & Returns                               │
├── OPERATIONAL CAPABILITIES ─────────────────────────────────────────┤
│  Product Formulation & Costing · Manufacturing & Capacity Planning    │
│  Marketing & Channel Management · Working-Capital Management           │
├── SUPPORTING CAPABILITIES ──────────────────────────────────────────┤
│  Competitive Intelligence · Regulatory Compliance · Master Data Mgmt  │
└─────────────────────────────────────────────────────────────────────┘
```

| Capability | Maps to ontology | Primary owner (agent/service) |
|---|---|---|
| Product Formulation & Costing | BP-1, BP-2 (BOM, procurement) | Product & Recipe svc / COO |
| Demand & Market Intelligence | BP-6, FP-1 (SAM, volume) | Demand svc / Market agent |
| Pricing Strategy | DP-7 | Pricing svc / CMO+CFO |
| Manufacturing & Capacity Planning | BP-3,4,5,10; DP-3,4 | Manufacturing svc / COO |
| Marketing & Channel Management | BP-7, BP-8; DP-8 | Marketing svc / CMO |
| Regulatory Compliance | IMS Act, FSSAI, GST rules | Compliance svc / Compliance agent |
| Working-Capital Management | BP-9, FP-5 | Finance svc / CFO |
| Financial Modeling & Simulation | FP-1…8 | Simulation svc |
| Capital & Funding Strategy | DP-1,5,6 | Financing svc / CFO+Investor |
| Valuation & Returns | FP-8 | Valuation svc / Investor |
| Competitive Intelligence | §2.4 | Intelligence svc / Competitor agent |
| Scenario Planning & Decision Governance | DP-2; orchestration | Scenario + Decision svc / Chairman |

---

## 3. Core Domains (DDD classification)

Classifying domains by strategic value guides where to invest custom engineering vs. buy/standardize.

| Class | Domain | Why | Investment |
|---|---|---|---|
| **CORE** | **Financial Modeling & Simulation** | the engine that turns assumptions into P&L/returns; VNL's analytical edge | build, custom |
| **CORE** | **Demand & Market Intelligence** | the TAM→SAM→SOM logic the workbook *lacks* (§8.2); biggest value gap | build, custom |
| **CORE** | **Decision Orchestration** (boardroom) | multi-agent reasoning & consensus; the platform's USP | build, custom |
| **SUPPORTING** | Product / BOM / Costing | necessary, well-understood | build, standard patterns |
| **SUPPORTING** | Manufacturing & Capacity | domain-specific but mechanical | build |
| **SUPPORTING** | Marketing, Channel & Compliance | rule-bound (IMS Act) | build |
| **SUPPORTING** | Capital, Financing & Valuation | standard corporate finance | build on standard formulas |
| **GENERIC** | Master/Reference Data | tiers, families, calendar | configure |
| **GENERIC** | Identity & Access, Notification, Document Generation | commodity | buy/integrate |

---

## 4. Bounded Contexts

Each context has its own ubiquitous language, owns its data, and integrates via explicit contracts. Contexts align 1:1 with the relational schemas (`ref`/`core`/`plan`/`proj`) and the services in §5.

| Bounded Context | Ubiquitous language | Owns (entities §2) | Source sheets |
|---|---|---|---|
| **Product & Recipe** | SKU, family, variant, BOM, ingredient, cost/box | Product, Ingredient, BOM | BOM sheets, Product Line |
| **Pricing** | MRP, net price, tier price, margin/box | Product price | In-house/Total Production |
| **Demand & Market** | TAM, SAM, SOM, tier mix, BPH | Market | In-house SAM, Revenue Breakup |
| **Manufacturing & Capacity** | plant, mode, capacity %, make-vs-buy | Plant/Inventory, capacity | In-house, Third Party, Contract |
| **Marketing & Compliance** | spend %, HCP detailing, IMS Act, channel | Expense (mktg/HCP), Doctor, Hospital | Indirect Expenses, IE Bifurcation |
| **Finance & P&L** | revenue, COGS, EBITDA, PAT, WC | Revenue, Expense, Inventory | P&L, WC sheets |
| **Capital & Financing** | round, equity/debt mix, debt, FD | Funding Round | Project Financing, Debt Schedule |
| **Valuation & Returns** | NPV, IRR, ROCE, EVA, WACC, payback | Valuation | NPV/ROCE/IRR sheets |
| **Competitive Intelligence** | benchmark, peer margin, plausibility | Competitor | Competitor Brands |
| **Scenario & Simulation** | scenario, assumption, snapshot, run | Scenario | Strategy, all (as engine) |
| **Decision & Governance** | proposal, consensus, veto, escalation | (cross-cutting) | — |
| **Reference/Master Data** | tier, family, fiscal year | reference dims | Index, Strategy |

### 4.1 Context Map (relationships)

```
        Reference/MasterData  ──(shared kernel)──►  ALL contexts
                  │
   Product&Recipe ─►(supplier)─► Pricing ─►(supplier)─┐
        │ cost/box                                    │ price
        ▼                                             ▼
   Manufacturing&Capacity ─► volume ─► Finance&P&L ◄── Demand&Market (SAM)
                                  ▲          │
   Marketing&Compliance ─spend──►─┘          ▼ EBITDA/PAT
   (ACL: regulatory rules)            Capital&Financing ─► Valuation&Returns
   CompetitiveIntelligence ─(conformist, advisory)─► Pricing, Finance
        │
   Scenario&Simulation ──(orchestrates, published language: scenario+snapshot)──► ALL
   Decision&Governance ──(customer of all; published decisions)──► Executive
```

- **Shared Kernel:** Reference/Master Data (tiers, families, calendar) — shared by all.
- **Customer–Supplier:** Product→Pricing→Finance→Valuation (downstream consumes upstream).
- **Anti-Corruption Layer:** Marketing&Compliance wraps external regulatory rules; Competitive Intelligence wraps untrusted external web data.
- **Published Language:** Scenario&Simulation exposes the `(scenario, snapshot)` contract every context conforms to.

---

## 5. Service Architecture

Microservices, one per bounded context, each owning its data store slice. Synchronous for queries (GraphQL/REST via gateway), asynchronous for state changes (events §8).

```
                       ┌───────────────────────┐
        Executive UI ─►│   API Gateway / BFF   │◄─ Agents (boardroom)
                       └───────────┬───────────┘
   ┌──────────┬──────────┬─────────┼─────────┬──────────┬──────────┐
   ▼          ▼          ▼         ▼         ▼          ▼          ▼
 Product/   Pricing   Demand/   Mfg/      Marketing/  Finance    Capital/
 Recipe     svc       Market    Capacity  Compliance  svc        Financing
 svc                  svc       svc       svc                    svc
   │          │          │         │         │          │          │
   └──────────┴──────────┴────┬────┴─────────┴──────────┴──────────┘
                              ▼            ▼            ▼
                        Valuation     Simulation    Decision/
                        svc           svc           Governance svc
                              │            │            │
                     ┌────────┴────────────┴────────────┴────────┐
                     │  Event Bus (domain events §8)             │
                     └────────────────────────────────────────────┘
   Cross-cutting: Identity & Access · Reference/MasterData · Notification · Document-Gen
```

| Service | Responsibility | Owns data | Exposes |
|---|---|---|---|
| **Product/Recipe** | SKUs, BOMs, ingredient rates, cost/box | `core.skus/boms/bom_lines/ingredients` | cost/box, recipe queries |
| **Pricing** | MRP, net price, tier pricing | `plan.prices` | price by SKU/tier |
| **Demand/Market** | TAM→SAM→SOM, demand forecast | `core.markets` | volume forecasts, SAM |
| **Manufacturing/Capacity** | plants, capacity, make-vs-buy, capex | `core.plants`, `plan.capex_plan` | producible volume, capex |
| **Marketing/Compliance** | spend allocation, HCP, rule enforcement | `plan.expense_assumptions`, `core.channels` | opex plan, compliance verdicts |
| **Finance/P&L** | consolidate revenue/expense, WC | `proj.pnl_lines`, `proj.working_capital` | P&L, EBITDA, runway |
| **Capital/Financing** | rounds, equity/debt mix, debt | `core.funding_rounds`, `plan.financing_plan`, `proj.debt_schedule` | capital structure |
| **Valuation/Returns** | NPV/IRR/ROCE/EVA | `proj.returns` | return metrics |
| **Competitive Intelligence** | benchmarks, plausibility | `core.competitors/_metrics` | peer deltas, flags |
| **Simulation** | run the model engine (§9) | run records | projected statements |
| **Scenario/Decision** | scenarios, assumptions, orchestration | `plan.scenarios/assumptions` | scenarios, decisions |

Patterns: **API Gateway** + **Backend-for-Frontend** for the Executive UI; **Database-per-service** (logical, via schema isolation); **Saga** for multi-service scenario runs (§8.3); **CQRS** read models for dashboards.

---

## 6. Agent Architecture

The reasoning tier (detailed in [AGENTS.md](AGENTS.md)) layered over the services.

```
                 ┌──────────── CHAIRMAN (Queen / orchestrator) ───────────┐
                 │  agenda · arbitration · consensus · human escalation    │
                 └───────────────────────────┬────────────────────────────┘
   Executive agents (hierarchical-mesh):      │
     CFO · CMO · COO · Investor  ◄── peer-to-peer SendMessage ──►          │
   Advisory agents:  Market · Competitor                                   │
                 ┌───────────────────────────┴────────────────────────────┐
   Worker agents: cost-engineer · pricing-strategist · demand-analyst ·    │
                  capacity-planner · finance-modeler · compliance-officer · │
                  scenario-runner · validator/reviewer                      │
                 └─────────────────────────────────────────────────────────┘
   Substrate:  ruflo/claude-flow (topology: hierarchical-mesh, max 15)
               memory: AgentDB + HNSW (namespace agent-teams)
               comms: SendMessage-first · orchestration: hooks_route
```

- **Two tiers:** *executive agents* (personas with decision rights & KPIs) and *worker agents* (task specialists). Chairman orchestrates; CFO/Investor hold binding vetoes (solvency, hurdle).
- **Agents ↔ services:** agents **call services** for facts/queries and **invoke the Simulation service** to run scenarios; they never compute the model themselves.
- **Agents ↔ events:** agents subscribe to domain events (e.g. `SimulationCompleted`) and emit decision events (`DecisionApproved`).
- **Guardrails:** validator agent gates every autonomous write (truth-score ≥ threshold); no agent moves capital or signs contracts (P5); external data enters only through an ACL (see §11).

---

## 7. Data Architecture

**Polyglot persistence** — the right store for each job, all projections of the one ontology.

| Store | Role | Detailed design | Holds |
|---|---|---|---|
| **PostgreSQL** | System of record (transactional, constrained) | [DATABASE_SCHEMA.md](DATABASE_SCHEMA.md) | `ref/core/plan/proj` entities + facts |
| **Neo4j** | Reasoning surface (lineage, impact) | [KNOWLEDGE_GRAPH.md](KNOWLEDGE_GRAPH.md) | entity graph + financial spine |
| **AgentDB + HNSW** | Vector memory (semantic recall) | ARCHITECTURE §2 | embeddings, decisions, prior scenarios |
| **Object store (S3-compatible)** | Snapshots, documents, board packs | — | immutable run artifacts, exports |
| **CQRS read models / cache** | Dashboard query acceleration | — | denormalized projections |

### 7.1 Data flow & governance
```
external feeds ─►[validation gate]─► PostgreSQL (record) ─┬─► Neo4j (graph rebuild per snapshot)
 (rates, FSSAI,                                            ├─► AgentDB (embeddings)
  competitor, actuals)                                     └─► Simulation (baseline)  ─► proj.* (results)
                                                                                            │
                                                          Executive dashboards ◄─ CQRS read models
```
- **Master Data Management:** Reference/Master Data context is the shared kernel; one authoritative tier/family/calendar.
- **Lineage:** every published number traces to `(scenario, snapshot, assumption set)`; the graph makes lineage a one-hop query (KNOWLEDGE_GRAPH §7).
- **Versioning:** immutable snapshots → reproducible runs.
- **Validation gate:** schema + range + temporal-overlap checks at write time — the systemic cure for the input defects that caused the `#REF!` storm.

---

## 8. Event Architecture

Event-driven core so that a change in one context **deliberately** triggers recomputation downstream — the controlled inverse of the spreadsheet's uncontrolled formula cascade.

### 8.1 Event catalogue (domain events)
| Event | Emitted by | Consumed by | Effect |
|---|---|---|---|
| `IngredientPriceChanged` | Product/Recipe | Simulation, Cost-engineer | recompute cost/box |
| `BOMRecomputed` | Product/Recipe | Finance, Valuation | refresh COGS |
| `PriceUpdated` | Pricing | Finance, Demand | revenue recompute |
| `SAMUpdated` | Demand/Market | Manufacturing, Finance | volume recompute |
| `CapacityPlanChanged` | Manufacturing | Finance, Capital | capex/volume shift |
| `ExpensePlanUpdated` | Marketing | Finance, Compliance | opex + rule check |
| `ComplianceVerdictIssued` | Compliance | Marketing, Chairman | block/allow spend |
| `AssumptionUpdated` | Scenario | Simulation | mark run stale |
| `SnapshotCreated` | Scenario | Simulation, Graph-sync | freeze baseline |
| `SimulationCompleted` | Simulation | Finance, Valuation, agents | results ready |
| `ReturnsComputed` | Valuation | Investor agent, Chairman | go/no-go input |
| `DecisionApproved` | Decision/Governance | all + Executive | commit assumptions, notify |

### 8.2 Patterns
- **Event bus:** Kafka/Redpanda (or NATS for lighter footprint) — durable, ordered per scenario partition.
- **Event sourcing** for *assumptions and decisions* (auditable history of why the plan changed).
- **CQRS:** write side = services; read side = dashboard projections.

### 8.3 Saga — "Run Scenario"
```
ScenarioRequested → snapshot baseline → (cost ▸ price ▸ demand ▸ capacity ▸ marketing)
   → Finance consolidate (resolves revenue↔expense circularity by iterative fixpoint)
   → Valuation compute → SimulationCompleted → agents review → DecisionApproved | Rejected
   (compensation: discard snapshot/run on failure; nothing partially committed)
```

---

## 9. Simulation Architecture

The CORE engine — the workbook's formula mesh lifted into a parameterized, reproducible service. Detailed lineage in KNOWLEDGE_GRAPH; relationships from ontology §7.

### 9.1 Engine composition (FP-1…8)
```
ASSUMPTIONS (scenario) + BASELINE (snapshot)
        │
        ▼
 ┌─────────────────────────── Calculation DAG ───────────────────────────┐
 │ Cost engine (BOM×volume)      Revenue engine (capacity×eff×SAM×price)  │
 │            └──────────┬───────────────┘                                │
 │                       ▼                                                 │
 │        Opex engine (%-tier-rev + ₹/box) ⇄ Revenue  ← iterative fixpoint │  ← resolves the
 │                       ▼                              (circular dep §6.8) │     revenue↔expense loop
 │            EBITDA → D&A → EBIT → Interest → PBT → Tax → PAT             │
 │     Working-Capital engine · Capex/Depreciation · Financing · Debt      │
 │                       ▼                                                 │
 │        Returns engine: NPV · PI · EVA · ROCE · ROE · IRR · Payback      │
 └─────────────────────────────────────────────────────────────────────────┘
        │
        ▼
 RESULTS → proj.* (keyed by scenario+snapshot) + SimulationCompleted event
```

### 9.2 Capabilities
- **Deterministic recompute** over an explicit dependency DAG (no hidden order; the structural fix for `#REF!`).
- **Circular-dependency resolution:** revenue↔expense solved by iterative convergence, not accidental iteration.
- **Scenario manager:** create/clone/compare scenarios; immutable snapshots.
- **Sensitivity & Monte Carlo:** fan-out runs over assumption distributions (parallelized — §12).
- **Demand front-end (new):** the TAM→SAM→SOM model the workbook lacks (§8.2) feeds the revenue engine.
- **Validation:** every run asserted **zero formula errors** before publish (the standing quality gate).

---

## 10. Technology Stack

Grounded in what this environment already provides; **Current** = available/used now, **Target** = production direction.

| Layer | Technology | Current/Target | Purpose |
|---|---|---|---|
| **Orchestration / Agents** | ruflo (claude-flow v3), hierarchical-mesh, max-15 | Current (enabled) | agent swarm, coordination, hooks |
| **Agent memory** | AgentDB + HNSW (hybrid backend) | Current (configured) | semantic recall, decision memory |
| **System of record** | PostgreSQL 15 (or CockroachDB for HA — available) | Target | transactional entities & facts |
| **Knowledge graph** | Neo4j 5 (Cypher) | Target | lineage, impact, reasoning |
| **ORM / migrations** | Prisma | Current (available) | schema management, type-safe access |
| **Event bus** | Kafka / Redpanda (or NATS) | Target | domain events, sagas |
| **Simulation engine** | Python (calc DAG, Monte Carlo) | Target (workbook today) | the model engine |
| **API** | GraphQL (BFF) + REST | Target | gateway, dashboards |
| **Object store** | S3-compatible | Target | snapshots, board packs |
| **Document gen** | xlsx / pptx / pdf skills | Current | exports, board packs |
| **Observability** | OpenTelemetry + metrics/logs | Target | tracing, audit |
| **Runtime** | Containers + Kubernetes | Target | deploy, scale |
| **Workbook bridge** | openpyxl + `formulas` recalc | Current | repaired model, verification |

> **Honesty note:** today the "platform" is the repaired workbook + the configured ruflo stack + this documentation set. The table's *Target* column is the migration path, not a claim of present state. (See ARCHITECTURE §9 roadmap.)

---

## 11. Security Architecture

| Domain | Control |
|---|---|
| **Authentication** | SSO/OIDC for humans; service identities (mTLS) for services; scoped tokens for agents |
| **Authorization** | RBAC by role (Founder/CFO/Analyst/Viewer) + **Row-Level Security scoped by scenario ownership** (DATABASE_SCHEMA §9) |
| **Agent instruction boundary (critical)** | Agents treat **all tool-sourced content as data, not instructions.** Market/Competitor agents ingest external web data through an **Anti-Corruption Layer** that strips/ignores embedded directives — prompt-injection defense |
| **Human-in-the-loop** | No agent moves money, signs contracts, dilutes equity, or commits capital. Those actions **escalate to humans** (AGENTS §10) |
| **Secrets** | No secrets/`.env` in repo or context (project `deny` rules enforced); vault-managed credentials |
| **Data classification** | financial plan = confidential; competitor intel = restricted; reference data = internal |
| **Encryption** | TLS in transit; at-rest encryption for PostgreSQL/Neo4j/object store |
| **Audit & non-repudiation** | `audit.change_log` + event-sourced assumptions/decisions; every decision linked to `(scenario, snapshot)` and approver |
| **Regulatory compliance** | IMS Act / FSSAI / GST encoded as enforced domain rules in Marketing&Compliance context; violations block via `ComplianceVerdictIssued` |
| **Reversibility** | agent writes are proposals until approved; originals preserved (as practiced — repaired file is a copy) |

---

## 12. Scalability Plan

| Dimension | Strategy |
|---|---|
| **Stateless services** | horizontal autoscaling behind the gateway; no session affinity |
| **Database** | read replicas for query load; **partition `proj.*` by `scenario_id`** (schema §8); connection pooling; CockroachDB option for geo-HA |
| **CQRS read models** | precomputed dashboard projections absorb read spikes without touching the write store |
| **Knowledge graph** | scenario-scoped subgraphs; index traversal anchors; read replicas for analytics |
| **Agent swarm** | bounded concurrency (max-15 config) with a work queue; scale workers horizontally; Chairman rate-limits fan-out |
| **Simulation** | **embarrassingly parallel Monte Carlo / sensitivity** fan-out (one run per worker); snapshot immutability makes runs independent and cacheable |
| **Event bus** | partition by scenario for ordered, parallel consumption; backpressure via consumer groups |
| **Caching** | memoize cost/box and unchanged sub-DAGs; invalidate on the relevant domain event only (targeted, not global) |
| **Multi-tenancy** | scenario/tenant isolation via RLS + schema scoping — supports many plans/companies on one platform |
| **Capacity roadmap** | Phase 1 single-node (current workbook scale) → Phase 2 partitioned PG + event bus → Phase 3 distributed (CockroachDB + K8s + parallel sim grid) |

### 12.1 Non-functional targets (illustrative)
| NFR | Target |
|---|---|
| Scenario run latency | < 5 s single run; Monte Carlo (1k paths) < 60 s parallel |
| Dashboard query | < 500 ms (read model) |
| Graph impact query | < 1 s (indexed traversal) |
| Recompute correctness | **0 formula errors** (hard gate) |
| Availability | 99.9% (HA DB + stateless services) |
| Reproducibility | 100% (snapshot-keyed) |

---

## Appendix A — Document series

| Doc | Scope |
|---|---|
| **01_SYSTEM_ARCHITECTURE.md** *(this)* | enterprise architecture — the complete platform |
| BUSINESS_ONTOLOGY.md | source of truth — entities, processes, flow |
| ARCHITECTURE.md | 5-layer reference architecture |
| DATABASE_SCHEMA.md | Data Layer — PostgreSQL |
| KNOWLEDGE_GRAPH.md | Knowledge Layer — Neo4j |
| AGENTS.md | Agent Layer — virtual boardroom |

## Appendix B — Traceability (capabilities → contexts → services → stores)

| Capability | Bounded Context | Service | Primary store |
|---|---|---|---|
| Formulation & Costing | Product & Recipe | Product/Recipe svc | PostgreSQL `core` + graph |
| Demand Intelligence | Demand & Market | Demand svc | PostgreSQL `core.markets` + graph |
| Pricing | Pricing | Pricing svc | `plan.prices` |
| Manufacturing | Manufacturing & Capacity | Mfg svc | `core.plants`, `plan.capex_plan` |
| Marketing & Compliance | Marketing & Compliance | Marketing svc | `plan.expense_assumptions` |
| Financial Consolidation | Finance & P&L | Finance svc | `proj.pnl_lines`, `proj.working_capital` |
| Capital & Funding | Capital & Financing | Financing svc | `core.funding_rounds`, `plan.financing_plan` |
| Valuation | Valuation & Returns | Valuation svc | `proj.returns` |
| Competitive Intel | Competitive Intelligence | Intelligence svc | `core.competitors` |
| Simulation | Scenario & Simulation | Simulation svc | `proj.*` + object store |
| Decision Governance | Decision & Governance | Decision svc | event store + AgentDB |

---

*End of 01_SYSTEM_ARCHITECTURE.md — the canonical platform blueprint for the Valencia Nutracare Decision Platform, governed by BUSINESS_ONTOLOGY.md.*
