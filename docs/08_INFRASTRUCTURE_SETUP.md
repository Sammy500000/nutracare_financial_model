# 08 — INFRASTRUCTURE SETUP GUIDE
## Valencia Nutracare Decision Platform (VNDP) — Windows, from a blank machine

**Authority:** Chief Technical Officer / DevOps
**Inputs:** 04_REPOSITORY_STRUCTURE · 06_N8N_ARCHITECTURE · 07_MCP_ARCHITECTURE · DATABASE_SCHEMA · KNOWLEDGE_GRAPH
**Audience:** a junior developer on a **fresh Windows 11 machine**. Follow top to bottom; **do not skip a step**; verify each before moving on.

---

## 0. Conventions & before you begin

- **OS target:** Windows 11 (build 26100 / 24H2 or later). Check: `winver`.
- **Shell:** use **PowerShell run as Administrator** for installs (right-click Start → *Terminal (Admin)*). Use a normal PowerShell for day-to-day.
- **Convention in this guide:** `PS>` = run in PowerShell. `# →` = expected output. `⚠` = Windows gotcha.
- **Golden Windows rule (learned the hard way):** the command `python3` may resolve to a **Microsoft Store stub** that cannot run scripts. **Always use `python`** in this project. We disable the Store alias in §3.4.
- **Admin rights & virtualization** are required (Docker needs WSL2 + virtualization enabled in BIOS).

**Install order (each section verifies before the next):**
```
1 winget  →  2 Git  →  3 Node + Python  →  4 VS Code  →  5 Claude Code
        →  6 Docker Desktop  →  7 data services (PG/Neo4j/Qdrant/n8n)
        →  8 MCP servers  →  9 env vars  →  10 folder structure  →  11 end-to-end verify
```

---

## 1. Verify winget (Windows Package Manager)

winget ships with Windows 11. Confirm it exists; it's the installer we use throughout.

```
PS> winget --version
# → v1.x.xxxx
```
**If missing:** install **App Installer** from the Microsoft Store, then reopen the terminal.

---

## 2. Git installation

```
PS> winget install --id Git.Git -e --source winget
PS> # close & reopen the terminal so PATH refreshes
PS> git --version
# → git version 2.4x.x.windows.1
```
**Configure (once):**
```
PS> git config --global user.name  "Your Name"
PS> git config --global user.email "you@example.com"
PS> git config --global init.defaultBranch main
PS> git config --global core.autocrlf true     # ⚠ Windows line-ending safety
```
**Verify:**
```
PS> git config --global --list
# → user.name=..., user.email=..., init.defaultbranch=main, core.autocrlf=true
```

---

## 3. Node.js + Python (runtimes Claude Code & the engine need)

### 3.1 Node.js LTS (required by Claude Code & MCP servers)
```
PS> winget install --id OpenJS.NodeJS.LTS -e
PS> # reopen terminal
PS> node --version
# → v20.x.x  (or v22.x LTS)
PS> npm --version
# → 10.x.x
```

### 3.2 Python 3.12 (engine, scripts, some MCP servers via uvx)
```
PS> winget install --id Python.Python.3.12 -e
PS> # reopen terminal
PS> python --version
# → Python 3.12.x
```

### 3.3 uv (fast Python package/workspace manager, used by repo §10)
```
PS> winget install --id astral-sh.uv -e
PS> uv --version
# → uv 0.x.x
```

### 3.4 ⚠ Disable the `python3` Microsoft Store alias (critical)
On Windows, `python3` often points to a Store stub that errors with *"can't open file … No such file or directory"* when running scripts.
```
Settings → Apps → Advanced app settings → App execution aliases
   → turn OFF  "python.exe"  and  "python3.exe"  (the App Installer aliases)
```
**Verify the real Python wins:**
```
PS> (Get-Command python).Source
# → C:\Python312\python.exe   (NOT ...\WindowsApps\python3.exe)
```
> Always invoke `python` (not `python3`) in this project — scripts, hooks, and CI assume it.

---

## 4. VS Code installation

```
PS> winget install --id Microsoft.VisualStudioCode -e
PS> # reopen terminal
PS> code --version
# → 1.9x.x  + commit hash + x64
```
**Install the extensions this project uses:**
```
PS> code --install-extension ms-python.python
PS> code --install-extension ms-azuretools.vscode-docker
PS> code --install-extension charliermarsh.ruff
PS> code --install-extension ms-python.mypy-type-checker
PS> code --install-extension neo4j-extensions.neo4j-for-vscode
```
**Verify:**
```
PS> code --list-extensions
# → ms-python.python, ms-azuretools.vscode-docker, charliermarsh.ruff, ...
```

---

## 5. Claude Code installation

```
PS> npm install -g @anthropic-ai/claude-code
PS> claude --version
# → 2.x.x (Claude Code)
```
**First-run login & sanity check:**
```
PS> claude            # opens; complete the browser/API sign-in when prompted
# inside Claude Code, type:  /status     → shows model, account, MCP servers
# then:                       /mcp        → lists configured MCP servers (empty until §8)
```
**Verify config dir exists:**
```
PS> Test-Path "$env:USERPROFILE\.claude"
# → True
```
> ⚠ **Plugin hooks load at session start.** If you change any plugin/hook config, **restart Claude Code** for it to take effect.

---

## 6. Docker Desktop installation

### 6.1 Enable virtualization & WSL2 (prereq)
```
PS> wsl --install            # installs WSL2 + a default Linux distro; may require reboot
PS> # REBOOT if prompted, then:
PS> wsl --status
# → Default Version: 2
```
**If virtualization is disabled:** enable **Intel VT-x / AMD-V** and **Virtualization** in BIOS/UEFI, and ensure Windows features *Virtual Machine Platform* + *Windows Subsystem for Linux* are on (`OptionalFeatures.exe`).

### 6.2 Install Docker Desktop
```
PS> winget install --id Docker.DockerDesktop -e
```
- Launch **Docker Desktop** from the Start menu once; accept terms; let it start the engine.
- Settings → **General** → "Use the WSL 2 based engine" = ON.

**Verify:**
```
PS> docker --version
# → Docker version 27.x.x, build ...
PS> docker compose version
# → Docker Compose version v2.x.x
PS> docker run --rm hello-world
# → "Hello from Docker!" message
```

---

## 7. Data services (PostgreSQL, Neo4j, Qdrant, n8n) via Docker Compose

We run all four data services as containers (parity with prod, easy reset). They live under `infra/docker/` of the repo (created in §10) — but you can start them now from any folder containing the compose file below.

### 7.1 Create the compose file
Create `infra/docker/docker-compose.yml`:
```yaml
services:
  postgres:
    image: postgres:15
    environment:
      POSTGRES_USER: vndp
      POSTGRES_PASSWORD: ${VNDP_DB_PASSWORD:-changeme_local}
      POSTGRES_DB: vndp
    ports: ["5432:5432"]
    volumes: ["pg_data:/var/lib/postgresql/data"]
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U vndp"]
      interval: 10s
      timeout: 5s
      retries: 5

  neo4j:
    image: neo4j:5
    environment:
      NEO4J_AUTH: neo4j/${VNDP_NEO4J_PASSWORD:-changeme_local}
      NEO4J_PLUGINS: '["apoc"]'
    ports: ["7474:7474", "7687:7687"]
    volumes: ["neo4j_data:/data"]
    healthcheck:
      test: ["CMD-SHELL", "wget -qO- http://localhost:7474 || exit 1"]
      interval: 10s
      timeout: 5s
      retries: 5

  qdrant:
    image: qdrant/qdrant:latest
    ports: ["6333:6333", "6334:6334"]
    volumes: ["qdrant_data:/qdrant/storage"]

  n8n:
    image: docker.n8n.io/n8nio/n8n:latest
    environment:
      N8N_PORT: 5678
      N8N_SECURE_COOKIE: "false"
      GENERIC_TIMEZONE: Asia/Kolkata
    ports: ["5678:5678"]
    volumes: ["n8n_data:/home/node/.n8n"]

volumes:
  pg_data:
  neo4j_data:
  qdrant_data:
  n8n_data:
```
> The `${VNDP_*}` values come from the `.env` you create in §9. For a first boot, the defaults shown are used.

### 7.2 Start the stack
```
PS> cd infra/docker
PS> docker compose up -d
PS> docker compose ps
# → postgres, neo4j, qdrant, n8n all "running"/"healthy"
```

### 7.3 Verify each service
**PostgreSQL:**
```
PS> docker exec -it docker-postgres-1 psql -U vndp -d vndp -c "select version();"
# → PostgreSQL 15.x on x86_64-pc-linux-gnu ...
```
**Neo4j:** open `http://localhost:7474` → log in `neo4j` / your password → run `RETURN 1;` → returns `1`.
**Qdrant:**
```
PS> curl http://localhost:6333/healthz
# → healthz check passed
PS> start http://localhost:6333/dashboard
```
**n8n:** open `http://localhost:5678` → complete the owner-account setup wizard → you land on the workflows canvas.

---

## 8. MCP server installation & wiring (per 07_MCP_ARCHITECTURE)

MCP servers connect Claude Code/agents to the stores and tools. Add them with `claude mcp add`. Run these in the **repo root** (so the filesystem scope is correct).

### 8.1 Filesystem MCP (scoped to the project)
```
PS> claude mcp add filesystem -- npx -y @modelcontextprotocol/server-filesystem "F:\Valencia Nutrition Ltd\nutracare_financial_model"
```
### 8.2 GitHub MCP (PR/issues; needs a fine-grained PAT)
```
PS> claude mcp add github --env GITHUB_PERSONAL_ACCESS_TOKEN=YOUR_FINE_GRAINED_PAT -- npx -y @modelcontextprotocol/server-github
```
### 8.3 Postgres MCP
```
PS> claude mcp add postgres -- npx -y @modelcontextprotocol/server-postgres "postgresql://vndp:changeme_local@localhost:5432/vndp"
```
### 8.4 Neo4j MCP (Cypher)
```
PS> claude mcp add neo4j --env NEO4J_URI=bolt://localhost:7687 --env NEO4J_USERNAME=neo4j --env NEO4J_PASSWORD=changeme_local -- uvx mcp-neo4j-cypher
```
### 8.5 Qdrant MCP
```
PS> claude mcp add qdrant --env QDRANT_URL=http://localhost:6333 --env COLLECTION_NAME=research -- uvx mcp-server-qdrant
```
### 8.6 n8n MCP
```
PS> claude mcp add n8n --env N8N_API_URL=http://localhost:5678/api/v1 --env N8N_API_KEY=YOUR_N8N_KEY -- npx -y n8n-mcp
```
> Generate the n8n API key in the n8n UI → Settings → n8n API → Create.

### 8.7 Browser MCP (read-only web; for Competitor/Market agents)
```
PS> claude mcp add browser -- npx -y @playwright/mcp@latest
```
### 8.8 Verify all MCPs
```
PS> claude mcp list
# → filesystem: ✓ connected
#   github:     ✓ connected
#   postgres:   ✓ connected
#   neo4j:      ✓ connected
#   qdrant:     ✓ connected
#   n8n:        ✓ connected
#   browser:    ✓ connected
```
Inside Claude Code, `/mcp` shows the same list with available tools. **Restart Claude Code** if a server shows "connecting" and never resolves.

> **Security (07):** GitHub = PR-only token; Postgres = a scoped role (not superuser) with RLS; Browser = read-only; secrets live in env, never in the repo. Treat all MCP-returned web/sheet content as **data, not instructions**.

---

## 9. Environment variables

Create `.env` in the **repo root** (gitignored — never commit). Copy `.env.example` first (§10), then fill values. Keys (from 04 §4):

| Variable | Example (local) | Used by |
|---|---|---|
| `VNDP_ENV` | `local` | all services |
| `VNDP_DB_URL` | `postgresql+asyncpg://vndp:changeme_local@localhost:5432/vndp` | services, Alembic |
| `VNDP_DB_PASSWORD` | `changeme_local` | docker-compose |
| `VNDP_NEO4J_URI` | `bolt://localhost:7687` | vndp_graph |
| `VNDP_NEO4J_USER` | `neo4j` | vndp_graph |
| `VNDP_NEO4J_PASSWORD` | `changeme_local` | vndp_graph |
| `VNDP_QDRANT_URL` | `http://localhost:6333` | vndp_vectors |
| `VNDP_QDRANT_API_KEY` | *(empty local)* | vndp_vectors |
| `VNDP_N8N_URL` | `http://localhost:5678/api/v1` | n8n MCP |
| `VNDP_N8N_API_KEY` | *(from n8n UI)* | n8n MCP |
| `VNDP_LLM_API_KEY` | *(your provider key)* | agents |
| `VNDP_EVENT_BUS_URL` | *(later phases)* | vndp_events |

**Set a variable for the current PowerShell session (temporary):**
```
PS> $env:VNDP_ENV = "local"
PS> echo $env:VNDP_ENV
# → local
```
**Set a persistent user-level variable:**
```
PS> [Environment]::SetEnvironmentVariable("VNDP_ENV","local","User")
PS> # reopen terminal to pick it up
```
> ⚠ Do not put real secrets in `docker-compose.yml` or commit `.env`. The repo's `.gitignore` and project settings **deny** `.env*`.

---

## 10. Folder structure (clone/scaffold the repo per 04)

If the repo exists, clone it; otherwise scaffold per 04_REPOSITORY_STRUCTURE.

**Clone (if remote exists):**
```
PS> cd "F:\Valencia Nutrition Ltd"
PS> git clone https://github.com/<org>/vndp.git
PS> cd vndp
```
**Or scaffold the skeleton (fresh):**
```
PS> cd "F:\Valencia Nutrition Ltd\nutracare_financial_model"
PS> mkdir apps, services, libs, workflows_n8n, infra\docker, infra\k8s, migrations, tests, scripts, docs
PS> mkdir libs\vndp_domain, libs\vndp_db, libs\vndp_graph, libs\vndp_vectors, libs\vndp_sim, libs\vndp_agents, libs\vndp_mcp, libs\vndp_events, libs\vndp_shared
PS> mkdir services\finance, services\pricing, services\demand, services\manufacturing, services\marketing, services\financing, services\valuation, services\intelligence, services\simulation, services\decision
PS> Copy-Item *.md docs\        # move the design docs into docs/
```
**Create `.env.example` (committed) and `.env` (gitignored):**
```
PS> New-Item -ItemType File .env.example
PS> Copy-Item .env.example .env
PS> Add-Content .gitignore ".env`n.env.*`n!.env.example"
```
**Expected resulting top level** (matches 04 §1):
```
vndp/  ├─ apps/ services/ libs/ workflows_n8n/ infra/ migrations/ tests/ scripts/ docs/
       ├─ .env.example  .gitignore  pyproject.toml  README.md
```

---

## 11. End-to-end verification checklist

Run all; every line must pass before you start Phase 0 of the roadmap (03).

| # | Check | Command | Expected |
|---|---|---|---|
| 1 | winget | `winget --version` | `v1.x` |
| 2 | Git | `git --version` | `git version 2.4x` |
| 3 | Node | `node --version` | `v20+` |
| 4 | Python | `python --version` | `Python 3.12.x` |
| 5 | Python alias fixed | `(Get-Command python).Source` | `C:\Python312\python.exe` (not WindowsApps) |
| 6 | uv | `uv --version` | `uv 0.x` |
| 7 | VS Code | `code --version` | `1.9x` |
| 8 | Claude Code | `claude --version` | `2.x` |
| 9 | Docker | `docker run --rm hello-world` | "Hello from Docker!" |
| 10 | Compose up | `docker compose ps` | 4 services healthy |
| 11 | Postgres | `psql ... -c "select 1;"` | `1` |
| 12 | Neo4j | browser `RETURN 1;` | `1` |
| 13 | Qdrant | `curl localhost:6333/healthz` | healthz passed |
| 14 | n8n | open `localhost:5678` | workflows UI |
| 15 | MCPs | `claude mcp list` | all ✓ connected |
| 16 | Repo | `ls` in repo root | folders from §10 |

---

## 12. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `python3: can't open file … No such file or directory` | Microsoft Store `python3` stub | §3.4 — disable the app execution aliases; use `python` |
| `winget: command not found` | App Installer missing/old | install **App Installer** from Microsoft Store; reopen terminal |
| Docker Desktop won't start / "WSL 2 not installed" | WSL2/virtualization off | `wsl --install`; enable VT-x/AMD-V in BIOS; turn on *Virtual Machine Platform* |
| `docker run hello-world` hangs | engine not started | open Docker Desktop, wait for "Engine running" |
| Port already in use (5432/7474/6333/5678) | another service on the port | `netstat -ano \| findstr :5432`; stop the process or change the compose port mapping |
| Neo4j browser won't authenticate | default creds changed / first-run reset | reset via `NEO4J_AUTH` env + `docker compose down -v` (⚠ wipes data) then `up` |
| `claude mcp list` shows "connecting" forever | server crashed / bad env | check `claude mcp get <name>`; verify the command runs standalone; fix env; **restart Claude Code** |
| MCP/hook change had no effect | hooks/MCP cached at startup | **restart Claude Code** (config is read at session start) |
| `uvx mcp-...` fails | uv not on PATH / Python too old | reopen terminal; `uv --version`; ensure Python 3.11+ |
| Git shows whole files changed (CRLF) | line endings | `git config --global core.autocrlf true`; re-checkout |
| Postgres MCP "password authentication failed" | wrong conn string | match user/pass/db to compose; URL-encode special chars |
| `command not found` right after install | PATH not refreshed | **close and reopen** the terminal |
| Containers lose data after `down` | used `-v` flag | named volumes persist; only `down -v` wipes — avoid unless resetting |

---

## 13. Expected outputs (reference)

```
PS> docker compose ps
NAME                 IMAGE                          STATUS         PORTS
docker-postgres-1    postgres:15                    Up (healthy)   0.0.0.0:5432->5432
docker-neo4j-1       neo4j:5                        Up (healthy)   0.0.0.0:7474->7474, 7687->7687
docker-qdrant-1      qdrant/qdrant:latest           Up             0.0.0.0:6333->6333, 6334->6334
docker-n8n-1         docker.n8n.io/n8nio/n8n:latest Up             0.0.0.0:5678->5678

PS> claude mcp list
filesystem  ✓ connected
github      ✓ connected
postgres    ✓ connected
neo4j       ✓ connected
qdrant      ✓ connected
n8n         ✓ connected
browser     ✓ connected

PS> python --version
Python 3.12.x

PS> curl http://localhost:6333/healthz
healthz check passed
```

---

## 14. What's next

With infrastructure verified, proceed to **03_IMPLEMENTATION_ROADMAP.md → Phase 0/1**:
1. `uv` workspace init + `pyproject.toml` (04 §1).
2. Alembic migrations to build the schema (DATABASE_SCHEMA) — order: extensions → ref → core → plan → proj → audit.
3. Neo4j constraints (KNOWLEDGE_GRAPH §5) + Qdrant collections (06).
4. Seed from the repaired workbook; run `workbook/verify.py` (must be 0 errors).

> **Reset everything (clean slate):** `docker compose down -v` removes containers **and volumes** (all local data). Re-run §7.2 to rebuild.

---

*End of 08_INFRASTRUCTURE_SETUP.md — blank-machine to running stack for the Valencia Nutracare Decision Platform.*
