# PLATFORM ARCHITECTURE — Valencia Nutracare Decision Platform (VNDP)

**Companion to:** [BUSINESS_ONTOLOGY.md](BUSINESS_ONTOLOGY.md)
**Purpose:** Turn the static Nutracare financial workbook into a living, AI-native decision platform — where data flows *up* into knowledge, agents reason over it, simulations explore the future, and executives steer with it.
**Authored by:** Chief Systems Architect

---

## 0. Design philosophy

The workbook today is a **single artifact that conflates five concerns**: it stores data, encodes domain knowledge, performs calculations, runs scenarios, and presents results — all in one fragile mesh of cross-sheet formulas. The two structural breaks we just repaired (a missing sheet and dead external price links cascading into ~2,000 errors) are the natural consequence of that conflation: when everything is one layer, one break is everywhere.

The platform **separates these five concerns into layers**, each with clean inputs, outputs, dependencies, and a single accountable owner:

```
┌─────────────────────────────────────────────────────────────────┐
│  5 │ EXECUTIVE LAYER      decisions, dashboards, board packs      │  ← humans steer
│    │                      (Strategy control panel, what-if)       │
├─────────────────────────────────────────────────────────────────┤
│  4 │ SIMULATION LAYER     scenario engine, forecasts, sensitivity │  ← the model runs
│    │                      (P&L · WC · Capex · Financing · Returns) │
├─────────────────────────────────────────────────────────────────┤
│  3 │ AGENT LAYER          autonomous reasoning & orchestration    │  ← ruflo swarm
│    │                      (cost, pricing, demand, compliance…)    │
├─────────────────────────────────────────────────────────────────┤
│  2 │ KNOWLEDGE LAYER      ontology, rules, relationships, memory  │  ← the brain
│    │                      (entities · processes · constraints)    │
├─────────────────────────────────────────────────────────────────┤
│  1 │ DATA LAYER           system of record, validated facts       │  ← ground truth
│    │                      (BOMs · prices · capacity · actuals)    │
└─────────────────────────────────────────────────────────────────┘
        DATA flows UP  ▲                          ▼  DECISIONS flow DOWN
```

**Two universal flows:**
- **Upward (facts → insight):** raw data is validated, given meaning, reasoned over, projected, and surfaced.
- **Downward (intent → action):** executive decisions become assumptions, which agents apply, which re-run simulations, which update the record.

**Grounding note (current vs target):** the platform is built *incrementally on what exists*. Each layer below states its **Current state** (what the repaired workbook + your configured ruflo/claude-flow stack already provide) and **Target state** (where it goes). Nothing here assumes infrastructure you don't have.

---

## 1. DATA LAYER — System of Record

> *"What is true."* The single, validated, versioned source of every fact the platform reasons about.

The Data Layer holds the **14 ontology entities** as first-class, queryable records — decoupled from the formulas that consume them. It is the only layer permitted to assert raw facts.

### Inputs
| Source | Entities fed | Cadence |
|---|---|---|
| BOM sheets (PP/LP/IFM/CNP/Infant Complementary) | `Ingredient`, `BOM`, `Product` cost/box | On recipe change |
| `Product Line`, `Strategy` | `Product` (SKU catalogue, tiers, brands), `Scenario` headers | On range planning |
| Ingredient rate cards (currently hard-coded in BOM `Rate/Kg`) | `Ingredient` prices | Procurement cycle |
| `In-house` / `Third Party` / `Contract` capacity inputs | `Market` SAM %, capacity, plant schedule | Annual plan |
| `Capex & Depreciation`, `Project Financing`, `Debt Schedule` | `Capex`, `Funding Round`, debt terms | Per funding round |
| `Competitor Brands` | `Competitor` benchmarks | Quarterly refresh |
| External feeds (target): FSSAI registry, GST schedules, commodity indices, actual sales | `Expense` rules, actuals vs plan | Live / scheduled |

### Outputs
- Clean, typed, **validated** datasets for each entity (one logical table per entity: `products`, `ingredients`, `boms`, `prices`, `capacity`, `funding_rounds`, `capex`, `actuals`, …).
- A **versioned snapshot** per planning cycle (so every simulation is reproducible against a known data state).
- **Data-quality signals** (nulls, units, out-of-range, broken links) — the very class of defect that produced the `#REF!` cascade.

### Dependencies
- **None upward.** This is the foundation.
- Conforms *downward to* the Knowledge Layer's entity definitions (schema = ontology §2).

### Ownership
- **Owner:** Finance Operations / Data Engineering.
- **Accountable for:** correctness, freshness, lineage, and unit consistency of every fact. The "no hard-coded external value without a documented source" rule (xlsx skill standard) is enforced here.

### Current → Target
- **Current:** the repaired `22 Cr Nutracare Project - REPAIRED.xlsx` is the system of record; inputs are blue cells, links are green, assumptions yellow.
- **Target:** promote the input cells to a lightweight store (SQLite/Parquet, or CockroachDB/Prisma — both available in this environment) with the workbook as a *projection*, not the master. Add a validation gate (schema + range checks) on every write.

---

## 2. KNOWLEDGE LAYER — Semantic Brain

> *"What it means and how it relates."* The ontology, the business rules, the dependency graph, and the memory that lets agents retrieve relevant context.

This layer is **`BUSINESS_ONTOLOGY.md` made executable**. It encodes not just entities but the *relationships and constraints* the user cares about most (their stated priority: "the flow of the data and how everything is related").

### Contents
1. **Entity–relationship graph** — the 14 entities and their edges (`Product` *produced from* `BOM`; `Ingredient` *component of* `BOM`; `Funding Round` *finances* `Capex`+`Inventory`; `Market`-SAM% *drives* BPH; etc.).
2. **Process catalogue** — 11 business / 8 decision / 8 forecasting processes (ontology §3–5) as named, runnable references.
3. **Rule & constraint engine** — the hard rules: GST 18%, tax 25%, **IMS Act** (no Tier-1 infant-formula consumer ads → budget shifts to HCP detailing), logistics ₹9→8.5/box, 5% contingency, capital-structure mix (15/85, 25/75, 10/90), depreciation 15% WDV.
4. **Assumptions register** — every yellow-flagged input with provenance and confidence (ontology §9).
5. **Dependency map** — the calculation DAG (ontology §7); the thing that, when violated, creates `#REF!` storms.
6. **Vector memory** — embeddings of sheets, decisions, and past scenarios for semantic retrieval.

### Inputs
- Validated entities from the **Data Layer**.
- `BUSINESS_ONTOLOGY.md` (the human-authored semantic spec).
- Domain rules (regulatory, accounting, pricing logic).

### Outputs
- A **queryable knowledge graph** ("which sheets break if In-house prices change?" → returns the DAG slice).
- **Embeddings + retrieval API** over entities, rules, and prior decisions.
- **Validated assumption sets** handed to the Simulation Layer.
- **Rule verdicts** ("is this marketing plan IMS-Act compliant?") for the Agent Layer.

### Dependencies
- **Data Layer** (facts to attach meaning to).

### Ownership
- **Owner:** Domain Architect / Knowledge Engineer (with Finance sign-off on rules).
- **Accountable for:** semantic correctness — that the relationships and constraints match the real business.

### Current → Target
- **Current:** ontology is Markdown; rules live implicitly in formulas; memory is the project `memory/` folder + auto-memory hooks.
- **Target:** materialize the graph and embeddings in **AgentDB / HNSW** (your configured hybrid memory backend, `enableHNSW: true`, `memoryGraph.enabled: true`) so agents query relationships at 150× search speed; lift hard rules into an explicit rule module that both agents and the simulation enforce.

---

## 3. AGENT LAYER — Autonomous Reasoning & Orchestration

> *"Who does the thinking and the work."* A coordinated swarm that reads the knowledge graph, computes, validates, and proposes — the ruflo/claude-flow swarm made purposeful for this domain.

Maps directly onto your configured stack: **hierarchical-mesh topology, max 15 agents, SendMessage coordination, shared `agent-teams` memory namespace, neural pattern learning.**

### Agent roster (domain-specialized)
| Agent | Responsibility | Reads | Writes |
|---|---|---|---|
| **cost-engineer** | Recompute BOM cost/box on ingredient-rate change | `Ingredient`, `BOM` | `Product` cost/box |
| **pricing-strategist** | Tier/MRP/net-price logic; replace the yellow price assumptions with sourced data | `Market`, `Competitor`, MRP | `Product` selling price |
| **demand-analyst** | TAM→SAM→SOM, tier-mix, capacity vs demand | `Market` SAM, capacity | volume forecasts |
| **capacity-planner** | Plant build-out timing, 75/25 own-vs-contract split | `Scenario`, capex | plant schedule |
| **finance-modeler** | Drive the Simulation Layer; assemble P&L/WC/financing | Knowledge rules | scenario specs |
| **compliance-officer** | Enforce IMS Act, FSSAI, GST, tax rules | rule engine | compliance verdicts |
| **scenario-runner** | Execute & compare simulation runs | Sim API | run results |
| **validator/reviewer** | Truth-score outputs, catch the `#REF!`-class defects pre-publish | all | quality gates |

Coordination pattern (per project `CLAUDE.md`): **Pipeline** for sequential model builds (cost → pricing → demand → finance → review), **Fan-out** for independent research (competitor, regulatory, commodity), **Supervisor** for ongoing scenario sweeps.

### Inputs
- Knowledge Layer queries (relationships, rules, retrieved precedent).
- Data Layer facts.
- **Executive intents** ("model a 30 Cr round at 40% Tier-1 mix").

### Outputs
- Computed updates written back to Data/Simulation (e.g., new cost/box, price recommendations).
- **Anomaly & risk flags** (broken dependency, margin collapse, compliance breach).
- **Narratives** explaining *why* a number moved (the audit trail executives need).
- Trained **neural patterns** (what worked) persisted to memory for reuse.

### Dependencies
- **Knowledge Layer** (what to reason with) and **Data Layer** (facts).
- Invokes the **Simulation Layer** (agents don't compute the model themselves; they orchestrate runs).

### Ownership
- **Owner:** AI / Automation team (operates the ruflo swarm).
- **Accountable for:** correct orchestration, that agents respect rules, and that every autonomous write is validated and reversible.

### Current → Target
- **Current:** ruflo MCP now `autoStart: true` (enabled this session, live on next restart); hooks fire telemetry; agents available but not yet domain-specialized.
- **Target:** instantiate the roster above as named claude-flow agents with the prompts/comms wiring from `CLAUDE.md`; gate all writes behind the validator agent (truth-score ≥ threshold, per `verification-quality` skill).

---

## 4. SIMULATION LAYER — Scenario & Forecast Engine

> *"What would happen if…"* The financial model as a *callable engine*, not a spreadsheet — the relationships from the ontology executed deterministically over any assumption set.

This is the workbook's formula mesh, **lifted out and made reusable**. It consumes an assumption set and produces full projected statements. Because data is mock (your stated point), the engine's value is the **relationship fidelity**, not the numbers.

### What it computes (the ontology's forecasting processes, FP-1…FP-8)
- **Revenue engine:** capacity × working-efficiency × tier-mix(SAM) × price → boxes → revenue (In-house + Third Party).
- **Cost engine:** BOM cost/box × volume → COGS.
- **Opex engine:** %-of-tier-revenue grid + ₹/box logistics → indirect expenses (resolves the revenue↔expense **circular dependency** via iterative calc — see ontology §6.8).
- **Working-capital engine:** monthly cash-flow rotation → WC requirement.
- **Capex/Depreciation, Financing, Debt** engines → capital structure & interest.
- **Returns engine:** NPV, PI, EVA, ROCE, ROE, IRR, payback (now reconnected to `P&L`).
- **Sensitivity / Monte Carlo (target):** vary any assumption, see distribution of outcomes.

### Inputs
- **Assumption set** from Knowledge Layer (validated) + Executive what-ifs.
- Baseline facts from Data Layer (the versioned snapshot).
- Run configuration from the scenario-runner agent.

### Outputs
- Full projected **financial statements** (P&L, WC, capex, financing) per scenario.
- **Return metrics** and their drivers.
- **Scenario comparisons** and sensitivity tables.
- A **reproducible run record** (assumptions + data version + results) → back to Data Layer.

### Dependencies
- **Knowledge Layer** (the relationships/DAG it executes; the rules it must honor).
- **Data Layer** (baseline).
- Driven by the **Agent Layer** (scenario-runner / finance-modeler).

### Ownership
- **Owner:** FP&A / Quant Modeling.
- **Accountable for:** calculation correctness and **zero formula errors** (xlsx skill mandate); guarding against the circular-reference and broken-link failure modes.

### Current → Target
- **Current:** the repaired workbook *is* the engine; recalculated via the `formulas` library (LibreOffice path unavailable) to a verified **0 errors**.
- **Target:** re-express the engine as a parameterized calculation module (Python) with the workbook as one renderer; add Monte Carlo + a TAM→SAM→SOM demand front-end (the biggest missing relationship per ontology §8.2).

---

## 5. EXECUTIVE LAYER — Decision Surface

> *"So what do we do?"* Where humans steer — the `Strategy` sheet evolved into a live control panel, plus dashboards, alerts, and board-ready outputs.

### Surfaces
- **Strategy control panel:** the per-year tier/capital/SKU/plant levers (ontology §6.4) become editable inputs that trigger simulation runs.
- **What-if console:** change a round size, a tier mix, a plant date → see P&L/returns shift instantly.
- **Dashboards:** revenue mix, margin bridge, capital deployment, returns, working-capital rotation.
- **Alerts:** agent-raised flags (compliance breach, margin/WC stress, dependency break).
- **Board pack generator:** narrative + statements + scenario comparison, exportable (xlsx/pptx/pdf — all available skills).

### Inputs
- **Simulation outputs** (projected statements, returns, sensitivities).
- **Agent recommendations & narratives** (the "why").

### Outputs
- **Decisions:** capital deployment per round, pricing per tier, tier-entry sequencing, plant-build timing, make-vs-buy split (the 8 decision processes, ontology §4).
- **Approved assumption changes** → flow *down* to the Knowledge Layer as the next baseline.
- **External reports** for investors/board.

### Dependencies
- **All layers below** (it is the apex; it consumes the stack's synthesized output).

### Ownership
- **Owner:** Founders / CXO / Investors.
- **Accountable for:** the actual business decisions and committing approved assumptions back into the platform.

### Current → Target
- **Current:** `Strategy` sheet (static summary) + manual reading of P&L.
- **Target:** an interactive console (the `Claude_Preview` / dashboard skills can render this) backed by the Simulation API, with one-click board-pack export.

---

## 6. Cross-Layer Data & Control Flow

```
EXECUTIVE     intent ("model 30Cr @ 40% Tier-1")                decisions, board pack
   │  ▲                │                                              ▲
   │  │ approved       ▼ what-if                                      │ reports
   ▼  │ assumptions
AGENT      scenario-runner / finance-modeler orchestrate ───┐   narratives + flags
   │  ▲                                                      │        ▲
   │  │ rule verdicts, retrieved context                    ▼        │ results
   ▼  │
KNOWLEDGE  graph query · rules · assumptions ──────────► SIMULATION engine
   │  ▲                                                   (P&L·WC·Capex·Fin·Returns)
   │  │ meaning, constraints                                  │  ▲
   ▼  │                                                       ▼  │ run record
DATA       validated entities + versioned snapshot ───────────┘
           (BOMs · prices · capacity · capex · funding · actuals)
```

- **Upward path (facts→decision):** Data → Knowledge (meaning) → Agent (reasoning) → Simulation (projection) → Executive (choice).
- **Downward path (decision→fact):** Executive approves → Knowledge updates assumptions → Agent applies → Simulation re-runs → Data records the new baseline.
- **Failure containment:** a break is now *localized* to its layer (a bad price is a Data-Layer validation failure, not a model-wide `#REF!` storm) — the architectural answer to the defect class we repaired.

---

## 7. Ontology → Layer Mapping (traceability)

| Ontology artifact (§) | Lands in layer |
|---|---|
| 14 Data Entities (§2) | **Data** (records) + **Knowledge** (definitions/edges) |
| Business Processes BP-1…11 (§3) | **Agent** (orchestration) + **Simulation** (execution) |
| Decision Processes DP-1…8 (§4) | **Executive** (levers) |
| Forecasting Processes FP-1…8 (§5) | **Simulation** (engines) |
| Dependency Graph (§7) | **Knowledge** (the DAG) → guards **Simulation** |
| Missing-info / integrity register (§8) | **Data** (validation) + **Knowledge** (gaps to fill) |
| Assumptions Register (§9) | **Knowledge** (provenance) → **Executive** (tunable) |

---

## 8. Governance & Non-Functional Concerns

- **Lineage:** every published number traces to a data version + assumption set + run id (kills "where did this come from?").
- **Validation gates:** Data write-time checks; Simulation 0-error mandate; Agent truth-score before publish.
- **Reproducibility:** snapshot + scenario = deterministic re-run.
- **Security/compliance:** rule engine enforces IMS Act / FSSAI / GST / tax; secrets and `.env` excluded (per project settings `deny` rules).
- **Reversibility:** agent writes are proposals until approved; originals preserved (as we did — repaired file is a copy).
- **Mock-data stance:** until real data lands, the platform is validated on **relationship fidelity and zero-error flow**, not values — exactly the priority you set.

---

## 9. Build Roadmap (incremental, on what exists)

| Phase | Deliverable | Layers touched |
|---|---|---|
| **0 — done** | Ontology authored; workbook repaired to 0 errors; ruflo enabled | Data, Knowledge, Simulation |
| **1** | Lift inputs into a validated store; workbook becomes a projection | Data |
| **2** | Materialize ontology graph + rules + embeddings in AgentDB/HNSW | Knowledge |
| **3** | Stand up domain agent roster on ruflo swarm with validator gate | Agent |
| **4** | Parameterize the calc engine; add demand model + Monte Carlo | Simulation |
| **5** | Interactive Strategy console + board-pack export | Executive |

---

## Appendix A — One-line layer summary

| # | Layer | Question | Owner | Core input → output |
|---|---|---|---|---|
| 1 | Data | What is true? | Finance Ops / Data Eng | raw feeds → validated entities |
| 2 | Knowledge | What does it mean? | Domain Architect | entities → graph + rules + memory |
| 3 | Agent | Who reasons/acts? | AI/Automation (ruflo) | intents → computed updates + flags |
| 4 | Simulation | What if? | FP&A / Quant | assumptions → projected statements + returns |
| 5 | Executive | What do we do? | Founders / CXO | projections → decisions + reports |

---

*End of ARCHITECTURE.md — the platform blueprint for the Valencia Nutracare Decision Platform, built on BUSINESS_ONTOLOGY.md.*
