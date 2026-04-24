{ pkgs, ... }: {

  home.packages = with pkgs; [
    fzf
    fd
    bat
    lazygit
    delta
    bottom
    duf
    dust
    just
    watchexec
    hyperfine
    tree
    tldr
    commitizen
    opencommit
    (ast-grep.overrideAttrs (old: { doCheck = false; }))
  ];

  programs.direnv = {
    enable = true;
    package = pkgs.direnv.overrideAttrs (_: {
      doCheck = false;
    });
    nix-direnv.enable = true;
  };

  programs.fish = {
    enable = true;

    # Custom abbreviations for productivity
    shellAbbrs = {
      # 🐳 Docker & Containers
      "d" = "docker";
      "dc" = "docker-compose";
      "dps" = "docker ps";
      "di" = "docker images";
      "dcup" = "docker-compose up -d";
      "dcdown" = "docker-compose down";
      
      # ☸️ Kubernetes  
      "kc" = "kubectl";
      "kgp" = "kubectl get pods";
      "kgs" = "kubectl get services";
      "kgd" = "kubectl get deployments";
      "kdp" = "kubectl describe pod";
      "kl" = "kubectl logs";
      
      # 📁 File operations
      "la" = "eza -la --icons";
      "lt" = "eza --tree --icons";
      "lz" = "eza -la --icons | head -20";
      
      # 🔍 Search & Find
      "rg" = "rg --color=always";
      "fd" = "fd --color=always";
      "bat" = "bat --style=numbers,changes";
      
      # 📦 Package Management
      "nr" = "nix-rebuild";
      "ns" = "nix search nixpkgs";
      "nsh" = "nix-shell";
      "nb" = "nix build";
      
      # ☁️ AWS Profile Management
      "awsw" = "aws-whoami";
      
      # 🚀 Development
      "vim" = "nvim";
      "v" = "nvim";
      "lg" = "lazygit";
      "t" = "tmux";
      "ta" = "tmux attach";
      "tn" = "tmux new-session";
      
      # 🌐 Network & System
      "ping" = "ping -c 4";
      "ports" = "netstat -tuln";
      "myip" = "curl -s ifconfig.me";
      "speed" = "speedtest-cli";
      
      # 📊 System monitoring
      "btm" = "btm --color always";
      "htop" = "btm";
      "df" = "duf";
      "du" = "dust";
      "ps" = "procs";
    };

    interactiveShellInit = ''
      set fish_greeting # Disable greeting

      # Overwrite default ctrl+r history-pager
      fzf_configure_bindings
      
      # Configure fish-abbreviation-tips plugin
      set -U ABBR_TIPS_PROMPT "\n💡 \e[1;36m{{ .abbr }}\e[0m \e[2m=>\e[0m \e[32m{{ .cmd }}\e[0m"
      set -U ABBR_TIPS_REGEXES \
        '(^(\w+\s+)+(-{1,2})\w+)(\s\S+)' \
        '(^( ?\w+){3}).*' \
        '(^( ?\w+){2}).*' \
        '(^( ?\w+){1}).*'
      
      # Configure sponge to keep git commit commands in history even when pre-commit hooks fail
      # This allows commit messages to remain accessible for retry after fixing hook failures
      set -U sponge_regex_patterns '^git\s+commit.*'
      
      # 📂 Dynamic multi-dot navigation: automatically handle any number of dots
      # Override Fish's command-not-found handler to catch dot patterns
      function __fish_command_not_found_handler --on-event fish_command_not_found
          set -l cmd $argv[1]
          
          # Check if command is only dots (3 or more)
          if string match -qr '^\.{3,}$' -- "$cmd"
              # Count the dots and calculate levels to go up
              set -l dot_count (string length "$cmd")
              set -l levels (math $dot_count - 1)
              
              # Build the cd command
              set -l path_parts ""
              for i in (seq $levels)
                  set path_parts "$path_parts../"
              end
              
              # Execute the cd command
              echo "📂 Going up $levels levels..."
              cd $path_parts
              commandline -f repaint
              return 0
          end
          
          # If not a dot pattern, let other handlers deal with it
          return 1
      end
      
      # 🎨 Create minimal wrapper functions to prevent red highlighting
      # These are ultra-lightweight functions that just call our handler
      # Fish will recognize them as valid commands (no red highlighting)
      # Cover 3-20 dots (covers 99% of realistic use cases)
      for i in (seq 3 20)
          set -l dots (string repeat -n $i .)
          eval "function $dots
              __fish_command_not_found_handler $dots
          end"
      end
    '';

    # workaround for fixing the path order: https://github.com/LnL7/nix-darwin/issues/122
    shellInit = ''
      # Volta
      set -gx VOLTA_HOME $HOME/.volta
      fish_add_path $VOLTA_HOME/bin

      # Go Binaries
      fish_add_path $GOPATH/bin

      # Cargo
      fish_add_path $HOME/.cargo/bin
    '';

    plugins = [
      # 🔍 Enhanced fuzzy finding and file navigation
      { name = "fzf"; src = pkgs.fishPlugins.fzf-fish.src; }
      
      # 🧠 Auto-completion and productivity
      { name = "autopair"; src = pkgs.fishPlugins.autopair.src; }        # Auto-close parentheses, quotes, etc.
      { name = "sponge"; src = pkgs.fishPlugins.sponge.src; }            # Remove failed commands from history
      
      # 🎨 Better command output and experience  
      { name = "colored-man-pages"; src = pkgs.fishPlugins.colored-man-pages.src; } # Colorized man pages
      
      # 🔧 Git workflow enhancement
      { name = "forgit"; src = pkgs.fishPlugins.forgit.src; }            # Interactive git commands using fzf
      { name = "plugin-git"; src = pkgs.fishPlugins.plugin-git.src; }    # Git aliases and functions
      
      # 🚀 Shell environment and compatibility
      { name = "bass"; src = pkgs.fishPlugins.bass.src; }                # Run bash utilities in fish shell
      { name = "foreign-env"; src = pkgs.fishPlugins.foreign-env.src; }  # Source bash scripts in fish
      
      # 💡 Smart command suggestions
      { name = "pisces"; src = pkgs.fishPlugins.pisces.src; }            # Auto-matching quotes, brackets, etc.
      
      # 🧠 Learning and productivity aids
      { 
        name = "fish-abbreviation-tips"; 
        src = pkgs.fetchFromGitHub {
          owner = "Gazorby";
          repo = "fish-abbreviation-tips";
          rev = "v0.7.0";
          sha256 = "sha256-F1t81VliD+v6WEWqj1c1ehFBXzqLyumx5vV46s/FZRU=";
        };
      }
    ];

    functions = {
      c = ''
        set DIR (zoxide query -l | fzf)
        z $DIR
      '';
      t = ''
        tmux attach -t "$(tmux ls -F '#{session_name}:#{window_name}' | fzf)"
      '';
      # 🔄 AWS Profile Management Functions
      awsx = ''
        if test -z $AWS_PROFILES
            set -gx AWS_PROFILES (aws configure list-profiles 2>/dev/null | string split \n)
        end

        if test (count $AWS_PROFILES) -eq 0
            echo "❌ No AWS profiles found. Configure profiles with 'aws configure sso'"
            return 1
        end

        set selected_profile (printf '%s\n' $AWS_PROFILES | fzf --height=15 --prompt="🔧 Select AWS Profile: " --preview="echo 'Profile: {}'" --preview-window=up:2)
        
        if test -n "$selected_profile"
            set -gx AWS_PROFILE "$selected_profile"
            echo "✅ Using AWS profile: $AWS_PROFILE"
            _aws_validate_session
        else
            echo "❌ No profile selected"
            return 1
        end
      '';

      # Show current AWS profile and identity
      aws-whoami = ''
        if test -n "$AWS_PROFILE"
            echo "🔧 Current AWS Profile: $AWS_PROFILE"
            echo "📋 Identity Information:"
            aws sts get-caller-identity --output table 2>/dev/null || echo "❌ Unable to get identity (session may be expired)"
        else
            echo "❌ No AWS profile currently set. Use 'awsx' to select one."
        end
      '';

      # Internal helper function for session validation
      _aws_validate_session = ''
        echo "🔍 Validating AWS session..."
        aws sts get-caller-identity &> /dev/null
        if test $status != 0
            echo "⚠️  AWS SSO session expired or invalid. Attempting to login..."
            aws sso login --profile $AWS_PROFILE
            if test $status -eq 0
                echo "✅ Successfully authenticated!"
                aws sts get-caller-identity --output table
            else
                echo "❌ Authentication failed for profile: $AWS_PROFILE"
            end
        else
            echo "✅ Valid AWS session found!"
            aws sts get-caller-identity --query "Account" --output text | read -l account_id
            echo "📊 Account ID: $account_id"
        end
      '';
      
      # 🔍 Find unmerged remote branches by author
      gunmerged = ''
        # Default to current git user if no argument provided
        set author_filter $argv[1]
        if test -z "$author_filter"
            set author_filter (git config user.name)
        end
        
        echo "🔍 Searching for unmerged branches by: $author_filter"
        
        for b in (git branch -r --no-merged | grep 'origin/' | string trim)
            set info (git log -1 --pretty=format:'%ci | %an' $b)
            echo "$info | $b"
        end | grep -i "$author_filter" | sort -t '|' -k2,2 -k1,1r
      '';
    };
  };

  programs.starship = {
    enable = true;

    settings = {
      aws = {
        disabled = false;
        format = "[$symbol($profile )($region )]($style)";
        symbol = "☁️ ";
        style = "bold yellow";
      };
      gcloud.disabled = true;
      git_status.disabled = true;
      command_timeout = 1500;
    };
  };

  programs.zoxide = {
    enable = true;
    enableFishIntegration = true;
  };

  programs.eza = {
    enable = true;
    enableFishIntegration = true;
  };

  programs.mise = {
    enable = true;
    package = pkgs.mise.overrideAttrs (_: {
      doCheck = false;
    });
    enableFishIntegration = true;
    globalConfig.settings = {
      experimental = true;
    };
  };

  home.shellAliases = {
    "cat" = "bat -pp";
    "k" = "kubectl";
    "ll" = "eza --icons --group --group-directories-first -l";
    # New CLI tool shortcuts
    "tree" = "broot --height 20";               # Interactive directory navigator
    "json" = "jless";                           # Interactive JSON viewer
    "cut" = "choose";                           # Human-friendly cut replacement
    "dig" = "dog";                              # Modern DNS lookup (doggo)
    "curl" = "httpie --print=HhBb";             # Modern HTTP client
  };
}
