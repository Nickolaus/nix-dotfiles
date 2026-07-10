# OpenLIT vs Phoenix Local AI Observability

Date: 2026-07-10

## Question

Which local AI observability stack should this dotfiles repo use: OpenLIT,
Phoenix, both, or another composition?

Main local constraint: on macOS, normal observability should not require starting
OrbStack or another Docker backend by hand. Target signals include Codex,
Claude Code, Cursor, Vibe, OpenCode, Headroom, RTK, workflow receipts, and
benchmark outcomes.

## Recommendation

Use an OpenTelemetry-first architecture with **Phoenix as the default local UI
and storage backend**, and keep **OpenLIT as an optional later coding-agent hook
lab**.

Why:

- Phoenix has a first-party no-Docker local path: install `arize-phoenix`, run
  `phoenix serve`, use the UI at `localhost:6006`. Its architecture docs describe
  SQLite as the default local/single-user storage backend, with state in
  `~/.phoenix/` or `PHOENIX_WORKING_DIR`.
- OpenLIT has the stronger first-party story for Codex, Claude Code, and Cursor
  hook telemetry: sessions, prompts, tool calls, file edits, subagents,
  code-impact metrics, and dedicated coding-agent UI views.
- OpenLIT's official self-hosted runtime is heavier: OpenLIT platform,
  ClickHouse, and OpenTelemetry Collector, deployed with Docker Compose or
  Kubernetes Helm. That conflicts with the no-OrbStack daily-use constraint.
- This repo's near-term value is durable local measurement without manual
  external runtime dependencies. Phoenix wins that. OpenLIT's advantage matters
  only after accepting and auditing local agent hook mutations.

## Source Findings

### OpenLIT

OpenLIT self-hosting is documented as a three-component stack:

- OpenLIT platform.
- ClickHouse storage.
- OpenTelemetry Collector.

Official deployment paths are Docker Compose and Kubernetes Helm.

OpenLIT coding-agent support is materially stronger than Phoenix for agent
internals. The CLI supports Claude Code, Cursor, and Codex hook/plugin
installation, emits OpenTelemetry, and targets an OpenLIT collector endpoint.
Its architecture normalizes vendor events into `coding_agent.*` and `gen_ai.*`
telemetry, stores traces in ClickHouse, and exposes `/agents` and
`/coding-agents` views.

OpenLIT coding-agent content capture modes:

- `minimal`: identifiers only.
- `metadata_only`: identifiers plus tool names and paths, without message bodies
  or file diffs.
- `full`: includes message bodies and file diffs.

The OpenLIT coding-agent docs state content capture defaults to `full`. For
this repo, that is too broad. Any OpenLIT hook trial should force
`OPENLIT_CODING_CONTENT_CAPTURE=metadata_only` or `minimal`.

OpenLIT SDK configuration also defaults prompt/response content capture on for
application tracing. That is useful for app debugging, but conflicts with this
repo's metadata-first capture policy unless disabled or carefully scoped.

### Phoenix

Phoenix supports Docker and Kubernetes, but also has a first-party terminal
deployment path:

```sh
pip install arize-phoenix
phoenix serve
```

Default UI is `http://localhost:6006`.

Phoenix architecture consists of a web UI, trace collector, and SQL backend.
The docs describe SQLite as the default storage option and best suited for local
development and single-user deployments. PostgreSQL is optional for production
and multi-user use. SQLite state defaults to `~/.phoenix/`, or can be moved with
`PHOENIX_WORKING_DIR`.

Phoenix tracing setup is explicitly for Phoenix, not Arize AX. It supports the
Phoenix OpenTelemetry wrapper for Python, `@arizeai/phoenix-otel` for
TypeScript, auto-instrumentation, tracing helpers, projects, and sessions.

Phoenix has a "Coding Agents" integration page, but it is not equivalent to
OpenLIT's runtime hook telemetry. It gives coding agents CLI/MCP/skill access
to Phoenix docs and Phoenix data operations. It does not provide the same
first-party Codex/Claude/Cursor file-edit, tool-call, and subagent rollups that
OpenLIT documents.

Phoenix/OpenInference privacy controls include environment variables for hiding
inputs, outputs, input messages, output messages, LLM prompts, tool definitions,
and embedding vectors. Phoenix also supports custom span processors that can
filter or redact spans before export.

### OpenTelemetry

Both tools sit on OpenTelemetry-compatible telemetry. The safest long-term
boundary is therefore this repo's own OTel/OpenInference-style schema, not
either backend's database or UI model. OpenTelemetry GenAI semantic conventions
are also now a stable reference point for portable LLM trace attributes.

## Comparison For This Repo

| Criterion | OpenLIT | Phoenix | Better fit |
| --- | --- | --- | --- |
| No Docker / no OrbStack | Official self-host is Docker Compose or Kubernetes Helm. | Official terminal path runs Python package with `phoenix serve`. | Phoenix |
| Local state | ClickHouse plus platform state; heavier lifecycle. | SQLite default under `~/.phoenix/` or `PHOENIX_WORKING_DIR`. | Phoenix |
| Coding-agent internals | First-party hooks for Codex, Claude Code, Cursor; dedicated `/agents` and `/coding-agents` views. | Coding-agent docs focus on CLI/MCP/skills agents use Phoenix; not equivalent runtime hooks. | OpenLIT |
| Config mutation risk | High if hooks installed: writes Codex/Claude/Cursor hook/plugin config. | Low for default server: no agent hook mutation required. | Phoenix |
| Capture defaults | Coding-agent capture defaults full content; SDK content capture also defaults on. | OpenInference hide/filter knobs exist; still needs explicit privacy env. | Phoenix |
| Fit with Home Manager | Docker helper works, but depends on external Docker daemon. | `phoenix serve` wrapper and optional launchd service fit repo style. | Phoenix |
| Outcome metrics | Requires custom adapters for receipts, RTK, Headroom, benchmarks. | Also requires custom adapters. | Tie |
| Future deep agent traces | Strongest option if audited hooks become acceptable. | Needs custom adapters for Codex/Claude/Cursor internals. | OpenLIT |

## Best Architecture

### Phase 1: Phoenix-First Native Local Backend

Change `aiObservability` default backend from OpenLIT Docker to Phoenix native:

- `aiObservability.backend = "phoenix"`.
- `aiObservability.phoenixPackage` defaults to this repo's
  `packages.<system>.arize-phoenix` package, which is built from the
  repo-owned `packages/arize-phoenix/uv.lock` with uv2nix; do not fetch
  `arize-phoenix` at helper runtime.
- `aiObservability.phoenixPort = 6006`, or another repo-specific free loopback
  port if needed.
- `aiObservability.phoenixGrpcPort = 4317`.
- `aiObservability.phoenixStateDir =
  "${config.xdg.stateHome}/ai-observability/phoenix"`.
- Provide explicit helper commands and a macOS user LaunchAgent by default
  (`aiObservability.autoStart = true`), because Phoenix UI and OTLP ingest are
  the same process.

Recommended scoped environment for Phoenix commands:

```sh
PHOENIX_WORKING_DIR="$XDG_STATE_HOME/ai-observability/phoenix"
PHOENIX_TELEMETRY_ENABLED=false
OPENINFERENCE_HIDE_INPUTS=true
OPENINFERENCE_HIDE_OUTPUTS=true
OPENINFERENCE_HIDE_INPUT_MESSAGES=true
OPENINFERENCE_HIDE_OUTPUT_MESSAGES=true
OPENINFERENCE_HIDE_LLM_PROMPTS=true
OPENINFERENCE_HIDE_LLM_TOOLS=true
```

Keep those scoped to helper commands or service definitions, not global shell
profile state. The Home Manager Phoenix wrapper enforces this by execing the
server through `env -i` with only `HOME`, `PATH`, `PHOENIX_*`, and
`OPENINFERENCE_*` in scope.

### Phase 2: Keep The Schema Backend-Neutral

Keep the existing `ai.setup.*` contract, but emit the configured backend:

- `ai.setup.agent`
- `ai.setup.config_commit`
- `ai.setup.dirty`
- `ai.setup.mcp_profile`
- `ai.setup.headroom.enabled`
- `ai.setup.headroom.proxy`
- `ai.setup.rtk.enabled`
- `ai.setup.backend`
- `ai.setup.workflow_kind`
- `ai.setup.capture_mode`

Add OpenInference/OTel-compatible fields where natural, but avoid locking
repo-owned outcome data to Phoenix-only or OpenLIT-only APIs.

### Phase 3: Instrument Repo-Owned Signals Before Agent Hooks

Prioritize signals that do not need prompt, output, or file-content capture:

- `ai-receipt-log` outcomes: plan, review, QA, ship, decision statuses over
  config commits.
- `rtk gain`: output-compression savings.
- `headroom-status`: proxy state, upstream route, compression health.
- `scripts/hot-benchmark.sh`: model latency, quality score, retry/error data.
- Git metadata: branch, commit, dirty bit, benchmark suite version.

This answers setup-quality questions without reading prompts, outputs, file
contents, or private ticket text.

### Phase 4: Subscription-Agent Metadata

Codex subscription/Auth usage can be observed with a managed metadata-only hook
because it runs locally and can ignore content-bearing hook fields. Claude Code
subscription/OAuth usage should be observed with its official OpenTelemetry
trace exporter through a scoped wrapper or env, with prompt/tool/content gates
disabled. Do not mutate provider auth or global base URLs for observability.

### Phase 5: OpenLIT Optional Hook Lab

Keep OpenLIT support behind an explicit backend command:

- Do not start Docker during activation.
- Do not install `openlit coding install --vendor=all`.
- Test one vendor at a time in disposable config first.
- Force `OPENLIT_CODING_CONTENT_CAPTURE=metadata_only` or `minimal`.
- Verify uninstall paths and reversibility.
- Disable product telemetry where supported.
- Keep endpoints loopback unless intentionally testing a shared collector.

Use OpenLIT if, and only if, Phoenix plus repo-owned signals cannot answer
questions about coding-agent internals, file edits, subagent linkage, per-tool
timelines, or Codex/Claude/Cursor-specific token/cost rollups.

## Current Commit Implication

Commit `3ff7555` added OpenLIT Docker helpers. That is not wrong, but it should
not remain the default if Docker-free local observability is the actual goal.

Recommended next implementation:

1. Keep `ai-observe-status`, `ai-observe-doctor`, and `ai-observe-smoke`.
2. Add Phoenix backend helpers: `ai-observe-phoenix-up`,
   `ai-observe-phoenix-down`, `ai-observe-phoenix-status`.
3. Map generic `ai-observe-up/down` to Phoenix when
   `aiObservability.backend = "phoenix"`.
4. Move OpenLIT Docker helpers behind `backend = "openlit"` and mark them
   optional/manual.
5. Update docs so OpenLIT is described as a deep hook lab, not the default local
   backend.

## Decision

Use **Phoenix-first + OpenTelemetry contract + optional OpenLIT hook lab**.

This gives:

- no OrbStack/Docker requirement for normal observability;
- local UI with durable SQLite state;
- backend-neutral telemetry that can later flow to OpenLIT, Grafana, Tempo,
  Langfuse, or raw collector pipelines;
- minimal config mutation risk;
- controlled path to OpenLIT's stronger coding-agent telemetry after hook
  behavior is audited.

Do not combine both on day one. Combining now adds two UIs, two storage models,
two privacy surfaces, and more local services before the repo has a stable metric
contract. Combine later only by routing the same OTel events to multiple backends
for a short comparison window.

## Sources

- OpenLIT self-hosting:
  <https://docs.openlit.io/latest/openlit/installation.md>
- OpenLIT coding-agent onboarding:
  <https://docs.openlit.io/latest/openlit/coding-agents/onboarding.md>
- OpenLIT coding-agent architecture:
  <https://docs.openlit.io/latest/openlit/coding-agents/architecture.md>
- OpenLIT SDK configuration:
  <https://docs.openlit.io/latest/sdk/configuration.md>
- Phoenix terminal deployment:
  <https://arize.com/docs/phoenix/self-hosting/deployment-options/terminal.md>
- Phoenix architecture:
  <https://arize.com/docs/phoenix/self-hosting/architecture.md>
- Phoenix tracing setup:
  <https://arize.com/docs/phoenix/tracing/how-to-tracing/setup-tracing.md>
- Phoenix coding-agent integration:
  <https://arize.com/docs/phoenix/integrations/developer-tools/coding-agents.md>
- Phoenix masking:
  <https://arize.com/docs/phoenix/tracing/how-to-tracing/advanced/masking-span-attributes.md>
- Phoenix span modification:
  <https://arize.com/docs/phoenix/tracing/how-to-tracing/advanced/modifying-spans.md>
- OpenTelemetry GenAI semantic conventions:
  <https://opentelemetry.io/docs/specs/semconv/gen-ai/>
