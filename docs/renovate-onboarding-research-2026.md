# Renovate Onboarding Research

Date: 2026-07-11

## Question

How should this `nix-dotfiles` repository onboard Renovate so dependency PRs are created for all relevant update surfaces, including major updates, with no automerge by default?

## Repo Findings

This repository already keeps research notes under `docs/*-research-2026.md`, so this note follows that convention.

Local scan:

- Existing Renovate config: none found.
- Dirty worktree before research: `flake.lock` already modified by user; do not edit it during onboarding research or config scaffolding.
- Dependency surfaces found by `rg --files --hidden`:
  - `flake.nix`
  - `flake.lock`
  - `packages/arize-phoenix/pyproject.toml`
  - `packages/arize-phoenix/uv.lock`
- No `.github/workflows`, `Dockerfile`, `package.json`, `Cargo.toml`, or `go.mod` were found in the repo scan.
- Recent commit history uses Conventional Commit style such as `fix(agents): ...`, `docs(agents): ...`, and `feat: ...`; Renovate semantic commits should be explicitly enabled to match this pattern.

## Primary Source Findings

### Onboarding and config file location

Renovate's hosted GitHub.com path is the Mend Renovate App at `https://github.com/apps/renovate`; Renovate docs say install the app for all or selected repositories, then Renovate starts onboarding for those repositories. Source: <https://docs.renovatebot.com/getting-started/installing-onboarding/#hosted-githubcom-app>

Renovate onboarding creates a "Configure Renovate" PR and does not make further repo changes or update PRs until the onboarding PR is merged. Source: <https://docs.renovatebot.com/getting-started/installing-onboarding/#no-risk-onboarding>

The onboarding PR defaults to a root `renovate.json`; supported repo config locations include `renovate.json`, `renovate.jsonc`, `.github/renovate.json`, `.github/renovate.jsonc`, `.renovaterc`, and related JSON/JSON5 variants. Source: <https://docs.renovatebot.com/configuration-options/#locations-for-configuration-filenames>

Renovate recommends explicit `.jsonc` when comments are desired; it warns that `package.json`-embedded Renovate config is deprecated. Source: <https://docs.renovatebot.com/configuration-options/#locations-for-configuration-filenames>

`configMigration` raises PRs when Renovate needs to migrate config, but Renovate docs say it only performs config migration on `.json` and `.json5` files. Source: <https://docs.renovatebot.com/configuration-options/#configmigration>

Recommendation for this repo: use root `renovate.json`. It is first in Renovate's search order, easy to see next to `flake.nix`, avoids deprecated `package.json` config, and preserves future `configMigration` PR support. Use `renovate.jsonc` only if comments are more important than config migration PRs.

### Baseline preset and valid current keys

The current Renovate docs and JSON schema consulted here correspond to Mend Renovate `43.259.0`. Source: <https://docs.renovatebot.com/configuration-options/> and <https://docs.renovatebot.com/renovate-schema.json>

`config:recommended` is Renovate's recommended configuration for most users and is language-independent. It includes the Dependency Dashboard, semantic prefix handling, ignored generated/vendor/test dirs, recommended grouping, merge confidence badges, replacement rules, workarounds, and digest changelog helpers. Source: <https://docs.renovatebot.com/presets-config/#configrecommended>

`config:best-practices` includes `config:recommended`, Docker digest pinning, GitHub Action digest pinning, config migration PRs, dev dependency pinning, abandonment checks, npm release-age safety, and weekly lock file maintenance. Source: <https://docs.renovatebot.com/presets-config/#configbest-practices>

Recommendation for this repo: start from `config:recommended`, then add explicit repo-specific settings. `config:best-practices` is stronger but includes Docker/GitHub Actions/dev-dependency behavior for surfaces not currently present, and it enables lock-file maintenance through a preset rather than making this repo's Nix policy explicit.

Use `$schema: "https://docs.renovatebot.com/renovate-schema.json"` in the config because Renovate publishes this schema for config validation. Source: <https://docs.renovatebot.com/configuration-options/> and <https://docs.renovatebot.com/renovate-schema.json>

Validate the resulting config with `renovate-config-validator`; Renovate docs say all Renovate distributions include it, and `npx --yes --package renovate -- renovate-config-validator` validates default config locations. Source: <https://docs.renovatebot.com/config-validation/>

For hosted-app validation feedback on config changes, use a branch matching `{{branchPrefix}}reconfigure`, for example `renovate/reconfigure`; Renovate will validate the config branch and comment/status the PR. Source: <https://docs.renovatebot.com/config-validation/#validation-of-renovate-config-change-prs>

### PRs for every update, including major updates

`automerge` defaults to `false`; setting it explicitly to `false` documents that every Renovate PR requires human merge unless future rules opt in. Source: <https://docs.renovatebot.com/configuration-options/#automerge>

`prCreation` defaults to `immediate`, and `immediate` creates PRs as soon as Renovate creates update branches. Source: <https://docs.renovatebot.com/configuration-options/#prcreation>

`prHourlyLimit` defaults to `2`; `0` means no hourly PR creation limit. Source: <https://docs.renovatebot.com/configuration-options/#prhourlylimit>

`prConcurrentLimit` defaults to `10`; `0` means no concurrent PR limit, and security PRs are created even if the limit is reached. Source: <https://docs.renovatebot.com/configuration-options/#prconcurrentlimit>

`branchConcurrentLimit` inherits `prConcurrentLimit` by default; `0` means no branch concurrency limit. Source: <https://docs.renovatebot.com/configuration-options/#branchconcurrentlimit>

`separateMajorMinor` defaults to `true`; Renovate recommends keeping it true because it creates separate PRs when both minor and major updates exist, and it has priority over package grouping. Source: <https://docs.renovatebot.com/configuration-options/#separatemajorminor>

`separateMultipleMajor=true` creates one PR per available major version stream, such as one PR for v2 and one for v3 instead of only the latest major. Source: <https://docs.renovatebot.com/configuration-options/#separatemultiplemajor>

Recommendation for user's "PRs for everything even major updates": explicitly set `automerge=false`, `prCreation=immediate`, `prHourlyLimit=0`, `prConcurrentLimit=0`, `branchConcurrentLimit=0`, `separateMajorMinor=true`, and `separateMultipleMajor=true`. This favors visibility over PR-volume throttling. If PR volume becomes too high later, reduce limits without disabling major PR creation.

### Managers needed for this repo

Renovate's Nix manager supports Nix dependencies, is currently beta, and must be opted into with `"nix": { "enabled": true }`. Source: <https://docs.renovatebot.com/modules/manager/nix/#enabling>

The Nix manager default file match is `/(^|/)flake\.nix$/`, supports the `git-refs` datasource, and has default config with `enabled=false`. Source: <https://docs.renovatebot.com/modules/manager/nix/#file-matching> and <https://docs.renovatebot.com/modules/manager/nix/#default-config>

The Nix manager supports lock file maintenance for `flake.lock`, input updates for `flake.lock`, and package rules where `depName` is the flake input name and `packageName` is the fully qualified root URL. Source: <https://docs.renovatebot.com/modules/manager/nix/#lock-file-maintenance> and <https://docs.renovatebot.com/modules/manager/nix/#additional-information>

Renovate's PEP 621 manager updates dependencies inside `pyproject.toml`; its official manager README says it also supports `uv`, including `uv.lock` files and `uv` workspaces. Source: <https://docs.renovatebot.com/modules/manager/pep621/> and <https://raw.githubusercontent.com/renovatebot/renovate/main/lib/modules/manager/pep621/readme.md>

Renovate's GitHub Actions manager updates workflow files under `.github/workflows` and action files, but this repository currently has no `.github/workflows` files. Source: <https://docs.renovatebot.com/modules/manager/github-actions/#file-matching>

Recommendation for initial `enabledManagers`: include `"nix"` and `"pep621"` only. Add `"github-actions"` when workflows appear; add `"dockerfile"`, `"npm"`, `"cargo"`, `"gomod"`, or others only when matching manifests appear.

### Nix-specific behavior and pitfalls

Nix's own `nix flake update` updates inputs in `flake.lock`; by default it updates all inputs, while positional input names update only selected inputs. Source: <https://nix.dev/manual/nix/2.34/command-ref/new-cli/nix3-flake-update>

Nix's own `nix flake lock` creates or updates missing lock entries and does not update existing entries; existing lock entry updates belong to `nix flake update`. Source: <https://nix.dev/manual/nix/2.34/command-ref/new-cli/nix3-flake-lock>

Renovate's Nix manager is beta and disabled by default, so a Nix flakes repo can appear "configured" while Nix updates are still skipped if `"nix.enabled": true` is omitted. Source: <https://docs.renovatebot.com/modules/manager/nix/#enabling>

Because Renovate identifies Nix dependencies by flake input name in `depName`, package rules should match repo inputs such as `nixpkgs`, `nix-darwin`, `home-manager`, `sops-nix`, `serena`, `codebase-memory-mcp`, `disko`, and `impermanence` by `matchDepNames` when special handling is needed. Source: <https://docs.renovatebot.com/modules/manager/nix/#additional-information>

Do not set `skipArtifactsUpdate=true` for this repo's Nix updates: Renovate docs say that setting skips artifacts such as lock files, which would defeat `flake.lock` update PRs. Source: <https://docs.renovatebot.com/configuration-options/#skipartifactsupdate>

Lock file maintenance should be explicit. Renovate lock file maintenance PRs are never grouped with other dependency updates. Source: <https://docs.renovatebot.com/configuration-options/#groupname> and <https://docs.renovatebot.com/modules/manager/nix/#lock-file-maintenance>

Do not configure artifact-error status checks with `statusCheckWhen`: strict validation with `renovate-config-validator --strict` rejected `statusCheckWhen` as an invalid current option for this repository config.

### Schedules, stability days, labels, and dashboard

The default schedule is "at any time"; Renovate recommends schedule windows of at least 3-4 hours when schedules are used because restrictive schedules can cause updates to be skipped. Source: <https://docs.renovatebot.com/configuration-options/#schedule>

`timezone` should be configured when schedules are used and should be an IANA timezone. Source: <https://docs.renovatebot.com/configuration-options/#timezone>

`minimumReleaseAge` delays branch/PR creation for the configured duration and has a status check named `renovate/stability-days` by default. Source: <https://docs.renovatebot.com/configuration-options/#minimumreleaseage> and <https://docs.renovatebot.com/configuration-options/#statuschecknames>

`dependencyDashboard` is included by `config:recommended`; it is useful to see pending, blocked, and manual-action updates. Source: <https://docs.renovatebot.com/presets-config/#configrecommended> and <https://docs.renovatebot.com/configuration-options/#dependencydashboard>

Use `labels` for baseline PR labels and `addLabels` in package rules when preserving baseline labels while adding manager-specific labels; Renovate docs say `labels` is non-mergeable and `addLabels` appends. Source: <https://docs.renovatebot.com/configuration-options/#addlabels>

### Vulnerability alerts

Renovate can read GitHub Vulnerability Alerts and customize fix PRs only on GitHub; it requires GitHub dependency graph, Dependabot alerts, and Renovate app read permission for Dependabot alerts. Source: <https://docs.renovatebot.com/configuration-options/#vulnerabilityalerts>

Vulnerability alert PRs ignore normal scheduling and PR/branch/concurrency/hourly limits and "skip the line". Source: <https://docs.renovatebot.com/configuration-options/#vulnerabilityalerts>

Strict validation with `renovate-config-validator --strict` rejected `vulnerabilityAlerts.vulnerabilityFixStrategy` as an invalid current option for this repository config, so the implementation keeps only supported vulnerability-alert labels and explicit `automerge=false`.

## Recommended Config Shape

Use the implemented root `renovate.json` shape:

```json
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": ["config:recommended"],
  "description": "Renovate config for Nix flake dotfiles and repo-owned Python env locks.",
  "timezone": "Europe/Berlin",
  "labels": ["dependencies"],
  "dependencyDashboard": true,
  "configMigration": true,
  "semanticCommits": "enabled",
  "semanticCommitType": "chore",
  "semanticCommitScope": "deps",
  "automerge": false,
  "prCreation": "immediate",
  "prHourlyLimit": 0,
  "prConcurrentLimit": 0,
  "branchConcurrentLimit": 0,
  "separateMajorMinor": true,
  "separateMultipleMajor": true,
  "enabledManagers": ["nix", "pep621"],
  "nix": {
    "enabled": true
  },
  "lockFileMaintenance": {
    "enabled": true,
    "schedule": ["before 4am on monday"]
  },
  "vulnerabilityAlerts": {
    "labels": ["dependencies", "security"],
    "automerge": false
  },
  "packageRules": [
    {
      "description": "Label Nix flake input updates and avoid fresh ref churn.",
      "matchManagers": ["nix"],
      "addLabels": ["nix"],
      "minimumReleaseAge": "3 days"
    },
    {
      "description": "Prioritize nixpkgs because it drives most system package changes.",
      "matchManagers": ["nix"],
      "matchDepNames": ["nixpkgs"],
      "addLabels": ["nixpkgs"],
      "prPriority": 10
    },
    {
      "description": "Label repo-owned Python project dependency updates.",
      "matchManagers": ["pep621"],
      "addLabels": ["python"]
    }
  ]
}
```

`rebaseWhen` is intentionally omitted. This repo has no in-repo CI workflow or branch-protection-as-code source, so hardcoding `rebaseWhen="conflicted"` would encode unverified policy. Renovate's default `rebaseWhen="auto"` uses `behind-base-branch` when automerge is configured or when the repository requires PRs to be up to date; otherwise it uses `conflicted`. Source: <https://docs.renovatebot.com/configuration-options/#rebasewhen>

## Implementation Requirements

1. Add root `renovate.json`; do not edit `flake.lock`.
2. Keep enabled managers to `nix` and `pep621` for current repo files.
3. Validate config with `npx --yes --package renovate -- renovate-config-validator --strict` or with installed Renovate if available. Source: <https://docs.renovatebot.com/config-validation/#strict-mode>
4. For repo-local sanity, run docs/config checks only: `git diff --check`; do not run `nix flake update`.
5. If using hosted Mend Renovate App, install/configure app at <https://github.com/apps/renovate> and open config PR from `renovate/reconfigure` for app-side validation feedback. Source: <https://docs.renovatebot.com/config-validation/#validation-of-renovate-config-change-prs>
6. After merging config, expect potentially many PRs because this recommendation intentionally disables Renovate's default hourly and concurrent PR caps.

## Caveats

- Nix manager is beta, so verify first generated PRs carefully before merging. Source: <https://docs.renovatebot.com/modules/manager/nix/#enabling>
- Hosted Mend Renovate App behavior depends on GitHub app installation and repository permissions; vulnerability alert PRs require GitHub dependency graph, Dependabot alerts, and app permission to read Dependabot alerts. Source: <https://docs.renovatebot.com/configuration-options/#vulnerabilityalerts>
- `enabledManagers` is intentionally narrow. Future repo additions such as `.github/workflows`, `Dockerfile`, `go.mod`, `Cargo.toml`, or `package.json` should update `enabledManagers` and add matching package rules.
- `prHourlyLimit=0` and `prConcurrentLimit=0` satisfy "PRs for everything" but can create high PR/CI volume. Source: <https://docs.renovatebot.com/configuration-options/#prhourlylimit> and <https://docs.renovatebot.com/configuration-options/#prconcurrentlimit>
