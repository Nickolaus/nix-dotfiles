{ config, lib, ... }:

let
  inherit (lib) mkEnableOption mkIf;

  cfg = config.aiCommitWorkflow;

  # Agent-facing commit rules. These are deliberately headless-agent specific:
  # they encode the failure modes an agent hits that a human at a terminal does
  # not (no persistent shell state between tool calls, no interactive editor, no
  # reliable sense of which commits are already published).
  commitWorkflowInstructions = ''

    ## Commit Workflow for AI Agents

    Applies only when the user asks for a commit.

    1. Read the full state before staging. Determine the base ref from the actual
       integration target (`gh pr view --json baseRefName -q .baseRefName`, or
       `git merge-base HEAD @{u}`). Do not assume `main` or `master`:

       ```bash
       git status --short
       git diff              # unstaged
       git diff --cached     # staged
       git log --oneline <base>..HEAD
       ```

    2. Stage explicitly. Stage only the files belonging to the intended commit.
       Do not use `git add -A` unless the user asks for it.

    3. Create one commit per bounded context. Split clearly separable changes into
       multiple independently valid commits. If the boundary is ambiguous, ask
       instead of inventing a split.

    4. Reconcile the change with the commit it belongs to before adding a new one.
       First establish the rewritable range -- the commits not yet published:

       ```bash
       git log --oneline @{u}..HEAD         # commits ahead of the tracked remote branch
       git branch -r --contains <commit>    # fallback when no upstream is configured
       ```

       - Amend `HEAD` when the change corrects it and `HEAD` is in the rewritable range.
       - Use `git commit --fixup=<commit>` then `git rebase -i --autosquash <base>`
         when the change belongs to an earlier commit in the rewritable range.
       - Create a new commit when the change is a new logical unit, or when the
         commit it belongs to falls outside the rewritable range.
       - Never rewrite a commit already pushed to a shared branch without explicit
         approval. On an approved personal branch use `--force-with-lease`,
         never `--force`.

    5. Write a single-line Conventional Commit subject: `type(scope): subject`.
       No body, no trailers. If a repository defines its own convention
       (recent `git log`, `.gitmessage`, commitlint or commitizen config),
       follow that instead.

    6. Commit through stdin in a single call. Do not rely on shell variables set in
       an earlier call -- agent shell state does not persist:

       ```bash
       git commit -F - <<'EOF'
       feat(auth): support passkey login
       EOF
       ```

    7. Handle hook-modified files. If a `pre-commit` hook reformats files, re-stage
       them and amend once, then stop and report. Do not loop.

    Never invoke an interactive commit helper from a headless agent (`cz commit`,
    `git commit` with no `-m`/`-F`, or any wrapper that opens an editor). They have
    no non-interactive path for supplying the answers and will hang.
  '';
in
{
  options.aiCommitWorkflow.enable =
    mkEnableOption "commit workflow rules for headless AI agents" // {
      default = true;
    };

  config = mkIf cfg.enable {
    home.file.".codex/AGENTS.md".text = commitWorkflowInstructions;
    home.file.".vibe/AGENTS.md".text = commitWorkflowInstructions;
    home.file.".claude/CLAUDE.md".text = commitWorkflowInstructions;
  };
}
