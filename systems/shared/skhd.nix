{ pkgs
, lib
, inputs
, config
, ...
}: {
  services.skhd = {
    enable = true;
    package = pkgs.skhd;
    skhdConfig = ''
      :: default : yabai -m config active_window_opacity 1; yabai -m config normal_window_opacity 1;

      lalt - e : yabai -m space --layout bsp
      lalt - s : yabai -m space --layout stack

      lalt - left  : yabai -m window --focus west
      lalt - down  : yabai -m window --focus south
      lalt - up    : yabai -m window --focus north
      lalt - right : yabai -m window --focus east


      lalt + shift - left : yabai -m window --warp west
      lalt + shift - right : yabai -m window --warp east
      lalt + shift - up : yabai -m window --warp north
      lalt + shift - down : yabai -m window --warp south

      lalt - h : yabai -m window --toggle bsp
      lalt - v : yabai -m window --toggle split

      lalt - 1 : yabai -m space --focus 1
      lalt - 2 : yabai -m space --focus 2
      lalt - 3 : yabai -m space --focus 3
      lalt - 4 : yabai -m space --focus 4
      lalt - 5 : yabai -m space --focus 5
      lalt - 6 : yabai -m space --focus 6
      lalt - 7 : yabai -m space --focus 7
      lalt - 8 : yabai -m space --focus 8
      lalt - 9 : yabai -m space --focus 9
      lalt - 0 : yabai -m space --focus 10

      lalt + shift - 1 : yabai -m window --space 1 && yabai -m space --focus 1
      lalt + shift - 2 : yabai -m window --space 2 && yabai -m space --focus 2
      lalt + shift - 3 : yabai -m window --space 3 && yabai -m space --focus 3
      lalt + shift - 4 : yabai -m window --space 4 && yabai -m space --focus 4
      lalt + shift - 5 : yabai -m window --space 5 && yabai -m space --focus 5
      lalt + shift - 6 : yabai -m window --space 6 && yabai -m space --focus 6

      lalt - f : yabai -m window --toggle float
      lalt + shift - q : yabai -m window --close

      lalt - return : open -na alacritty
      lalt - b : open -na /Applications/Google\ Chrome.app/

      lalt - l : pmset displaysleepnow

      # tilde like in linux
      rctrl - 0x1E : skhd -k "alt - n"

      # pipe like in linux
      rctrl - 0x32 : skhd -t "|"

      # @ like in linux
      rctrl - q : skhd -t "@"

      # curly brackets
      rctrl - 7 : skhd -t "{"
      rctrl - 8 : skhd -t "}"

      # backslash
      rctrl - 0x1B : skhd -t "\"


      # defines a new mode 'resize' with an on_enter command, that captures keypresses
      :: resize @ : yabai -m config active_window_opacity 1; yabai -m config normal_window_opacity 0.9;

      # from 'default' mode, activate mode 'resize'
      # (this is the key combination you want to use to enter resize mode)
      lalt - r ; resize 

      # from 'resize' mode, activate mode 'default'
      # (this is the keypress required to leave resize mode)
      resize < escape ; default

      # equalize windows
      resize < ctrl - 0 : yabai -m space --balance

      # increase window size
      resize < left : yabai -m window --resize left:-25:0
      resize < down : yabai -m window --resize top:0:25
      resize < up : yabai -m window --resize top:0:-25
      resize < right : yabai -m window --resize left:25:0


      # decrease window size
      resize < alt - right : yabai -m window --resize left:25:0
      resize < alt - up : yabai -m window --resize bottom:0:-25
      resize < alt - down : yabai -m window --resize top:0:25
      resize < alt - left : yabai -m window --resize right:-25:0
    '';
  };
}