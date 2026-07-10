# Phoenix Nix Packaging Research

Date: 2026-07-10

## Question

How should Arize Phoenix be provided in this Nix/Home Manager codebase without
Docker, OrbStack, runtime `uvx`, or global provider environment mutation?

## Findings

- `arize-phoenix` is not available in nixpkgs under an Arize/Phoenix package
  name. The live nixpkgs package search only found unrelated Phoenix framework,
  wallet, and wxPython packages.
- Phoenix's supported local path is still a normal Python package plus
  `phoenix serve`; its upstream docs describe terminal self-hosting and
  environment variables such as `PHOENIX_PORT`, `PHOENIX_GRPC_PORT`,
  `PHOENIX_WORKING_DIR`, and `PHOENIX_SQL_DATABASE_URL`.
- PyPI currently publishes `arize-phoenix` version `17.23.0` with Python
  constraint `>=3.10,<3.15`. This repo pins the local environment to Python
  3.13 to match the current system interpreter and avoid accidental Python
  major-version drift.
- Phoenix is licensed under Elastic License 2.0. Direct flake package builds
  need unfree enabled; both current host configs already set
  `nixpkgs.config.allowUnfree = true`.
- uv2nix's documented flake pattern is to load a uv workspace, create a
  pyproject overlay, build a Python package set, and expose a `mkVirtualEnv`
  package from `workspace.deps.default`.

## Decision

Use a repo-owned mini uv project at `packages/arize-phoenix`:

- `pyproject.toml` depends on `arize-phoenix==17.23.0`.
- `uv.lock` is committed and is the dependency authority.
- `packages/arize-phoenix/default.nix` builds a Python 3.13 virtualenv via
  uv2nix from the committed lock.
- `flake.nix` exposes `packages.<system>.arize-phoenix`.
- `aiObservability.phoenixPackage` defaults to that flake package.

This keeps dependency resolution declarative and reviewable while avoiding
runtime `uvx --from arize-phoenix`, Docker, and hand-maintained Python
dependency lists.

## Sources

- Phoenix terminal self-hosting docs:
  <https://arize.com/docs/phoenix/self-hosting/deployment-options/terminal>
- Phoenix configuration docs:
  <https://arize.com/docs/phoenix/self-hosting/configuration>
- Phoenix PyPI release metadata:
  <https://pypi.org/project/arize-phoenix/>
- uv2nix hello-world template:
  <https://github.com/pyproject-nix/uv2nix/blob/master/templates/hello-world/flake.nix>
