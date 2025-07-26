# SketchyBar Go Plugins and Tools Makefile
# Builds optimized binaries for macOS (both Intel and Apple Silicon)

# Configuration
BINARY_DIR := bin
PLUGINS_DIR := plugins
TOOLS_DIR := tools
GO_VERSION := 1.21

# True SketchyBar plugins (called by SketchyBar to update items)
PLUGINS := cpu memory network battery volume front_app notifications clock moon_phase weather spotify

# Utility tools (standalone CLI tools for users/scripts)
TOOLS := titlebar config

# All targets to build
ALL_TARGETS := $(PLUGINS) $(TOOLS)

# Build flags for aggressive optimization  
LDFLAGS := -w -s
SIZE_LDFLAGS := $(LDFLAGS) -X main.version= -X main.commit= -X main.date=
BUILD_FLAGS := -ldflags="$(LDFLAGS)" -trimpath
SIZE_FLAGS := -ldflags="$(SIZE_LDFLAGS)" -trimpath -a -gcflags=all=-l -tags=netgo

# UPX compression available through Nix system packages

# Optimization targets
.PHONY: build-optimized build-compressed

# Default target
.PHONY: all
all: clean build

# Compare binary sizes
.PHONY: size-comparison
size-comparison:
	@echo "📊 Binary Size Comparison:"
	@echo "=================================="
	@if [ -d "$(BINARY_DIR)" ]; then \
		total_size=$$(du -ch $(BINARY_DIR)/* 2>/dev/null | tail -1 | cut -f1); \
		echo "Total size: $$total_size"; \
		echo ""; \
		echo "Individual binaries:"; \
		ls -lah $(BINARY_DIR)/ | grep -v "^d" | awk '{printf "%-15s %8s\n", $$9, $$5}' | sort; \
	else \
		echo "No binaries found. Run 'make build' first."; \
	fi

# Clean build artifacts
.PHONY: clean
clean:
	@echo "🧹 Cleaning build artifacts..."
	@rm -rf $(BINARY_DIR)

# Create build directory
$(BINARY_DIR):
	@mkdir -p $(BINARY_DIR)

# Build all plugins and tools
.PHONY: build
build: $(BINARY_DIR) build-plugins build-tools

# Build with aggressive size optimization
.PHONY: build-optimized
build-optimized: $(BINARY_DIR)
	@echo "🎯 Building size-optimized binaries..."
	@for plugin in $(PLUGINS); do \
		if [ -d "$(PLUGINS_DIR)/$$plugin" ]; then \
			echo "🔌 Building $$plugin plugin (optimized)..."; \
			cd $(PLUGINS_DIR)/$$plugin && go build $(SIZE_FLAGS) -o ../../$(BINARY_DIR)/$$plugin . && cd ../..; \
		fi; \
	done
	@for tool in $(TOOLS); do \
		if [ -d "$(TOOLS_DIR)/$$tool" ]; then \
			echo "🛠️ Building $$tool tool (optimized)..."; \
			cd $(TOOLS_DIR)/$$tool && go build $(SIZE_FLAGS) -o ../../$(BINARY_DIR)/$$tool . && cd ../..; \
		fi; \
	done

# Build optimized + UPX compression
.PHONY: build-compressed
build-compressed: build-optimized
	@echo "📦 Compressing binaries with UPX..."
	@for binary in $(BINARY_DIR)/*; do \
		if [ -f "$$binary" ]; then \
			echo "  Compressing $$(basename $$binary)..."; \
			upx --force-macos --best --lzma "$$binary" 2>/dev/null || echo "  ⚠️  Failed to compress $$(basename $$binary)"; \
		fi; \
	done
	@echo "✅ Compression complete!"

# Build plugins only
.PHONY: build-plugins
build-plugins: $(BINARY_DIR) $(addprefix $(BINARY_DIR)/,$(PLUGINS))

# Build tools only
.PHONY: build-tools
build-tools: $(BINARY_DIR) $(addprefix $(BINARY_DIR)/,$(TOOLS))

# Individual plugin build targets
$(BINARY_DIR)/%: $(PLUGINS_DIR)/%/main.go | $(BINARY_DIR)
	@echo "🔌 Building $* plugin..."
	@cd $(PLUGINS_DIR)/$* && go build $(BUILD_FLAGS) -o ../../$(BINARY_DIR)/$* .

# Individual tool build targets
$(BINARY_DIR)/titlebar: $(TOOLS_DIR)/titlebar/main.go | $(BINARY_DIR)
	@echo "🛠️ Building titlebar tool..."
	@cd $(TOOLS_DIR)/titlebar && go build $(BUILD_FLAGS) -o ../../$(BINARY_DIR)/titlebar .

$(BINARY_DIR)/config: $(TOOLS_DIR)/config/main.go | $(BINARY_DIR)
	@echo "⚙️ Building config tool..."
	@cd $(TOOLS_DIR)/config && go build $(BUILD_FLAGS) -o ../../$(BINARY_DIR)/config .

# Development build (with debug info)
.PHONY: build-dev
build-dev: $(BINARY_DIR)
	@echo "🛠️ Building development versions..."
	@echo "Building plugins..."
	@for plugin in $(PLUGINS); do \
		if [ -d "$(PLUGINS_DIR)/$$plugin" ]; then \
			echo "🔌 Building $$plugin (dev)..."; \
			cd $(PLUGINS_DIR)/$$plugin && go build -o ../../$(BINARY_DIR)/$$plugin-dev . && cd ../..; \
		fi; \
	done
	@echo "Building tools..."
	@for tool in $(TOOLS); do \
		if [ -d "$(TOOLS_DIR)/$$tool" ]; then \
			echo "🛠️ Building $$tool (dev)..."; \
			cd $(TOOLS_DIR)/$$tool && go build -o ../../$(BINARY_DIR)/$$tool-dev . && cd ../..; \
		fi; \
	done

# Install dependencies
.PHONY: deps
deps:
	@echo "📦 Installing Go dependencies..."
	@go mod download
	@go mod tidy

# Run tests
.PHONY: test
test:
	@echo "🧪 Running tests..."
	@go test -v ./...

# Run tests with coverage
.PHONY: test-coverage
test-coverage:
	@echo "📊 Running tests with coverage..."
	@go test -v -coverprofile=coverage.out ./...
	@go tool cover -html=coverage.out -o coverage.html
	@echo "Coverage report generated: coverage.html"

# Lint code
.PHONY: lint
lint:
	@echo "🔍 Linting code..."
	@if command -v golangci-lint >/dev/null 2>&1; then \
		golangci-lint run; \
	else \
		echo "golangci-lint not found, using go vet..."; \
		go vet ./...; \
	fi

# Format code
.PHONY: fmt
fmt:
	@echo "✨ Formatting code..."
	@go fmt ./...

# Build for both architectures (universal binary)
.PHONY: build-universal
build-universal: $(BINARY_DIR)
	@echo "🏗️ Building universal binaries..."
	@for plugin in $(PLUGINS); do \
		if [ -d "$(CMD_DIR)/$$plugin" ]; then \
			echo "Building $$plugin (universal)..."; \
			cd $(CMD_DIR)/$$plugin && \
			GOOS=darwin GOARCH=amd64 go build $(BUILD_FLAGS) -o ../../$(BINARY_DIR)/$$plugin-amd64 . && \
			GOOS=darwin GOARCH=arm64 go build $(BUILD_FLAGS) -o ../../$(BINARY_DIR)/$$plugin-arm64 . && \
			lipo -create ../../$(BINARY_DIR)/$$plugin-amd64 ../../$(BINARY_DIR)/$$plugin-arm64 -output ../../$(BINARY_DIR)/$$plugin && \
			rm ../../$(BINARY_DIR)/$$plugin-amd64 ../../$(BINARY_DIR)/$$plugin-arm64 && \
			cd ../..; \
		fi; \
	done

# Install plugins to SketchyBar directory
.PHONY: install
install: build
	@echo "📦 Installing plugins to SketchyBar directory..."
	@mkdir -p ~/.config/sketchybar/plugins-go
	@cp $(BINARY_DIR)/* ~/.config/sketchybar/plugins-go/
	@chmod +x ~/.config/sketchybar/plugins-go/*

# Benchmark plugins
.PHONY: benchmark
benchmark: build
	@echo "⚡ Benchmarking plugins..."
	@for plugin in $(PLUGINS); do \
		if [ -f "$(BINARY_DIR)/$$plugin" ]; then \
			echo "Benchmarking $$plugin..."; \
			time ./$(BINARY_DIR)/$$plugin; \
		fi; \
	done

# Development server (rebuild on file changes)
.PHONY: dev
dev:
	@echo "🔄 Starting development server..."
	@if command -v air >/dev/null 2>&1; then \
		air; \
	else \
		echo "Air not found. Install with: go install github.com/cosmtrek/air@latest"; \
		echo "Running manual build..."; \
		$(MAKE) build; \
	fi

# Generate documentation
.PHONY: docs
docs:
	@echo "📚 Generating documentation..."
	@go doc -all . > PLUGINS.md

# Show build info
.PHONY: info
info:
	@echo "ℹ️ Build Information"
	@echo "==================="
	@echo "Go Version: $(shell go version)"
	@echo "Plugins: $(PLUGINS)"
	@echo "Binary Directory: $(BINARY_DIR)"
	@echo "Build Flags: $(BUILD_FLAGS)"
	@echo ""
	@echo "Available targets:"
	@echo "  all          - Clean and build all plugins"
	@echo "  build        - Build all plugins (optimized)"
	@echo "  build-dev    - Build with debug info"
	@echo "  build-universal - Build universal binaries"
	@echo "  clean        - Remove build artifacts"
	@echo "  deps         - Install dependencies"
	@echo "  test         - Run tests"
	@echo "  lint         - Lint code"
	@echo "  fmt          - Format code"
	@echo "  install      - Install to SketchyBar directory"
	@echo "  benchmark    - Benchmark plugins"
	@echo "  dev          - Development mode with auto-rebuild"

# Quick development cycle
.PHONY: quick
quick: fmt lint build
	@echo "🚀 Quick development cycle complete!"

# Check for required tools
.PHONY: check-tools
check-tools:
	@echo "🔧 Checking required tools..."
	@command -v go >/dev/null 2>&1 || (echo "❌ Go not found" && exit 1)
	@echo "✅ Go found: $(shell go version)"
	@command -v make >/dev/null 2>&1 || (echo "❌ Make not found" && exit 1)
	@echo "✅ Make found"
	@echo "🎉 All required tools are available!" 