{ config, flake, lib, ... }:

let
  inherit (lib) mkEnableOption mkIf;

  cfg = config.aiAdhdOutput;
  aiSources = import ../../../flake/ai-agent-sources.nix { inherit flake; };
  iHaveAdhdSrc = aiSources.skills.i-have-adhd;

  # Single point of truth: the pinned `i-have-adhd` flake input's own SKILL.md
  # is embedded verbatim (not hand-paraphrased), so bumping the flake input is
  # the only thing ever needed to keep this in sync. Upstream ships this skill
  # opt-in (`disable-model-invocation: true`, honored directly by Claude Code
  # and Codex regardless of the aiAgents.catalog entry's own implicit
  # setting), so making it the default here means injecting the ruleset the
  # same way caveman.nix does rather than relying on skill auto-invocation.
  iHaveAdhdSkillFile = iHaveAdhdSrc + "/skills/i-have-adhd/SKILL.md";
  adhdDefaultInstructions = ''

    This skill activates by default at the start of every session -- no
    trigger phrase needed. What follows is the pinned i-have-adhd skill
    definition itself, verbatim from ${iHaveAdhdSkillFile}, which governs
    output shape and when to drop it for the rest of the session.

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
