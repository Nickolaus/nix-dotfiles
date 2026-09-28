# Semantic-If Link Scoring Research

Date: 2026-09-28

## Question

Should this Darwin `nix-dotfiles` workstation (host `zoidberg`) run a local non-autoregressive "semantic if" / System-1 decision engine, and if so which project, what hardware posture, and how should it be wired so an agent can score search-result links before fetching or crawling page bodies?

## Answer

Yes. The engine is [Ollaya](https://github.com/ollaya-dev/ollaya) with the `winnow:e4b` model, exposed as a frozen `linkgate` model. Nothing runs at login: the first call starts a loopback daemon, and the model unloads when idle. Agents reach it through the `ollaya-gate` batch CLI, or through the opt-in `decide` MCP profile.

Implementation:

| File | Role |
|---|---|
| `packages/ollaya/default.nix` | Prebuilt aarch64-darwin release, unpatched, with a `bin/ollaya` env wrapper |
| `hosts/shared/ai-agents-lib.nix` | `prebuiltReleases.ollaya` version + tarball hash pin; `ollayaSupported` platform guard |
| `hosts/shared/ai-agents.nix` | `mcpServers.ollaya` (stdio `ollaya mcp`, `targets = [ ]`) and `mcpProfiles.decide` |
| `home/features/ai/ollaya.nix` | `ollaya-setup`, `ollaya-gate`, `ollaya-status`, `ollaya-stop`, frozen `linkgate` schema, agent instructions |
| `scripts/update-mcp-runtime-versions.py` | `github-releases` datasource; refreshes the tarball hash with the version |
| `renovate.json` | Renovate disabled for `ollaya-dev/ollaya` (it can bump the version but not the hash) |

## Scope

Chosen use: after a web search returns about 10-20 titles/URLs/snippets, score those hits with one frozen schema before `fetch` or Crawl4AI reads bodies. High recall: drop only confident junk (off-topic, commercial, wrong platform). Borderline rows still get fetched. Page bodies are never scored.

Rejected use: choosing MCP profiles, Agent Skills, tools, or triage/escalation steps.

- Capability selection is a high-cardinality fuzzy choice over dozens of natural-language descriptions. Small decision models are weakest exactly there (Laya: Banking77 0.425 vs Jev 0.870; see below).
- A wrong skill is recoverable; dropping the only good source is not. Any gate must bias toward keep.
- Repo MCP profiles are deliberate human/repo opt-in compositions (`hosts/shared/ai-agents.nix`), not runtime-scored sets.

Link scoring fits: a small fixed label set, a short state (query + title + URL + snippet), 10-20 rows per search, and kept junk costs less than dropped gold.

## Candidates

| Project | What it is | License | Apple path | Service shape |
|---|---|---|---|---|
| [ollaya-dev/ollaya](https://github.com/ollaya-dev/ollaya) | Rust daemon + CLI for decision models ("Ollama for decision models"); TypeSafe `/v1/systemone` compatible; model registry incl. Laya, Winnow, decider, Kev, NLI, GLiClass | Apache-2.0 (models keep their own licenses) | ONNX Runtime (static) on CPU; llama.cpp with Metal for GGUF models | Auto-started loopback daemon, one runner process per loaded model, stdio or HTTP MCP proxy |
| [NandhaKishorM/laya](https://github.com/NandhaKishorM/laya) | NAR System-1 encoder; `choice` / `score` / `noul`; Router over checkpoints | Apache-2.0 | torch `cpu` / `mps` | `laya-serve` HTTP (serialized, `max_workers=1`), `laya-mcp-server` stdio that loads weights in-process, NixOS/systemd module only |
| [logan-markewich/jeff](https://github.com/logan-markewich/jeff) | Self-hosted TypeSafe Jev System One API on GLiFormer ~400M | MIT | CUDA, MPS, CPU; ONNX CPU path | HTTP `/v1/systemone` with a server-side batcher for concurrent requests |
| [TheoLeeCJ/SemIf](https://github.com/TheoLeeCJ/SemIf) | Open-weight logit readout research bench (Qwen3.5-4B class) | MIT (code) | MLX and PyTorch/MPS | CLI `semif-score` only; no HTTP or MCP service |

Why Ollaya over the others for this repo:

- It already has the daemon-plus-thin-client shape that Laya would need a custom wrapper for: model weights live in a daemon child, and `ollaya mcp` is a ~12 MB proxy, so per-session MCP profile spawns never reload weights.
- It runs a GGUF 4B decision model on Metal. The Laya-class encoders it also serves were not accurate enough on this task (measured below).
- It ships one static binary with no Python environment and no runtime downloads beyond model weights.
- Jeff and SemIf offer no model that beats `winnow:e4b` on typed decisions, and SemIf has no service at all.

## Upstream findings

### Ollaya

Sources: [README.md](https://github.com/ollaya-dev/ollaya/blob/main/README.md), [docs/api.md](https://github.com/ollaya-dev/ollaya/blob/main/docs/api.md), release [v0.7.5](https://github.com/ollaya-dev/ollaya/releases/tag/v0.7.5).

- API: `POST /api/decide` (native, with timings and routing), `POST /v1/systemone` and `/v1/decisions` (TypeSafe-identical), `/api/pull`, `/api/create`, `/api/ps`, `/api/tags`. One `state` per request, 1-256 questions per request.
- Question types: `choice` (2-255 labels), `score` (2-10 levels), `noul` (probability that a statement holds).
- Concurrency: a loaded model's runner computes one forward pass at a time; extra requests queue (`OLLAYA_MAX_QUEUE`, default 512). No server-side batching of different states.
- Modelfiles bake a question set into a named model (`FROM <model>`, `QUESTIONS <file.json>`); `/api/decide` then needs only a state.
- Upstream accuracy on typed-decisions: `winnow:e4b` 0.722 (TypeSafe Jev 0.738), `kev:9b` 0.722, `winnow` 12B 0.702, `decider:4b` 0.680. Upstream latency for `winnow:e4b`: 89 ms for five questions on an RTX 4090 (not this machine).
- Weights are fetched from each model author's Hugging Face repository, pinned to a commit and verified by sha256; Ollaya publishes only small ONNX graphs.
- Environment variables: `OLLAYA_HOST`, `MODELS`, `KEEP_ALIVE`, `MAX_LOADED_MODELS`, `LOAD_TIMEOUT`, `DEVICE`, `MAX_QUEUE`, `API_KEY`, `ORIGINS`, `REGISTRY`, `LOG`, `LOG_DIR`, `LIBRARY_PATH`.
- Project age: repository created 2026-09-23; expect API churn. The `decide` MCP tool description claims auto-pull, but the tool returns `model "…" not found, try pulling it first`.

### Laya

Sources: [README.md](https://github.com/NandhaKishorM/laya/blob/main/README.md), [laya/serve.py](https://github.com/NandhaKishorM/laya/blob/main/laya/serve.py), [laya/mcp/server.py](https://github.com/NandhaKishorM/laya/blob/main/laya/mcp/server.py).

- Checkpoints: English (ModernBERT-large ~421M, 512 context), multilingual (mmBERT-base ~322M), typed-decisions fine-tune.
- Upstream "honest limits": zero-shot typed-decisions 0.362 (English) vs random ~0.318; weak on >20-option `choice`; English `noul` can follow `true`/`false` wording ([#156](https://github.com/NandhaKishorM/laya/issues/156)).
- Stock `laya-serve` serializes inference; batching of many states exists only in the SDK (`predict_batch`). `laya-mcp-server` loads weights in-process.
- Ollaya serves the same checkpoints (`laya:en`, `laya:multilingual`, `laya:typed-decisions`) with fp32 parity to the PyTorch reference, so Laya is reachable without its Python stack.

### Jeff and SemIf

- Jeff ([README](https://github.com/logan-markewich/jeff/blob/main/README.md)): `JEFF_MAX_BATCH` / `JEFF_MAX_WAIT_MS` coalesce concurrent requests; upstream p50 151 ms on L4/Modal (not this machine). Same encoder weight class as Laya.
- SemIf ([README](https://github.com/TheoLeeCJ/SemIf/blob/main/README.md), [docs/MLX.md](https://github.com/TheoLeeCJ/SemIf/blob/main/docs/MLX.md)): Qwen3.5-4B, ~9 GB on disk, upstream ~0.26 s warm on an M5 24 GB. Research CLI, useful only as an offline quality ceiling.

## Hardware

- MacBook Pro Mac16,7, Apple M4 Pro (10P + 4E cores, 20 GPU cores), 48 GB unified memory, Metal.
- Resident local LLM: default Ollama service on 11434 with the 4.4 GB commit model. No other large model is resident, so an 8 GB Metal decision model fits.

## Measurements on this machine

All numbers below are local measurements with Ollaya 0.7.5 on `127.0.0.1:11435`.

### Accuracy

Two fixture sets of 12 search hits each (6 relevant, 6 junk), questions `relevant` (`noul`) and `fetch` (`choice`: open / maybe / skip). A hit counts as correct when open/maybe matches relevant and skip matches junk.

| Set / query | `laya:en` `fetch` | `laya:en` `noul` ≥ 0.3 | `winnow:e4b` `fetch` |
|---|---|---|---|
| A: "how to configure launchd agents with nix-darwin home-manager" | 6/12 | 11/12 | 11/12 |
| B: "how to cancel a spawned tokio task in rust async when a timeout expires" | 5/12 | 8/12 | 12/12 |

- `laya:en` `choice` answers are at chance level on both sets (it kept shoe ads and charger shops). Its `noul` is usable on set A but drops a true hit on set B (`tokio::time::timeout` 0.25 while Python asyncio scored 0.71). It is not good enough as a pre-filter either.
- `winnow:e4b` separates cleanly: relevant `noul` 0.45-0.97 vs junk 0.01-0.04.
- The shipped `linkgate` model (query moved from the instructions into the state) with the keep rule from design decision 4 scored 12/12 on both sets. The closest calls were a relevant hit at `relevant` 0.53 (`tokio::time::timeout`) and a junk hit at 0.08 (Python `asyncio.wait_for`).
- `fetch` confidence varies between model loads: the same junk hit scored skip 0.46 in one run and 0.62 in another. A confidence threshold alone therefore leaks junk intermittently; in a live 15-hit session, both junk hits (skip confidence 0.28 and 0.49, `relevant` 0.05) were kept under a confidence-only rule.

### Latency and memory

| | `laya:en` (CPU, ONNX) | `winnow:e4b` (Metal, llama.cpp) |
|---|---|---|
| Cold load from disk | 5 s | 26 s |
| Reload with weights in the OS file cache | – | 1-4.5 s |
| Warm, per hit (2 questions) | ~115 ms | ~390 ms |
| 12 hits, serial | 1.4 s | 4.9 s |
| 12 hits, 12 concurrent requests | 1.3 s | 4.7 s |
| Runner RSS while loaded | 1.8-2.9 GB | 6.8-8.3 GB |
| Download | 0.85 GB | 8 GB |

- Concurrency does not help: the runner computes one forward pass at a time.
- Idle daemon after unload: about 15 MB, and runner processes exit.

### Runtime behaviour

- `ollaya mcp` over stdio is a thin proxy (12-14 MB). `initialize` and `tools/list` start nothing; the first `tools/call` spawns `ollaya serve`, which is detached (re-parented to launchd) and survives the MCP session.
- Every CLI entry point auto-starts the daemon. The daemon inherits the caller's environment (`OLLAYA_MODELS`, `KEEP_ALIVE`, `LOG_DIR` verified), so every caller must go through the same wrapper.
- Concurrent auto-starts are race-safe: five parallel `ollaya list` calls produced one daemon.
- Logs append to `$OLLAYA_LOG_DIR/server.log` without rotation. The pidfile is always `~/.ollaya/server.<port>.pid`.
- Binding: `127.0.0.1` and `[::1]` only. No outbound connections during start and decisions; no telemetry or update endpoints in the binary (the only "telemetry" strings belong to ONNX Runtime). Registry hosts are used only for pulls.
- MCP tools: `decide` (one state per call, no `keep_alive` argument, defaults to the `laya` router when `model` is omitted), `list_models`, `show_model`, `pull_model` (downloads). The server's MCP instructions tell agents to call `decide` before every routing or triage step.

### Packaging

- `otool -L`: system frameworks only; ONNX Runtime is statically linked. The llama.cpp dylibs use `@rpath` with `LC_RPATH @loader_path` and are loaded from `../lib/ollaya/llama`. The binary runs unmodified from a read-only tree, writes nothing next to itself, and has no self-update.
- Signatures are ad-hoc and linker-signed, so stripping and fixup must be skipped.
- `ollaya stop` identifies its daemon by process name. A makeWrapper-style `.ollaya-wrapped` rename makes it refuse to stop and delete the pidfile, so the package keeps the real binary named `ollaya` under `libexec/` and puts a small env script at `bin/ollaya`.

## Design decisions

1. **No launchd agent.** Auto-start is detached, race-safe, and cheap when idle (~15 MB). Clients never talk to launchd, so `RunAtLoad = false` would add nothing. `ollaya-stop` ends the daemon explicitly.
2. **`OLLAYA_KEEP_ALIVE=5m`, `OLLAYA_MAX_LOADED_MODELS=1`.** A reload from the file cache costs a few seconds; 8 GB is released between searches.
3. **Frozen `linkgate` model.** Callers send only `{query, title, url, snippet}` and cannot fall back to the weaker `laya` router. Questions:
   - `relevant` (`noul`): "This search result (title, url, snippet) is useful for answering the research query in the state's `query` field."
   - `fetch` (`choice`): open / maybe / skip, where skip means unrelated, commercial, or wrong platform.
4. **Keep policy.** Drop a hit only when `fetch=skip` and either its confidence is ≥ `ollaya.skipConfidence` (0.5) or `relevant` is < `ollaya.dropRelevantBelow` (0.1). Two independent questions agreeing is required for low-confidence skips; `relevant` alone never drops a hit. Measured separation so far: junk `relevant` 0.01-0.08, relevant hits 0.21-0.97. `confidence` is TypeSafe-normalized over three options, so 0.5 means a skip probability of about 0.67.
5. **`ollaya-gate` is the primary path.** One command scores a whole result list (JSONL in, JSONL out, input order preserved). MCP `decide` needs one tool call per hit and is the fallback.
6. **stdio MCP in an opt-in profile.** `mcpServers.ollaya` has `targets = [ ]`; `mcpProfiles.decide` adds it to the default servers. `--http` would add a second persistent process for no gain.
7. **Agent instructions override upstream.** The managed snippet requires `model: "linkgate"`, forbids `pull_model`, and forbids routing, triage, skill, or MCP-profile selection, regardless of the Ollaya MCP server's own instructions.
8. **No upstream skill.** The bundled `ollaya-decisions` skill tells agents to install via `curl -fsSL https://ollaya.dev/install.sh | sh` and promotes routing/triage use; both conflict with this repo's rules.
9. **State outside the Nix store.** Models in `~/.local/share/ollaya/models`, logs in `~/.local/state/ollaya`.
10. **Platform guard.** The package, MCP server, profile, and Home Manager module exist only where `lib.meta.availableOn` accepts the aarch64-darwin package; Linux hosts evaluate unchanged.

## Agent flow

1. Run web search and collect about 10-20 hits.
2. `ollaya-gate --query "<query>" < hits.jsonl` (or MCP `decide` with `model: "linkgate"` per hit in the `decide` profile).
3. Drop hits with `keep: false`; keep everything else.
4. For kept hits: `context7` for library docs, otherwise `fetch` for one static page, Crawl4AI only when crawl boundary rules apply (`home/features/ai/crawl4ai.nix`).

## Risks

- **False negatives.** A wrong skip drops the only good source. Mitigation: a skip needs high confidence or a `relevant` score under 0.1; every relevant hit measured so far had `fetch=open` and `relevant` ≥ 0.21. Raise `ollaya.skipConfidence` or lower `ollaya.dropRelevantBelow` if gold hits are ever dropped.
- **Small fixtures.** Two sets of 12 hits, both English and both technical. Non-English queries and non-technical topics are unmeasured.
- **Upstream churn.** The project is days old; the MCP tool description is already wrong about auto-pull. Pinned version plus hash; updates go through `scripts/update-system.sh` only.
- **MCP surface.** `pull_model` can start multi-GB downloads, and the upstream MCP instructions push routing use. Only the managed instruction snippet counters this; the profile gateway cannot filter tools.
- **Shared daemon environment.** The first caller's environment (including `PATH`) is inherited by the daemon and its runners.
- **Memory.** `winnow:e4b` uses ~8 GB while loaded. Fine next to the 4.4 GB commit model; revisit if a large local model becomes resident again.

## Caveats

- Upstream numbers (RTX 4090, T4, L4, M5) are not this machine; only the "Measurements on this machine" section is local.
- SemIf remains the offline quality comparison if `linkgate` quality disappoints.
- Candidates for a later comparison inside Ollaya: `kev:9b` (0.722 upstream, larger) and `decider:4b` (0.680 upstream).
