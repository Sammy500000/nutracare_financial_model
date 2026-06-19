# VNDP task runner — commands only, no logic. Run `just <recipe>`.
# (Install just: `winget install Casey.Just` or `cargo install just`.)

set windows-shell := ["powershell.exe", "-NoLogo", "-Command"]

# list recipes
default:
    @just --list

# resolve the uv workspace
sync:
    uv sync

# lint + format check + import order
lint:
    uv run ruff check .
    uv run ruff format --check .

# auto-fix lint + format
fix:
    uv run ruff check --fix .
    uv run ruff format .

# strict type check
types:
    uv run mypy .

# run tests (pass marker e.g. `just test unit`)
test marker="":
    uv run pytest {{ if marker != "" { "-m " + marker } else { "" } }}

# golden-master acceptance gate
golden:
    uv run pytest -m golden

# workbook zero-error gate
verify:
    python workbook/verify.py

# bring up local stack
up:
    docker compose -f infra/docker/docker-compose.yml up -d

# tear down (keeps volumes)
down:
    docker compose -f infra/docker/docker-compose.yml down

# full local gate (mirrors CI)
ci: lint types verify
    uv run pytest
