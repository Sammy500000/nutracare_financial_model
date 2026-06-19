# KNOWLEDGE_GRAPH.md — Valencia Nutracare (Neo4j Design)

**Companion to:** [BUSINESS_ONTOLOGY.md](BUSINESS_ONTOLOGY.md) · [ARCHITECTURE.md](ARCHITECTURE.md) (Knowledge Layer §2) · [DATABASE_SCHEMA.md](DATABASE_SCHEMA.md)
**Engine:** Neo4j 5.x (Cypher)
**Purpose:** Model the business as a **property graph** so agents can traverse *relationships and causality* — the graph counterpart of the relational store. Its signature capability is **lineage/impact analysis**: trace any change (e.g. a commodity price) through to its effect on EBITDA and Valuation. (This is the structural answer to the `#REF!` dependency problem we repaired — dependencies become first-class, queryable edges.)

---

## 0. Conventions

| Element | Convention | Example |
|---|---|---|
| **Node label** | `PascalCase`, singular | `:Product`, `:Commodity` |
| **Relationship type** | `UPPER_SNAKE_CASE`, verb, directed | `-[:COMPOSED_OF]->` |
| **Property** | `camelCase` | `ratePerKg`, `samShare` |
| **Identity** | each node has a unique business key (`+ uuid` for externals) | `Product.skuId` |
| **Currency** | INR canonical (`numeric`); "Cr" is presentation only |
| **Scenario scoping** | facts/derivations link to a `:Scenario` so the graph is reproducible |

---

## 1. The Value-Chain Spine (your example, realized)

```
(:Competitor)-[:BENCHMARKS]->(:Product)-[:COMPOSED_OF]->(:Ingredient)
   -[:SOURCED_FROM]->(:Commodity)-[:DRIVES]->(:Cost)
   -[:DETERMINES]->(:Margin)-[:AGGREGATES_TO]->(:EBITDA)-[:FEEDS]->(:Valuation)
```

| Hop | Meaning | Ontology link |
|---|---|---|
| Competitor → Product | peer benchmarks the SKU's margin/price | §2.4 |
| Product → Ingredient | recipe composition (BOM line) | §2.1→2.3 |
| Ingredient → Commodity | ingredient priced off a raw commodity market | §2.2 |
| Commodity → Cost | commodity rate drives cost/box & COGS | §2.3 |
| Cost → Margin | revenue − cost = gross margin | §2.10/2.11 |
| Margin → EBITDA | margins less indirect expense → EBITDA | §6.6 |
| EBITDA → Valuation | EBITDA/PAT discounted → NPV/IRR/ROCE/EVA | §6.19–6.22 |

This spine is the **backbone**; the full graph below hangs the other entities off it.

---

## 2. Node Catalogue

### Entity nodes (the ontology's nouns)
| Label | Key properties | Source |
|---|---|---|
| `:Competitor` | `name`, `grossMargin`, `ebitdaMargin`, `adSpendPct`, `spendToEarnRe1` | Competitor Brands |
| `:ProductFamily` | `code` (PP/LP/IFP/CNP), `name`, `boxSizeG`, `gstRate` | Product Line |
| `:Product` *(SKU)* | `skuId`, `variant`, `tier`, `flavour`, `boxSizeG`, `activeFromYear` | Product Line |
| `:Brand` | `name`, `tier` (Wonder Womb, Garbhika…) | Product Line |
| `:Ingredient` | `name`, `qtyPer100g`, `uom` | BOM sheets |
| `:Commodity` | `name`, `ratePerKg`, `market` (Dairy, Cereals, Sweeteners…) | BOM rate cards |
| `:BOM` | `family`, `version`, `batchCost`, `packagingCost`, `conversionCost` | BOM sheets |
| `:Tier` | `level` (1-3), `label` | Strategy |
| `:Market` | `family`, `tier`, `year`, `samShare` | In-house SAM table |
| `:Plant` | `name`, `mode` (contract/in_house/third_party), `kgPerDay`, `year` | In-house / Capex |
| `:Channel` | `type` (hospital/doctor/retail), `name` | Indirect Expenses |
| `:FundingRound` | `roundNo`, `year`, `amountInr`, `tiersTargeted` | Strategy / Financing |
| `:Scenario` | `scenarioId`, `name`, `horizonYears` | platform |

### Derivation / metric nodes (the ontology's calculated flow)
| Label | Key properties | Source |
|---|---|---|
| `:Cost` | `type` (costPerBox / cogs), `year`, `valueInr` | BOM / P&L |
| `:Revenue` | `year`, `tier`, `valueInr` | P&L / Revenue Breakup |
| `:Expense` | `category` (marketing/hcp/distribution/…), `year`, `valueInr` | Indirect Expenses |
| `:Capex` | `year`, `plantsAdded`, `totalInr` | Capex & Depreciation |
| `:WorkingCapital` | `family`, `year`, `initialInr`, `rotation` | WC sheets |
| `:Margin` | `type` (gross/ebitdaMargin), `year`, `pct` | P&L |
| `:EBITDA` | `year`, `valueInr`, `marginPct` | P&L |
| `:Valuation` | `metric` (NPV/IRR/ROCE/EVA/PI/payback), `value` | NPV/IRR/ROCE sheets |

---

## 3. Relationship Catalogue

| Pattern | Properties | Cardinality | Meaning |
|---|---|---|---|
| `(:Competitor)-[:BENCHMARKS]->(:ProductFamily)` | `metric`, `delta` | m:n | peer comparison |
| `(:Competitor)-[:COMPETES_IN]->(:Market)` | — | m:n | shared segment |
| `(:Brand)-[:BRANDS]->(:ProductFamily)` | `tier` | m:1 | brand per family/tier |
| `(:Product)-[:VARIANT_OF]->(:ProductFamily)` | — | m:1 | SKU rolls up to family |
| `(:Product)-[:SOLD_IN]->(:Tier)` | — | m:1 | tier placement |
| `(:Product)-[:TARGETS]->(:Market)` | — | m:1 | addressable segment |
| `(:ProductFamily)-[:HAS_RECIPE]->(:BOM)` | `version` | 1:1(active) | family recipe |
| `(:BOM)-[:COMPOSED_OF]->(:Ingredient)` | `qtyPer100g`, `qtyPerBox` | 1:n | recipe lines |
| `(:Ingredient)-[:SOURCED_FROM]->(:Commodity)` | `yield` | m:1 | raw-material source |
| `(:Commodity)-[:DRIVES]->(:Cost)` | `ratePerKg` | 1:n | rate → cost |
| `(:BOM)-[:YIELDS]->(:Cost)` | `costPerBox` | 1:n | recipe → cost/box |
| `(:Product)-[:GENERATES]->(:Revenue)` | `boxes`, `unitPrice` | 1:n | sales |
| `(:Plant)-[:PRODUCES]->(:ProductFamily)` | `mode`, `capacityPct` | m:n | manufacturing |
| `(:Market)-[:HAS_SAM]->(:ProductFamily)` | `share`, `tier`, `year` | m:n | demand driver |
| `(:Channel)-[:RECEIVES_SPEND]->(:Expense)` | `year` | 1:n | HCP detailing |
| `(:Cost)-[:DETERMINES]->(:Margin)` | — | n:1 | cost → gross margin |
| `(:Revenue)-[:CONTRIBUTES_TO]->(:Margin)` | — | n:1 | revenue → margin |
| `(:Expense)-[:REDUCES]->(:EBITDA)` | — | n:1 | opex drag |
| `(:Margin)-[:AGGREGATES_TO]->(:EBITDA)` | — | n:1 | gross → EBITDA |
| `(:Capex)-[:DEPRECIATES_INTO]->(:Expense)` | `rate` | 1:n | D&A |
| `(:FundingRound)-[:FINANCES]->(:Capex)` | `equityPct`, `debtPct` | 1:n | capital → assets |
| `(:FundingRound)-[:FINANCES]->(:WorkingCapital)` | — | 1:n | capital → WC |
| `(:EBITDA)-[:FEEDS]->(:Valuation)` | — | n:n | returns engine |
| `(:Scenario)-[:PARAMETERIZES]->(...)` | — | 1:n | scenario scoping of facts/derivations |

---

## 4. Full Graph (visual)

```
        (Competitor)
            │ BENCHMARKS / COMPETES_IN
            ▼
 (Brand)─BRANDS─►(ProductFamily)◄─VARIANT_OF─(Product)─GENERATES─►(Revenue)
                      │                 │  SOLD_IN/TARGETS            │
                 HAS_RECIPE             ▼                             │ CONTRIBUTES_TO
                      ▼               (Tier)──(Market)─HAS_SAM─┐      ▼
                   (BOM)─COMPOSED_OF─►(Ingredient)            │   (Margin)
                    │  YIELDS              │ SOURCED_FROM      │      ▲ DETERMINES
                    ▼                      ▼                   │   (Cost)◄─DRIVES─(Commodity)
                  (Cost)◄──────────────DRIVES──────────────────┘      │
                                                                       │ AGGREGATES_TO
 (Plant)─PRODUCES─►(ProductFamily)                                     ▼
 (Channel)─RECEIVES_SPEND─►(Expense)─REDUCES─►(EBITDA)◄────────────────┘
 (FundingRound)─FINANCES─►(Capex)─DEPRECIATES_INTO─►(Expense)           │ FEEDS
 (FundingRound)─FINANCES─►(WorkingCapital)                             ▼
 (Scenario)─PARAMETERIZES─►{all facts & derivations}             (Valuation)
```

---

## 5. Cypher — Constraints & Indexes (production)

```cypher
// Uniqueness / node-key constraints
CREATE CONSTRAINT product_sku  IF NOT EXISTS FOR (p:Product)       REQUIRE p.skuId IS UNIQUE;
CREATE CONSTRAINT family_code  IF NOT EXISTS FOR (f:ProductFamily) REQUIRE f.code  IS UNIQUE;
CREATE CONSTRAINT ingr_name    IF NOT EXISTS FOR (i:Ingredient)    REQUIRE i.name  IS UNIQUE;
CREATE CONSTRAINT commodity    IF NOT EXISTS FOR (c:Commodity)     REQUIRE c.name  IS UNIQUE;
CREATE CONSTRAINT competitor   IF NOT EXISTS FOR (c:Competitor)    REQUIRE c.name  IS UNIQUE;
CREATE CONSTRAINT scenario_id  IF NOT EXISTS FOR (s:Scenario)      REQUIRE s.scenarioId IS UNIQUE;
CREATE CONSTRAINT tier_level   IF NOT EXISTS FOR (t:Tier)          REQUIRE t.level IS UNIQUE;

// Lookup indexes (hot traversal anchors)
CREATE INDEX market_fty   IF NOT EXISTS FOR (m:Market)    ON (m.family, m.tier, m.year);
CREATE INDEX cost_year    IF NOT EXISTS FOR (c:Cost)      ON (c.year);
CREATE INDEX ebitda_year  IF NOT EXISTS FOR (e:EBITDA)    ON (e.year);
CREATE INDEX val_metric   IF NOT EXISTS FOR (v:Valuation) ON (v.metric);
```

## 6. Cypher — Seed pattern (the spine, by example)

```cypher
// Commodity → Ingredient → BOM → Product, and the financial chain
MERGE (dairy:Commodity {name:'Skimmed Milk Powder'}) SET dairy.ratePerKg=320, dairy.market='Dairy';
MERGE (smp:Ingredient  {name:'Skimmed Milk Powder'}) SET smp.qtyPer100g=35, smp.uom='g';
MERGE (smp)-[:SOURCED_FROM {yield:1.0}]->(dairy);

MERGE (pp:ProductFamily {code:'PP'}) SET pp.name='Pregnancy Powder', pp.boxSizeG=500, pp.gstRate=0.18;
MERGE (bom:BOM {family:'PP', version:1}) SET bom.batchCost=20000000, bom.packagingCost=20, bom.conversionCost=7;
MERGE (pp)-[:HAS_RECIPE {version:1}]->(bom);
MERGE (bom)-[:COMPOSED_OF {qtyPer100g:35, qtyPerBox:175}]->(smp);

MERGE (sku:Product {skuId:'PP-T3-GARBHIKA'}) SET sku.tier=3, sku.variant='base', sku.boxSizeG=500;
MERGE (sku)-[:VARIANT_OF]->(pp);

MERGE (kapiva:Competitor {name:'Kapiva'}) SET kapiva.grossMargin=0.72, kapiva.ebitdaMargin=-0.21;
MERGE (kapiva)-[:BENCHMARKS {metric:'grossMargin', delta:0.15}]->(pp);

// Financial derivation chain (scenario-scoped)
MERGE (sc:Scenario {scenarioId:'BASE-Y1'}) SET sc.name='22Cr Base', sc.horizonYears=5;
MERGE (cost:Cost   {type:'costPerBox', year:1, valueInr:178.594});
MERGE (marg:Margin {type:'gross', year:1, pct:0.569});
MERGE (eb:EBITDA   {year:1, valueInr:134900000, marginPct:0.153});
MERGE (val:Valuation {metric:'NPV'});
MERGE (dairy)-[:DRIVES {ratePerKg:320}]->(cost);
MERGE (bom)-[:YIELDS {costPerBox:178.594}]->(cost);
MERGE (cost)-[:DETERMINES]->(marg);
MERGE (marg)-[:AGGREGATES_TO]->(eb);
MERGE (eb)-[:FEEDS]->(val);
FOREACH (n IN [cost,marg,eb,val] | MERGE (sc)-[:PARAMETERIZES]->(n));
```

## 7. Cypher — The killer queries (why a graph)

```cypher
// (A) IMPACT / BLAST RADIUS: if a commodity price moves, which valuations are affected?
MATCH (c:Commodity {name:'Skimmed Milk Powder'})
      -[:DRIVES]->(:Cost)-[:DETERMINES]->(:Margin)
      -[:AGGREGATES_TO]->(:EBITDA)-[:FEEDS]->(v:Valuation)
RETURN DISTINCT v.metric, v.value;

// (B) LINEAGE: full provenance of an EBITDA figure (what feeds it)
MATCH path = (src)-[:DRIVES|YIELDS|DETERMINES|CONTRIBUTES_TO|REDUCES|AGGREGATES_TO*1..6]->(e:EBITDA {year:1})
RETURN path;

// (C) WHICH PRODUCTS use a given commodity (procurement risk)
MATCH (c:Commodity {name:'Skimmed Milk Powder'})<-[:SOURCED_FROM]-(:Ingredient)
      <-[:COMPOSED_OF]-(:BOM)<-[:HAS_RECIPE]-(f:ProductFamily)<-[:VARIANT_OF]-(p:Product)
RETURN f.code, collect(p.skuId) AS skus;

// (D) COMPETITIVE GAP: families where a peer's gross margin beats ours
MATCH (comp:Competitor)-[b:BENCHMARKS]->(f:ProductFamily)
WHERE b.metric='grossMargin' AND b.delta > 0
RETURN comp.name, f.code, b.delta ORDER BY b.delta DESC;

// (E) DEMAND DRIVER: SAM share by family/tier driving volume
MATCH (m:Market)-[s:HAS_SAM]->(f:ProductFamily)
RETURN f.code, s.tier, s.share, s.year ORDER BY f.code, s.tier;
```

> Query (A)/(B) are the graph's reason to exist: **dependency tracing as a first-class operation.** The workbook's `#REF!` storm happened because dependencies were invisible; here they are queryable edges, so the "blast radius" of any change is one traversal away.

---

## 8. Mapping: Graph ↔ Relational ↔ Ontology

| Graph node | Relational table (DATABASE_SCHEMA) | Ontology entity (§2) |
|---|---|---|
| `:Product` | `core.skus` | Product |
| `:Ingredient` | `core.ingredients` | Ingredient |
| `:Commodity` | `core.ingredient_prices` (rate source) | Ingredient (rate) |
| `:BOM` | `core.boms` + `core.bom_lines` | BOM |
| `:Competitor` | `core.competitors` / `core.competitor_metrics` | Competitor |
| `:Channel` | `core.channels` | Hospital / Doctor |
| `:Market` | `core.markets` | Market |
| `:FundingRound` | `core.funding_rounds` | Funding Round |
| `:Cost / :Revenue / :Expense` | `proj.revenue_projection`, `proj.pnl_lines` | Cost / Revenue / Expense |
| `:Margin / :EBITDA` | `proj.pnl_lines` | (derived) |
| `:Valuation` | `proj.returns` | Valuation |
| `:Scenario` | `plan.scenarios` | Scenario |
| `:WorkingCapital` | `proj.working_capital` | Inventory/WC |
| `:Capex` | `plan.capex_plan` | Capex |

**Division of labour:** the relational store is the **system of record** (transactional integrity, constraints); the graph is the **reasoning surface** (traversal, lineage, impact, recommendation). The Agent Layer (AGENTS.md) queries the graph; the Simulation Layer reads/writes the relational store. Both are projections of the same ontology.

---

## 9. Production notes

- **Sync:** the graph is rebuilt/upserted from the relational store per snapshot (`Scenario` + version), keeping a single source of truth.
- **Scenario isolation:** scope traversals with `(:Scenario)-[:PARAMETERIZES]->` so two scenarios never bleed.
- **Performance:** index traversal anchors (`Cost.year`, `EBITDA.year`, `Valuation.metric`); keep the spine relationships typed narrowly so variable-length paths stay cheap.
- **Agent integration:** maps onto the configured AgentDB memory-graph (`memoryGraph.enabled`); the Chairman/CFO agents run query (A)/(B) for impact analysis before any recommendation.
- **Mock-data stance:** node *properties* are placeholders; the **labels and relationships are the deliverable** — exactly the flow/relationship focus you set.

---

## Appendix A — Node & relationship inventory

**Nodes (21):** Competitor, ProductFamily, Product, Brand, Ingredient, Commodity, BOM, Tier, Market, Plant, Channel, FundingRound, Scenario, Cost, Revenue, Expense, Capex, WorkingCapital, Margin, EBITDA, Valuation.

**Relationships (22):** BENCHMARKS, COMPETES_IN, BRANDS, VARIANT_OF, SOLD_IN, TARGETS, HAS_RECIPE, COMPOSED_OF, SOURCED_FROM, DRIVES, YIELDS, GENERATES, PRODUCES, HAS_SAM, RECEIVES_SPEND, DETERMINES, CONTRIBUTES_TO, REDUCES, AGGREGATES_TO, DEPRECIATES_INTO, FINANCES, FEEDS, PARAMETERIZES.

---

*End of KNOWLEDGE_GRAPH.md — the Neo4j reasoning surface for the Valencia Nutracare Decision Platform, built on BUSINESS_ONTOLOGY.md.*
