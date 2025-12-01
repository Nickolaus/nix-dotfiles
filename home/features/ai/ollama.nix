{ pkgs, lib, ... }: {
  
  # Enable ollama service for local LLM hosting
  # Temporarily disabled due to build failure in nixpkgs
  services.ollama = {
    enable = false;
    package = pkgs.ollama;
    
    # Configure network settings
    host = "127.0.0.1";  # localhost only for security
    port = 11434;        # default ollama port
    
    # Set up environment variables for optimal performance
    environmentVariables = {
      # Maximize performance for local development
      OLLAMA_NUM_PARALLEL = "4";          # Allow multiple parallel requests
      OLLAMA_MAX_LOADED_MODELS = "3";     # Allow 3 models in memory (increased for new models)
      OLLAMA_FLASH_ATTENTION = "1";       # Enable flash attention for speed
      
      # CPU optimization
      OLLAMA_NUM_THREADS = "0";           # Use all available CPU cores (0 = auto-detect)
      OLLAMA_MAX_VRAM = "0";              # Don't limit VRAM usage
      
      # Performance tuning
      OLLAMA_KEEP_ALIVE = "5m";           # Keep models loaded for 5 minutes
      OLLAMA_NOPRUNE = "false";           # Allow pruning old models
      
      # Enable logging for debugging if needed
      OLLAMA_DEBUG = "0";  # Set to "1" for debugging
    };
    
    # Hardware acceleration detection
    acceleration = 
      if pkgs.stdenv.isDarwin then false  # macOS: use CPU for stability
      else if pkgs.config.cudaSupport or false then "cuda"
      else if pkgs.config.rocmSupport or false then "rocm" 
      else false;
  };
  
  # Add helpful aliases for ollama management
  home.shellAliases = {
    # Model management
    "ollama-pull" = "ollama pull";
    "ollama-list" = "ollama list";
    "ollama-rm" = "ollama rm";
    
    # Quick model pulls for development - Updated to Qwen3
    "ollama-setup-minimal" = "ollama pull qwen3:8b";              # Primary model (5.2GB)
    "ollama-setup-advanced" = "ollama pull qwen3:14b";            # Advanced model (9.3GB)
    "ollama-setup-large" = "ollama pull qwen3:32b-q4_K_M";        # Large quantized model (20GB)
    "ollama-setup-all" = "ollama pull qwen3:8b && ollama pull qwen3:14b && ollama pull qwen3:32b-q4_K_M";  # All three models
    "ollama-setup-opencommit" = "ollama pull qwen3:8b";           # Best balance for commit messages
    
    # Service management
    "ollama-status" = "ollama ps";
    "ollama-stop" = "ollama stop";
  };
  
  # Create a simple script to check if ollama is running and ready
  home.packages = with pkgs; [
    (writeShellScriptBin "ollama-health" ''
      #!/usr/bin/env bash
      
      echo "🔍 Checking ollama service status..."
      
      # Check if service is running
      if curl -s http://127.0.0.1:11434/api/tags >/dev/null 2>&1; then
        echo "✅ Ollama service is running on http://127.0.0.1:11434"
        
        # Show performance info
        echo ""
        echo "⚡ Performance Status:"
        
        # Check loaded models
        loaded_models=$(curl -s http://127.0.0.1:11434/api/ps 2>/dev/null)
        if [[ -n "$loaded_models" ]]; then
          echo "🧠 Loaded models:"
          echo "$loaded_models" | ${jq}/bin/jq -r '.models[]? | "   • \(.name) - \(.details.parameter_size) params"' 2>/dev/null || echo "   (none currently loaded)"
        fi
        
        # Show available models
        echo ""
        echo "📚 Available models:"
        curl -s http://127.0.0.1:11434/api/tags | ${jq}/bin/jq -r '.models[]? | "   📦 \(.name) (\(.size / 1024 / 1024 / 1024 | floor)GB)"' 2>/dev/null || echo "   No models found - run 'ollama pull <model-name>' to download models"
        
        # Show resource usage
        echo ""
        echo "💻 Resource Usage:"
        if command -v pgrep >/dev/null; then
          ollama_pid=$(pgrep -x ollama)
          if [[ -n "$ollama_pid" ]]; then
            memory_mb=$(ps -p "$ollama_pid" -o rss= 2>/dev/null | awk '{print int($1/1024)}')
            cpu_percent=$(ps -p "$ollama_pid" -o %cpu= 2>/dev/null | awk '{print $1}')
            echo "   🧮 Memory: ''${memory_mb}MB"
            echo "   🔥 CPU: ''${cpu_percent}%"
            echo "   🔧 PID: $ollama_pid"
          fi
        fi
        
        # Show environment settings
        echo ""
        echo "⚙️  Configuration:"
        echo "   Threads: ''${OLLAMA_NUM_THREADS:-auto}"
        echo "   Parallel: ''${OLLAMA_NUM_PARALLEL:-1}"
        echo "   Max Models: ''${OLLAMA_MAX_LOADED_MODELS:-1}"
        echo "   Keep Alive: ''${OLLAMA_KEEP_ALIVE:-5m}"
        
      else
        echo "❌ Ollama service is not responding"
        echo "💡 Try: 'launchctl restart org.nixos.ollama' or check service logs"
      fi
    '')
    
    (writeShellScriptBin "ollama-setup" ''
      #!/usr/bin/env bash
      
      echo "🚀 Setting up ollama with Qwen3 models for development use..."
      
      # Wait for service to be ready
      echo "⏳ Waiting for ollama service to start..."
      timeout=30
      while ! curl -s http://127.0.0.1:11434/api/tags >/dev/null 2>&1 && [ $timeout -gt 0 ]; do
        sleep 1
        ((timeout--))
      done
      
      if [ $timeout -eq 0 ]; then
        echo "❌ Ollama service failed to start within 30 seconds"
        exit 1
      fi
      
      echo "✅ Ollama service is ready"
      
      # Pull recommended Qwen3 models for development
      echo "📦 Pulling Qwen3 models for coding and commit messages..."
      echo "   This may take a while for the first time..."
      
      # Pull primary model for general use and commit messages
      if ollama pull qwen3:8b; then
        echo "✅ Successfully pulled qwen3:8b (5.2GB - primary model)"
      else
        echo "⚠️  Failed to pull qwen3:8b - you may need to pull it manually later"
      fi
      
      # Ask user if they want to pull additional models
      echo ""
      read -p "📥 Pull qwen3:14b (9.3GB) for advanced tasks? [y/N]: " -n 1 -r
      echo
      if [[ $REPLY =~ ^[Yy]$ ]]; then
        if ollama pull qwen3:14b; then
          echo "✅ Successfully pulled qwen3:14b (9.3GB - advanced model)"
        else
          echo "⚠️  Failed to pull qwen3:14b"
        fi
      fi
      
      echo ""
      read -p "📥 Pull qwen3:32b-q4_K_M (20GB) for complex tasks? [y/N]: " -n 1 -r
      echo
      if [[ $REPLY =~ ^[Yy]$ ]]; then
        if ollama pull qwen3:32b-q4_K_M; then
          echo "✅ Successfully pulled qwen3:32b-q4_K_M (20GB - large quantized model)"
        else
          echo "⚠️  Failed to pull qwen3:32b-q4_K_M"
        fi
      fi
      
      echo ""
      echo "🎉 Setup complete! Available commands:"
      echo ""
      echo "🔧 Management:"
      echo "   • ollama-health     - Check service status"
      echo "   • ollama list       - List downloaded models"
      echo "   • ollama pull <model> - Download additional models"
      echo ""
      echo "🤖 Quick Model Setup:"
      echo "   • ollama-setup-minimal   - Pull qwen3:8b (5.2GB)"
      echo "   • ollama-setup-advanced  - Pull qwen3:14b (9.3GB)"
      echo "   • ollama-setup-large     - Pull qwen3:32b-q4_K_M (20GB)"
      echo "   • ollama-setup-all       - Pull all three models"
      echo ""
      echo "🤖 OpenCommit:"
      echo "   • oco               - Generate commit messages"
      echo "   • oco-check         - Validate configuration"
      echo "   • oco-model         - Switch between model presets"
      echo "   • oco-hook-enable   - Enable git hook integration"
      echo ""
      echo "💡 Try 'oco-model' to see available model presets for different use cases"
    '')

    (writeShellScriptBin "ollama-turbo" ''
      #!/usr/bin/env bash
      
      echo "🚀 Ollama Performance Turbo Mode"
      echo "This will restart ollama with maximum performance settings"
      echo ""
      
      # Stop current ollama service
      echo "🛑 Stopping ollama service..."
      launchctl stop org.nixos.ollama || true
      sleep 2
      
      # Kill any remaining processes
      pkill -f ollama || true
      sleep 1
      
      # Export optimized environment variables for this session
      export OLLAMA_NUM_THREADS=0              # Use all CPU cores
      export OLLAMA_NUM_PARALLEL=4             # Allow 4 parallel requests
      export OLLAMA_MAX_LOADED_MODELS=3        # Keep 3 models in memory (increased for Qwen3)
      export OLLAMA_KEEP_ALIVE=10m             # Keep models loaded longer
      export OLLAMA_FLASH_ATTENTION=1          # Enable flash attention
      export OLLAMA_MAX_VRAM=0                 # Don't limit VRAM
      
      echo "⚡ Starting ollama with turbo settings..."
      echo "   Threads: $OLLAMA_NUM_THREADS (all cores)"
      echo "   Parallel: $OLLAMA_NUM_PARALLEL"
      echo "   Max Models: $OLLAMA_MAX_LOADED_MODELS"
      echo "   Keep Alive: $OLLAMA_KEEP_ALIVE"
      
      # Start ollama service
      launchctl start org.nixos.ollama
      
      # Wait for service to be ready
      echo "⏳ Waiting for service to start..."
      timeout=15
      while ! curl -s http://127.0.0.1:11434/api/tags >/dev/null 2>&1 && [ $timeout -gt 0 ]; do
        sleep 1
        ((timeout--))
      done
      
      if [ $timeout -eq 0 ]; then
        echo "❌ Service failed to start within 15 seconds"
        exit 1
      fi
      
      echo "✅ Ollama turbo mode activated!"
      echo ""
      echo "💡 Test performance with: oco-verbose --dry-run"
      echo "💡 Check status with: ollama-health"
    '')
  ];
} 