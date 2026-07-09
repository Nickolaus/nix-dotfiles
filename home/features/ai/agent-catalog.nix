{ config, lib, osConfig ? { }, pkgs, ... }:

let
  aiAgentsLib = import ../../../hosts/shared/ai-agents-lib.nix { inherit lib pkgs; };

  aiCfg = if osConfig ? aiAgents then osConfig.aiAgents else null;
  catalogEnabled = aiCfg != null && aiCfg.enable && aiCfg.catalog.enable;
  cfg = if catalogEnabled then aiCfg.catalog else { skills = { }; roles = { }; plugins = { }; };

  allTargets = [ "codex" "claude" "cursor" "vibe" ];
  targetEnabled = target: aiCfg.targets.${target}.enable;
  enabledTargets = if catalogEnabled then builtins.filter targetEnabled allTargets else [ ];

  renderedPathsFor = aiAgentsLib.renderedSkillPathsFor enabledTargets;

  managedMainSkillEntries = lib.concatMap
    (name:
      let
        skill = cfg.skills.${name};
        renderedPaths = renderedPathsFor name skill;
      in
      lib.optionals skill.managed (map
        (path: {
          name = if skill.text != null then "${path}/SKILL.md" else path;
          value =
            if skill.text != null then
              { text = skill.text; }
            else
              { source = skill.source; };
        })
        renderedPaths))
    (builtins.attrNames cfg.skills);

  managedExtraSkillEntries = lib.concatMap
    (name:
      let
        skill = cfg.skills.${name};
        renderedPaths = renderedPathsFor name skill;
      in
      lib.optionals skill.managed (lib.concatMap
        (path:
          lib.mapAttrsToList
            (relPath: text: {
              name = "${path}/${relPath}";
              value = { inherit text; };
            })
            skill.extraFiles)
        renderedPaths))
    (builtins.attrNames cfg.skills);

  managedSkillEntries = managedMainSkillEntries ++ managedExtraSkillEntries;

  roleCountsByTarget = builtins.listToAttrs (map
    (target: {
      name = target;
      value = builtins.length (builtins.filter
        (roleName: builtins.elem target cfg.roles.${roleName}.targets)
        (builtins.attrNames cfg.roles));
    })
    allTargets);

  pluginCountsByTarget = builtins.listToAttrs (map
    (target: {
      name = target;
      value = builtins.length (builtins.filter
        (pluginName: builtins.elem target cfg.plugins.${pluginName}.targets)
        (builtins.attrNames cfg.plugins));
    })
    allTargets);

  manifest = {
    enabled = catalogEnabled;
    enabledTargets = enabledTargets;
    skills = map
      (name:
        let
          skill = cfg.skills.${name};
          expectedPaths = renderedPathsFor name skill;
        in
        {
          inherit name;
          inherit (skill) owner trust implicit managed targets;
          expectedSkillDirs = expectedPaths;
          renderedSkillFiles = lib.optionals skill.managed (map (path: "${path}/SKILL.md") expectedPaths);
        })
      (builtins.attrNames cfg.skills);
    roles = builtins.attrNames cfg.roles;
    plugins = builtins.attrNames cfg.plugins;
    inherit roleCountsByTarget pluginCountsByTarget;
  };

  manifestJson = builtins.toJSON manifest;
  manifestPath = ".agents/catalog/manifest.json";

  checkPython = pkgs.writeText "agent-catalog-check.py" ''
    import json
    import os
    import re
    import sys

    manifest_path, home = sys.argv[1], sys.argv[2]

    with open(manifest_path) as f:
        manifest = json.load(f)

    errors = []
    warnings = []
    skill_name_re = re.compile(r"^[a-z0-9]+(-[a-z0-9]+)*$")

    def parse_frontmatter(path):
        with open(path, encoding="utf-8") as f:
            lines = f.read().splitlines()
        if not lines or lines[0].strip() != "---":
            return None, "missing YAML frontmatter"
        fields = {}
        i = 1
        while i < len(lines):
            line = lines[i]
            if line.strip() == "---":
                return fields, None
            if ":" not in line:
                i += 1
                continue
            key, value = line.split(":", 1)
            value = value.strip().strip('"').strip("'")
            if value in (">", "|"):
                folded = []
                i += 1
                while i < len(lines):
                    next_line = lines[i]
                    if next_line.strip() == "---":
                        i -= 1
                        break
                    if next_line and not next_line.startswith((" ", "\t")):
                        i -= 1
                        break
                    if next_line.strip():
                        folded.append(next_line.strip())
                    i += 1
                value = " ".join(folded)
            fields[key.strip()] = value
            i += 1
        return None, "unterminated YAML frontmatter"

    for skill in manifest.get("skills", []):
        if not skill_name_re.fullmatch(skill["name"]):
            errors.append(f"{skill['name']}: catalog name violates Agent Skills naming rules")

        if skill.get("trust") == "external-experimental":
            warnings.append(f"{skill['name']}: external-experimental trust; explicit invocation only")

        if not skill.get("managed"):
            warnings.append(f"{skill['name']}: runtime-owned; catalog does not render files")
            continue

        for rel in skill.get("renderedSkillFiles", []):
            path = os.path.join(home, rel)
            if not os.path.isfile(path):
                errors.append(f"{skill['name']}: missing {path}")
                continue

            fields, error = parse_frontmatter(path)
            if error:
                errors.append(f"{skill['name']}: {path}: {error}")
                continue

            actual_name = fields.get("name", "").strip()
            description = fields.get("description", "").strip()
            if not actual_name:
                errors.append(f"{skill['name']}: {path}: missing frontmatter name")
            elif not skill_name_re.fullmatch(actual_name):
                errors.append(f"{skill['name']}: {path}: frontmatter name violates Agent Skills naming rules")
            elif actual_name != skill["name"]:
                errors.append(f"{skill['name']}: {path}: frontmatter name is {actual_name!r}")
            if not description:
                errors.append(f"{skill['name']}: {path}: missing frontmatter description")
            elif len(description) < 20:
                warnings.append(f"{skill['name']}: description is very short")
            elif len(description) > 1024:
                errors.append(f"{skill['name']}: description exceeds 1024 chars")

    if warnings:
        print("Warnings:")
        for warning in warnings:
            print(f"  warning: {warning}")

    if errors:
        print("Errors:", file=sys.stderr)
        for error in errors:
            print(f"  error: {error}", file=sys.stderr)
        raise SystemExit(1)

    print("agent-catalog-check: ok")
  '';

  agentCatalogCheckScript = pkgs.writeShellScriptBin "agent-catalog-check" ''
    set -euo pipefail

    manifest="$HOME/${manifestPath}"
    if [ ! -f "$manifest" ]; then
      echo "error: missing $manifest (apply Home Manager first)" >&2
      exit 1
    fi

    ${pkgs.jq}/bin/jq empty "$manifest"

    ${pkgs.python3}/bin/python3 ${checkPython} "$manifest" "$HOME"
  '';

  agentCatalogStatusScript = pkgs.writeShellScriptBin "agent-catalog-status" ''
    set -euo pipefail

    manifest="$HOME/${manifestPath}"
    if [ ! -f "$manifest" ]; then
      echo "missing $manifest (apply Home Manager first)"
      exit 1
    fi

    jq=${pkgs.jq}/bin/jq
    "$jq" empty "$manifest"

    echo "Agent catalog: $manifest"
    if [ "$("$jq" -r '.enabled' "$manifest")" != "true" ]; then
      echo "  disabled"
      exit 0
    fi

    echo
    echo "Enabled targets:"
    "$jq" -r '.enabledTargets[]? | "  " + .' "$manifest"

    echo
    echo "Skills by target:"
    while IFS= read -r target; do
      managed="$("$jq" --arg target "$target" '[.skills[] | select(.managed and (.targets | index($target)))] | length' "$manifest")"
      runtime="$("$jq" --arg target "$target" '[.skills[] | select((.managed | not) and (.targets | index($target)))] | length' "$manifest")"
      echo "  $target: $managed managed, $runtime runtime-owned"
    done < <("$jq" -r '.enabledTargets[]?' "$manifest")

    echo
    echo "Rendered skill files:"
    missing=0
    while IFS= read -r rel; do
      if [ -f "$HOME/$rel" ]; then
        echo "  ok      $HOME/$rel"
      else
        echo "  missing $HOME/$rel"
        missing=1
      fi
    done < <("$jq" -r '.skills[] | select(.managed) | .renderedSkillFiles[]?' "$manifest")
    if [ "$missing" = "1" ]; then
      echo "  run: home-manager switch"
    fi

    echo
    echo "Trust summary:"
    "$jq" -r '.skills | group_by(.trust)[]? | "  " + .[0].trust + ": " + (length | tostring)' "$manifest"

    echo
    echo "Roles by target (declared, not rendered in first slice):"
    "$jq" -r '.roleCountsByTarget | to_entries[] | "  " + .key + ": " + (.value | tostring)' "$manifest"

    echo
    echo "Plugins by target (declared, not rendered in first slice):"
    "$jq" -r '.pluginCountsByTarget | to_entries[] | "  " + .key + ": " + (.value | tostring)' "$manifest"

    echo
    echo "Runtime-owned catalog entries:"
    "$jq" -r '.skills[] | select(.managed | not) | "  " + .name + " (" + .owner + ")"' "$manifest"

    echo
    echo "Duplicate catalog names: n/a (Nix attrset keys enforce uniqueness)"
  '';
in
{
  home.file = lib.mkIf catalogEnabled (
    builtins.listToAttrs managedSkillEntries
    // builtins.listToAttrs [
      {
        name = manifestPath;
        value.text = manifestJson;
      }
    ]
  );

  home.packages = lib.optionals catalogEnabled [
    agentCatalogCheckScript
    agentCatalogStatusScript
  ];
}
