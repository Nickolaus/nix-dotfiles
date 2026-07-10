# Local AI Observability Research

Date: 2026-07-10

## Question

Can we install something like Langfuse locally to gather proper metrics about the AI setup and measure impacts of setup changes?

Short answer: yes. But for this repo, Langfuse alone is not the best first move if the main target is Codex/Claude/Cursor/Vibe/OpenCode behavior. The best design is an OpenTelemetry-first local observability layer, with a specialized LLM UI on top.

## Current Local Context

The dotfiles already have several measurement-adjacent pieces:

- `headroom`: local proxy layer for compression and provider routing.
- `rtk`: dev-tool output compression with `rtk gain` for savings.
- `ai-receipt-log`: local repo-scoped workflow outcome receipts.
- `scripts/hot-benchmark.sh`: local Ollama model benchmark with warmed-model runs and commit-message quality scoring.
- `codebase-memory`, `graphify`, `chonkie`: repo/context tooling with explicit boundaries.

Missing piece: durable trace/event storage, dashboards, and consistent run metadata across AI tools.

## Source Findings

### OpenTelemetry Baseline

OpenTelemetry is the right substrate for this setup because it is open source, vendor/tool agnostic, and covers generation, export, and collection of telemetry data such as traces, metrics, and logs. It intentionally leaves backend storage and visualization to other tools. Source: <https://opentelemetry.io/docs/what-is-opentelemetry/>

OpenTelemetry has current GenAI semantic conventions and a separate GenAI conventions repository. This matters because we should avoid inventing field names for model, token usage, cost, agent step, tool call, and MCP events when standards exist. Source: <https://opentelemetry.io/docs/specs/semconv/gen-ai/>

Nixpkgs currently has `opentelemetry-collector-contrib` as `otelcol-contrib` version `0.144.0`, but does not currently package `langfuse`, `openlit`, or Arize Phoenix as direct nixpkgs packages. That pushes UI/backends toward Docker Compose or upstream container images, while Nix can manage wrappers, policy, collector config, and helper commands.

### Langfuse

Langfuse is open source and self-hostable with Docker. Low-scale/local Docker Compose is explicitly supported for testing and low-scale deployments, but Langfuse warns that it lacks high availability, scaling, and backup functionality. Source: <https://langfuse.com/self-hosting>

Langfuse v3 architecture is heavier than "one small app": web container, worker container, Postgres, ClickHouse, Redis/Valkey, and S3/blob storage. ClickHouse stores traces/observations/scores; Postgres handles transactional data; Redis handles queue/cache; blob storage persists events, multimodal inputs, and exports. Source: <https://langfuse.com/self-hosting>

Langfuse supports OpenTelemetry ingestion. It maps OTel/OpenInference/MLflow-style attributes into Langfuse traces and observations, including input, output, model, model parameters, token usage, and cost. Its current OTLP endpoint supports HTTP JSON/protobuf, not gRPC. Source: <https://langfuse.com/integrations/native/opentelemetry>

Fit: strongest for LLM application traces, prompt management, datasets/evals, and Langfuse-native UI. Less directly aligned with local coding-agent telemetry unless we build or adopt adapters.

### Arize Phoenix

Phoenix is free to self-host with no feature limitations, no license fees, no usage limits, and no feature gates. Its docs say traces, prompts, and data stay within your infrastructure and can be air-gapped. Source: <https://arize.com/docs/phoenix/self-hosting>

Phoenix offers terminal, Docker/Compose, Kubernetes, Helm, AWS CloudFormation, and Railway deployment options. It includes tracing, evals, datasets, experiments, and prompt management. Source: <https://arize.com/docs/phoenix/self-hosting>

Phoenix supports OpenTelemetry setup via Phoenix-specific wrappers for Python and TypeScript, automatic instrumentation for popular frameworks/providers, tracing helpers, projects, and sessions. Source: <https://arize.com/docs/phoenix/tracing/how-to-tracing/setup-tracing>

Fit: excellent local-first eval/trace platform, likely simpler than Langfuse for local trial. It is an app-observability platform, not a turnkey "observe Codex/Claude shell agent internals" layer.

### OpenLIT

OpenLIT positions itself as an OpenTelemetry-native AI engineering platform with LLM observability, GPU monitoring, guardrails, evaluations, prompt management, vault, and playground. It sends traces/metrics through an OpenTelemetry Collector to ClickHouse, and the UI reads from ClickHouse. Source: <https://github.com/openlit/openlit>

OpenLIT can be self-hosted with `docker compose up -d`, exposes an OTLP endpoint at `http://127.0.0.1:4318`, and its UI defaults to `http://127.0.0.1:3000`. Source: <https://github.com/openlit/openlit>

OpenLIT specifically documents AI coding-agent observability for Claude Code, Cursor, and Codex. Its CLI claims to install vendor hooks that emit OTel traces for session, prompt, tool call, file edit, subagent spawn, and code-impact events. Source: <https://github.com/openlit/openlit>

Fit: most directly aligned with this repo's goal if "AI setup" means local coding agents, MCPs, tool calls, and setup changes. Risk: installing vendor hooks is invasive and must be audited before touching Codex/Claude/Cursor configs.

### Helicone

Helicone is open source and self-hostable. Its local Docker path uses its repository Docker setup. Architecture includes Web, Worker/proxy logging, Jawn API server, Supabase for app DB/auth, ClickHouse for analytics, and Minio for logs. Source: <https://github.com/Helicone/helicone>

Fit: best when you route API calls through a gateway/proxy and want request logs, costs, experiments, and provider-level observability. Less ideal for observing local agent tool calls, file edits, MCP behavior, and workflow outcomes unless everything is forced through its proxy or custom logging is added.

## Evaluation Criteria

Proper impact metrics need more than token counts. We need five layers:

1. Run identity: agent, model, provider, base URL, Headroom state, MCP profile, config commit, repo, task type, tool version.
2. Cost/resource: input/output/cache tokens, estimated USD, local Ollama durations, compression before/after, `rtk` savings.
3. Performance: end-to-end latency, model latency, tool-call latency, queue time, cold-start/load time, retries/rate limits.
4. Reliability: errors, failed tool calls, MCP startup failures, provider failures, sandbox escalations, fallback paths.
5. Outcome quality: benchmark score, eval score, CI result, review finding count, task accepted/reverted, workflow receipt status.

Without layer 5, dashboards can show "cheaper/faster" while quality silently regresses.

## Recommendation

### Primary Recommendation

Use an OpenTelemetry-first design and test OpenLIT first in an isolated local PoC.

Reason: OpenLIT is the only researched option that explicitly targets Codex/Claude/Cursor-style coding-agent telemetry, and it uses OTel so data can move later to Grafana/Tempo, Langfuse, Phoenix, or raw collector pipelines. This matches repo priorities: local-first, explicit use, no provider auth mutation, and measurable AI setup changes.

### Secondary Recommendation

Evaluate Langfuse or Phoenix as the LLM engineering UI after the local agent telemetry question is solved.

- Choose Langfuse if prompt management, datasets, scores, and production-grade LLM app observability are more important than minimal local footprint.
- Choose Phoenix if free self-host, evals, datasets/experiments, and privacy/no feature gates matter most.
- Keep Helicone as a gateway option only if we decide to route provider calls centrally through an API gateway.

## Proposed Architecture

Phase 0: metric schema, no service install

- Define `ai.setup.*` attributes:
  - `ai.setup.config_commit`
  - `ai.setup.agent`
  - `ai.setup.mcp_profile`
  - `ai.setup.headroom.enabled`
  - `ai.setup.headroom.proxy`
  - `ai.setup.rtk.enabled`
  - `ai.setup.workflow_kind`
- Define redaction defaults:
  - prompts/outputs off or sampled for coding agents;
  - secrets never captured;
  - file contents never captured by default;
  - paths hashed or repo-relative when possible.

Phase 1: isolated OpenLIT PoC

- Run OpenLIT Docker Compose manually or through explicit helper commands.
- Bind only localhost.
- Avoid Headroom ports `8787` and `8788`; avoid Ollama ports `11434`, `11435`, `11436`.
- Prefer UI port `3010` if possible to avoid conflicts with other local dashboards.
- Do not run `openlit coding install --vendor=all` initially.
- First send synthetic OTLP events and existing local metrics (`ai-receipt`, `rtk gain`, `hot-benchmark`) to verify schema and dashboard value.

Phase 2: controlled coding-agent hook audit

- Inspect what OpenLIT modifies for Codex/Claude/Cursor before enabling.
- Enable one vendor at a time, starting with a disposable profile or test repo.
- Verify uninstall restores state.
- Confirm no provider credentials, prompts, or private file contents leak outside localhost.

Phase 3: quality/eval integration

- Convert `scripts/hot-benchmark.sh` output into structured JSON.
- Add fixed task suites for common setup changes:
  - "Headroom on/off"
  - "MCP profile baseline vs nix-dotfiles"
  - "local Ollama route vs provider route"
  - "RTK on/off"
- Store results with config commit and metric schema version.

Phase 4: optional backend comparison

- Replay the same OTel events into OpenLIT, Langfuse, or another backend.
- Compare:
  - local resource footprint;
  - usefulness of trace UI;
  - eval workflow;
  - query/filter ergonomics;
  - backup/export story;
  - how much custom adapter code is needed.

## Superseded Initial Implementation Shape

This section captured the first OpenLIT-oriented implementation shape before
the Phoenix comparison. It is superseded by the implementation notes below:

- `aiObservability.enable = true` for helper availability.
- `aiObservability.backend = "phoenix"` by default.
- Helper commands:
  - `ai-observe-status`
  - `ai-observe-up`
  - `ai-observe-down`
  - `ai-observe-doctor`
  - `ai-observe-smoke`
- No global `OPENAI_BASE_URL`, `ANTHROPIC_BASE_URL`, `OTEL_EXPORTER_OTLP_ENDPOINT`, or provider auth changes.
- Docker Compose remains explicit OpenLIT-only runtime, not Home Manager activation side effect.
- Nix manages scripts/config/templates; Docker runs backend services.

## Risks

- Prompt/output capture can store sensitive code, secrets, tickets, or private conversation text. Default should be metadata-only until explicitly enabled.
- Agent hook installers may mutate user config files. Must be audited and reversible before enabling.
- Langfuse v3 local stack is heavier than it looks due Postgres, ClickHouse, Redis, and blob storage.
- Metrics can mislead unless benchmark inputs and task suites are fixed.
- Local dashboards need backup/retention policy or they become stale local state.

## Final Ranking

1. OpenLIT PoC: best first experiment for local coding-agent observability.
2. Phoenix: best second option for simple self-hosted traces/evals with no feature gates.
3. Langfuse: best if we want mature LLM product workflow and accept heavier stack.
4. Helicone: best only if central API gateway/proxy becomes desired architecture.
5. Raw OTel + Grafana/Tempo/Prometheus: best long-term substrate, but too much custom UI work as first step.

## Go / No-Go

Go for research-to-prototype only if we accept these guardrails:

- local-only endpoints;
- metadata-first capture;
- no vendor hook install until audited;
- no provider auth/base-url changes;
- fixed benchmark suite before claiming improvements;
- rollback command for every config mutation.

Recommended next step: design Phase 0 schema plus OpenLIT isolated smoke test. Do not install agent hooks yet.

## Implementation Notes

The helper surface is implemented in `home/features/ai/observability.nix`.

- Default backend is Phoenix, not OpenLIT, so normal local observability does
  not require Docker/OrbStack. `ai-observe-up` dispatches to
  `ai-observe-phoenix-up` and starts a declaratively supplied Phoenix package
  with `PHOENIX_HOST=127.0.0.1`, `PHOENIX_PORT=6006`, and
  `PHOENIX_GRPC_PORT=4317`. The helper refuses to fetch `arize-phoenix` with
  `uvx`; set `aiObservability.phoenixPackage` from a Nix overlay/package first.
- Phoenix state, pid, and logs live outside the repo under
  `${config.xdg.stateHome}/ai-observability/phoenix`; the helper also sets an
  explicit SQLite URL in that directory.
- OpenLIT remains available behind explicit commands
  `ai-observe-openlit-up/status/smoke/down`; it still fetches release tag
  `openlit-1.23.0` into XDG state and starts Docker Compose only when invoked.
  `ai-observe-openlit-hook-audit` prints the disposable-config/uninstall/privacy
  checklist without installing hooks.
- Smoke telemetry remains metadata-only and uses the `ai.setup.*` contract from
  this document with `ai.setup.backend` set to the active backend. It also marks
  whether repo-owned signals are locally available: workflow receipts,
  `headroom-status`, `rtk gain`, and `scripts/hot-benchmark.sh`.
- Coding-agent hooks remain audit-only and are not installed by either backend.
