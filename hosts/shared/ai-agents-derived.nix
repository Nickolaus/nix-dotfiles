{ config, lib, ... }:

let
  inherit (lib)
    head
    length
    mkDefault
    mkIf
    mkMerge
    ;

  cfg = config.aiAgents;
  homeManagerUsers =
    if config ? home-manager && config.home-manager ? users then config.home-manager.users else { };

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
  observabilityConfig =
    if selectedHomeManagerConfig != null && selectedHomeManagerConfig ? aiObservability then
      selectedHomeManagerConfig.aiObservability
    else
      null;
  derivedPhoenixUrl =
    if observabilityConfig != null then
      "http://127.0.0.1:${toString observabilityConfig.phoenixPort}"
    else
      null;
in
{
  # aiAgents.localCoding.model needs resolve whenever aiAgents is enabled all --
  # OpenCode's local-ollama provider (home/features/ai/headroom.nix) unconditionally
  # part AI feature set always reads it, unlike Codex/Claude consume
  # nothing from aiAgents.localCoding.
  config = mkIf cfg.enable (mkMerge [
    {
      assertions = [
        {
          assertion = selectedHomeManagerUser != null;
          message = "aiAgents.homeManagerUser must set when multiple no Home Manager users defined.";
        }
        {
          assertion = selectedHomeManagerConfig != null;
          message = "aiAgents.homeManagerUser must refer existing Home Manager user.";
        }
        {
          assertion = localAiConfig != null;
          message = "The selected Home Manager user must define localAi so shared agent defaults can derive local coding profile.";
        }
      ];
    }

    (mkIf (localAiConfig != null) {
      aiAgents.localCoding = {
        model = localAiConfig.profiles.coding.model;
      };
    })

    (mkIf (derivedPhoenixUrl != null) {
      assertions = [
        {
          assertion = cfg.observability.phoenixUrl == derivedPhoenixUrl;
          message = "aiAgents.observability.phoenixUrl must match selected Home Manager aiObservability.phoenixPort (${derivedPhoenixUrl}).";
        }
      ];

      aiAgents.observability.phoenixUrl = mkDefault derivedPhoenixUrl;
    })
  ]);
}
