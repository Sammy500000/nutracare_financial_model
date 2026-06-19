# ADR-0003 — LLM & embeddings: open-source, local-first via Ollama

- **Status:** Accepted · 2026-06-19
- **Deciders:** CTO (stakeholder delegated: "best available open-source tools")
- **Resolves:** RISK_REGISTER R-05

## Context

The Agent Boardroom (`AGENTS.md`, PydanticAI) needs an LLM for reasoning/extraction; the Knowledge Layer
(`KNOWLEDGE_GRAPH`/Qdrant) and n8n Research Ingestion need an embedding model. Constraints: open-source,
swappable, data stays local (financial plan = confidential, 01 §11), and it must work with PydanticAI (which
speaks the OpenAI-compatible API) and with Qdrant. The roadmap (03 §P2 risk) recommends "a small local model,
made swappable."

## Decision

Serve open-weight models locally through **Ollama** (OpenAI-compatible endpoint at `:11434/v1`), wired via env
(`VNDP_LLM_BASE_URL`, `VNDP_LLM_MODEL`, `VNDP_EMBED_MODEL`) so any model is a config swap:

- **Agent/extraction LLM:** **Qwen2.5-Instruct** (Apache-2.0) — default `qwen2.5:14b-instruct`; scale to
  `qwen2.5:32b-instruct` or `llama3.3:70b` where hardware allows. Strong reasoning/structured-output for the
  typed PydanticAI contracts and financial debate.
- **Embeddings:** **`nomic-embed-text`** (open, 768-dim, long-context) for all Qdrant collections; alternative
  `bge-m3` for multilingual. Embeddings are **data, not instructions** (ACL before reasoning).

PydanticAI agents target the OpenAI-compatible provider pointed at Ollama; no proprietary key required.

## Consequences

- **+** Fully open-source, local, no per-token cost, confidential data never leaves the host.
- **+** Model is a one-line env swap; embedding dim (768) fixes the Qdrant collection vector size.
- **−** Quality/throughput below frontier hosted models; mitigated by model-size scaling + the validator/truth-score
  gate (09 §9) and by keeping the provider abstraction swappable to a hosted endpoint if needed.
- **−** Requires Ollama installed locally (added to setup prerequisites); CI mocks the LLM (no live calls in unit tests).
