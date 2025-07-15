{ pkgs, lib, ... }: {
  
  # OpenCommit initial configuration (only sets defaults if not already configured)
  home.activation.opencommitConfig = lib.hm.dag.entryAfter ["writeBoundary"] ''
    # Configure OpenCommit for local ollama usage with conventional commits
    $DRY_RUN_CMD ${pkgs.opencommit}/bin/opencommit config set OCO_API_URL=http://127.0.0.1:11434/v1
    $DRY_RUN_CMD ${pkgs.opencommit}/bin/opencommit config set OCO_API_KEY=ollama
    $DRY_RUN_CMD ${pkgs.opencommit}/bin/opencommit config set OCO_TOKENS_MAX_INPUT=32768
    $DRY_RUN_CMD ${pkgs.opencommit}/bin/opencommit config set OCO_TOKENS_MAX_OUTPUT=300
    $DRY_RUN_CMD ${pkgs.opencommit}/bin/opencommit config set OCO_DESCRIPTION=false
    $DRY_RUN_CMD ${pkgs.opencommit}/bin/opencommit config set OCO_EMOJI=false
    $DRY_RUN_CMD ${pkgs.opencommit}/bin/opencommit config set OCO_LANGUAGE=en
    $DRY_RUN_CMD ${pkgs.opencommit}/bin/opencommit config set OCO_GITPUSH=false
    $DRY_RUN_CMD ${pkgs.opencommit}/bin/opencommit config set OCO_ONE_LINE_COMMIT=true
    $DRY_RUN_CMD ${pkgs.opencommit}/bin/opencommit config set OCO_PROMPT_MODULE=conventional-commit
    
    # Only set default model if not already configured
    if ! ${pkgs.opencommit}/bin/opencommit config get OCO_MODEL >/dev/null 2>&1; then
      $DRY_RUN_CMD ${pkgs.opencommit}/bin/opencommit config set OCO_MODEL=tavernari/git-commit-message:latest
    fi
  '';
  
  # Environment variables for dynamic model switching
  home.sessionVariables = {
    OCO_DEFAULT_MODEL = "tavernari/git-commit-message:latest";
  };
  
  # Simple aliases for opencommit usage
  home.shellAliases = {
    # Main commands - OpenCommit with native conventional commits
    "oco" = "opencommit";
    
    # Jira integration
    "oco-jira" = "oco-jira-commit";
    "oco-ticket" = "oco-jira-commit";
    
    # Quick commit types (conventional)
    "oco-feat" = "opencommit --context='feat: feature implementation'";
    "oco-fix" = "opencommit --context='fix: bug fix'";
    "oco-docs" = "opencommit --context='docs: documentation update'";
    "oco-refactor" = "opencommit --context='refactor: code refactoring'";
    "oco-test" = "opencommit --context='test: testing changes'";
    "oco-chore" = "opencommit --context='chore: maintenance task'";
    
    # Configuration
    "oco-config" = "opencommit config";
    "oco-status" = "opencommit config get";
  };
  
  # Essential scripts only
  home.packages = with pkgs; [
    # Simple health check
    (writeShellScriptBin "oco-check" ''
      #!/usr/bin/env bash
      
      echo "🔍 OpenCommit Health Check"
      echo ""
      
      # Check ollama service
      if curl -s http://127.0.0.1:11434/api/tags >/dev/null 2>&1; then
        echo "✅ Ollama: Running"
        
        # Check model
        model=$(opencommit config get OCO_MODEL 2>/dev/null | grep "OCO_MODEL=" | cut -d'=' -f2 || echo "qwen3:8b")
        if curl -s http://127.0.0.1:11434/api/tags | ${jq}/bin/jq -r '.models[]?.name' | grep -q "^$model$"; then
          echo "✅ Model: $model available"
        else
          echo "⚠️  Model: $model not found"
          echo "💡 Run: ollama pull $model"
        fi
      else
        echo "❌ Ollama: Not running"
        echo "💡 Run: launchctl start org.nixos.ollama"
      fi
      
      # Check git repo
      if git rev-parse --git-dir >/dev/null 2>&1; then
        echo "✅ Git: Repository detected"
        if git diff --cached --quiet; then
          echo "ℹ️  Staged: No changes (run 'git add .' first)"
        else
          echo "✅ Staged: Ready for commit"
        fi
      else
        echo "ℹ️  Git: Not in repository"
      fi
    '')
    
    # Enhanced model switcher with persistence - Updated for Qwen3
    (writeShellScriptBin "oco-model" ''
      #!/usr/bin/env bash
      
      declare -A models=(
        # Model sizes from smallest/fastest to largest/slowest
        ["xs"]="mistral:7b"                                     # 1.31s - Extra small, fastest
        ["s"]="llama3.2:latest"                                 # 1.91s - Small, fast
        ["m"]="tavernari/git-commit-message:latest"             # 1.96s - Medium, specialized (DEFAULT)
        ["l"]="gemma3:4b"                                       # 4.47s - Large, balanced
        ["xl"]="devstral:24b"                                   # 5.04s - Extra large, code-focused
        ["xxl"]="gemma3:12b"                                    # 10.26s - Extra extra large, detailed
        ["xxxl"]="gemma3:27b"                                   # 17.29s - Maximum size, comprehensive
      )
      
      if [ $# -eq 0 ]; then
        current=$(opencommit config get OCO_MODEL 2>/dev/null | grep "OCO_MODEL=" | cut -d'=' -f2 || echo "''${OCO_DEFAULT_MODEL:-not set}")
        echo "🤖 Current model: $current"
        echo "🏠 Default model: ''${OCO_DEFAULT_MODEL:-tavernari/git-commit-message:latest}"
        echo ""
        echo "Available model sizes (benchmark results):"
        echo ""
        echo "⚡ Fast Models (< 2s):"
        echo "  xs: mistral:7b (1.31s) - Extra small, fastest"
        echo "  s: llama3.2:latest (1.91s) - Small, fast"
        echo "  m: tavernari/git-commit-message:latest (1.96s) - Medium, specialized ⭐ DEFAULT"
        echo ""
        echo "✅ Medium Models (2-6s):"
        echo "  l: gemma3:4b (4.47s) - Large, balanced"
        echo "  xl: devstral:24b (5.04s) - Extra large, code-focused"
        echo ""
        echo "🐌 Large Models (>10s) - High capability, slow response:"
        echo "  xxl: gemma3:12b (10.26s) - Extra extra large, detailed"
        echo "  xxxl: gemma3:27b (17.29s) - Maximum size, comprehensive"
        echo ""
        echo "Usage:"
        echo "  oco-model <size>    - Switch to model size (xs/s/m/l/xl/xxl/xxxl)"
        echo "  oco-model default   - Switch to default model (alias for 'm')"
        echo "  oco-model reset     - Reset to default model"
        echo "  oco-model status    - Show current configuration"
        exit 0
      fi
      
      case "$1" in
        "reset")
          default_model="''${OCO_DEFAULT_MODEL:-tavernari/git-commit-message:latest}"
          echo "🔄 Resetting to default model: $default_model"
          opencommit config set OCO_MODEL="$default_model"
          echo "✅ Reset to default model"
          ;;
        "status")
          current=$(opencommit config get OCO_MODEL 2>/dev/null | grep "OCO_MODEL=" | cut -d'=' -f2 || echo "not set")
          echo "🤖 Current model: $current"
          echo "🏠 Default model: ''${OCO_DEFAULT_MODEL:-tavernari/git-commit-message:latest}"
          
          # Check if model is available
          if curl -s http://127.0.0.1:11434/api/tags | ${jq}/bin/jq -r '.models[]?.name' | grep -q "^$current$"; then
            echo "✅ Model status: Available"
          else
            echo "⚠️  Model status: Not downloaded"
            echo "💡 Run: ollama pull $current"
          fi
          ;;
        *)
          preset="$1"
          
          # Handle aliases
          case "$preset" in
            "default")
              preset="m"
              ;;
          esac
          
          if [[ -n "''${models[$preset]}" ]]; then
            model="''${models[$preset]}"
            echo "🔄 Switching to $preset model: $model"
            
            # Pull model if needed
            if ! curl -s http://127.0.0.1:11434/api/tags | ${jq}/bin/jq -r '.models[]?.name' | grep -q "^$model$"; then
              echo "📦 Downloading model..."
              ollama pull "$model" || {
                echo "❌ Failed to download model"
                exit 1
              }
            fi
            
            # Update config
            opencommit config set OCO_MODEL="$model"
            echo "✅ Model switched to: $model"
            echo "💡 This setting persists across system rebuilds"
          else
            echo "❌ Unknown preset: $preset"
            echo "Available sizes: xs s m l xl xxl xxxl"
            echo "Aliases: default (→ m)"
            echo "Commands: reset status"
          fi
          ;;
      esac
    '')
    
    # Jira integration - Simple context-based approach
    (writeShellScriptBin "oco-jira-commit" ''
      #!/usr/bin/env bash
      
      echo "🎫 OpenCommit with Jira Integration"
      echo ""
      
      # Get current branch
      branch=$(git rev-parse --abbrev-ref HEAD)
      echo "📋 Current branch: $branch"
      
      # Extract Jira ticket from branch name (flexible patterns)
      # Supports: task/ABC-1234, feature/PROJ-123-description, PROJ-123-description, etc.
      jira_ticket=$(echo "$branch" | grep -oE '[A-Z]+-[0-9]+' | head -1)
      
      if [[ -n "$jira_ticket" ]]; then
        echo "🎫 Found ticket: $jira_ticket"
        echo "🤖 Running OpenCommit with Jira context..."
        echo ""
        
        # Quick pre-check
        if ! curl -s http://127.0.0.1:11434/api/tags >/dev/null 2>&1; then
          echo "❌ Ollama not running"
          echo "💡 Start with: launchctl start org.nixos.ollama"
          exit 1
        fi
        
        # Use OpenCommit's command-line template feature directly
        echo "🤖 Running OpenCommit with Jira template..."
        
        # Use the documented command-line template syntax: oco 'PROJ-123 - $msg'
        opencommit "$jira_ticket - \$msg"
      else
        echo "❌ No Jira ticket in branch: $branch"
        echo ""
        echo "💡 Supported formats:"
        echo "   • task/ABC-1234"
        echo "   • feature/PROJ-123-description"
        echo "   • PROJ-123-description"
        echo "   • bugfix/TEAM-456-fix"
        echo "   • any-branch-with-TICKET-123-anywhere"
        echo ""
        echo "💡 Or use regular commit: oco"
      fi
    '')
    
    # Simple setup script
    (writeShellScriptBin "opencommit-setup" ''
      #!/usr/bin/env bash
      
      echo "🔧 OpenCommit Setup"
      echo ""
      
      # Check ollama
      if ! curl -s http://127.0.0.1:11434/api/tags >/dev/null 2>&1; then
        echo "❌ Ollama not running"
        echo "💡 Start with: launchctl start org.nixos.ollama"
        exit 1
      fi
      
      # Check/pull model
      model="tavernari/git-commit-message:latest"
      if ! curl -s http://127.0.0.1:11434/api/tags | ${jq}/bin/jq -r '.models[]?.name' | grep -q "^$model$"; then
        echo "📦 Pulling model: $model"
        ollama pull "$model" || exit 1
      fi
      
      echo "✅ Setup complete!"
      echo ""
      echo "📖 Usage:"
      echo "   1. Stage changes: git add ."
      echo "   2. Generate commit: oco"
      echo "   3. Jira integration: oco-jira"
      echo ""
      echo "🔧 Commands:"
      echo "   • oco-check    - Health check"
      echo "   • oco-model    - Switch models"
      echo "   • oco-config   - View config"
    '')
  ];
} 