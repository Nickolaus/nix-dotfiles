# Codex MCP Config Rebase Research

Date: 2026-07-10

## Question

Why can `git rebase origin/main` abort with this error even when `git status`
looks clean?

```text
Your local changes to the following files would be overwritten by checkout:
        .codex/config.toml
```

## Short Answer

The MCP rollout mixed two ownership models on one path:

1. `.codex/config.toml` was tracked as repo policy.
2. `mcp-profile-onboard` and `codebase-memory-onboard` also wrote clone-local
   MCP state into that same tracked file, then hid it with `skip-worktree`.

That can make `git status` look clean while the working tree still differs from
`HEAD`. During rebase, Git performs checkout-like operations; if the target tree
also changes `.codex/config.toml`, Git refuses to overwrite the hidden local
edit.

## Primary Source Findings

Git documents `git rebase <upstream>` as building a commit list, checking out
`<upstream>` with the equivalent of `git checkout --detach <upstream>`, then
replaying commits and finally checking out the branch again. Source:
<https://git-scm.com/docs/git-rebase>, lines 319-326.

Git's checkout/read-tree safety rule is to refuse an update when local working
tree changes would be overwritten. Source:
<https://git-scm.com/docs/git-read-tree>, lines 396-398.

`.git/info/exclude` is a local ignore mechanism, but Git's ignore rules do not
apply to files already tracked by Git. Source:
<https://git-scm.com/docs/gitignore>, lines 226-239 and 270-274.

`skip-worktree` is not a general "private tracked file" mechanism. Git defines
it as a hint to avoid writing the file when reasonably possible, and warns that
not all commands fully honor it; commands may still write those files in
important cases such as merge or rebase conflicts. Source:
<https://git-scm.com/docs/git-update-index>, lines 478-487.

OpenAI's Codex config docs say user config lives in `~/.codex/config.toml`, and
project overrides can live in `.codex/config.toml` for trusted projects. Source:
<https://developers.openai.com/codex/config-basic>, lines 699-704.

OpenAI's Codex config precedence puts trusted project `.codex/config.toml`
layers above user config. Source:
<https://developers.openai.com/codex/config-basic>, lines 710-721.

Codex MCP servers can be configured in `~/.codex/config.toml` or in a
project-scoped `.codex/config.toml`, and each server uses a
`[mcp_servers.<name>]` table with fields such as `command`, `args`, and `env`.
Source: <https://developers.openai.com/codex/mcp>, lines 719-723 and 762-773.

## Local Findings

Before this fix, this repo tracked `.codex/config.toml` with repo-scoped MCP
entries for `nixos` and `codebase-memory`, and also tracked
`.codex/cache/codebase-memory/.gitkeep`.

`home/features/ai/mcp-profiles.nix` wrote profile entries into
`.codex/config.toml` and then called `git update-index --skip-worktree` when the
file was tracked.

`home/features/ai/codebase-memory.nix` wrote the repo-scoped
`codebase-memory` MCP entry into `.codex/config.toml` and used the same
tracked-file hiding pattern.

The existing design note in
`docs/codebase-memory-mcp-scoped-cache-handoff.md` already states the desired
end state: no tracked `.codex/config.toml` per repo and no tracked
`.codex/cache`.

## Fix Direction

The resilient fix is to make ownership explicit:

- Tracked project MCP config is team-owned. Private onboarding must not mutate
  it.
- Clone-local MCP config can be written only when the file is untracked and kept
  private through `.git/info/exclude`.
- `.codex/config.toml` and `.codex/cache/` should not be tracked in this repo.
  A committed `.codex/config.example.toml` can document the recommended local
  shape without becoming mutable runtime state.

This removes the hidden dirty tracked file that causes checkout/rebase to abort.
