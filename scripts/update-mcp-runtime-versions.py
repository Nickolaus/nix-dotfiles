#!/usr/bin/env python3
"""Check or update package-manager MCP runtime version pins."""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
import urllib.parse
import urllib.request
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
VERSIONS_FILE = REPO_ROOT / "hosts/shared/ai-agents-lib.nix"
FLAKE_FILE = REPO_ROOT / "flake.nix"
UPDATE_SCRIPT_FILE = REPO_ROOT / "scripts/update-system.sh"
CODEX_EXAMPLE_FILE = REPO_ROOT / ".codex/config.example.toml"
CODEX_PRIVATE_FILE = REPO_ROOT / ".codex/config.toml"

# `ai-agents-lib.nix`-style pins: an explicit `# renovate:` comment above a
# `key = "value";` nix binding. depName/datasource are spelled out in the
# comment because the nix attribute name (e.g. `nixos`) rarely matches the
# real package name (e.g. `mcp-nixos`).
PIN_RE = re.compile(
    r"(?P<comment>[ \t]*# renovate: datasource=(?P<datasource>\S+) "
    r"depName=(?P<depName>\S+)(?: versioning=(?P<versioning>\S+))?)\n"
    r"(?P<prefix>[ \t]*(?P<key>\w+) = \")(?P<currentValue>[^\"]+)(?P<suffix>\";)"
)

# `flake.nix`-style pins: a flake input pinned to an explicit GitHub release
# tag directly in its own URL (`github:owner/repo/vX.Y.Z`). `nix flake
# update` never rewrites these -- it only re-locks whatever ref the URL
# already names, so the tag itself is the only thing that can go stale. No
# comment annotation needed: owner/repo is the depName already.
FLAKE_TAG_RE = re.compile(
    r'url = "github:(?P<depName>[^/"]+/[^/"]+)/(?P<currentValue>v\d+\.\d+\.\d+)";'
)

# update-system.sh-style pins: same `# renovate:` comment convention as
# PIN_RE, but bash assignment syntax forbids spaces around `=`
# (`KEY="value"`, not `KEY = "value"`).
SHELL_PIN_RE = re.compile(
    r"(?P<comment>[ \t]*# renovate: datasource=(?P<datasource>\S+) "
    r"depName=(?P<depName>\S+)(?: versioning=(?P<versioning>\S+))?)\n"
    r"(?P<prefix>[ \t]*(?P<key>\w+)=\")(?P<currentValue>[^\"]+)(?P<suffix>\")"
)


def fetch_json(url: str) -> dict:
    request = urllib.request.Request(
        url,
        headers={
            "Accept": "application/json",
            "User-Agent": "nix-dotfiles-mcp-runtime-version-check",
        },
    )
    with urllib.request.urlopen(request, timeout=30) as response:
        return json.load(response)


def latest_npm(dep_name: str) -> str:
    package_path = urllib.parse.quote(dep_name, safe="@")
    payload = fetch_json(f"https://registry.npmjs.org/{package_path}")
    return payload["dist-tags"]["latest"]


def latest_pypi(dep_name: str) -> str:
    package_path = urllib.parse.quote(dep_name, safe="")
    payload = fetch_json(f"https://pypi.org/pypi/{package_path}/json")
    return payload["info"]["version"]


def latest_github_tag(dep_name: str) -> str:
    # GitHub's /tags order isn't a guaranteed-sorted API contract, so parse
    # every vX.Y.Z tag and pick the max by parsed version instead of trusting
    # entry [0]. Non-semver tags (rc/beta/etc.) are ignored.
    best: tuple[int, int, int] | None = None
    best_name = ""
    page = 1
    while True:
        payload = fetch_json(
            f"https://api.github.com/repos/{dep_name}/tags?per_page=100&page={page}"
        )
        if not payload:
            break
        for tag in payload:
            match = re.fullmatch(r"v(\d+)\.(\d+)\.(\d+)", tag["name"])
            if not match:
                continue
            parsed = tuple(int(part) for part in match.groups())
            if best is None or parsed > best:
                best = parsed
                best_name = tag["name"]
        if len(payload) < 100:
            break
        page += 1

    if best is None:
        raise ValueError(f"no vX.Y.Z tags found for {dep_name}")
    return best_name


def latest_for(datasource: str, dep_name: str) -> str:
    if datasource == "npm":
        return latest_npm(dep_name)
    if datasource == "pypi":
        return latest_pypi(dep_name)
    if datasource == "github-tags":
        return latest_github_tag(dep_name)
    raise ValueError(f"unsupported datasource: {datasource}")


def rewrite_pinned_file(
    path: Path, pattern: re.Pattern[str], write: bool
) -> tuple[bool, dict[str, str]]:
    text = path.read_text()
    changed = False
    pinned_by_key: dict[str, str] = {}

    def replace(match: re.Match[str]) -> str:
        nonlocal changed
        datasource = match.group("datasource")
        dep_name = match.group("depName")
        current = match.group("currentValue")
        key = match.group("key")
        latest = latest_for(datasource, dep_name)
        pinned_by_key[key] = latest

        if current == latest:
            print(f"ok: {dep_name} {current}")
            return match.group(0)

        changed = True
        print(f"update: {dep_name} {current} -> {latest}")
        return (
            f"{match.group('comment')}\n"
            f"{match.group('prefix')}{latest}{match.group('suffix')}"
        )

    new_text = pattern.sub(replace, text)

    if write and changed:
        path.write_text(new_text)

    return changed, pinned_by_key


def rewrite_flake_tags(write: bool) -> bool:
    text = FLAKE_FILE.read_text()
    changed = False

    def replace(match: re.Match[str]) -> str:
        nonlocal changed
        dep_name = match.group("depName")
        current = match.group("currentValue")
        latest = latest_for("github-tags", dep_name)

        if current == latest:
            print(f"ok: {dep_name} {current}")
            return match.group(0)

        changed = True
        print(f"update: {dep_name} {current} -> {latest}")
        return f'url = "github:{dep_name}/{latest}";'

    new_text = FLAKE_TAG_RE.sub(replace, text)

    if write and changed:
        FLAKE_FILE.write_text(new_text)
        # flake.nix and flake.lock must agree: relock the inputs whose tag we
        # just bumped so a stale lock doesn't sit alongside the new URL until
        # someone happens to run a separate `nix flake update`.
        print("Refreshing flake.lock for updated GitHub-tag inputs...")
        result = subprocess.run(["nix", "flake", "update"], cwd=REPO_ROOT)
        if result.returncode != 0:
            raise RuntimeError("nix flake update failed after bumping flake.nix tags")

    return changed


def sync_codex_nixos_config(path: Path, nixos_version: str, write: bool) -> bool:
    if not path.exists():
        return False

    text = path.read_text()
    new_text = re.sub(
        r'args = \[(?:"--from", "mcp-nixos==[^"]+", "mcp-nixos"|"mcp-nixos")\]',
        f'args = ["--from", "mcp-nixos=={nixos_version}", "mcp-nixos"]',
        text,
        count=1,
    )

    changed = new_text != text
    if changed:
        print(f"sync: {path.relative_to(REPO_ROOT)} mcp-nixos -> {nixos_version}")
        if write:
            path.write_text(new_text)
    return changed


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Check or update npm/PyPI MCP runtime version pins."
    )
    parser.add_argument(
        "--write",
        action="store_true",
        help="rewrite pinned versions instead of only reporting drift",
    )
    parser.add_argument(
        "--sync-private-codex",
        action="store_true",
        help="also sync ignored .codex/config.toml mcp-nixos entry when present",
    )
    args = parser.parse_args()

    changed, pinned_by_key = rewrite_pinned_file(VERSIONS_FILE, PIN_RE, args.write)
    changed = rewrite_flake_tags(args.write) or changed
    shell_changed, _ = rewrite_pinned_file(UPDATE_SCRIPT_FILE, SHELL_PIN_RE, args.write)
    changed = shell_changed or changed
    nixos_version = pinned_by_key.get("nixos")
    if nixos_version:
        changed = (
            sync_codex_nixos_config(CODEX_EXAMPLE_FILE, nixos_version, args.write)
            or changed
        )
        if args.sync_private_codex:
            changed = (
                sync_codex_nixos_config(CODEX_PRIVATE_FILE, nixos_version, args.write)
                or changed
            )

    if changed and not args.write:
        print("error: MCP runtime pins are stale; rerun with --write", file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
