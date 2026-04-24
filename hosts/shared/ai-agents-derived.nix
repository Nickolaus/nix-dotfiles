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

  needsLocalCoding =
    cfg.targets.codex.enable
    || cfg.targets.claude.enable
    || cfg.codex.managed.enable
    || cfg.claude.managed.enable;
in
{
  config = mkIf cfg.enable (mkMerge [
    (mkIf needsLocalCoding {
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
    })
    (mkIf (localAiConfig != null) {
      aiAgents.localCoding = {
        openaiBaseUrl =
          "${if localAiConfig.runtime.sessionProxy.enable then localAiConfig.sessionEndpoint else localAiConfig.codingEndpoint}/v1";
        anthropicBaseUrl =
          if localAiConfig.runtime.sessionProxy.enable then localAiConfig.sessionEndpoint else localAiConfig.codingEndpoint;
        model = localAiConfig.profiles.coding.model;
      };
    })
  ]);
}
