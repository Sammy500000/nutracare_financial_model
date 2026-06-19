# ADR-0002 — Event bus: Redpanda (Kafka-compatible)

- **Status:** Accepted · 2026-06-19
- **Deciders:** CTO (stakeholder-selected)
- **Resolves:** RISK_REGISTER R-06

## Context

`01_SYSTEM_ARCHITECTURE` §8 specifies an event-driven core (domain events such as `IngredientPriceChanged`,
`SnapshotCreated`, `SimulationCompleted`, `DecisionApproved`) with durable, **per-scenario-partitioned** ordering
and consumer-group backpressure, but left the technology as "Target" (Kafka/Redpanda/NATS). Events first appear
when the Simulation service ships (P3) and are exercised heavily by n8n ingestion (P5) and the agent boardroom (P6).

## Decision

Use **Redpanda** (Kafka API-compatible) as the event bus for all environments. Local stack runs a single-node
Redpanda + Console via `infra/docker/docker-compose.yml` (Kafka on `:9092`, schema registry on `:18081`,
console on `:8080`). Topics are partitioned by `scenario_id` for ordered, parallel consumption. A thin
`libs/vndp_events` package owns event contracts (PascalCase, past-tense) and the producer/consumer adapter; until
the bus is wired (pre-P5) an in-process adapter satisfies the same interface.

## Consequences

- **+** Kafka ecosystem + tooling, no JVM/ZooKeeper footprint; single binary, fast local boot.
- **+** Durable ordered partitions match the per-scenario saga model (01 §8.3) and reproducibility key.
- **−** Heavier than NATS for a single-dev laptop; mitigated by `--smp=1 --overprovisioned` in dev.
- Schema registry enables typed event contracts and forward/backward compatibility checks.
