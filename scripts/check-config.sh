#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

echo "Checking current-system flake outputs..."
nix flake check

echo "Checking AI agent catalog candidate..."
nix eval '.#darwinConfigurations.zoidberg.config.home-manager.users."C.Hessel".home.file.".agents/catalog/manifest.json".text' >/dev/null
if command -v agent-catalog-check >/dev/null 2>&1 && [ -f "$HOME/.agents/catalog/manifest.json" ]; then
  echo "Checking applied AI agent catalog..."
  agent-catalog-check
else
  echo "Skipping applied AI agent catalog check (agent-catalog-check or manifest not present yet)."
fi

echo "Evaluating Darwin host: zoidberg"
nix eval .#darwinConfigurations.zoidberg.config.system.build.toplevel.drvPath >/dev/null

echo "Evaluating NixOS host: farnsworth"
nix eval .#nixosConfigurations.farnsworth.config.system.build.toplevel.drvPath >/dev/null

echo "Evaluating NixOS host: farnsworth-x86"
nix eval .#nixosConfigurations.farnsworth-x86.config.system.build.toplevel.drvPath >/dev/null

echo "Evaluating installer package: farnsworth-installer aarch64-linux"
nix eval .#packages.aarch64-linux.farnsworth-installer.drvPath >/dev/null

echo "Evaluating installer package: farnsworth-installer x86_64-linux"
nix eval .#packages.x86_64-linux.farnsworth-installer.drvPath >/dev/null

echo "All declared host configurations evaluate."
