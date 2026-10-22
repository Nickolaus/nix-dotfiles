{ config, flake, lib, ... }:

let
  inherit (lib) mkEnableOption mkIf;

  cfg = config.aiAdhdOutput;
  aiSources = import ../../../flake/ai-agent-sources.nix { inherit flake; };
  iHaveAdhdSrc = aiSources.skills.i-have-adhd;

  # Single point of truth: the pinned `i-have-adhd` flake input's own SKILL.md
  # is embedded verbatim (not hand-paraphrased), so bumping the flake input is
  # the only thing ever needed to keep this in sync. Upstream ships this skill
  # opt-in (frontmatter `disable-model-invocation: true` for Claude Code,
  # Cursor, and Vibe; agents/openai.yaml policy for Codex), so making it the
  # default here means injecting the ruleset the same way caveman.nix does
  # rather than relying on skill auto-invocation.
  iHaveAdhdSkillFile = iHaveAdhdSrc + "/skills/i-have-adhd/SKILL.md";
  adhdDefaultInstructions = ''

    This skill activates by default at the start of every session -- no
    trigger phrase needed. What follows is the pinned i-have-adhd skill
    definition itself, verbatim from ${iHaveAdhdSkillFile}, which governs
    output shape and when to drop it for the rest of the session.

    Precedence with caveman: i-have-adhd owns response structure: the
    first-line action, numbered steps, a one-line state restatement, time
    estimates, visible wins, and the final next action. caveman owns
    sentence-level wording. The task always needs these structural elements,
    so caveman's no-recap, no-unrequested-lists and no-follow-up-offers rules
    leave them in place and only compress their wording. A one-line state
    restatement is not a recap. Write the final next action as a concrete
    `Next:` line, never as an offer question.

    ${builtins.readFile iHaveAdhdSkillFile}
  '';
in
{
  options.aiAdhdOutput.enable = mkEnableOption "ADHD-friendly output shaping by default (i-have-adhd skill)" // {
    default = true;
  };

  config = mkIf cfg.enable {
    home.file.".codex/AGENTS.md".text = adhdDefaultInstructions;
    home.file.".vibe/AGENTS.md".text = adhdDefaultInstructions;
    home.file.".claude/CLAUDE.md".text = adhdDefaultInstructions;
  };
}
