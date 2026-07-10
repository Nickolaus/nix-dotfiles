{ config, flake, lib, ... }:

let
  inherit (lib) mkEnableOption mkIf mkOption types;

  clientType = types.enum [ "codex" "claude" "cursor" "vibe" ];
  trustType = types.enum [
    "local-authored"
    "pinned-flake"
    "vendored-reviewed"
    "external-experimental"
  ];

  aiSources = import ../../flake/ai-agent-sources.nix { inherit flake; };
  cavemanSrc = aiSources.skills.caveman;
  gstackSrc = aiSources.skills.gstack;
  mattpocockSkillsSrc = aiSources.skills.mattpocock-skills;

  mattpocockSkill = { category, name, implicit }: {
    inherit name;
    value = {
      source = mattpocockSkillsSrc + "/skills/${category}/${name}";
      targets = [ "codex" ];
      trust = "pinned-flake";
      owner = "github:mattpocock/skills";
      inherit implicit;
    };
  };

  mattpocockEngineeringSkills = [
    { name = "ask-matt"; implicit = false; }
    { name = "code-review"; implicit = true; }
    { name = "codebase-design"; implicit = true; }
    { name = "diagnosing-bugs"; implicit = true; }
    { name = "domain-modeling"; implicit = true; }
    { name = "grill-with-docs"; implicit = false; }
    { name = "implement"; implicit = false; }
    { name = "improve-codebase-architecture"; implicit = false; }
    { name = "prototype"; implicit = true; }
    { name = "research"; implicit = true; }
    { name = "resolving-merge-conflicts"; implicit = true; }
    { name = "setup-matt-pocock-skills"; implicit = false; }
    { name = "tdd"; implicit = true; }
    { name = "to-spec"; implicit = false; }
    { name = "to-tickets"; implicit = false; }
    { name = "triage"; implicit = false; }
    { name = "wayfinder"; implicit = false; }
  ];

  mattpocockProductivitySkills = [
    { name = "grill-me"; implicit = false; }
    { name = "grilling"; implicit = true; }
    { name = "handoff"; implicit = false; }
    { name = "teach"; implicit = false; }
    { name = "writing-great-skills"; implicit = false; }
  ];

  cavemanSkills = [
    "caveman"
    "caveman-commit"
    "caveman-review"
    "caveman-compress"
    "caveman-help"
    "caveman-stats"
    "cavecrew"
  ];

  browserQaLabSkill = ''
    ---
    name: browser-qa-lab
    description: "Use when validating browser UI, frontend behavior, screenshots, persisted browser state, or user-flow QA with the existing web MCP profile and curated gstack browser references."
    ---

    # Browser QA Lab

    Use this skill for browser-facing QA of a local app, site, or frontend flow.

    Repo policy:
    - Use the existing `mcp-profile-web` profile when browser MCP tools are needed.
    - The profile owns `chrome-devtools` and `puppeteer`.
    - Do not run raw gstack `/browse`, `/qa`, `/qa-only`, `$B`, setup, upgrade, telemetry, tunnel, pair-agent, ngrok, or GBrain flows from the upstream references.
    - Do not add a long-lived browser daemon.

    Curated upstream references from the pinned `github:garrytan/gstack` input are rendered under `references/`.
    Read them for browser QA ideas, evidence patterns, and flow coverage, but follow this file's repo policy first.

    QA workflow:
    1. Run `ai-receipt-status` before QA and treat commit mismatch warnings as stale evidence.
    2. Identify target URL, expected flow, and any required local server command from repo context.
    3. Exercise the user flow with available browser MCP tools; include stateful behavior when relevant.
    4. Capture concise evidence: screenshot names, tested URL, viewport, and pass/fail result.
    5. Do not store cookies, tokens, localStorage secrets, prompts, raw logs, full paths, or full file contents in notes.
    6. After QA, log outcome with `ai-receipt-log --kind qa --status <pass|fail|needs-work|blocked> --summary <text> --evidence <text>`.

    If the web MCP profile is not available, say to run `mcp-profile-onboard web <repo>` and start a new agent session. Use non-browser checks only when they still answer the QA question.
  '';

  browserQaLabReferences = {
    "references/BROWSER.md" = builtins.readFile (gstackSrc + "/BROWSER.md");
    "references/browse/SKILL.md" = builtins.readFile (gstackSrc + "/browse/SKILL.md");
    "references/qa-only/SKILL.md" = builtins.readFile (gstackSrc + "/qa-only/SKILL.md");
  };

  graphifyAutoSkill = ''
    ---
    name: graphify-auto
    description: "Use when working in a repository and the task needs codebase architecture, code relationships, implementation planning, ticket-driven investigation, Graphify, graphify-out, or a persistent project graph. Ensures the repo's Graphify graph exists and is current on demand before querying or falling back."
    ---

    # Graphify Auto

    When a repository task benefits from Graphify context, run `graphify-ensure` from the repo root before saying no graph exists.

    Workflow:
    1. If inside a git repo, run `graphify-ensure`.
    2. If `graphify-out/graph.json` or `graphify-out/graph.json.gz` exists after that, use Graphify's normal query/path/explain flow for codebase-oriented questions.
    3. If `graphify-ensure` is unavailable or fails, use repo-scoped codebase-memory when available.
    4. Fall back to `rg` only for narrow text probes or when graph/codebase MCP options are unavailable.

    Ticket-driven work:
    - Fetch ticket body first.
    - If Jira/Atlassian returns app-shell HTML, login pages, or opaque connector output twice, ask for pasted ticket text.
    - If Atlassian MCP tools are absent, say Codex needs direct Atlassian HTTP MCP plus OAuth: `mcp-profile-onboard atlassian <repo>`, then `codex mcp login atlassian`, then a new Codex session.
  '';

  codebaseMemoryAutoSrc = ../../.agents/skills/codebase-memory-auto;

  skillType = types.submodule ({ ... }: {
    options = {
      source = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Canonical skill directory containing SKILL.md. Rendered as a Home Manager source link.";
      };

      text = mkOption {
        type = types.nullOr types.lines;
        default = null;
        description = "Generated SKILL.md contents for local-authored catalog skills.";
      };

      extraFiles = mkOption {
        type = types.attrsOf types.lines;
        default = { };
        description = "Additional files rendered relative to the skill directory for curated reference slices.";
      };

      targets = mkOption {
        type = types.listOf clientType;
        default = [ "codex" "claude" "cursor" "vibe" ];
        description = "Agent clients that should receive this catalog skill.";
      };

      trust = mkOption {
        type = trustType;
        default = "local-authored";
        description = "Reviewed provenance level for this skill.";
      };

      implicit = mkOption {
        type = types.bool;
        default = true;
        description = "Whether the skill may be implicitly invoked by matching its description.";
      };

      owner = mkOption {
        type = types.str;
        default = "local";
        description = "Human-readable owner or upstream provenance label.";
      };

      managed = mkOption {
        type = types.bool;
        default = true;
        description = "Whether the catalog renders this skill. Runtime-owned entries are reported but not written.";
      };
    };
  });

  roleType = types.submodule ({ ... }: {
    options = {
      description = mkOption {
        type = types.str;
        default = "";
        description = "Short role description. Roles are declared but not rendered in the first catalog slice.";
      };

      prompt = mkOption {
        type = types.lines;
        default = "";
        description = "Role system/developer prompt. Roles are declared but not rendered in the first catalog slice.";
      };

      targets = mkOption {
        type = types.listOf clientType;
        default = [ "codex" "claude" ];
        description = "Agent clients intended for this role.";
      };

      tools = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "Neutral tool names intended for later target-specific role rendering.";
      };

      deniedTools = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "Neutral denied tool names intended for later target-specific role rendering.";
      };

      model = mkOption {
        type = types.str;
        default = "inherit";
        description = "Target model hint for later role rendering.";
      };

      effort = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Target reasoning-effort hint for later role rendering.";
      };

      maxTurns = mkOption {
        type = types.nullOr types.int;
        default = null;
        description = "Turn limit hint for later role rendering.";
      };

      skills = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "Catalog skill names this role expects.";
      };

      mcpServers = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "aiAgents.mcpServers names this role expects.";
      };

      sandboxMode = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Target sandbox hint for later role rendering.";
      };

      isolation = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Target isolation hint for later role rendering.";
      };
    };
  });

  pluginType = types.submodule ({ ... }: {
    options = {
      targets = mkOption {
        type = types.listOf clientType;
        default = [ "codex" ];
        description = "Agent clients intended for this plugin. Plugins are declared but not rendered in the first catalog slice.";
      };

      source = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Local or pinned plugin source directory.";
      };

      installation = mkOption {
        type = types.enum [ "AVAILABLE" "INSTALLED" "DISABLED" ];
        default = "AVAILABLE";
        description = "Future marketplace installation policy.";
      };

      category = mkOption {
        type = types.str;
        default = "Productivity";
        description = "Future marketplace category.";
      };
    };
  });

  skillNamePattern = "^[a-z0-9]+(-[a-z0-9]+)*$";
  validSkillName = name: builtins.match skillNamePattern name != null;
  trimScalar = value:
    let
      trimmed = lib.trim value;
      len = builtins.stringLength trimmed;
    in
    if len >= 2 && lib.hasPrefix "\"" trimmed && lib.hasSuffix "\"" trimmed then
      builtins.substring 1 (len - 2) trimmed
    else if len >= 2 && lib.hasPrefix "'" trimmed && lib.hasSuffix "'" trimmed then
      builtins.substring 1 (len - 2) trimmed
    else
      trimmed;
  canReadSkillText = skill:
    skill.text != null || (skill.source != null && builtins.pathExists (skill.source + "/SKILL.md"));
  skillText = skill:
    if skill.text != null then
      skill.text
    else
      builtins.readFile (skill.source + "/SKILL.md");
  takeUntilFrontmatterEnd = lines:
    if lines == [ ] then
      [ ]
    else
      let
        line = builtins.head lines;
      in
      if lib.trim line == "---" then
        [ ]
      else
        [ line ] ++ takeUntilFrontmatterEnd (builtins.tail lines);
  frontmatterLines = text:
    let
      lines = lib.splitString "\n" text;
    in
    if lines != [ ] && lib.trim (builtins.head lines) == "---" then
      takeUntilFrontmatterEnd (builtins.tail lines)
    else
      [ ];
  frontmatterValue = key: text:
    let
      matches = builtins.filter (match: match != null)
        (map (line: builtins.match "${key}:[[:space:]]*(.*)" line) (frontmatterLines text));
    in
    if matches == [ ] then null else trimScalar (builtins.head (builtins.head matches));
  hasFrontmatter = text:
    let
      lines = lib.splitString "\n" text;
    in
    lines != [ ] && lib.trim (builtins.head lines) == "---"
    && builtins.any (line: lib.trim line == "---") (builtins.tail lines);

  cfg = config.aiAgents.catalog;
in
{
  options.aiAgents.catalog = {
    enable = mkEnableOption "Nix-managed AI agent catalog" // {
      default = true;
    };

    skills = mkOption {
      type = types.attrsOf skillType;
      default =
        builtins.listToAttrs
          (map
            (skill: {
              name = skill;
              value = {
                source = cavemanSrc + "/skills/${skill}";
                targets = [ "codex" "cursor" "vibe" ];
                trust = "pinned-flake";
                owner = "caveman";
                implicit = true;
              };
            })
            cavemanSkills)
        // builtins.listToAttrs
          (map
            (skill:
              mattpocockSkill {
                category = "engineering";
                inherit (skill) name implicit;
              })
            mattpocockEngineeringSkills)
        // builtins.listToAttrs
          (map
            (skill:
              mattpocockSkill {
                category = "productivity";
                inherit (skill) name implicit;
              })
            mattpocockProductivitySkills)
        // {
          browser-qa-lab = {
            text = browserQaLabSkill;
            extraFiles = browserQaLabReferences;
            targets = [ "codex" "claude" "cursor" "vibe" ];
            trust = "pinned-flake";
            owner = "github:garrytan/gstack via nix-dotfiles policy";
            implicit = true;
          };

          graphify-auto = {
            text = graphifyAutoSkill;
            targets = [ "codex" "claude" "vibe" ];
            trust = "local-authored";
            owner = "graphify";
            implicit = true;
          };

          codebase-memory-auto = {
            source = codebaseMemoryAutoSrc;
            targets = [ "codex" ];
            trust = "local-authored";
            owner = "nix-dotfiles";
            implicit = true;
          };

          graphify = {
            targets = [ "codex" "claude" "vibe" ];
            trust = "external-experimental";
            owner = "graphify";
            implicit = false;
            managed = false;
          };

          chonkie = {
            targets = [ "codex" "claude" "cursor" "vibe" ];
            trust = "external-experimental";
            owner = "github:chonkie-inc/skills";
            implicit = false;
            managed = false;
          };
        };
      description = "Declarative reusable AI-agent skills.";
    };

    roles = mkOption {
      type = types.attrsOf roleType;
      default = { };
      description = "Neutral role declarations. First catalog slice validates references but does not render role files.";
    };

    plugins = mkOption {
      type = types.attrsOf pluginType;
      default = { };
      description = "Plugin declarations. First catalog slice validates sources but does not render marketplace files.";
    };
  };

  config = mkIf (config.aiAgents.enable && cfg.enable) {
    assertions =
      lib.mapAttrsToList
        (name: skill: {
          assertion = !skill.managed || ((skill.source != null) != (skill.text != null));
          message = "aiAgents.catalog.skills.${name} must set exactly one of source or text when managed.";
        })
        cfg.skills
      ++ lib.mapAttrsToList
        (name: skill: {
          assertion = skill.extraFiles == { } || (skill.managed && skill.text != null);
          message = "aiAgents.catalog.skills.${name}.extraFiles requires a managed text skill.";
        })
        cfg.skills
      ++ lib.mapAttrsToList
        (name: skill: {
          assertion = skill.source == null || builtins.pathExists (skill.source + "/SKILL.md");
          message = "aiAgents.catalog.skills.${name}.source must contain SKILL.md.";
        })
        cfg.skills
      ++ lib.mapAttrsToList
        (name: skill: {
          assertion = !skill.managed || validSkillName name;
          message = "aiAgents.catalog.skills.${name} must match Agent Skills naming rules: lowercase alphanumeric plus single hyphens.";
        })
        cfg.skills
      ++ lib.mapAttrsToList
        (name: skill: {
          assertion = !skill.managed || (canReadSkillText skill && hasFrontmatter (skillText skill));
          message = "aiAgents.catalog.skills.${name} must have SKILL.md YAML frontmatter.";
        })
        cfg.skills
      ++ lib.mapAttrsToList
        (name: skill: {
          assertion = !skill.managed || (canReadSkillText skill && frontmatterValue "name" (skillText skill) == name);
          message = "aiAgents.catalog.skills.${name} SKILL.md frontmatter name must equal the catalog key.";
        })
        cfg.skills
      ++ lib.mapAttrsToList
        (name: skill: {
          assertion =
            !skill.managed
            || (canReadSkillText skill && frontmatterValue "description" (skillText skill) != null && frontmatterValue "description" (skillText skill) != "");
          message = "aiAgents.catalog.skills.${name} SKILL.md frontmatter description must be non-empty.";
        })
        cfg.skills
      ++ lib.mapAttrsToList
        (name: skill: {
          assertion = skill.trust != "external-experimental" || (!skill.implicit);
          message = "aiAgents.catalog.skills.${name} has external-experimental trust and must set implicit = false.";
        })
        cfg.skills
      ++ lib.concatMap
        (roleName:
          let
            role = cfg.roles.${roleName};
            unknownSkills = builtins.filter (skill: !(builtins.hasAttr skill cfg.skills)) role.skills;
            unknownServers = builtins.filter (server: !(builtins.hasAttr server config.aiAgents.mcpServers)) role.mcpServers;
          in
          [
            {
              assertion = unknownSkills == [ ];
              message =
                "aiAgents.catalog.roles.${roleName}.skills references unknown catalog skills: "
                + builtins.concatStringsSep ", " unknownSkills;
            }
            {
              assertion = unknownServers == [ ];
              message =
                "aiAgents.catalog.roles.${roleName}.mcpServers references unknown aiAgents.mcpServers: "
                + builtins.concatStringsSep ", " unknownServers;
            }
          ])
        (builtins.attrNames cfg.roles)
      ++ lib.mapAttrsToList
        (name: plugin: {
          assertion = plugin.source == null || builtins.pathExists plugin.source;
          message = "aiAgents.catalog.plugins.${name}.source must exist.";
        })
        cfg.plugins;
  };
}
