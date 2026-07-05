{ config, lib, ... }:
let
  inherit (lib) head length mkIf mkMerge;

  cfg = config.aiAgents;

  homeManagerUsers =
    if config ? home-manager && config.home-manager ? users then
      config.home-manager.users
    else
      { };

  homeManagerUserNames = builtins.attrNames homeManagerUsers;

  selectedHomeManagerUser =
    if cfg.homeManagerUser != null then
      cfg.homeManagerUser
    else if length homeManagerUserNames == 1 then
      head homeManagerUserNames
    else
      null;

  selectedHomeManagerConfig =
    if selectedHomeManagerUser != null && builtins.hasAttr selectedHomeManagerUser homeManagerUsers then
      homeManagerUsers.${selectedHomeManagerUser}
    else
      null;

  localAiConfig =
    if selectedHomeManagerConfig != null && selectedHomeManagerConfig ? localAi then
      selectedHomeManagerConfig.localAi
    else
      null;
in
{
  # aiAgents.localCoding.model needs to resolve whenever aiAgents is enabled at all --
  # OpenCode's local-ollama provider (home/features/ai/headroom.nix) is unconditionally
  # part of the AI feature set and always reads it, unlike Codex/Claude which consume
  # nothing from aiAgents.localCoding.
  config = mkIf cfg.enable (mkMerge [
    {
      assertions = [
        {
          assertion = selectedHomeManagerUser != null;
          message = "aiAgents.homeManagerUser must be set when multiple or no Home Manager users are defined.";
        }
        {
          assertion = selectedHomeManagerConfig != null;
          message = "aiAgents.homeManagerUser must refer to an existing Home Manager user.";
        }
        {
          assertion = localAiConfig != null;
          message = "The selected Home Manager user must define localAi so shared agent defaults can derive the local coding profile.";
        }
      ];
    }
    (mkIf (localAiConfig != null) {
      aiAgents.localCoding = {
        model = localAiConfig.profiles.coding.model;
      };
    })
  ]);
}
