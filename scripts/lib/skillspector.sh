# shellcheck shell=bash
#
# Shared SkillSpector pin, sourced by scripts/update-system.sh (which installs
# the scanner) and scripts/check-skills.sh (which refuses to scan with any
# other version). One definition means the installer and the gate cannot
# disagree about which scanner produced a verdict, which matters because
# SCAN_EXCEPTIONS entries in check-skills.sh are re-reviewed against the
# findings of a specific scanner version.
#
# Bumping SKILLSPECTOR_TAG therefore means re-reading the SCAN_EXCEPTIONS
# rationales in check-skills.sh: a new analyzer can report findings the
# recorded review never looked at.
#
# This file defines values and comparison helpers only. It is sourced, never
# executed, so it carries no shebang and is not executable.

# SKILLSPECTOR_REPO and SKILLSPECTOR_PYTHON are read by the sourcing
# scripts, which shellcheck cannot see when it lints this file on its own.
# shellcheck disable=SC2034
#
# renovate: datasource=github-tags depName=NVIDIA/skillspector
SKILLSPECTOR_TAG="v2.13.4"
SKILLSPECTOR_REPO="https://github.com/NVIDIA/skillspector.git"
# yara-python ships self-contained macOS wheels only up to cp313. Newer
# interpreters build it from source against Homebrew's OpenSSL, which breaks
# the YARA analyzer on the next openssl major upgrade.
SKILLSPECTOR_PYTHON="3.13"

# `skillspector --version` prints "SkillSpector v<version>". Extract and
# compare the version exactly rather than grepping for a substring, so a pin
# of v2.13.1 does not silently accept v2.13.10.
skillspector_installed_version() {
    skillspector --version 2>/dev/null \
        | sed -nE 's/[^0-9]*([0-9]+\.[0-9]+\.[0-9]+).*/\1/p' \
        | head -1
}

skillspector_version_matches_pin() {
    [[ "$(skillspector_installed_version)" == "${SKILLSPECTOR_TAG#v}" ]]
}
