{
  pkgs,
  ...
}: {
  services.aerospace = {
    enable = true;
    package = pkgs.aerospace;

    settings= {
      enable-normalization-flatten-containers = true;
      enable-normalization-opposite-orientation-for-nested-containers = true;

      on-focused-monitor-changed = ["move-mouse monitor-lazy-center"];
      on-focus-changed = [
        "move-mouse window-lazy-center"
      ];

      automatically-unhide-macos-hidden-apps = false;

      accordion-padding = 30;
      default-root-container-layout = "tiles";
      default-root-container-orientation = "auto";

      gaps = {
        outer.bottom = 10;
        outer.top = 10;
        outer.left = 10;
        outer.right = 10;
        inner.horizontal = 10;
        inner.vertical = 10;
      };

      key-mapping.preset = "qwerty";
      mode.main.binding = {
        alt-1 = "workspace 1";
        alt-2 = "workspace 2";
        alt-3 = "workspace 3";
        alt-4 = "workspace 4";
        alt-5 = "workspace 5";
        alt-6 = "workspace 6";

        alt-shift-1 = ["move-node-to-workspace 1" "workspace 1"];
        alt-shift-2 = ["move-node-to-workspace 2" "workspace 2"];
        alt-shift-3 = ["move-node-to-workspace 3" "workspace 3"];
        alt-shift-4 = ["move-node-to-workspace 4" "workspace 4"];
        alt-shift-5 = ["move-node-to-workspace 5" "workspace 5"];
        alt-shift-6 = ["move-node-to-workspace 6" "workspace 6"];

        alt-left = "focus --boundaries-action wrap-around-the-workspace left";
        alt-right = "focus --boundaries-action wrap-around-the-workspace right";
        alt-up = "focus --boundaries-action wrap-around-the-workspace up";
        alt-down = "focus --boundaries-action wrap-around-the-workspace down";

        alt-shift-left = "move left";
        alt-shift-right = "move right";
        alt-shift-up = "move up";
        alt-shift-down = "move down";

        alt-h = "join-with left";
        alt-v = "join-with up";

        alt-s = "layout v_accordion"; # 'layout stacking' in i4
        alt-w = "layout h_accordion"; # 'layout tabbed' in i3
        alt-e = "layout tiles horizontal vertical"; # 'layout toggle split' in i3

        alt-shift-space = "layout floating tiling"; # 'floating toggle' in i3

        alt-enter = "exec-and-forget open -na WezTerm";
        alt-b = "exec-and-forget open -na \"Google Chrome\" --args --new-window";

        alt-l = "exec-and-forget pmset displaysleepnow";

        alt-shift-q = "close --quit-if-last-window";

        alt-r = "mode resize";
      };

      mode.resize.binding = {
        left = "resize width +50";
        right = "resize width -50";
        up = "resize height +50";
        down = "resize height -50";
        enter = "mode main";
        esc = "mode main";
      };
    };
  };
}