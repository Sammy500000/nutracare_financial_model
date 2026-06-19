# BUSINESS ONTOLOGY — Valencia Nutracare Lifesciences (VNL)

**Source workbook:** `Copy of 22 Cr Nutracare Project.xlsx`
**Authored by:** Chief Systems Architect analysis
**Status:** Master reference document for the entire project
**Scope:** Complete semantic, structural, and financial model of the workbook — every sheet, metric, dependency, formula, assumption, gap, entity, and process.

---

## 0. How to read this document

This file is the **single source of truth** for what the Nutracare financial model *means*. It is organized in five layers:

1. **Business model overview** — what the company is doing and why the model exists.
2. **Data entities (the ontology core)** — the nouns of the business and where they live.
3. **Processes** — business, decision, and forecasting processes (the verbs).
4. **Sheet-by-sheet analysis** — for all 30 sheets: purpose, metrics, dependencies, formulas, assumptions, missing info.
5. **Dependency graph + data-integrity register** — how sheets feed each other and where the model is currently broken.

Throughout, monetary values are in **Indian Rupees**; `Cr` = crore = 10,000,000 (10⁷); `10^7` in formulas converts rupees → crore.

---

## 1. Business Model Overview

**Valencia Nutracare Lifesciences (VNL / VNLS)** is launching a portfolio of **maternal and infant/child nutrition powders** in India. The workbook is a **5-year integrated financial model** that simulates a phased, capital-staged scale-up from contract manufacturing to owned plants.

### 1.1 Product universe (4 families × 3 tiers)

| Family | Code | Box size | Tier 1 brand | Tier 2 brand | Tier 3 brand |
|---|---|---|---|---|---|
| Pregnancy Powder | PP | 500 g | Wonder Womb | Matrunayana | Garbhika |
| Lactation Powder | LP | 500 g | Lacto Love | Milknest | Matrusneha |
| Infant Nutrition / Formula | IFP / IFM | 400 g | Alpha Baby | Healthy Cubs | Poshit |
| Child Nutrition Powder | CNP / CP | 400 g | Little Vita GOLD | Little Vita PRO | Little Vita CHINDI |

- **Natal Care** = Pregnancy + Lactation (500 g boxes).
- **Infant & Child Care** = Infant + Child (400 g boxes).
- **Tiers** map to market segments: **Tier 1** = Metro / premium / institutional; **Tier 2** = Mid cities; **Tier 3** = Small towns / mass / value.

### 1.2 The three-phase scale-up (the spine of the model)

| | Year 1 | Year 2 | Year 3 | Year 4 | Year 5 |
|---|---|---|---|---|---|
| **Investor capital deployed** | ₹22 Cr | ₹60 Cr | ₹220 Cr | — | — |
| **Tiers targeted** | Tier 3 | Tier 1 & 3 | All tiers | All tiers | All tiers |
| **SKUs** | 4 | 14 | 24 | 24 | 24 |
| **Manufacturing** | Contract | In-house + Third Party | In-house + Third Party | … | … |
| **New plants** | 0 | 1 | 2 | 3 | 3 |
| **Cumulative plants** | 0 | 1 | 3 | 6 | 9 |

Total investor capital across rounds = **₹302 Cr** (`Project Financing`!O19). The "22 Cr" in the filename is **only the Year-1 seed round**.

### 1.3 The economic engine (one line)

> **Recipe (BOM) → cost/box → boxes/batch → capacity × working-efficiency × tier-mix → boxes/year → × selling price → Revenue → − COGS → Gross Profit → − Indirect Expenses → EBITDA → − D&A → EBIT → − Interest → PBT → − Tax → PAT → feeds capital structure, returns, and working capital.**

---

## 2. Data Entities (Ontology Core)

These are the 14 first-class business entities requested, each mapped to its physical location, key attributes, and relationships.

### 2.1 `Product`
- **Where:** `Product Line` (catalogue + SKU counts by year/tier), `Strategy`, every revenue/BOM sheet.
- **Attributes:** family (PP/LP/IFP/CNP), tier (1/2/3), trimester/age-stage variant, flavour, brand name, box size (400/500 g), MRP, selling price, cost/box, GST class (18%).
- **Identity:** a *SKU* = family × tier × (trimester | age-stage) × flavour. SKU count grows 4 → 14 → 24 as variants/tiers activate.
- **Relations:** `Product` *is produced from* `BOM`; *sold into* `Market`/Tier; *generates* `Revenue`; *consumes* `Ingredient`.

### 2.2 `Ingredient`
- **Where:** the BOM sheets (`PP BOM`, `LP BOM`, `IFM BOM`, `CNP BOM`, `Infant Complementary BOM`).
- **Attributes:** ingredient name, quantity per 100 g, quantity per box (×4 or ×5), rate/kg, rate/gram, rate/box.
- **Examples:** Skimmed Milk Powder, Maltodextrin, Fructooligosaccharides, Whey Powder, DHA/ARA oil powders, Vitamin & Mineral premixes, Soy/Rice protein, Cocoa, Ragi, Jaggery, flavours.
- **Relations:** `Ingredient` *is a component of* `BOM`; rate changes drive cost/box and therefore Gross Margin.

### 2.3 `BOM` (Bill of Material)
- **Where:** `PP BOM`, `LP BOM`, `IFM BOM`, `CNP BOM`, `Infant Complementary BOM`.
- **Attributes:** ingredient list + quantities, raw-material subtotal, packaging cost, conversion cost, **total cost/box**, production cost/batch (₹2 Cr fixed), **boxes/batch** = batch cost ÷ cost/box.
- **Key outputs:** Cost/Box — PP **178.59**, LP **158.84**, IFP **124.18**, CNP **121.88** (₹). Conversion cost is pulled from `Contract (1 yr)` (₹7/box natal, ₹11.2/box infant); packaging is ₹12–20/box.
- **Relations:** `BOM` *defines* `Product` cost → feeds `Total Production`, `Contract (1 yr)`, COGS in `P&L`.

### 2.4 `Competitor`
- **Where:** `Competitor Brands` (hidden).
- **Attributes (as % of revenue / margins):** advertising, brand building, doctor detailing, employee benefits, channel commissions, logistics, legal/FSSAI, IT, R&D, gross margin, EBITDA margin, "₹ spent to earn ₹1".
- **Instances:** **HealthKart, Kapiva, OZiva, Wellbeing Nutrition**, plus an **"Early Stage Guide"** benchmark band.
- **Relations:** benchmark source for `Expense` ratios and `Strategy` plausibility; not formula-linked (reference/validation only).

### 2.5 `Hospital`
- **Where:** implicit in `Indirect Expenses` → *HCP Detailing & Medical Engagement* and its `IE Biffurcation` line items ("Hospital & Nursing home tie-ups").
- **Attributes:** detailing spend %, institutional channel (Tier 1).
- **Relations:** a distribution/endorsement channel; spend scales with revenue and is **mandatory** where consumer ads are banned (see IMS Act, §6.1).

### 2.6 `Doctor` (HCP — Health-Care Professional)
- **Where:** `Indirect Expenses` (HCP Detailing rows 10–14, 57) and `IE Biffurcation` ("OBGYN, Gynecologist, Pediatrician detailing", "Lactation Consultant & Dietitian programs", "KOL").
- **Attributes:** detailing % per tier/product, KOL/influencer spend.
- **Relations:** prescription/recommendation driver; the **primary demand lever for infant formula** (consumer advertising is legally restricted).

### 2.7 `Inventory` / Working Capital
- **Where:** `WC (Year 1)`, `WC (Year 2)`, `WC (Year 3-5)`, `WC (Year 3)` (legacy).
- **Attributes:** monthly boxes produced, cost/box, revenue/box, monthly indirect expense, cash outflow, cash inflow, opening/closing working capital, **W.C. rotation** = annual revenue ÷ initial working capital.
- **Relations:** `Inventory`/WC is funded by `Funding Round`; sizes the capital requirement in `Project Financing`; rotation measures capital efficiency.

### 2.8 `Funding Round`
- **Where:** `Strategy` (capital by year), `Total Production` (Year-1 split), `Year 2`, `Year 3`, `Project Financing` (O14:O18), `Contract (1 yr)`.
- **Instances:** **₹22 Cr (Y1)**, **₹60 Cr (Y2)**, **₹220 Cr (Y3)** — total ₹302 Cr.
- **Attributes:** amount, year, intended use (production vs marketing vs capex vs WC), source (Investor raise vs VNL own funds vs debt).
- **Relations:** a `Funding Round` *finances* `Capex` + `Inventory`/WC; structured by the financing-mix rules in `Project Financing`.

### 2.9 `Market`
- **Where:** `Strategy` (tiers targeted), `In-house (2-5yrs)` SAM table (rows 36–40), `Revenue Breakup` (tier/product mix), `Competitor Brands`.
- **Attributes:** Tier definition, **SAM (Serviceable Addressable Market) share by product × tier** (e.g. PP Tier 3 = 89.73%, Tier 1 = 4.47%, Tier 2 = 5.8%), tier mix of revenue.
- **Relations:** `Market` SAM % drives the **BPH (Boxes-Per-Hour) allocation** per tier, which drives production and revenue.

### 2.10 `Revenue`
- **Where:** `Contract (1 yr)` (Y1), `In-house (2-5yrs)` + `Third Party (2-5yrs)` (Y2-5), aggregated in `P&L` rows 6–33, decomposed in `Revenue Breakup`.
- **Attributes:** revenue/box, boxes/year, gross revenue, per-product per-tier breakup, revenue growth %.
- **Formula spine:** `Revenue = Boxes/Year × Selling Price/Box`; Year-1 = `Contract (1 yr)`!E27 (₹88.41 Cr).
- **Relations:** top line of `P&L`; basis for percentage-of-revenue `Expense` lines and `Valuation`.

### 2.11 `Expense`
- **Where:** `Indirect Expenses` (master, tier × product × year), `IE Biffurcation` (granular % drivers), `P&L` rows 36–66, `Contract (1 yr)` (Y1 indirect breakup).
- **Categories:** COGS; Marketing & Advertising; HCP Detailing & Medical Engagement; Distribution & Logistics (₹9/box Y1-2, ₹8.5/box Y3+); R&D/Regulatory/Compliance; G&A/Operations; Employee Cost; **Contingency (5% of indirect)**.
- **Relations:** `Expense` reduces `Revenue` → EBITDA → PAT; many lines are %-of-tier-revenue, so they *depend on* `Revenue Breakup`.

### 2.12 `Valuation` / Returns
- **Where:** `Project NPV, PI & EVA`, `ROCE & RONW`, `IRR & Payback Period`.
- **Metrics:** NPV, Profitability Index (PI), Economic Value Added (EVA), ROCE, ROE/RONW, WACC, NOPAT, IRR, Payback Period, Discounted Payback Period.
- **Key parameters:** Ke = **10.8%**, Kd = **12%** (9% post-tax), Tax = **25%**, machine life = 7 yrs, evaluation horizon = 7 yrs.
- **Relations:** consumes `P&L` (PAT/EBIT) + `Project Financing` (capital) + `Debt Schedule`. **⚠ Currently broken** — see §8.

### 2.13 `Strategy`
- **Where:** `Strategy` (the executive summary sheet) + `Index`.
- **Attributes:** per-year tier targeting, capital deployed, SKU count, manufacturing mode, plant build-out.
- **Relations:** the **control panel / scenario header**; its cells are formulas pulling from `Product Line` and `In-house (2-5yrs)`, so it reflects (does not drive) the operational sheets.

### 2.14 `Scenario`
- **Where:** encoded as the **Year-1 / Year-2 / Year-3 funding-stage structure** (`Index`, `Total Production`, `Year 2`, `Year 3`, the three `WC` sheets) and capacity ramps (`In-house (2-5yrs)` rows 104–116).
- **Attributes:** funding amount, working-efficiency % per quarter (80% Y1-2 → 100% Y3+), own-brand vs contract split (75/25), plant additions.
- **Relations:** a `Scenario` is a *coherent set of assumptions per phase*; switching scenarios = editing the capacity %, capital, and plant-count drivers.

---

## 3. Business Processes

| # | Process | Where modelled | Trigger → Output |
|---|---|---|---|
| BP-1 | **Product formulation** | BOM sheets | Ingredient recipe → cost/box |
| BP-2 | **Procurement / costing** | BOM (rate/kg) | Ingredient rates → raw-material cost |
| BP-3 | **Manufacturing — contract** | `Contract (1 yr)` | Tons/day → boxes/year (Y1) |
| BP-4 | **Manufacturing — in-house** | `In-house (2-5yrs)` | Plant capacity × efficiency → boxes/year |
| BP-5 | **Manufacturing — third party** | `Third Party (2-5yrs)` | Contract-mfg share (25%) → boxes/year |
| BP-6 | **Sales & tier allocation** | SAM table + Revenue Breakup | SAM % → BPH per tier → revenue mix |
| BP-7 | **Marketing & HCP detailing** | `Indirect Expenses`, `IE Biffurcation` | %-of-revenue → spend, IMS-Act-constrained |
| BP-8 | **Distribution & logistics** | `Indirect Expenses` (₹/box) | Boxes × ₹9/8.5 → logistics cost |
| BP-9 | **Working-capital management** | `WC (Year 1/2/3-5)` | Monthly CO/CI → WC requirement & rotation |
| BP-10 | **Capex / plant build-out** | `Capex & Depreciation` | Plants added → land+machinery+depreciation |
| BP-11 | **Financial reporting** | `P&L` | Consolidate revenue & expense → PAT |

## 4. Decision Processes

| # | Decision | Driver cells | Lever |
|---|---|---|---|
| DP-1 | **How much capital to raise each round** | `Strategy`!I7:M7 (22/60/220) | Funding amount per phase |
| DP-2 | **Which tiers to enter when** | `Strategy`!I6:M6 | Tier sequencing (T3 → T1&T3 → all) |
| DP-3 | **Make vs buy (in-house vs contract/3P)** | `In-house`!C115:G116 (75/25 split) | Own-brand vs contract-mfg ratio |
| DP-4 | **When to add plants** | `In-house`!C3:C7 (0,1,2,3,3) | Plant-addition schedule |
| DP-5 | **Capital structure (equity/debt mix)** | `Project Financing`!C13:J13 | Capex 15/85 (Y1-3), 25/75 (Y4-5); WC 10/90 (Y4-5) |
| DP-6 | **Surplus-cash deployment** | `Project Financing`!S13 (25%), U13 (6%) | % of free cash → fixed deposits |
| DP-7 | **Pricing (MRP & selling price by tier)** | `In-house`!C91:C102, `Total Production`!C20:C23 | Selling price per SKU/tier |
| DP-8 | **Marketing-spend allocation** | `IE Biffurcation` tier × line grid | %-of-revenue per tier/line/year |

## 5. Forecasting Processes

| # | Forecast | Method | Where |
|---|---|---|---|
| FP-1 | **Revenue forecast** | Bottom-up: capacity × efficiency × tier-mix × price | `In-house`/`Third Party` → `P&L` |
| FP-2 | **Capacity ramp** | Working-efficiency % per quarter (80% → 100%) | `In-house`!C104:L116 |
| FP-3 | **Cost forecast** | BOM-driven cost/box held constant × volume | BOM → COGS |
| FP-4 | **Indirect-expense forecast** | %-of-tier-revenue grid + ₹/box logistics | `IE Biffurcation` → `Indirect Expenses` |
| FP-5 | **Working-capital forecast** | Monthly cash-flow rotation simulation | `WC` sheets |
| FP-6 | **Capex/depreciation forecast** | Plants × per-plant cost; 15% reducing-balance | `Capex & Depreciation` |
| FP-7 | **Financing & debt forecast** | Mix rules + retained earnings + FD interest | `Project Financing`, `Debt Schedule` |
| FP-8 | **Returns forecast** | DCF (NPV/IRR/PI), EVA, ROCE/ROE | `Project NPV…`, `IRR…`, `ROCE…` |

---

## 6. Sheet-by-Sheet Analysis (all 30 sheets)

> Legend: **(V)** visible, **(H)** hidden. Cross-references use `Sheet`!Cell.

### 6.1 `Index` (H)
1. **Purpose:** Table of contents / navigation map of the workbook.
2. **Metrics:** none — labels only (BOM list, P&L, "22Cr Summary", Year 1/2/3 sub-pages).
3. **Dependencies:** none (static text).
4. **Formulas:** none.
5. **Assumptions:** documents the 3-stage structure (22Cr / 60Cr / "Plant @100% efficiency").
6. **Missing:** several index items (e.g. "22Cr Summary Sheet") have no corresponding live sheet.
7. **Entities:** `Product`, `Funding Round`, `Scenario`.
8/9/10. Documents BP/DP/FP structure at a glance.

### 6.2 BOM sheets — `PP BOM`, `LP BOM`, `IFM BOM`, `CNP BOM`, `Infant Complementary BOM` (H)
1. **Purpose:** Compute **cost per box** for each product family from an ingredient recipe; derive boxes per ₹2 Cr batch. `Infant Complementary BOM` is the complementary-food (weaning) variant.
2. **Metrics:** Quantity/100 g, Quantity/box (×5 for 500 g, ×4 for 400 g), Rate/kg, Rate/gram, Rate/box, Raw-material total, Packaging cost, Conversion cost, **Total cost/box**, Production cost/batch (₹2 Cr), **Boxes/batch**, Boxes/variant.
3. **Dependencies:** Conversion cost ← `Contract (1 yr)`!C43/C51. Outputs → `Total Production`!C9:F9, `Year 2`, `Year 3`.
4. **Formulas:** `E=D*5` (or ×4); `G=F/1000`; `H=E*G`; `Total = SUM(H...)+packaging+conversion`; `Boxes/batch = batchcost / cost/box`.
5. **Assumptions:** 100 g recipe = full box content; ₹2 Cr batch cost is uniform; 500 g for natal, 400 g for infant/child; flavour variants (Kesar Pista, Chocolate, Vanilla) share one recipe.
6. **Missing:** GST-inclusive cost cells (`Total Cost (Incl. GST)`) mostly blank; "AS PER PROJECTIONS SHEET" cross-checks reference **external Google Sheets via IMPORTRANGE** and resolve to `#REF!`.
7. **Entities:** `Ingredient`, `BOM`, `Product`.
8/9/10. BP-1, BP-2 (formulation & procurement costing).
- **Key cost/box outputs:** PP 178.59 · LP 158.84 · IFP 124.18 · CNP 121.88 · Infant Complementary 99.51 (₹).

### 6.3 `Total Production` (H)
1. **Purpose:** Year-1 "Early Stage Fund" production master — converts the ₹22 Cr seed into batches, boxes, revenue, and gross profit; also holds the **TRIO FIT machine working-capacity** engineering notes.
2. **Metrics:** Funding split (Natal 11 + Infant/Child 11 = 22 Cr), cost/box (← BOMs), boxes/batch, selling price, revenue/batch, COGS/batch, gross profit/batch, total boxes (563,051), avg cost/box, production-capacity days, 1-day capacity.
3. **Dependencies:** ← all 4 BOMs; → `Contract (1 yr)`!C2,C5:F5,C20:C23.
4. **Formulas:** `Boxes/Batch = ROUND(batch/cost,0)`; `Revenue/Batch = price × boxes`; capacity = blender L × density × efficiency.
5. **Assumptions:** 2 production cycles/year; ₹8 Cr production + ₹3 Cr marketing per half; 300 kg/batch; bulk density 0.4.
6. **Missing:** `C30` Marketing Expense = `#REF!` → EBITDA (C31) and Batch-2 funds (C34) broken; `C60:C65` source/application = `#REF!`.
7. **Entities:** `Funding Round`, `Product`, `Revenue`, `Scenario`.
8/9/10. BP-3, FP-1, FP-3 for Year 1.

### 6.4 `Strategy` (V)
1. **Purpose:** One-screen executive summary of the 5-year plan (the scenario header).
2. **Metrics:** Tiers targeted, investor capital (22/60/220/0/0 Cr), SKUs (4/14/24/24/24), manufacturing mode, plants set up & cumulative (0/1/3/6/9).
3. **Dependencies:** SKUs ← `Product Line`!C4/C10/C26; plants ← `In-house (2-5yrs)`!C3:C7.
4. **Formulas:** `I8='Product Line'!C4`; `Total Plants Iₙ = Iₙ + prev`.
5. **Assumptions:** capital only in Years 1-3; SKUs flat at 24 from Y3.
6. **Missing:** no explicit revenue/EBITDA targets per phase (would make it a true dashboard).
7. **Entities:** `Strategy`, `Funding Round`, `Scenario`, `Market`.
8/9/10. DP-1, DP-2, DP-4.

### 6.5 `Product Line` (V)
1. **Purpose:** Canonical SKU catalogue per year + tier, plus brand-name master per family/tier.
2. **Metrics:** SKU counts (`COUNTA`) — Y1=4, Y2=14, Y3-5=24; tier code per SKU; brand names.
3. **Dependencies:** feeds `Strategy`!I8:K8.
4. **Formulas:** `=COUNTA(range)` per year block.
5. **Assumptions:** SKUs vary year-to-year via added flavours (1-2 per variant); trimester split for pregnancy; age-stage split for infant (0-6/6-12/12-24 m).
6. **Missing:** flavour-level SKUs not individually costed; no per-SKU price/volume here.
7. **Entities:** `Product`, `Market`.
8/9/10. Defines the `Product` dimension used by every revenue sheet.

### 6.6 `P&L` (V)
1. **Purpose:** Consolidated 5-year Profit & Loss statement — the financial spine.
2. **Metrics:** Revenue from Operations (per product × tier), Other Income, Total Revenue, Revenue Growth %, COGS, Gross Profit Margin %, Indirect Expenses (Marketing, HCP, Distribution, R&D, G&A, Employee, Contingency 5%), Total Expenses, **EBITDA & margin**, D&A, EBIT, Financial Costs, PBT, Tax (25%), **PAT & Net margin**.
3. **Dependencies:** Y1 ← `Contract (1 yr)`; Y2-5 ← `In-house (2-5yrs)` + `Third Party (2-5yrs)`; expenses ← `Indirect Expenses`; D&A ← `Capex & Depreciation`; interest ← `Debt Schedule`; other income ← `Project Financing`.
4. **Formulas:** `Total Revenue = Operations + Other Income`; `EBITDA = Revenue − Total Expenses`; `Tax = IF(PBT>0, PBT×25%, 0)`; `PAT = PBT − Tax`.
5. **Assumptions:** flat 25% tax; 5% contingency; D&A excluded from EBITDA then subtracted for EBIT.
6. **Missing / broken:** Year 2-5 columns are largely **`#REF!`** because in-house selling prices (`In-house`!D91/D97) come from broken IMPORTRANGE. **Year-1 column is the only fully computed year** (Revenue 88.41 Cr, EBITDA 13.50 Cr, PAT 10.12 Cr). Note this sheet is named **`P&L`**, but return sheets look for **`Profit & Loss Ac`** (does not exist) — see §8.
7. **Entities:** `Revenue`, `Expense`, `Valuation`.
8/9/10. BP-11, FP-1, FP-4.

### 6.7 `Competitor Brands` (H)
1. **Purpose:** Benchmark VNL's cost structure against listed/established D2C nutrition brands.
2. **Metrics (% of revenue / margins):** advertising, brand building, doctor detailing, employee benefits, channel commission, logistics, legal/FSSAI, IT, rent, R&D, gross margin, EBITDA margin, "₹ to earn ₹1".
3. **Dependencies:** none (reference data, mostly text like "~38%").
4. **Formulas:** minimal (one `=+6%`).
5. **Assumptions:** R&D 1.5-2× higher for infant formula; early-stage brands run negative EBITDA (-30 to -50%).
6. **Missing:** values stored as text strings ("~38%") so they are **not machine-usable**; no direct linkage into the model.
7. **Entities:** `Competitor`, `Expense`, `Market`.
8/9/10. Validation input for DP-8 and the `Expense` assumptions.

### 6.8 `Revenue Breakup` (V)
1. **Purpose:** Decompose total revenue into product × tier shares and % mix; produce the tier/product weightings used to allocate marketing spend.
2. **Metrics:** revenue per SKU (× tier), % of total, Tier-1/2/3 subtotals, per-family mix %, average mix.
3. **Dependencies:** ← `P&L`!C6:G31; → `Indirect Expenses` (the `Revenue Breakup`!C36:G40 ratios drive per-product marketing).
4. **Formulas:** `D=C/$C$3` (share of revenue); `Tier = SUM(...)`; `VALUE(SUBSTITUTE(...,"%",""))` to coerce.
5. **Assumptions:** Year-1 is 100% Tier 3 (matches Strategy); mix derived purely from P&L.
6. **Missing / broken:** Years 2-5 are **`#REF!`** (inherit from P&L breakage). Creates a **circularity risk**: `Indirect Expenses` depends on `Revenue Breakup`, which depends on `P&L`, whose expenses depend on `Indirect Expenses`.
7. **Entities:** `Revenue`, `Market`, `Expense`.
8/9/10. FP-1, BP-6, feeds FP-4.

### 6.9 `Indirect Expenses` (V) — 1,759 cells, the expense engine
1. **Purpose:** Tier × product × year grid of all non-COGS operating expenses.
2. **Metrics:** Marketing & Advertising, HCP Detailing & Medical Engagement, Distribution & Logistics, R&D/Regulatory/Compliance, G&A/Operations, Employee Cost — each split Tier 1/2/3 × Year 1-5 × product family.
3. **Dependencies:** % drivers ← `IE Biffurcation`; revenue weights ← `Revenue Breakup`; logistics uses box counts; rolls up into `P&L`!C40:G63.
4. **Formulas:** `=VALUE(SUBSTITUTE('IE Biffurcation'!cell,"%",""))` to pull %; `spend = %_tier × (RevenueBreakup product share / total)`; logistics = `₹9 or 8.5 × boxes`.
5. **Assumptions:** Marketing as % of *tier net revenue*; logistics ₹9/box (Y1-2) → ₹8.5/box (Y3+); IMS-Act prohibition (Tier 1 infant-formula consumer ads = 0).
6. **Missing / broken:** pervasive **`#REF!`** (264 cells) from the revenue cascade; Tier-1/Tier-2 spends are 0 in Year 1 by design (Tier-3-only launch).
7. **Entities:** `Expense`, `Doctor`, `Hospital`, `Market`.
8/9/10. BP-7, BP-8, FP-4, DP-8.

### 6.10 `Contract (1 yr)` (V) — Year-1 operating model
1. **Purpose:** Full Year-1 P&L-feeder under **contract manufacturing** funded by the ₹22 Cr round.
2. **Metrics:** cost/box, selling price, profit/box, tons/day (5), boxes/day (11,250), working days/year (312), boxes/year, revenue (in Cr), COGS, gross profit, working-capital draw, conversion charges (₹35k/day ÷ 5,000 boxes = ₹7/box natal; ₹70k ÷ 6,250 = ₹11.2/box infant), sources & application of funds, indirect-expense breakup.
3. **Dependencies:** ← `Total Production`, `WC (Year 1)`, BOMs; → `P&L`!C6,C27:C30,C36; → BOM conversion costs.
4. **Formulas:** `Boxes/Year = (days × boxes/day)/2`; `Revenue = boxes × price`; conversion/box = charges/day ÷ boxes/day.
5. **Assumptions:** 2 factories (Rohan Sir's 2 t/day + another 4 t); 26 working days × 12 months; product split 50/50 by weight; ₹9/box logistics; 10% contingency.
6. **Missing:** assumes a second factory exists ("Assuming another factory will have 4 tons"); `D32:D34` reference blank cells.
7. **Entities:** `Revenue`, `Expense`, `Funding Round`, `Inventory`, `Product`.
8/9/10. BP-3, FP-1 for Year 1 — **the most complete, working part of the model.**

### 6.11 `In-house (2-5yrs)` (V) — 855 cells, the Year-2-5 production/revenue engine
1. **Purpose:** Model owned-plant production and revenue for Years 2-5: capacity → tier allocation (via SAM) → boxes → revenue.
2. **Metrics:** new/total plants, working capacity, gross revenue/COGS/gross profit, **BPH (Boxes Per Hour) per tier per product**, SAM % (Tier 1/2/3 per family), MRP & selling/cost/profit per box per tier, quarterly working-capacity %, own-brand (75%) vs contract (25%) split, quarterly revenue table.
3. **Dependencies:** plants ← itself/`Capex`; SAM table (rows 36-40); → `P&L` (D6:G6, COGS), `Third Party`, `Capex`, `Strategy`.
4. **Formulas:** `Boxes/Year = minutes/year × BPH × capacity`; `BPH_tier = ROUND(SAM% × total BPH,0)`; capacity = blended ramp of plant-add years.
5. **Assumptions:** 40,000 kg/day/plant, 25 days × 7 months, 16 h/day; capacity 80% (Y1-2) → 100% (Y3+); 75/25 own/contract; SAM Tier-3-heavy (≈88-92%).
6. **Missing / broken:** **Selling prices `D91` & `D97` come from broken IMPORTRANGE → `#REF!`**, which zeroes/breaks all in-house revenue and cascades into `P&L`, `Revenue Breakup`, `Indirect Expenses`. This is the **single most damaging break in the model.**
7. **Entities:** `Product`, `Market`, `Revenue`, `Scenario`.
8/9/10. BP-4, BP-6, FP-1, FP-2.

### 6.12 `Third Party (2-5yrs)` (V)
1. **Purpose:** Model the **25% contract-manufactured** share of Years 2-5 volume/revenue (VNL's only cost = processing charges).
2. **Metrics:** plants, working capacity (contract share), boxes per tier/product, gross revenue; mirrors In-house BPH/SAM tables.
3. **Dependencies:** ← `In-house (2-5yrs)` (BPH, capacity %, contract split C116); → `P&L`!D6:G6 / D31:G31.
4. **Formulas:** `Boxes = minutes/year × BPH × capacity`; capacity = cumulative contract-share blend.
5. **Assumptions:** identical BPH/SAM to in-house; selling prices via IMPORTRANGE.
6. **Missing / broken:** selling prices `C63`, `C69` = **`#REF!`** (IMPORTRANGE) → gross revenue `R4:R7` = `#REF!`.
7. **Entities:** `Product`, `Revenue`, `Market`.
8/9/10. BP-5, FP-1.

### 6.13 `IE Biffurcation` (V) — 560 cells
1. **Purpose:** The granular **% driver matrix** behind `Indirect Expenses`: every spend line × tier × year.
2. **Metrics:** %-of-tier-net-revenue for ~30 line items grouped under Marketing, HCP, Distribution, R&D, G&A, Employee — laid out Tier 3 / Tier 2 / Tier 1 × Year 1-5.
3. **Dependencies:** consumed by `Indirect Expenses` via `SUBSTITUTE/VALUE`.
4. **Formulas:** mostly hard-coded % inputs (e.g. 0.03, "-"); group subtotals.
5. **Assumptions:** Tier-3 front-loaded trial spend; Tier-1 infant-formula consumer ads = "-" (IMS Act); 3 brand budgets from Year 3.
6. **Missing:** "-" placeholders are treated as 0 downstream; some line items lack notes.
7. **Entities:** `Expense`, `Market`, `Doctor`, `Hospital`.
8/9/10. DP-8, FP-4 — the **assumption book for opex.**

### 6.14 Working-capital sheets — `WC (Year 1)` (V), `WC (Year 2)` (V), `WC (Year 3-5)` (V), `WC (Year 3)` (H, legacy)
1. **Purpose:** Size working capital via a **month-by-month cash-flow rotation** per product; `WC (Year 3)` is a superseded earlier version (hidden).
2. **Metrics:** monthly boxes, cost/box, revenue/box, monthly indirect expense, monthly cash outflow & inflow, difference, opening/net/closing WC, **initial working capital**, **W.C. rotation = annual revenue ÷ initial WC**, application split (production vs indirect).
3. **Dependencies:** ← `Contract (1 yr)`, `Total Production`, `Indirect Expenses`, BOMs; → `Contract (1 yr)`!C30:C34, `Project Financing`!N4:N6, `Year 2`/`Year 3`.
4. **Formulas:** `CO = boxes×cost + indirect`; `CI = boxes×price`; `Closing = Opening + (CI−CO)`; initial WC seeded from first-month outflow.
5. **Assumptions:** uniform monthly production; 3.5× safety multiplier on production application (`H=(boxes×cost)×3.5`); rotation as the efficiency KPI.
6. **Missing / broken:** `WC (Year 2)` & `WC (Year 3-5)` carry **307 `#REF!`** each (downstream of price breaks); `WC (Year 3)` is stale/duplicative.
7. **Entities:** `Inventory`, `Funding Round`, `Revenue`, `Expense`.
8/9/10. BP-9, FP-5.

### 6.15 `Year 2` (H) & `Year 3` (H)
1. **Purpose:** Phase work-pages for the ₹60 Cr (Y2) and ₹220 Cr / "100% efficiency" (Y3) rounds — production, WC delta, capex, and indirect-expense breakups per round.
2. **Metrics:** funding (60 / —), cost/box (← BOM "incl-projection" cells), boxes, revenue, fresh WC needed (Y2 vs Y1), plant capex table, capacity %, indirect-expense bifurcation.
3. **Dependencies:** ← BOMs (`H32`/`H35`/`H39` projection cells — broken), `WC` sheets, `Contract (1 yr)`, `Capex`.
4. **Formulas:** mirror `Contract (1 yr)` but at 40 t/day; `Fresh capital = WCₙ − WCₙ₋₁`.
5. **Assumptions:** Y2 40 t/day; 25×12 days; own/contract split via capacity sheet.
6. **Missing / broken:** cost/box cells = **`#REF!`** (reference non-valued BOM projection cells + IMPORTRANGE); capex table imported via IMPORTRANGE = `#REF!`; 35 (Y2) / 42 (Y3) error cells.
7. **Entities:** `Funding Round`, `Scenario`, `Inventory`, `Product`.
8/9/10. FP-1/3/5 per phase.

### 6.16 `Capex & Depreciation` (V)
1. **Purpose:** Cost each new plant (land + machinery + contingency) and compute depreciation.
2. **Metrics:** new plants/year, Land & Construction, Machinery, Misc & Contingency, **Total Capex/year**; per-plant cost build (₹23.94 Cr); land sizing (3 acres, 70% constructible, ₹120/sq ft land, ₹800/sq ft shed → ₹8.886 Cr); machinery list (FBD, blender, HVAC, sifter, sachet filler, lab…); **depreciation @ 15% reducing balance**.
3. **Dependencies:** plants ← `In-house`!C3:C7; → `P&L`!C71:G71 (D&A), `Project Financing`!N3, `Debt Schedule`.
4. **Formulas:** `Land = plants × 8.886`; `Machinery = (Total − Land − Misc − Contingency) × plants`; `Dep = Cumulative × 15%`.
5. **Assumptions:** machine life 7 yrs; ₹10 Cr contingency/plant; per-plant total can "go up to 16 Cr"; 15% WDV depreciation; FY labels 27-28 → 31-32.
6. **Missing:** no salvage value; straight 15% ignores asset-class differences; no working-life retirement.
7. **Entities:** `Capex`/fixed asset, `Scenario`.
8/9/10. BP-10, FP-6.

### 6.17 `Project Financing` (V)
1. **Purpose:** Determine **how capex + working capital are funded** each year (own funds / fund-raise / debt) and track retained earnings, surplus, fixed deposits, and free cash flow.
2. **Metrics:** new/total plants, WC, capex, total capital requirement, fixed asset, funding-mix %, retained earnings, capital funded (22/60/220), surplus capital, surplus retained earnings, FD (25% of FCF), cumulative FD, interest income (6%), free cash flow.
3. **Dependencies:** ← `Capex`, `WC` sheets, `P&L` (PAT+D&A); → `Debt Schedule`, `ROCE & RONW`, `Project NPV…`, `P&L` other income.
4. **Formulas:** Capex Y1-3 = 15% own / 85% raise; Y4-5 = 25% own / 75% debt; WC Y4-5 = 10% own / 90% debt; `FD = FCF × 25%`; `Interest = cumulative FD × 6%`.
5. **Assumptions:** surplus capital carried forward; Year-4 uses surplus first then debt; retained earnings reinvested.
6. **Missing / broken:** heavy **`#REF!`** (63) because WC inputs (`N5`,`N6`) and PAT (`N16:N18`) come from broken sheets; total raise O19 = 302 Cr survives.
7. **Entities:** `Funding Round`, `Valuation`, `Inventory`, `Capex`.
8/9/10. DP-5, DP-6, FP-7.

### 6.18 `Allocation` (H)
1. **Purpose:** Split capex & WC between equity- and debt-sourced funding (helper for ROCE/RONW capital base).
2. **Metrics:** capex, WC, total, capex sourced by equity, WC sourced by equity.
3. **Dependencies:** ← `Project Financing`!C/G 14-18.
4. **Formulas:** `=Capex × K4`, `=WC × K5` (split factors).
5. **Assumptions:** Year-1 100% equity-funded.
6. **Missing / broken:** split factors `K4`/`K5` are blank → `#VALUE!`/`#REF!`; sheet appears partially abandoned.
7. **Entities:** `Funding Round`, `Valuation`.
8/9/10. Supports FP-7.

### 6.19 `Project NPV, PI & EVA` (H)
1. **Purpose:** DCF valuation — NPV, Profitability Index, and Economic Value Added.
2. **Metrics:** cash outflows (capital), discount factor @ WACC, PV of outflows; cash inflows (PAT + D&A) over 7 years, PV of inflows; NPV; PI; NOPAT; WACC; EVA = NOPAT − (capital × WACC); Ke 10.8%, Kd 12%/9%.
3. **Dependencies:** ← `Project Financing` (H4:H8), `ROCE & RONW` (WACC), and **`Profit & Loss Ac`** (PAT/EBIT).
4. **Formulas:** `PV = CF / (1+WACC)^n`; `NPV = ΣPV_in − ΣPV_out`; `PI = (NPV + Investment)/Investment`; `EVA = NOPAT − capital×WACC`.
5. **Assumptions:** 7-year horizon; Years 6-7 repeat Year-5 inflow; Ke from benchmark "pg.3".
6. **Missing / broken:** references sheet **`Profit & Loss Ac` which does not exist** (actual sheet is `P&L`) → entire sheet `#REF!`. **All valuation outputs are currently non-functional.**
7. **Entities:** `Valuation`.
8/9/10. FP-8 (broken).

### 6.20 `Debt Schedule` (V)
1. **Purpose:** Track cumulative debt drawn for capex + WC and the annual interest expense.
2. **Metrics:** capex debt, WC debt, total, cumulative debt, **interest expense @ 12%**.
3. **Dependencies:** ← `Project Financing`!F/J 14-18; → `P&L`!C74:G74.
4. **Formulas:** `Cumulative = prior + new`; `Interest = cumulative × 12%`.
5. **Assumptions:** flat 12% cost of debt; interest-only (no principal-repayment schedule modelled); debt only from Year 4.
6. **Missing / broken:** later years `#REF!` (from financing breaks); **no amortization / repayment schedule** — debt never reduces.
7. **Entities:** `Funding Round` (debt), `Expense` (interest).
8/9/10. FP-7.

### 6.21 `ROCE & RONW` (H)
1. **Purpose:** Return on Capital Employed, Return on Equity/Net Worth, and WACC per year.
2. **Metrics:** Equity, Debt, Total Capital Employed, EBIT, PAT, WACC %, ROCE %, ROE %, Ke, Kd.
3. **Dependencies:** ← `Project Financing` (equity/debt), **`Profit & Loss Ac`** (EBIT/PAT), `Project NPV…` (Ke/Kd).
4. **Formulas:** `WACC = (E/CE)×Ke + (D/CE)×Kd`; `ROCE = EBIT/CE`; `ROE = PAT/Equity`.
5. **Assumptions:** Ke 10.8%, Kd 9% post-tax; capital employed = equity + cumulative debt.
6. **Missing / broken:** again references **`Profit & Loss Ac`** → `#REF!`; only Year-1 WACC (9%) computes.
7. **Entities:** `Valuation`, `Funding Round`.
8/9/10. FP-8 (broken).

### 6.22 `IRR & Payback Period` (H)
1. **Purpose:** Internal Rate of Return, simple Payback, and Discounted Payback.
2. **Metrics:** cash inflows/outflows, net cash flow, discount factor @ IRR, discounted CF, NPV check; payback = initial outflow ÷ annual inflow; discounted payback via cumulative discounted inflows.
3. **Dependencies:** ← `Project NPV…`, `Project Financing`, **`Profit & Loss Ac`**.
4. **Formulas:** `IRR` hard-coded **0.90598 (90.6%)**; `DF = 1/(1+IRR)^n`; payback interpolation.
5. **Assumptions:** IRR is a **manually pasted constant, not a live `IRR()` calculation** — it will not update if cash flows change.
6. **Missing / broken:** inflows reference `Profit & Loss Ac` → `#REF!`; the hard-coded 90.6% IRR is unverifiable and almost certainly stale.
7. **Entities:** `Valuation`.
8/9/10. FP-8 (broken + hard-coded).

---

## 7. Dependency Graph (calculation flow)

```
                 ┌─────────────┐
   Ingredient ─▶ │  BOM sheets │ ─▶ cost/box ─┐
                 └─────────────┘              │
                                              ▼
   Strategy / Scenario drivers ──▶  Total Production ──▶ Contract (1 yr)  [YEAR 1]
        (capital, tiers, plants)         │                     │
                                         │                     ▼
   Capex & Depreciation ◀── plants ──────┤              WC (Year 1) ──▶ Project Financing
        │   (D&A)                        │                                    │
        ▼                                ▼                                    ▼
   In-house (2-5yrs) + Third Party ─▶  P&L  ◀── Indirect Expenses ◀── IE Biffurcation
        │  [YEARS 2-5]                  │  ▲          ▲
        │                              │  │          │
        │                              ▼  │          │
        └────────── Revenue Breakup ───┘  └──────────┘   (revenue↔expense interplay)
                                         │
                                         ▼
                    Debt Schedule ─▶  [needs "Profit & Loss Ac"] ─▶ NPV/PI/EVA · ROCE/RONW · IRR/Payback
                                                  ⚠ BROKEN LINK
```

**Critical path:** `BOM → In-house prices → P&L → Returns`. Two breaks (missing `Profit & Loss Ac` sheet; broken IMPORTRANGE prices) sever this path for Years 2-5 and for **all** return metrics.

---

## 8. Missing Information & Data-Integrity Register

This section is **mandatory reading before trusting any output.** The model computes correctly for **Year 1 only**; Years 2-5 and all valuation metrics are currently broken.

### 8.1 Structural breaks (must fix first)

| Issue | Evidence | Impact |
|---|---|---|
| **Missing sheet `Profit & Loss Ac`** | 23 formulas in `Project NPV…`, `ROCE & RONW`, `IRR & Payback` reference it; the real sheet is named **`P&L`** | **All** NPV, PI, EVA, ROCE, ROE, IRR, payback = `#REF!` |
| **Broken IMPORTRANGE (external Google Sheets)** | 13 cells: `In-house`!D91/D97, `Third Party`!C63/C69, BOM "projection" cells, `Year 2` capex import | In-house & 3P **selling prices = `#REF!`** → Year 2-5 revenue/COGS/P&L/WC all break |
| **Cascade of `#REF!`** | ~2,000+ cached error cells: Indirect Expenses 264, Revenue Breakup 204, WC(Y2) 307, WC(Y3-5) 307, P&L 134, IRR 64, Project Financing 63, NPV 51 | Years 2-5 financials unusable until prices restored |
| **Hard-coded IRR** | `IRR & Payback`!C3 = `0.90598` (a constant, not `=IRR(...)`) | Will not react to cash-flow changes; 90.6% is implausibly high and likely stale |
| **No debt repayment schedule** | `Debt Schedule` computes interest only; cumulative debt never amortizes | Overstates interest, understates equity build |

### 8.2 Business information gaps

- **No demand/market-size model:** SAM % (Tier splits) are assumed, but there is no TAM→SAM→SOM funnel, population, penetration rate, or competitive-capture logic justifying volumes.
- **No balance sheet or cash-flow statement** (only P&L + financing fragments) — cannot verify solvency or true free cash flow.
- **Selling prices vs MRP:** MRP is listed per tier, but net selling prices for Years 2-5 depend on the broken import; the price–MRP–discount logic is external.
- **Customer / channel entities absent:** no modelling of distributors, e-commerce vs pharmacy split, returns, or credit period (WC uses a generic 3.5× multiplier instead).
- **Competitor data is text, not numeric** — cannot be used in calculations or sensitivities.
- **No scenario toggle / sensitivity tables** — scenarios are hard-edited drivers, not switchable cases.
- **`Allocation` sheet abandoned** — equity/debt split factors (`K4`,`K5`) blank.
- **Tax simplification** — flat 25%, no MAT, carry-forward losses, or depreciation-linked tax shield interplay.
- **No headcount build** behind Employee Cost; no inflation/escalation on ingredient rates or salaries across 5 years.

### 8.3 Assumption fragility

- Cost/box held **flat for 5 years** (no raw-material inflation).
- ₹2 Cr batch cost is uniform across all four products.
- "Second factory will have 4 tons" — capacity assumed, not contracted.
- 75/25 own/contract split and 80%→100% capacity ramp are planning assumptions, not validated.

---

## 9. Assumptions Register (key numeric inputs)

| Assumption | Value | Source |
|---|---|---|
| Investor rounds | 22 / 60 / 220 Cr (Y1/Y2/Y3) | `Strategy`!I7:K7 |
| Total capital | 302 Cr | `Project Financing`!O19 |
| Box sizes | 500 g (natal) / 400 g (infant·child) | BOMs, `Contract` |
| Batch cost | ₹2 Cr per product | BOMs `H27` etc. |
| Cost/box | PP 178.59 · LP 158.84 · IFP 124.18 · CNP 121.88 | BOMs |
| Y1 selling price | PP 280 · LP 286 · IFP 242 · CNP 212 | `Total Production`!C20:C23 |
| Conversion charge | ₹7/box (natal), ₹11.2/box (infant) | `Contract`!C43,C51 |
| Logistics | ₹9/box (Y1-2), ₹8.5/box (Y3+) | `Indirect Expenses`!C15 |
| Contingency | 5% of indirect (P&L); 10% (Y1 contract) | `P&L`!C64, `Contract`!D69 |
| Working schedule | 25-26 days/mo; 7 mo/yr (in-house), 12 (contract); 16 h/day | `In-house`!C25:C27 |
| Plant capacity | 40,000 kg/day | `In-house`!C30 |
| Capacity ramp | 80% (Y1-2) → 100% (Y3+) | `In-house`!C107:L110 |
| Own / contract split | 75% / 25% | `In-house`!C115:C116 |
| Per-plant capex | ₹23.94 Cr (land 8.886 + machinery + 10 contingency) | `Capex`!C26 |
| Depreciation | 15% reducing balance, 7-yr life | `Capex`!E39 |
| Cost of equity (Ke) | 10.8% | `Project NPV…`!H10 |
| Cost of debt (Kd) | 12% (9% post-tax) | `Project NPV…`!H11 |
| Tax rate | 25% | `P&L`!C77 |
| Capital-structure mix | Capex 15/85 (Y1-3), 25/75 (Y4-5); WC 10/90 (Y4-5) | `Project Financing`!C13:J13 |
| Surplus → FD | 25% of FCF @ 6% interest | `Project Financing`!S13,U13 |
| Evaluation horizon | 7 years | `Project NPV…`!B4 |

---

## 10. Year-1 Verified Headline Numbers (the only fully-computing year)

| Metric | Value |
|---|---|
| Revenue from Operations | ₹88.41 Cr |
| COGS | ₹50.31 Cr |
| Gross Profit Margin | 56.9% |
| Total Indirect Expenses + COGS | ₹74.92 Cr |
| EBITDA | ₹13.50 Cr (15.3% margin) |
| PAT | ₹10.12 Cr (11.4% margin) |
| Year-1 boxes | 3,510,000 |
| Initial Working Capital | ₹21.60 Cr |

*(Years 2-5 figures exist in the sheets but are `#REF!`-broken; do not cite them until §8.1 is remediated.)*

---

## Appendix A — Sheet inventory (30 sheets)

| # | Sheet | State | Role |
|---|---|---|---|
| 1 | Index | hidden | Navigation |
| 2 | Infant Complementary BOM | hidden | BOM (weaning food) |
| 3 | Total Production | hidden | Y1 production master |
| 4 | Year 2 | hidden | Y2 phase page |
| 5 | Year 3 | hidden | Y3 phase page |
| 6 | WC (Year 3) | hidden | Legacy WC (superseded) |
| 7 | PP BOM | hidden | BOM Pregnancy |
| 8 | LP BOM | hidden | BOM Lactation |
| 9 | IFM BOM | hidden | BOM Infant Formula |
| 10 | CNP BOM | hidden | BOM Child Nutrition |
| 11 | Product Line | visible | SKU & brand catalogue |
| 12 | Strategy | visible | Executive summary |
| 13 | P&L | visible | Consolidated P&L |
| 14 | Competitor Brands | hidden | Benchmarks |
| 15 | Revenue Breakup | visible | Revenue mix |
| 16 | Indirect Expenses | visible | Opex engine |
| 17 | Contract (1 yr) | visible | Y1 operating model |
| 18 | In-house (2-5yrs) | visible | Y2-5 production/revenue |
| 19 | Third Party (2-5yrs) | visible | Y2-5 contract mfg |
| 20 | IE Biffurcation | visible | Opex % drivers |
| 21 | WC (Year 1) | visible | Y1 working capital |
| 22 | WC (Year 2) | visible | Y2 working capital |
| 23 | WC (Year 3-5) | visible | Y3-5 working capital |
| 24 | Capex & Depreciation | visible | Plant capex & D&A |
| 25 | Project Financing | visible | Funding mix |
| 26 | Allocation | hidden | Equity/debt split (abandoned) |
| 27 | Project NPV, PI & EVA | hidden | DCF valuation (broken) |
| 28 | Debt Schedule | visible | Debt & interest |
| 29 | ROCE & RONW | hidden | Capital returns (broken) |
| 30 | IRR & Payback Period | hidden | IRR/payback (broken) |

---

*End of BUSINESS_ONTOLOGY.md — the master reference for the Valencia Nutracare financial model.*
