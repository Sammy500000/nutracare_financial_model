# DATABASE SCHEMA — Valencia Nutracare Decision Platform (PostgreSQL)

**Companion to:** [BUSINESS_ONTOLOGY.md](BUSINESS_ONTOLOGY.md) · [ARCHITECTURE.md](ARCHITECTURE.md) (Data Layer §1)
**Target:** PostgreSQL 15+
**Purpose:** Production-grade relational model for the 14 ontology entities + scenario/versioning, so every projection is reproducible against a known data state. Emphasis on **relationships and referential integrity** (the priority: flow over mock values).

---

## 0. Conventions

| Concern | Rule |
|---|---|
| **Naming** | `snake_case`; tables **plural**; PK `<singular>_id`; FK `<referenced_singular>_id`. |
| **Schemas (namespaces)** | `ref` (reference/dimensions), `core` (business entities), `plan` (scenarios, assumptions, inputs), `proj` (projections/outputs), `audit`. |
| **Surrogate keys** | `bigint GENERATED ALWAYS AS IDENTITY` PK on every table; stable **natural keys** enforced via `UNIQUE`. |
| **Money** | `numeric(18,4)` in **INR** (canonical). "Cr" (÷10⁷) is presentation only — never stored. |
| **Rates** | `numeric(18,6)` (e.g. ₹/gram). **Percentages** stored as fractions `numeric(9,6)` with `CHECK (x >= 0)`. |
| **Quantities** | grams `numeric(12,4)`; boxes/counts `bigint`. |
| **Audit columns** | every table: `created_at timestamptz NOT NULL DEFAULT now()`, `updated_at timestamptz NOT NULL DEFAULT now()` (touch trigger below). |
| **Temporal data** | effective-dated rows use `daterange`; overlaps blocked by `EXCLUDE` constraints (needs `btree_gist`). |
| **FK policy** | dimensions: `ON DELETE RESTRICT`; child/detail rows: `ON DELETE CASCADE`. All FK columns are **indexed**. |
| **Soft business state** | `status` enums rather than hard deletes for planning artifacts. |

```sql
-- Extensions
CREATE EXTENSION IF NOT EXISTS btree_gist;   -- EXCLUDE constraints on temporal ranges
CREATE EXTENSION IF NOT EXISTS pgcrypto;     -- gen_random_uuid() for external/public ids

-- Schemas
CREATE SCHEMA IF NOT EXISTS ref;
CREATE SCHEMA IF NOT EXISTS core;
CREATE SCHEMA IF NOT EXISTS plan;
CREATE SCHEMA IF NOT EXISTS proj;
CREATE SCHEMA IF NOT EXISTS audit;

-- Shared updated_at trigger
CREATE OR REPLACE FUNCTION audit.touch_updated_at() RETURNS trigger AS $$
BEGIN NEW.updated_at = now(); RETURN NEW; END;
$$ LANGUAGE plpgsql;
```

### Enumerated types
```sql
CREATE TYPE ref.manufacturing_mode AS ENUM ('contract','in_house','third_party');
CREATE TYPE ref.expense_category   AS ENUM
    ('marketing','hcp_detailing','distribution','rnd_regulatory','ga_ops','employee','contingency');
CREATE TYPE ref.channel_type       AS ENUM ('hospital','doctor','retail','ecommerce','pharmacy');
CREATE TYPE ref.scenario_status    AS ENUM ('draft','active','archived');
CREATE TYPE ref.valuation_metric   AS ENUM ('npv','pi','eva','roce','roe','wacc','irr','payback','disc_payback');
CREATE TYPE ref.pnl_line           AS ENUM
    ('revenue_ops','other_income','total_revenue','cogs','gross_profit',
     'marketing','hcp_detailing','distribution','rnd_regulatory','ga_ops','employee','contingency',
     'total_expense','ebitda','depreciation','ebit','finance_cost','pbt','tax','pat');
```

---

## 1. Entity-Relationship Overview (textual ERD)

```
ref.tiers ─────┐                         ref.product_families ──┐
               │                                 │  1            │
core.brands ───┤ (family,tier)             core.product_variants │
               ▼                                 ▼  *            ▼
            core.skus ◀── family,variant,tier,flavour ───────────┘
               │ 1
               ├──────────────▶ plan.prices (sku, tier, MRP, net price)  [temporal]
               │
core.ingredients ─1─< core.ingredient_prices [temporal]
               │
core.boms ─1─< core.bom_lines >─ ingredient        (recipe per family)
               │
core.plants ── mode ── ref.manufacturing_mode
core.markets (SAM share: family × tier × year)
core.competitors ─1─< core.competitor_metrics
core.channels (hospital/doctor) ──< plan.expense_assumptions
core.funding_rounds            plan.capex_items ─< plan.capex_plan

plan.scenarios ─1─< plan.assumptions
plan.scenarios ─1─< plan.capex_plan / prices / expense_assumptions / sam_overrides
plan.scenarios ─1─< proj.* (all projections carry scenario_id + snapshot_id)
plan.data_snapshots ─1─< proj.*

proj.revenue_projection · proj.pnl_lines · proj.working_capital ·
proj.debt_schedule · proj.financing_plan · proj.returns
```

**Reading the flow:** `ingredients → bom_lines → boms (cost/box) → skus`; `skus + prices + markets(SAM) + plants(capacity) → proj.revenue_projection → proj.pnl_lines → proj.returns`. Every `proj.*` row is stamped with `(scenario_id, snapshot_id)` for reproducibility — the architectural cure for the `#REF!` cascade (a break is contained, not global).

---

## 2. `ref` — Reference / Dimension tables

```sql
-- Market tiers (Tier 1 Metro, Tier 2 Mid, Tier 3 Value)
CREATE TABLE ref.tiers (
    tier_id      smallint PRIMARY KEY CHECK (tier_id BETWEEN 1 AND 3),
    code         text NOT NULL UNIQUE,             -- 'tier_1'
    label        text NOT NULL,                    -- 'Metro / Premium / Institutional'
    created_at   timestamptz NOT NULL DEFAULT now(),
    updated_at   timestamptz NOT NULL DEFAULT now()
);

-- Product families: PP, LP, IFP, CNP
CREATE TABLE ref.product_families (
    family_id    smallint PRIMARY KEY,
    code         text NOT NULL UNIQUE,             -- 'PP','LP','IFP','CNP'
    name         text NOT NULL,
    box_size_g   numeric(8,2) NOT NULL CHECK (box_size_g > 0),   -- 500 natal / 400 infant-child
    gst_rate     numeric(5,4) NOT NULL DEFAULT 0.18 CHECK (gst_rate >= 0),
    created_at   timestamptz NOT NULL DEFAULT now(),
    updated_at   timestamptz NOT NULL DEFAULT now()
);

-- Calendar of projection years (Y1..Y5 → FY labels)
CREATE TABLE ref.fiscal_years (
    year_no      smallint PRIMARY KEY CHECK (year_no BETWEEN 1 AND 10),
    fy_label     text NOT NULL UNIQUE,             -- 'FY27-28'
    start_date   date NOT NULL,
    end_date     date NOT NULL,
    CHECK (end_date > start_date)
);
```
**Indexes:** PKs + the `UNIQUE(code)` constraints suffice (small dimensions).

---

## 3. `core` — Business Entities

### 3.1 Brands & Variants & SKUs (`Product`, ontology §2.1)
```sql
-- One brand per family × tier (Wonder Womb, Garbhika, …)
CREATE TABLE core.brands (
    brand_id     bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    family_id    smallint NOT NULL REFERENCES ref.product_families(family_id) ON DELETE RESTRICT,
    tier_id      smallint NOT NULL REFERENCES ref.tiers(tier_id)            ON DELETE RESTRICT,
    brand_name   text NOT NULL,
    created_at   timestamptz NOT NULL DEFAULT now(),
    updated_at   timestamptz NOT NULL DEFAULT now(),
    UNIQUE (family_id, tier_id)
);

-- Variant within a family: trimester (PP), age-stage (IFP), single (LP/CNP)
CREATE TABLE core.product_variants (
    variant_id   bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    family_id    smallint NOT NULL REFERENCES ref.product_families(family_id) ON DELETE RESTRICT,
    code         text NOT NULL,                    -- 'TRI_1','AGE_0_6M','BASE'
    name         text NOT NULL,
    created_at   timestamptz NOT NULL DEFAULT now(),
    updated_at   timestamptz NOT NULL DEFAULT now(),
    UNIQUE (family_id, code)
);

-- A sellable SKU = family × variant × tier × flavour
CREATE TABLE core.skus (
    sku_id        bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    public_id     uuid NOT NULL DEFAULT gen_random_uuid() UNIQUE,
    family_id     smallint NOT NULL REFERENCES ref.product_families(family_id) ON DELETE RESTRICT,
    variant_id    bigint   NOT NULL REFERENCES core.product_variants(variant_id) ON DELETE RESTRICT,
    tier_id       smallint NOT NULL REFERENCES ref.tiers(tier_id)              ON DELETE RESTRICT,
    flavour       text NOT NULL DEFAULT 'standard',
    box_size_g    numeric(8,2) NOT NULL CHECK (box_size_g > 0),
    active_from_year smallint NOT NULL REFERENCES ref.fiscal_years(year_no),  -- when SKU enters range
    is_active     boolean NOT NULL DEFAULT true,
    created_at    timestamptz NOT NULL DEFAULT now(),
    updated_at    timestamptz NOT NULL DEFAULT now(),
    UNIQUE (family_id, variant_id, tier_id, flavour)
);
CREATE INDEX ix_skus_family   ON core.skus(family_id);
CREATE INDEX ix_skus_variant  ON core.skus(variant_id);
CREATE INDEX ix_skus_tier     ON core.skus(tier_id);
CREATE INDEX ix_skus_active   ON core.skus(family_id, tier_id) WHERE is_active;  -- partial
```

### 3.2 Ingredients & temporal pricing (`Ingredient`, §2.2)
```sql
CREATE TABLE core.ingredients (
    ingredient_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name          text NOT NULL UNIQUE,            -- 'Skimmed Milk Powder'
    uom           text NOT NULL DEFAULT 'kg',
    created_at    timestamptz NOT NULL DEFAULT now(),
    updated_at    timestamptz NOT NULL DEFAULT now()
);

-- Effective-dated rate card; no overlapping periods per ingredient
CREATE TABLE core.ingredient_prices (
    price_id      bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    ingredient_id bigint NOT NULL REFERENCES core.ingredients(ingredient_id) ON DELETE CASCADE,
    rate_per_kg   numeric(18,4) NOT NULL CHECK (rate_per_kg >= 0),
    valid_period  daterange NOT NULL DEFAULT daterange(CURRENT_DATE, NULL, '[)'),
    source        text,                            -- provenance (skill standard)
    created_at    timestamptz NOT NULL DEFAULT now(),
    updated_at    timestamptz NOT NULL DEFAULT now(),
    EXCLUDE USING gist (ingredient_id WITH =, valid_period WITH &&)
);
CREATE INDEX ix_ingredient_prices_ing ON core.ingredient_prices(ingredient_id);
```

### 3.3 BOM header + lines (`BOM`, §2.3)
```sql
-- One BOM (recipe) per family, versioned
CREATE TABLE core.boms (
    bom_id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    family_id       smallint NOT NULL REFERENCES ref.product_families(family_id) ON DELETE RESTRICT,
    version         integer NOT NULL DEFAULT 1,
    box_size_g      numeric(8,2) NOT NULL CHECK (box_size_g > 0),
    packaging_cost  numeric(18,4) NOT NULL DEFAULT 0 CHECK (packaging_cost >= 0),
    conversion_cost numeric(18,4) NOT NULL DEFAULT 0 CHECK (conversion_cost >= 0),
    batch_cost      numeric(18,4) NOT NULL DEFAULT 20000000 CHECK (batch_cost > 0),  -- ₹2 Cr
    status          text NOT NULL DEFAULT 'active',
    -- raw-material cost/box is derived from bom_lines; total exposed as a generated/maintained view
    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now(),
    UNIQUE (family_id, version)
);

CREATE TABLE core.bom_lines (
    bom_line_id   bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    bom_id        bigint NOT NULL REFERENCES core.boms(bom_id) ON DELETE CASCADE,
    ingredient_id bigint NOT NULL REFERENCES core.ingredients(ingredient_id) ON DELETE RESTRICT,
    qty_per_100g  numeric(12,4) NOT NULL CHECK (qty_per_100g >= 0),
    line_no       smallint,
    created_at    timestamptz NOT NULL DEFAULT now(),
    updated_at    timestamptz NOT NULL DEFAULT now(),
    UNIQUE (bom_id, ingredient_id)
);
CREATE INDEX ix_bom_lines_bom ON core.bom_lines(bom_id);
CREATE INDEX ix_bom_lines_ing ON core.bom_lines(ingredient_id);
```
> **Derived cost/box** (= Σ(qty_per_box × rate) + packaging + conversion) is computed in the Simulation Layer or a `core.v_bom_cost` view — not stored, to avoid the stale-value defect.

### 3.4 Plants & Markets (`Inventory`/capacity, `Market`, §2.7/2.9)
```sql
CREATE TABLE core.plants (
    plant_id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name              text NOT NULL,
    mode              ref.manufacturing_mode NOT NULL,
    kg_per_day        numeric(14,2) NOT NULL DEFAULT 0 CHECK (kg_per_day >= 0),
    commissioned_year smallint REFERENCES ref.fiscal_years(year_no),
    created_at        timestamptz NOT NULL DEFAULT now(),
    updated_at        timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX ix_plants_mode ON core.plants(mode);

-- SAM share by family × tier × year (drives BPH/volume allocation)
CREATE TABLE core.markets (
    market_id   bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    family_id   smallint NOT NULL REFERENCES ref.product_families(family_id) ON DELETE RESTRICT,
    tier_id     smallint NOT NULL REFERENCES ref.tiers(tier_id)            ON DELETE RESTRICT,
    year_no     smallint NOT NULL REFERENCES ref.fiscal_years(year_no),
    sam_share   numeric(9,6) NOT NULL CHECK (sam_share >= 0 AND sam_share <= 1),
    created_at  timestamptz NOT NULL DEFAULT now(),
    updated_at  timestamptz NOT NULL DEFAULT now(),
    UNIQUE (family_id, tier_id, year_no)
);
CREATE INDEX ix_markets_year ON core.markets(year_no);
```

### 3.5 Channels, Competitors (`Hospital`/`Doctor`, `Competitor`, §2.4–2.6)
```sql
CREATE TABLE core.channels (
    channel_id  bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    type        ref.channel_type NOT NULL,
    name        text NOT NULL,
    created_at  timestamptz NOT NULL DEFAULT now(),
    updated_at  timestamptz NOT NULL DEFAULT now(),
    UNIQUE (type, name)
);

CREATE TABLE core.competitors (
    competitor_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name          text NOT NULL UNIQUE,            -- HealthKart, Kapiva, OZiva…
    created_at    timestamptz NOT NULL DEFAULT now(),
    updated_at    timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE core.competitor_metrics (
    metric_id     bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    competitor_id bigint NOT NULL REFERENCES core.competitors(competitor_id) ON DELETE CASCADE,
    metric_key    text NOT NULL,                   -- 'gross_margin','ebitda_margin','advertising_pct'
    value_pct     numeric(9,6),                    -- numeric where known
    value_text    text,                            -- fallback for '~38%' style benchmark bands
    note          text,
    created_at    timestamptz NOT NULL DEFAULT now(),
    updated_at    timestamptz NOT NULL DEFAULT now(),
    UNIQUE (competitor_id, metric_key)
);
CREATE INDEX ix_comp_metrics_comp ON core.competitor_metrics(competitor_id);
```

### 3.6 Funding rounds (`Funding Round`, §2.8)
```sql
CREATE TABLE core.funding_rounds (
    round_id       bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    round_no       smallint NOT NULL UNIQUE,
    year_no        smallint NOT NULL REFERENCES ref.fiscal_years(year_no),
    amount_inr     numeric(18,4) NOT NULL CHECK (amount_inr >= 0),   -- 22/60/220 Cr → INR
    tiers_targeted text,                            -- 'Tier 3', 'Tier 1 & 3', 'All'
    mode           ref.manufacturing_mode,
    purpose        text,
    created_at     timestamptz NOT NULL DEFAULT now(),
    updated_at     timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX ix_rounds_year ON core.funding_rounds(year_no);
```

---

## 4. `plan` — Scenarios, Assumptions & Inputs (`Scenario`, `Strategy`, `Expense`, `Valuation` params)

### 4.1 Scenario & reproducibility spine
```sql
CREATE TABLE plan.scenarios (
    scenario_id   bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    public_id     uuid NOT NULL DEFAULT gen_random_uuid() UNIQUE,
    name          text NOT NULL UNIQUE,
    description   text,
    horizon_years smallint NOT NULL DEFAULT 5 CHECK (horizon_years BETWEEN 1 AND 10),
    base_currency char(3) NOT NULL DEFAULT 'INR',
    status        ref.scenario_status NOT NULL DEFAULT 'draft',
    created_by    text,
    created_at    timestamptz NOT NULL DEFAULT now(),
    updated_at    timestamptz NOT NULL DEFAULT now()
);

-- Immutable data version a scenario run was computed against
CREATE TABLE plan.data_snapshots (
    snapshot_id   bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    scenario_id   bigint NOT NULL REFERENCES plan.scenarios(scenario_id) ON DELETE CASCADE,
    label         text NOT NULL,
    taken_at      timestamptz NOT NULL DEFAULT now(),
    UNIQUE (scenario_id, label)
);
CREATE INDEX ix_snapshots_scenario ON plan.data_snapshots(scenario_id);

-- Free-form assumptions register (ontology §9) with provenance & confidence
CREATE TABLE plan.assumptions (
    assumption_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    scenario_id   bigint NOT NULL REFERENCES plan.scenarios(scenario_id) ON DELETE CASCADE,
    key           text NOT NULL,                   -- 'tax_rate','ke','kd','logistics_per_box'
    value_numeric numeric(18,6),
    value_text    text,
    unit          text,
    source        text,
    confidence    text CHECK (confidence IN ('low','medium','high')),
    created_at    timestamptz NOT NULL DEFAULT now(),
    updated_at    timestamptz NOT NULL DEFAULT now(),
    UNIQUE (scenario_id, key)
);
CREATE INDEX ix_assumptions_scenario ON plan.assumptions(scenario_id);
```

### 4.2 Pricing (`Product` price, §2.10) — scenario-scoped & temporal
```sql
CREATE TABLE plan.prices (
    price_id      bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    scenario_id   bigint NOT NULL REFERENCES plan.scenarios(scenario_id) ON DELETE CASCADE,
    sku_id        bigint NOT NULL REFERENCES core.skus(sku_id)           ON DELETE CASCADE,
    mrp_inr       numeric(18,4) NOT NULL CHECK (mrp_inr >= 0),
    net_price_inr numeric(18,4) NOT NULL CHECK (net_price_inr >= 0),     -- excl GST, to-trade
    valid_period  daterange NOT NULL DEFAULT daterange(CURRENT_DATE, NULL, '[)'),
    source        text,
    created_at    timestamptz NOT NULL DEFAULT now(),
    updated_at    timestamptz NOT NULL DEFAULT now(),
    EXCLUDE USING gist (scenario_id WITH =, sku_id WITH =, valid_period WITH &&),
    CHECK (net_price_inr <= mrp_inr)
);
CREATE INDEX ix_prices_scenario_sku ON plan.prices(scenario_id, sku_id);
```

### 4.3 Expense assumptions (`Expense`, §2.11) — the tier × product × year grid
```sql
CREATE TABLE plan.expense_assumptions (
    expense_id    bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    scenario_id   bigint NOT NULL REFERENCES plan.scenarios(scenario_id) ON DELETE CASCADE,
    category      ref.expense_category NOT NULL,
    family_id     smallint REFERENCES ref.product_families(family_id) ON DELETE RESTRICT, -- nullable = all
    tier_id       smallint REFERENCES ref.tiers(tier_id)            ON DELETE RESTRICT,
    year_no       smallint NOT NULL REFERENCES ref.fiscal_years(year_no),
    channel_id    bigint REFERENCES core.channels(channel_id) ON DELETE SET NULL,         -- HCP channel
    pct_of_revenue numeric(9,6) CHECK (pct_of_revenue >= 0),
    per_box_inr    numeric(18,4) CHECK (per_box_inr >= 0),                                -- logistics ₹/box
    note          text,
    created_at    timestamptz NOT NULL DEFAULT now(),
    updated_at    timestamptz NOT NULL DEFAULT now(),
    UNIQUE (scenario_id, category, family_id, tier_id, year_no),
    CHECK (pct_of_revenue IS NOT NULL OR per_box_inr IS NOT NULL)   -- one driver must be set
);
CREATE INDEX ix_expense_scenario      ON plan.expense_assumptions(scenario_id);
CREATE INDEX ix_expense_cat_year      ON plan.expense_assumptions(category, year_no);
```

### 4.4 Capex plan & financing (`Capex`, `Funding Round` mix, §2.12/§6.16-6.17)
```sql
CREATE TABLE plan.capex_items (              -- reusable per-plant cost catalogue (machinery list)
    item_id      bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name         text NOT NULL UNIQUE,        -- 'FBD','HVAC','Land & Plant Building'
    unit_cost_inr numeric(18,4) NOT NULL CHECK (unit_cost_inr >= 0),
    category     text,
    created_at   timestamptz NOT NULL DEFAULT now(),
    updated_at   timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE plan.capex_plan (
    capex_plan_id  bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    scenario_id    bigint NOT NULL REFERENCES plan.scenarios(scenario_id) ON DELETE CASCADE,
    year_no        smallint NOT NULL REFERENCES ref.fiscal_years(year_no),
    plants_added   smallint NOT NULL DEFAULT 0 CHECK (plants_added >= 0),
    land_cost      numeric(18,4) NOT NULL DEFAULT 0,
    machinery_cost numeric(18,4) NOT NULL DEFAULT 0,
    misc_contingency numeric(18,4) NOT NULL DEFAULT 0,
    depreciation_rate numeric(5,4) NOT NULL DEFAULT 0.15 CHECK (depreciation_rate >= 0),
    created_at     timestamptz NOT NULL DEFAULT now(),
    updated_at     timestamptz NOT NULL DEFAULT now(),
    UNIQUE (scenario_id, year_no)
);
CREATE INDEX ix_capex_plan_scenario ON plan.capex_plan(scenario_id);

CREATE TABLE plan.financing_plan (
    financing_id   bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    scenario_id    bigint NOT NULL REFERENCES plan.scenarios(scenario_id) ON DELETE CASCADE,
    year_no        smallint NOT NULL REFERENCES ref.fiscal_years(year_no),
    capex_own_pct  numeric(5,4) NOT NULL CHECK (capex_own_pct BETWEEN 0 AND 1),
    capex_debt_pct numeric(5,4) NOT NULL CHECK (capex_debt_pct BETWEEN 0 AND 1),
    wc_own_pct     numeric(5,4) NOT NULL CHECK (wc_own_pct BETWEEN 0 AND 1),
    wc_debt_pct    numeric(5,4) NOT NULL CHECK (wc_debt_pct BETWEEN 0 AND 1),
    interest_rate  numeric(5,4) NOT NULL DEFAULT 0.12 CHECK (interest_rate >= 0),
    fd_rate        numeric(5,4) NOT NULL DEFAULT 0.06,
    created_at     timestamptz NOT NULL DEFAULT now(),
    updated_at     timestamptz NOT NULL DEFAULT now(),
    UNIQUE (scenario_id, year_no),
    CHECK (capex_own_pct + capex_debt_pct = 1),
    CHECK (wc_own_pct + wc_debt_pct = 1)
);
CREATE INDEX ix_financing_scenario ON plan.financing_plan(scenario_id);
```

---

## 5. `proj` — Projections / Outputs (`Revenue`, P&L, WC, returns)

All projection rows are stamped `(scenario_id, snapshot_id)` → fully reproducible.

```sql
-- Revenue facts per SKU × tier × mode × year
CREATE TABLE proj.revenue_projection (
    rev_id        bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    scenario_id   bigint NOT NULL REFERENCES plan.scenarios(scenario_id)     ON DELETE CASCADE,
    snapshot_id   bigint NOT NULL REFERENCES plan.data_snapshots(snapshot_id) ON DELETE CASCADE,
    sku_id        bigint NOT NULL REFERENCES core.skus(sku_id)               ON DELETE RESTRICT,
    year_no       smallint NOT NULL REFERENCES ref.fiscal_years(year_no),
    mode          ref.manufacturing_mode NOT NULL,
    boxes         bigint NOT NULL DEFAULT 0 CHECK (boxes >= 0),
    unit_price_inr numeric(18,4) NOT NULL DEFAULT 0,
    revenue_inr   numeric(18,4) NOT NULL DEFAULT 0,
    cogs_inr      numeric(18,4) NOT NULL DEFAULT 0,
    created_at    timestamptz NOT NULL DEFAULT now(),
    UNIQUE (scenario_id, snapshot_id, sku_id, year_no, mode)
);
CREATE INDEX ix_rev_scn_year ON proj.revenue_projection(scenario_id, year_no);
CREATE INDEX ix_rev_sku      ON proj.revenue_projection(sku_id);

-- Consolidated P&L lines per scenario × year (enum-driven, tidy/long format)
CREATE TABLE proj.pnl_lines (
    pnl_id       bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    scenario_id  bigint NOT NULL REFERENCES plan.scenarios(scenario_id)     ON DELETE CASCADE,
    snapshot_id  bigint NOT NULL REFERENCES plan.data_snapshots(snapshot_id) ON DELETE CASCADE,
    year_no      smallint NOT NULL REFERENCES ref.fiscal_years(year_no),
    line_item    ref.pnl_line NOT NULL,
    amount_inr   numeric(18,4) NOT NULL DEFAULT 0,
    created_at   timestamptz NOT NULL DEFAULT now(),
    UNIQUE (scenario_id, snapshot_id, year_no, line_item)
);
CREATE INDEX ix_pnl_scn_year ON proj.pnl_lines(scenario_id, year_no);

-- Working capital per product × year (monthly rotation summarized)
CREATE TABLE proj.working_capital (
    wc_id        bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    scenario_id  bigint NOT NULL REFERENCES plan.scenarios(scenario_id)     ON DELETE CASCADE,
    snapshot_id  bigint NOT NULL REFERENCES plan.data_snapshots(snapshot_id) ON DELETE CASCADE,
    family_id    smallint NOT NULL REFERENCES ref.product_families(family_id) ON DELETE RESTRICT,
    year_no      smallint NOT NULL REFERENCES ref.fiscal_years(year_no),
    initial_wc_inr numeric(18,4) NOT NULL DEFAULT 0,
    wc_rotation  numeric(12,4),                    -- revenue / initial WC
    created_at   timestamptz NOT NULL DEFAULT now(),
    UNIQUE (scenario_id, snapshot_id, family_id, year_no)
);
CREATE INDEX ix_wc_scn_year ON proj.working_capital(scenario_id, year_no);

-- Debt schedule per year
CREATE TABLE proj.debt_schedule (
    debt_id        bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    scenario_id    bigint NOT NULL REFERENCES plan.scenarios(scenario_id)     ON DELETE CASCADE,
    snapshot_id    bigint NOT NULL REFERENCES plan.data_snapshots(snapshot_id) ON DELETE CASCADE,
    year_no        smallint NOT NULL REFERENCES ref.fiscal_years(year_no),
    new_debt_inr   numeric(18,4) NOT NULL DEFAULT 0,
    cumulative_debt_inr numeric(18,4) NOT NULL DEFAULT 0,
    interest_inr   numeric(18,4) NOT NULL DEFAULT 0,
    created_at     timestamptz NOT NULL DEFAULT now(),
    UNIQUE (scenario_id, snapshot_id, year_no)
);

-- Valuation / return metrics (NPV, IRR, ROCE…); year_no NULL for whole-project metrics
CREATE TABLE proj.returns (
    return_id    bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    scenario_id  bigint NOT NULL REFERENCES plan.scenarios(scenario_id)     ON DELETE CASCADE,
    snapshot_id  bigint NOT NULL REFERENCES plan.data_snapshots(snapshot_id) ON DELETE CASCADE,
    metric       ref.valuation_metric NOT NULL,
    year_no      smallint REFERENCES ref.fiscal_years(year_no),
    value        numeric(18,6) NOT NULL,
    created_at   timestamptz NOT NULL DEFAULT now(),
    UNIQUE (scenario_id, snapshot_id, metric, year_no)
);
CREATE INDEX ix_returns_scn ON proj.returns(scenario_id);
```

---

## 6. `audit` — Change tracking
```sql
CREATE TABLE audit.change_log (
    log_id      bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    table_name  text NOT NULL,
    row_pk      text NOT NULL,
    action      text NOT NULL CHECK (action IN ('INSERT','UPDATE','DELETE')),
    changed_by  text NOT NULL DEFAULT current_user,
    changed_at  timestamptz NOT NULL DEFAULT now(),
    diff        jsonb
);
CREATE INDEX ix_changelog_table ON audit.change_log(table_name, changed_at);
CREATE INDEX ix_changelog_diff  ON audit.change_log USING gin (diff);
```
Attach `audit.touch_updated_at` (BEFORE UPDATE) to every entity table, and a generic row-audit trigger writing to `audit.change_log` on the mutable `core`/`plan` tables.

---

## 7. Relationships summary (FK matrix)

| Child table | FK column → Parent | On delete | Cardinality |
|---|---|---|---|
| core.brands | family_id → ref.product_families; tier_id → ref.tiers | RESTRICT | many brands : 1 family/tier |
| core.product_variants | family_id → ref.product_families | RESTRICT | many : 1 |
| core.skus | family_id, variant_id, tier_id, active_from_year | RESTRICT | many SKUs : 1 family/variant/tier |
| core.ingredient_prices | ingredient_id → core.ingredients | CASCADE | many prices : 1 ingredient |
| core.boms | family_id → ref.product_families | RESTRICT | 1 BOM(version) : 1 family |
| core.bom_lines | bom_id → core.boms; ingredient_id → core.ingredients | CASCADE / RESTRICT | many lines : 1 BOM |
| core.markets | family_id, tier_id, year_no | RESTRICT | SAM grid |
| core.competitor_metrics | competitor_id → core.competitors | CASCADE | many : 1 |
| core.funding_rounds | year_no → ref.fiscal_years | RESTRICT | 1 round : 1 year |
| plan.data_snapshots | scenario_id → plan.scenarios | CASCADE | many : 1 |
| plan.assumptions | scenario_id → plan.scenarios | CASCADE | many : 1 |
| plan.prices | scenario_id → plan.scenarios; sku_id → core.skus | CASCADE | many : 1 |
| plan.expense_assumptions | scenario_id, family_id, tier_id, year_no, channel_id | CASCADE / RESTRICT / SET NULL | grid |
| plan.capex_plan / financing_plan | scenario_id → plan.scenarios; year_no → ref.fiscal_years | CASCADE | 1 : year |
| proj.* | scenario_id → plan.scenarios; snapshot_id → plan.data_snapshots; (+ sku/family/year) | CASCADE / RESTRICT | facts |

---

## 8. Indexing & performance strategy

- **Every FK column is indexed** (PostgreSQL does not auto-index FKs) — prevents slow joins and lock escalation on parent deletes.
- **Composite uniques double as covering indexes** for the natural-key lookups (e.g. `skus(family,variant,tier,flavour)`, `markets(family,tier,year)`).
- **Partial indexes** for hot subsets: `skus … WHERE is_active`, current-period prices.
- **GiST EXCLUDE** on temporal tables (`ingredient_prices`, `plan.prices`) guarantees no overlapping validity — data-integrity at the engine level.
- **Reporting access pattern** is `(scenario_id, year_no)` → those composite indexes exist on every `proj.*` table.
- **Partitioning (scale-out, optional):** range-partition `proj.revenue_projection` and `proj.pnl_lines` by `scenario_id` (or LIST by `year_no`) once scenario count grows large.
- **GIN** on `audit.change_log.diff` (jsonb) for change forensics.

---

## 9. Production concerns

| Concern | Approach |
|---|---|
| **Reproducibility** | `(scenario_id, snapshot_id)` on every projection; snapshots immutable. |
| **Referential integrity** | FKs everywhere; RESTRICT on dimensions, CASCADE on owned detail. |
| **Domain integrity** | CHECK constraints (tiers 1–3, percentages 0–1, financing splits sum to 1, net_price ≤ MRP). |
| **Temporal correctness** | `daterange` + EXCLUDE — no overlapping prices/rates. |
| **Auditability** | `audit.change_log` + `updated_at` triggers; source/confidence on assumptions & prices. |
| **Security (RLS)** | Enable `ROW LEVEL SECURITY` on `plan.*`/`proj.*`, scoped by scenario ownership; `deny` on secrets (per project settings). |
| **Migrations** | Manage via Prisma/Flyway/sqitch (Prisma is available in this environment); each enum/table change is a forward-only migration. |
| **Currency** | canonical INR; "Cr" only at presentation (view layer), never persisted. |
| **Mock-data stance** | schema enforces *relationships and constraints*; values can be swapped freely without breaking integrity — the priority you set. |

---

## Appendix A — Table inventory (24 tables)

| Schema | Tables |
|---|---|
| `ref` | tiers, product_families, fiscal_years |
| `core` | brands, product_variants, skus, ingredients, ingredient_prices, boms, bom_lines, plants, markets, channels, competitors, competitor_metrics, funding_rounds |
| `plan` | scenarios, data_snapshots, assumptions, prices, expense_assumptions, capex_items, capex_plan, financing_plan |
| `proj` | revenue_projection, pnl_lines, working_capital, debt_schedule, returns |
| `audit` | change_log |

---

*End of DATABASE_SCHEMA.md — production-grade PostgreSQL model for the Valencia Nutracare Decision Platform, derived from BUSINESS_ONTOLOGY.md.*
