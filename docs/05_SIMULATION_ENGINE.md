# 05 — SIMULATION ENGINE
## Valencia Nutracare Decision Platform (VNDP)

**Authority:** Chief Enterprise Architect
**Source of truth:** [BUSINESS_ONTOLOGY.md](BUSINESS_ONTOLOGY.md)
**Aligns with:** [01_SYSTEM_ARCHITECTURE.md](01_SYSTEM_ARCHITECTURE.md) (§9) · [02_DOMAIN_MODEL.md](02_DOMAIN_MODEL.md) · [AGENTS.md](AGENTS.md)
**Status:** Simulation engine spec · v1.0
**Note:** No code — module contracts, dependency DAG, and interaction design only. The workbook's formulas become **module functions**; values are mock, so the deliverable is the **calculation flow**.

---

## 1. From workbook to engine

The repaired 30-sheet workbook is a deterministic calculator with hidden, fragile dependency wiring. The engine **lifts each calculation cluster into a named module** with an explicit `(inputs → outputs)` contract and a declared dependency edge. The benefit is exactly the inverse of the `#REF!` failure: the dependency graph is **explicit, ordered, and validated**, so a change propagates deliberately and a break is localized.

```
            ┌──────────────────────── DECISION / INTERPRETATION ─────────────────────────┐
   LAYER 3  │                        AGENT DEBATE LAYER (boardroom)                       │
            └───────────────▲───────────────────────────────────────────▲────────────────┘
            ┌───────────────┴───────────── SEARCH ──────────────────────┴────────────────┐
   LAYER 2  │   OPTIMIZATION LAYER (decisions)        MONTE CARLO LAYER (uncertainty)      │
            └───────────────▲───────────────────────────────────────────▲────────────────┘
            ┌───────────────┴───────────── DETERMINISTIC CORE ───────────┴────────────────┐
   LAYER 1  │  M-CAPEX · M-BOM · M-DEMAND · M-COMP · M-PNL · M-WC · M-FUND · M-RET          │
            └──────────────────────────────────────────────────────────────────────────────┘
                       all runs keyed to (scenario_id, snapshot_id) — reproducible
```

---

## 2. Deterministic Core — module contracts

Each module is a pure function `f(inputs, assumptions) → outputs` scoped to a `(scenario, snapshot)`. "Workbook source" maps to ontology sheets.

### M-BOM — Bill-of-Materials / Cost Engine
| | |
|---|---|
| **Purpose** | Compute cost/box per family and boxes/batch from the recipe. |
| **Inputs** | ingredient rates (₹/kg), recipe qty/100g, packaging cost, conversion cost, batch cost (₹2 Cr), box size (400/500 g) |
| **Outputs** | `costPerBox[family]`, `boxesPerBatch[family]`, raw-material cost |
| **Dependencies** | ← ingredient prices (exogenous / M-COMP priors). None internal. **Root of the cost chain.** |
| **Workbook source** | PP/LP/IFM/CNP/Infant-Complementary BOM, Total Production |

### M-CAPEX — Capex & Depreciation / Capacity Engine
| | |
|---|---|
| **Purpose** | Turn the plant build-out into capex, depreciation, and installed capacity. |
| **Inputs** | plant schedule (0/1/2/3/3), per-plant cost (land+machinery+contingency), depreciation rate (15% WDV), kg/day/plant |
| **Outputs** | `capex[year]`, `dAndA[year]`, `installedCapacity[year]` (kg/day → boxes) |
| **Dependencies** | ← Strategy (plant schedule). **Feeds M-DEMAND (capacity) and M-PNL (D&A).** |
| **Workbook source** | Capex & Depreciation |

### M-DEMAND — Market Demand / Volume Engine
| | |
|---|---|
| **Purpose** | Convert capacity, working-efficiency, tier-mix (SAM) and price into sellable boxes. *(Houses the TAM→SAM→SOM front-end the workbook lacks — ontology §8.2.)* |
| **Inputs** | installed capacity (M-CAPEX), SAM% by family×tier×year, working-efficiency ramp (80→100%), own/contract split (75/25), tiers targeted (Strategy), prices |
| **Outputs** | `boxes[sku, tier, mode, year]`, demand-vs-capacity gap |
| **Dependencies** | ← M-CAPEX (capacity), Strategy (tiers), Market (SAM). **Feeds M-PNL (volume), M-WC.** |
| **Workbook source** | In-house (2-5yrs) SAM/BPH tables, Third Party, Revenue Breakup |

### M-COMP — Competition / Benchmark Engine
| | |
|---|---|
| **Purpose** | Provide expense-ratio priors and plausibility bounds from peers. |
| **Inputs** | competitor gross/EBITDA margins, ad/HCP/logistics spend ratios, "₹ to earn ₹1" |
| **Outputs** | `expenseRatioPriors[category]`, plausibility bounds (min/max), margin sanity flags |
| **Dependencies** | ← Competitor benchmarks (exogenous). **Feeds M-PNL (priors) and Optimization (constraints).** Advisory — never overrides actuals. |
| **Workbook source** | Competitor Brands |

### M-PNL — Profit & Loss / Consolidation Engine
| | |
|---|---|
| **Purpose** | Revenue → COGS → indirect expenses → EBITDA → D&A → EBIT → interest → PBT → tax → PAT. |
| **Inputs** | `boxes` (M-DEMAND), prices, `costPerBox` (M-BOM), expense %s (IE bifurcation + M-COMP priors), `dAndA` (M-CAPEX), `interest` (M-FUND), tax 25%, contingency 5% |
| **Outputs** | P&L lines, EBITDA & margin, PAT & margin, gross margin |
| **Dependencies** | ← M-DEMAND, M-BOM, M-CAPEX, M-COMP, **M-FUND (interest)**; **revenue↔expense cycle** with the opex sub-step (resolved by fixpoint, §3). **Feeds M-WC, M-FUND, M-RET.** |
| **Workbook source** | P&L, Indirect Expenses, IE Bifurcation, Revenue Breakup |

### M-WC — Working Capital Engine
| | |
|---|---|
| **Purpose** | Size working capital via the monthly cash-flow rotation. |
| **Inputs** | monthly boxes (M-DEMAND), cost/box (M-BOM), price, monthly indirect expense (M-PNL), 3.5× safety multiplier |
| **Outputs** | `initialWC[family]`, `wcRotation`, `wcRequirement[year]` |
| **Dependencies** | ← M-DEMAND, M-BOM, M-PNL. **Feeds M-FUND (capital requirement).** |
| **Workbook source** | WC (Year 1 / 2 / 3-5) |

### M-FUND — Funding / Capital Structure Engine
| | |
|---|---|
| **Purpose** | Fund capex + WC via the equity/debt mix; track debt, interest, retained earnings, FD income, free cash flow. |
| **Inputs** | capex requirement (M-CAPEX), WC requirement (M-WC), PAT (M-PNL, retained), round amounts (22/60/220), mix rules (15/85, 25/75, 10/90), debt 12%, FD 25%@6% |
| **Outputs** | equity/debt split, `debtSchedule`, `interest[year]`, surplus, FD income, FCF |
| **Dependencies** | ← M-CAPEX, M-WC, M-PNL; **interest↔PBT cycle** with M-PNL (fixpoint, §3). **Feeds M-PNL (interest), M-RET (capital base).** |
| **Workbook source** | Project Financing, Debt Schedule, Allocation |

### M-RET — Valuation / Returns Engine
| | |
|---|---|
| **Purpose** | NPV, PI, EVA, ROCE, ROE, IRR, payback, discounted payback. |
| **Inputs** | cash flows = PAT + D&A (M-PNL), capital outflow (M-FUND), WACC (Ke 10.8% / Kd 9% post-tax), 7-yr horizon |
| **Outputs** | the return metric set + sensitivities |
| **Dependencies** | ← M-PNL, M-FUND. **Terminal module → Agent Debate Layer.** |
| **Workbook source** | Project NPV/PI/EVA, ROCE & RONW, IRR & Payback |

---

## 3. Deterministic dependency DAG & cycle resolution

```
        Strategy ──► M-CAPEX ──┬──► installedCapacity ──► M-DEMAND ──► boxes ─┐
                                └──► D&A ───────────────────────────┐         │
   ingredient rates ──► M-BOM ──► costPerBox ──────────────┐        │         │
   Competitor ──► M-COMP ──► expense priors ───────┐       │        │         │
                                                    ▼       ▼        ▼         ▼
                                                ┌──────────  M-PNL  ──────────┐
                                                │  revenue ⇄ opex  (fixpoint)  │
                                                │  PBT ⇄ interest  (fixpoint)  │
                                                └───────┬───────────┬──────────┘
                                       PAT+D&A ▼        │ monthly    │ retained
                                          M-WC ◄────────┘ inputs     ▼
                                            │ wcReq                 M-FUND ──► interest (back to M-PNL)
                                            └──────────► M-FUND ──► capital base ──► M-RET ──► returns
```

**Two intentional cycles** (the workbook's circular references, now made explicit and convergent):
1. **revenue ⇄ expense** — opex is %-of-revenue; revenue nets to the P&L that contains opex.
2. **PBT ⇄ interest** — interest depends on debt funded against a requirement that depends on PAT.

**Resolution:** the engine runs a **fixed-point iteration** — seed expenses/interest at 0, compute the P&L, recompute expenses/interest, repeat until `|Δ| < ε` (typically 3–5 passes). Deterministic, ordered, convergence-checked — never accidental spreadsheet iteration. A run **fails closed** if it does not converge or if any module emits an error (the zero-error gate).

---

## 4. LAYER 2A — Monte Carlo Layer

| | |
|---|---|
| **Purpose** | Quantify outcome uncertainty by sampling uncertain inputs and running the deterministic core N times. |
| **Inputs** | probability distributions per uncertain assumption (ingredient rates, SAM%, prices, efficiency ramp, conversion cost, tax/WACC), iteration count `N`, random seed (stored for reproducibility) |
| **Outputs** | distributions (PDF/CDF) of EBITDA / PAT / NPV / IRR; P10·P50·P90; probability(NPV<0); **tornado / sensitivity ranking** (which inputs move the outcome most) |
| **Dependencies** | wraps the **entire deterministic core** (M-BOM…M-RET) as the per-iteration evaluator; reads `Scenario` assumptions; emits `SimulationCompleted` |
| **Interaction** | each iteration = one full DAG solve (incl. fixpoints). Iterations are **independent → embarrassingly parallel** (one worker per path; ties to scalability §12 of doc 01). Seed + snapshot ⇒ bit-reproducible. |

---

## 5. LAYER 2B — Optimization Layer

| | |
|---|---|
| **Purpose** | Search the **decision space** for the choice set that maximizes an objective subject to constraints. |
| **Decision variables** | tier sequencing (DP-2), pricing per tier (DP-7), plant-add timing (DP-4), make-vs-buy split (DP-3), funding mix (DP-5), marketing allocation (DP-8), round sizing (DP-1) |
| **Objective(s)** | maximize NPV / IRR / EVA (or multi-objective Pareto: return vs. runway risk) |
| **Constraints** | capacity ≥ demand; cash runway > 0; financing mix policy; **IMS-Act compliance**; **M-COMP plausibility bounds** (e.g. opex not below peer floors); SKU/tier validity |
| **Inputs** | decision-variable bounds, objective spec, constraint set, the deterministic core as the **evaluation function**, (optionally) Monte Carlo for **robust/stochastic optimization** (maximize P50 NPV s.t. P10 NPV ≥ 0) |
| **Outputs** | optimal decision set + the efficient frontier (return vs. risk) + constraint shadow-prices |
| **Dependencies** | calls the deterministic core (and optionally Monte Carlo) repeatedly; reads M-COMP bounds; proposes decisions to the Agent Debate Layer |
| **Methods** | LP/MILP where linear; Bayesian optimization / genetic algorithms for the non-linear, expensive-to-evaluate full model |

---

## 6. LAYER 3 — Agent Debate Layer

| | |
|---|---|
| **Purpose** | The virtual boardroom ([AGENTS.md](AGENTS.md)) interprets the quantitative outputs, argues trade-offs, and produces a **recommended scenario with rationale and dissent**. |
| **Inputs** | Monte Carlo distributions, Optimization frontier + recommended decisions, each agent's KPIs & decision rights |
| **Process** | CFO (solvency/runway) · CMO (growth/spend) · COO (capacity/cost) · Investor (hurdle/IRR) · Market & Competitor (plausibility) debate via `SendMessage`; **binding vetoes**: CFO on solvency, Investor on hurdle; **Chairman** drives consensus (`hive-mind_consensus`) or arbitrates |
| **Outputs** | board-ready recommendation, chosen `(scenario, decision set)`, dissent record, escalations to humans for irreversible acts (capital commitment) |
| **Dependencies** | ← Monte Carlo, ← Optimization, ← all core modules (for drill-down); → writes decision-of-record to memory; → may **re-parameterize a Scenario and re-run** the core |
| **Guardrail** | agents *recommend*; humans *commit*. No capital movement, contracts, or dilution executed by agents (P5). |

---

## 7. How it all interacts (the closed loop)

```
   ┌──────────────────────────────── BOARD CYCLE ────────────────────────────────┐
   │ 1. Agents/Strategy set candidate DECISIONS  ──────────────►  Optimization     │
   │ 2. Optimization searches, calling the DETERMINISTIC CORE as evaluator         │
   │ 3. Monte Carlo STRESS-TESTS the top candidates (uncertainty → P10/P50/P90)     │
   │ 4. Agent Debate INTERPRETS distributions + frontier, argues, Chairman decides  │
   │ 5. Chosen scenario COMMITTED (human-approved) → new snapshot → core re-run     │
   │ 6. Results persisted (scenario_id, snapshot_id); events notify dashboards      │
   └───────────────────────────────────────────────────────────────────────────────┘
                deterministic core is the shared evaluator for layers 2 & 3
```

- **Deterministic core** = the single source of computed truth; everything above calls it.
- **Monte Carlo** = "how risky?" (uncertainty around a fixed decision).
- **Optimization** = "what should we choose?" (best decision under constraints).
- **Agent Debate** = "what do we do, and why?" (judgment, trade-offs, consensus, human escalation).
- **Reproducibility** threads through all: every layer's output is keyed to `(scenario, snapshot, seed)`.

---

## 8. Mapping — modules ↔ platform

| Sim module | Domain aggregate (02) | Service (01 §5) | Bounded context |
|---|---|---|---|
| M-BOM | BillOfMaterials, Ingredient | Product/Recipe svc | Product & Recipe |
| M-CAPEX | Capex, Strategy | Manufacturing svc | Manufacturing & Capacity |
| M-DEMAND | Market | Demand svc | Demand & Market |
| M-COMP | Competitor | Intelligence svc | Competitive Intelligence |
| M-PNL | RevenueProjection, ExpensePlan | Finance svc | Finance & P&L |
| M-WC | WorkingCapital | Finance svc | Finance & P&L |
| M-FUND | FundingRound | Financing svc | Capital & Financing |
| M-RET | Valuation | Valuation svc | Valuation & Returns |
| Monte Carlo / Optimization / Debate | (cross-cutting) | Simulation + Decision svc | Scenario & Simulation |

---

*End of 05_SIMULATION_ENGINE.md — the simulation engine for the Valencia Nutracare Decision Platform, derived from BUSINESS_ONTOLOGY.md.*
