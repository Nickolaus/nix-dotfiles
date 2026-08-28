# SkillSpector integration research (2026)

Status: research note. Repo inspection is complete. Upstream facts below were checked against the repository README and latest release metadata on 2026-08-28; release-interface details should still be revalidated when implementation pins a version.

## Verified upstream facts

- The project describes itself as a security scanner for Claude Code, Codex, MCP, and other agent skills. It supports local directories/files, Git repositories, URLs, and zip archives.
- The current latest release is `v2.11.0` (2026-08-28). It ships a Python package/CLI and documents installation through `uv tool install`.
- The scanner advertises 71 vulnerability patterns across 17 categories, JSON/Markdown/SARIF output, risk scoring, baselines, and optional LLM analysis.
- Static scanning can run with `--no-llm`. The README states that dependency checks may query OSV.dev with dependency coordinates and that SkillSpector does not sandbox a skill selected for installation.
- The optional MCP server exposes `scan_skill`; its documented HTTP transport has no authentication, while the README notes an existing stdio initialization hang. These are reasons to keep MCP disabled by default.
- Release `v2.11.0` documents the install-gate contract used here: scan exit codes `0` (score ≤ 50), `1` (score > 50), `2` (error); JSON fields under `risk_assessment`; and recommendation values `SAFE`, `CAUTION`, and `DO_NOT_INSTALL`. Its guidance maps `SAFE` to allow, `CAUTION` to prompt/warn, and `DO_NOT_INSTALL` to block.

Primary sources: [SkillSpector README](https://github.com/NVIDIA/SkillSpector/blob/main/README.md), [latest release](https://github.com/NVIDIA/SkillSpector/releases/tag/v2.11.0), [NVIDIA scanning guide](https://docs.nvidia.com/skills/scanning-agent-skills).

## Decision

Integrate NVIDIA SkillSpector as an explicit, pinned pre-install security check for managed agent skills. Do not model it as an entry in `aiAgents.catalog.skills`, and do not run it from Home Manager activation.

The catalog is a renderer for agent skill content, while SkillSpector is a scanner/tool. This separation matches the existing catalog model: runtime-owned tools are represented with `managed = false`, and catalog plugins are currently declarations only ([`hosts/shared/ai-agent-catalog.nix`](../hosts/shared/ai-agent-catalog.nix)).

## Repo evidence

- `scripts/update-system.sh` already owns mutable update orchestration: flake updates, MCP runtime pin updates, Homebrew convergence, rebuild, verification, and rollback guidance.
- `scripts/check-config.sh` performs Nix evaluation and, on Darwin, checks the applied catalog manifest with `agent-catalog-check`.
- `home/features/ai/agent-catalog.nix` renders `.agents/catalog/manifest.json` and materializes managed skill directories during Home Manager activation. It is therefore the correct source of scan inventory, but not the correct lifecycle hook for a networked or mutable scanner.
- `hosts/shared/ai-agent-catalog.nix` validates skill names, frontmatter, sources, trust, and managed/runtime-owned state. External-experimental entries are explicit-only (`implicit = false`); `graphify` and `chonkie` are runtime-owned.
- `home/features/ai/chonkie.nix` demonstrates the existing mutable `uv tool install` pattern and intentionally exposes status/update helpers. This is precedent, not proof that SkillSpector should use the same lifecycle.
- `AGENTS.md` requires Nix/Home Manager for declarative packages, idempotent activation, sops-managed secrets, focused checks, and no credentials in source.

## Recommended design

### 1. Package and pin

Prefer a Nix package derivation when SkillSpector’s release metadata and dependencies can be reproduced cleanly. Pin source revision, version, and hashes in the flake/package definition; expose the executable through a small AI tooling module or an existing package aggregation module.

If upstream packaging is not yet suitable, use a separately pinned `uv` tool installation as a transitional option. Keep the exact package/version pin in repository configuration and make upgrades an explicit maintenance change. Do not install an unpinned `latest` binary during activation.

Primary sources: [SkillSpector repository](https://github.com/NVIDIA/skillspector), [SkillSpector releases](https://github.com/NVIDIA/skillspector/releases), [Nixpkgs packaging manual](https://nixos.org/manual/nixpkgs/stable/), [Nix flakes manual](https://nixos.org/manual/nix/latest/command-ref/new-cli/nix3-flake.html).

### 2. Scan inventory

Scan only managed, materialized skill directories listed by the generated catalog manifest. Do not recursively scan the whole home directory, Nix store, MCP caches, or secret directories.

The scan wrapper should:

1. Read `.agents/catalog/manifest.json`.
2. Select entries where `managed` is true.
3. Select each generated `scanSources` entry, deduplicated. These are Nix-store source directories for upstream skills and realized candidate trees for generated text skills, including curated extra files.
4. Run SkillSpector in its static/no-LLM mode if supported by the pinned version.
5. Emit a machine-readable report outside the Nix store and a concise terminal summary.

Also support an explicit single-path command for reviewing a proposed external skill before adding it to the catalog. Runtime-owned entries should be opt-in scan targets, not silently included in the managed gate.

Primary sources: [catalog manifest implementation](../home/features/ai/agent-catalog.nix), [SkillSpector README/source](https://github.com/NVIDIA/skillspector).

### 3. Lifecycle placement

Use two gates:

- `scripts/check-config.sh`: local/CI validation of the current checkout and rendered catalog. This must remain usable without network access when the pinned scanner is already available.
- `scripts/update-system.sh`: run the same gate after flake/input updates and before `darwin-rebuild` or `nixos-rebuild`.

Do not run SkillSpector in `home.activation`. Home Manager activation should remain idempotent and should not download tools, call external services, or make a switch depend on an unavailable network. Activation may materialize files; the pre-rebuild check scans them before system convergence.

### 4. Failure policy

Default to fail-closed for scanner execution errors and high/critical findings before applying a newly updated configuration. A scanner that is missing, crashes, cannot load its rules, or returns an unknown status must not be treated as a clean result.

Allow a deliberate, visible bypass for emergency recovery, for example `--skip-skill-scan`, with:

- an interactive confirmation in the update script;
- a warning naming the skipped check;
- no bypass in CI;
- a receipt/report entry if the existing receipt tooling is used.

Treat low/medium findings according to SkillSpector’s stable severity contract once verified against the pinned release. Until then, do not hard-code severity names or exit-code assumptions from memory; test the exact release and document the mapping.

### 5. Network, LLM, and secrets

The normal gate should be deterministic and static-only. No API key, model provider, telemetry endpoint, or secret should be needed. Do not pass environment files, MCP credentials, sops paths, or full home-directory contents to the scanner.

If SkillSpector offers an LLM-enhanced mode, expose it as an explicit review command, never as the default upgrade gate. Its provider, data handling, network requirements, timeout, and failure behavior must be documented from upstream before enabling it.

Primary sources: [SkillSpector repository](https://github.com/NVIDIA/skillspector), [NVIDIA agent-skill scanning documentation](https://docs.nvidia.com/skills/scanning-agent-skills), [sops-nix documentation](https://github.com/Mic92/sops-nix).

### 6. MCP implications

Do not enable SkillSpector’s MCP server as part of the default setup. A local CLI gate has a smaller trust and availability surface. If an MCP interface is later useful, keep it opt-in, local/stdio where possible, separately configured from `aiAgents.mcpServers`, and never expose a network listener by default.

Any MCP integration must be reviewed for unauthenticated HTTP behavior, filesystem scope, subprocess permissions, logging of scanned content, and client-specific onboarding. Existing MCP profiles deliberately require explicit onboarding and keep secrets out of generated Nix content (`home/features/ai/mcp-profiles.nix`).

Primary sources: [SkillSpector repository](https://github.com/NVIDIA/skillspector), [existing MCP profile policy](../home/features/ai/mcp-profiles.nix).

### 7. Cross-platform behavior

Keep the wrapper platform-neutral and package the scanner for both declared systems: Darwin hosts (`zoidberg`) and NixOS hosts (`farnsworth`, `farnsworth-x86`). If upstream only publishes one platform or requires a native runtime, fail clearly on unsupported systems and retain a review-only path rather than silently skipping the security gate.

Run the scan against the same rendered/materialized paths on both platforms. Do not rely on `/etc/profiles` or Homebrew-specific paths for scanner discovery; use the Nix-provided executable or an explicit, validated tool path.

Primary sources: [flake host outputs](../flake.nix), [Nixpkgs platform/package guidance](https://nixos.org/manual/nixpkgs/stable/).

### 8. Rollback and reporting

The scan must happen before rebuild, so a failed scan leaves the active system generation unchanged. If a bad skill passes and is later discovered, remove/revert the catalog source and rebuild; existing update script guidance already points to system-generation rollback for rebuild failures.

Store reports in a temporary or state directory, not the Nix store and not committed source. Reports must omit prompts, secrets, cookies, full raw logs, and full paths where possible. If logged through `ai-receipt-log`, record only status, scanner version, catalog/commit identifier, and a compact report path or digest.

## Implementation sequence

1. Verify the pinned SkillSpector release interface, license, supported platforms, install method, static/no-LLM flag, severity mapping, exit codes, output formats, MCP behavior, and network/telemetry behavior from upstream.
2. Add a reproducible package/install path and a `skillspector-status`/`skillspector-update` policy only if a mutable transitional install is still needed.
3. Add a scan wrapper that derives targets from the manifest and rejects missing/unreadable targets.
4. Call the wrapper from `check-config.sh`, then from `update-system.sh` before rebuild; add CI coverage for clean, high-severity, missing-binary, malformed-report, and explicit-bypass cases.
5. Test Darwin and both NixOS architectures, then document rollback and the exact pinned version.

## Conclusion

Add SkillSpector as a pinned, static pre-rebuild gate over the rendered managed-skill inventory. Keep it outside the skill catalog and Home Manager activation; keep MCP and LLM modes opt-in; fail closed on scanner errors and high/critical findings; provide a visible emergency bypass; and preserve system rollback by scanning before rebuild.
