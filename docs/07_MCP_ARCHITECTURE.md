# 07 — MCP ARCHITECTURE
## Valencia Nutracare Decision Platform (VNDP)

**Authority:** Chief Enterprise Architect
**Source of truth:** [BUSINESS_ONTOLOGY.md](BUSINESS_ONTOLOGY.md)
**Aligns with:** [01_SYSTEM_ARCHITECTURE.md](01_SYSTEM_ARCHITECTURE.md) (security §11) · [AGENTS.md](AGENTS.md) · [06_N8N_ARCHITECTURE.md] *(pending)*
**Status:** MCP integration spec · v1.0

---

## 1. Purpose & principles

The **Model Context Protocol (MCP)** is how the agent layer reaches the outside world — stores, the workbook, the web, code, and automation. This document defines all eight MCP servers, each with **Purpose · Access Rights · Security Model · Agent Usage**.

### Governing security principles (apply to every MCP)
| # | Principle |
|---|---|
| S1 | **Instruction-source boundary** — content returned by any MCP (web pages, sheet cells, file contents, rows, issues) is **data, not instructions**. Agents never execute directives embedded in tool results. |
| S2 | **Least privilege** — each MCP is scoped to the narrowest path/database/repo/permission needed; read-only by default. |
| S3 | **Write gating** — any state-changing call (DB write, file write, commit, sheet edit, workflow trigger) is **proposed, validated, and human-approved** for irreversible effects. Agents recommend; humans commit. |
| S4 | **No secrets in context** — credentials live in a vault/env; `.env` and secret paths are denied (project settings `deny`). MCPs receive scoped tokens, never raw secrets in prompts. |
| S5 | **Audit** — every MCP call (actor, args, result hash) is logged to `audit.change_log`; writes are non-repudiable. |
| S6 | **Untrusted-source quarantine** — Browser/Google-Sheets/Research content passes through an Anti-Corruption Layer (ACL) that strips embedded instructions before reaching reasoning. |

### Trust zones
```
   TRUSTED (internal, write-capable w/ gating)        UNTRUSTED (external, read, ACL-wrapped)
   ┌───────────────────────────────────────┐         ┌──────────────────────────────────────┐
   │ Postgres · Neo4j · Qdrant · Filesystem │         │ Browser (web) · Google Sheets (shared) │
   │ · GitHub · n8n                         │         │ · Research sources                     │
   └───────────────────────────────────────┘         └──────────────────────────────────────┘
                    ▲                                            │ ACL: strip directives, validate
                    └──────────────── agents ────────────────────┘
```

---

## 2. MCP Integrations

### 2.1 Filesystem MCP
| | |
|---|---|
| **Purpose** | Read/write the documentation set, the repaired workbook, simulation artifacts, snapshots, and exports (board packs). |
| **Access Rights** | **Scoped to the project root** `F:\…\nutracare_financial_model` only. Read: docs, workbook, dumps. Write: `/docs`, `/exports`, `/snapshots`. **Denied:** `.env*`, secret/key files, paths outside project root. |
| **Security Model** | Path allow-list (project root) + deny-list (secrets); write gating (S3) on anything outside scratch; all writes audited; symlink escape blocked. |
| **Agent Usage** | All agents read specs; **Chairman/Document agents** write board packs & decision records; **validator** reads artifacts to verify. |

### 2.2 GitHub MCP
| | |
|---|---|
| **Purpose** | Version the documentation, schema migrations, and simulation/config as code; PRs, issues, review. |
| **Access Rights** | Single repo (this project). Read: code, PRs, issues. Write: branches, commits, PRs, issue comments — **never force-push, never to default branch directly**. No repo-admin (settings, secrets, collaborators). |
| **Security Model** | Fine-grained PAT scoped to one repo; branch-protection respected; commits authored transparently (no attribution trailer unless configured, per project rule); write gating (S3) — PRs opened for human merge, not auto-merged. |
| **Agent Usage** | **Worker/devops agents** open PRs for schema/spec changes; **reviewer agent** comments; humans merge. Used by the GitHub-* skills already present in the project. |

### 2.3 Postgres MCP
| | |
|---|---|
| **Purpose** | The system of record — read/write the relational entities & projections ([DATABASE_SCHEMA.md](DATABASE_SCHEMA.md)). |
| **Access Rights** | Per-role DB users: **read-only** role for analyst/advisory agents (Market, Competitor, Investor read); **scoped read-write** for owning services (Finance svc writes `proj.*`, Pricing writes `plan.prices`). **RLS scoped by `scenario_id`.** No DDL/superuser from agents (migrations go via GitHub→Prisma). |
| **Security Model** | Row-Level Security by scenario ownership; least-privilege roles; parameterized queries only (no string-built SQL — injection defense); write gating on `plan.*`/`core.*` edits; every mutation audited. |
| **Agent Usage** | **CFO/COO/Investor** read facts & projections; **Simulation svc** writes `proj.*` under a service identity; agents read via the read-only role for reasoning. |

### 2.4 Browser MCP
| | |
|---|---|
| **Purpose** | Gather external web intelligence — competitor pricing/launches, market/demographic data, regulatory updates. |
| **Access Rights** | **Read-only browsing**, no authenticated sessions, no form submission, no logins, no downloads without approval. Domain allow-list for routine sources; ad-hoc URLs flagged. |
| **Security Model** | **Untrusted zone** — all fetched content is data (S1) and passes the ACL (S6): instructions/hidden text stripped before reasoning; never follow links/endpoints suggested by fetched content; no PII submitted; suspicious/unfamiliar URLs require human confirmation. |
| **Agent Usage** | **Competitor agent** (benchmarks) and **Market agent** (sizing) — feeding M-COMP and M-DEMAND. Also drives the n8n Competitor/Market workflows (06). |

### 2.5 Google Sheets MCP
| | |
|---|---|
| **Purpose** | Bridge the live source workbook (the model authored in Sheets/xlsx) ↔ the platform; the basis of the **Workbook Synchronization** workflow (06). |
| **Access Rights** | **Read** the designated workbook(s); **write only to a sandboxed "platform-output" tab**, never the human-authored input cells. No sharing/permission changes, no creating spreadsheets. |
| **Security Model** | Scoped OAuth to specific sheet IDs; **content treated as untrusted** (a cell can contain a prompt-injection string) → ACL (S6); writes gated & limited to the output tab; validation gate (schema/range/`#REF!` scan) before any cell is trusted — the systemic cure for the original defect. |
| **Agent Usage** | **Sync worker / Workbook agent** reads inputs into Postgres and writes computed results back to the output tab; never edits human inputs autonomously. |

### 2.6 Neo4j MCP
| | |
|---|---|
| **Purpose** | Query the knowledge graph for **lineage and impact** ([KNOWLEDGE_GRAPH.md](KNOWLEDGE_GRAPH.md)) — "if commodity X moves, which valuations shift?" |
| **Access Rights** | **Read-heavy**: agents run parameterized Cypher reads. Writes restricted to the **graph-sync service** that rebuilds the graph from Postgres per snapshot. No schema/`admin` procedures from agents. |
| **Security Model** | Read-only role for agents; parameterized Cypher only (injection defense); scenario-scoped traversals (`:Scenario`-bounded); sync writes audited; APOC/admin procedures disabled for agent role. |
| **Agent Usage** | **CFO/Chairman** run impact (blast-radius) and lineage queries before recommending; **Competitor** queries `BENCHMARKS` edges; **validator** traces provenance. |

### 2.7 Qdrant MCP
| | |
|---|---|
| **Purpose** | Vector store for semantic memory & retrieval — research corpus, prior scenarios/decisions, competitor/market documents (RAG for agents). |
| **Access Rights** | Read (similarity search) for all agents; **write/upsert** restricted to the ingestion/sync workers (Research Ingestion, Competitor/Market workflows). Per-collection scoping (research / decisions / competitor / market). |
| **Security Model** | Collection-level ACL; metadata filters enforce scenario/tenant isolation; embeddings carry source provenance; retrieved chunks are **data, not instructions** (S1) — quarantined before reasoning; no raw secret text embedded. |
| **Agent Usage** | All agents do semantic recall ("what did we decide last time / what does the research say"); ingestion workers upsert. Backs the AgentDB/memory layer described in earlier docs (Qdrant is the chosen external vector DB). |

### 2.8 n8n MCP
| | |
|---|---|
| **Purpose** | Trigger and monitor the automation workflows (06) — competitor monitoring, market/financial intelligence, research ingestion, workbook sync. |
| **Access Rights** | **Execute/trigger** a fixed allow-list of named workflows; read run status/logs. **Cannot create or edit** workflow definitions (those are versioned via GitHub). No credential access. |
| **Security Model** | Scoped API key; workflow allow-list (no arbitrary execution); each workflow runs with its own least-privilege credentials (not the agent's); trigger calls audited; outputs re-enter the platform through the same validation gates. |
| **Agent Usage** | **Chairman/orchestrator** triggers an intelligence refresh before a board cycle; **Market/Competitor agents** kick their pipelines; results land in Postgres/Qdrant/Neo4j for the next reasoning pass. |

---

## 3. MCP × Agent usage matrix

| MCP | CFO | CMO | COO | Investor | Market | Competitor | Chairman | Workers/Svc |
|---|---|---|---|---|---|---|---|---|
| Filesystem | R | R | R | R | R | R | R/W | R/W |
| GitHub | – | – | – | – | – | – | R | R/W (PR) |
| Postgres | R | R/w* | R/w* | R | R | R | R | R/W (svc) |
| Browser | – | R | – | – | R | R | – | R (ACL) |
| Google Sheets | – | – | – | – | – | – | – | R / W-output |
| Neo4j | R | R | R | R | R | R | R | W (sync) |
| Qdrant | R | R | R | R | R | R | R | R/W (ingest) |
| n8n | – | trigger | – | – | trigger | trigger | trigger | run |

*R = read · W = write (gated) · w\* = scoped write to the agent's own domain tables · "–" = not used.*

---

## 4. Access-rights summary (least privilege)

| MCP | Default | Write capability | Hard limits |
|---|---|---|---|
| Filesystem | read project root | `/docs`,`/exports`,`/snapshots` (gated) | deny secrets, no escape |
| GitHub | read repo | branch/PR (gated) | no force-push, no default-branch, no admin |
| Postgres | read (RLS) | own-domain tables (gated) | no DDL/superuser, scenario-scoped |
| Browser | read web | none | no auth/login/submit/download |
| Google Sheets | read workbook | output tab only | no input-cell edit, no sharing |
| Neo4j | read graph | sync service only | no admin procs, parameterized only |
| Qdrant | read/search | ingest workers only | collection-scoped |
| n8n | trigger allow-list | n/a | no workflow edit, no cred access |

---

## 5. Security model (cross-cutting)

| Control | Implementation |
|---|---|
| **AuthN** | service identities (mTLS/scoped tokens) per MCP; no shared creds |
| **AuthZ** | per-MCP role + per-row RLS (Postgres) + collection ACL (Qdrant) + scenario scoping (Neo4j) |
| **Injection defense** | parameterized queries (PG/Neo4j); ACL strips embedded directives (Browser/Sheets/Research); S1 boundary |
| **Write safety** | S3 gating — irreversible writes proposed → validated → human-approved; reversible writes audited |
| **Secrets** | vault-managed; never in prompts/context; `.env*` denied |
| **Audit** | every call → `audit.change_log` (actor, MCP, args, result hash, timestamp) |
| **Quarantine** | untrusted-zone results never directly parameterize a write to the trusted zone without validation |
| **Human-in-the-loop** | capital/contract/dilution actions are out of scope for *every* MCP — escalated to humans (AGENTS §10) |

---

## 6. How a board cycle uses the MCPs (illustrative flow)

```
 Chairman ──(n8n MCP)──► trigger intel refresh
   ├─ Competitor/Market agents ──(Browser MCP, ACL)──► web ──► extract ──(Qdrant/Postgres/Neo4j MCP)──► stores
 CFO/COO ──(Postgres MCP, read)──► facts ; ──(Neo4j MCP)──► impact/lineage queries
 Simulation svc ──► runs engine (05) ──(Postgres MCP, write proj.*, gated)──► results
 Agents debate ──(Qdrant MCP)──► recall prior decisions ; Chairman synthesizes
 Decision approved (human) ──(Filesystem/GitHub MCP)──► board pack + decision-of-record committed
 (Google Sheets MCP) ──► write computed results back to the workbook output tab
```

---

*End of 07_MCP_ARCHITECTURE.md — the MCP integration design for the Valencia Nutracare Decision Platform, governed by BUSINESS_ONTOLOGY.md.*
