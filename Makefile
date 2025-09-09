# ################################################################################
# # Configuration and Variables
# ################################################################################

# --- GC Debug Configuration ---
# This is the single switch to control all GC debugging.
# Set to 1 to enable the compile-time trace and the runtime stats summary.
# Set to 0 for a quiet build and run.
GC_DEBUG_MODE ?= 0

# These two variables are now set based on the master switch.
GC_PRINT_STATS := $(GC_DEBUG_MODE)
GC_DEBUG       := $(GC_DEBUG_MODE)

# We must export GC_DEBUG for the `zig build` process to see it.
# This allows `build.zig` to add the -DGC_DEBUG compile flag.
export GC_DEBUG

# --- General Project Configuration ---
ZIG    ?= $(shell which zig || echo ~/.local/share/zig/0.14.1/zig)
BUILD_TYPE    ?= Debug
BUILD_OPTS      = -Doptimize=$(BUILD_TYPE)
JOBS          ?= $(shell nproc || echo 2)
SRC_DIR       := src
EXAMPLES_DIR  := examples
BUILD_DIR     := zig-out
CACHE_DIR     := .zig-cache
BINARY_NAME   := example
RELEASE_MODE := ReleaseSafe
TEST_FLAGS := --summary all #--verbose
JUNK_FILES := *.o *.obj *.dSYM *.dll *.so *.dylib *.a *.lib *.pdb temp/

# Automatically find all example names
ZIG_EXAMPLES  := $(patsubst %.zig,%,$(notdir $(wildcard examples/zig/*.zig)))
ELZ_EXAMPLES  := $(wildcard examples/elz/*.elz)
EXAMPLE       ?= all
ELZ_EXAMPLE   ?= all

SHELL         := /usr/bin/env bash
.SHELLFLAGS   := -eu -o pipefail -c

################################################################################
# Targets
################################################################################

.PHONY: all help build rebuild run run-quiet run-elz run-elz-quiet test release clean lint format docs serve-docs install-deps setup-hooks test-hooks
.DEFAULT_GOAL := help

help: ## Show the help messages for all targets
	@echo "Usage: make <target>"
	@echo ""
	@echo "Targets:"
	@grep -E '^[a-zA-Z_-]+:.*## .*$$' Makefile | \
	awk 'BEGIN {FS = ":.*## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'

all: build test lint docs  ## build, test, lint, and doc

init: ## Initialize a new Zig project
	@echo "Initializing a new Zig project..."
	@$(ZIG) init

build: ## Build project (e.g. 'make build BUILD_TYPE=ReleaseSafe')
	@echo "Building project in $(BUILD_TYPE) mode with $(JOBS) concurrent jobs..."
	@$(ZIG) build $(BUILD_OPTS) -j$(JOBS)

rebuild: clean build  ## clean and build

run: ## Run a Zig example (e.g. 'make run EXAMPLE=e1_ffi_1')
	@if [ "$(EXAMPLE)" = "all" ]; then \
	   echo "--> Running all Zig examples..."; \
	   fail=0; \
	   for ex in $(ZIG_EXAMPLES); do \
	      echo ""; \
	      echo "--> Running '$$ex'"; \
	      GC_PRINT_STATS=$(GC_PRINT_STATS) $(ZIG) build run-$$ex $(BUILD_OPTS) || { echo "FAILED: $$ex"; fail=1; }; \
	   done; \
	   exit $$fail; \
	else \
	   echo "--> Running Zig example: $(EXAMPLE)"; \
	   GC_PRINT_STATS=$(GC_PRINT_STATS) $(ZIG) build run-$(EXAMPLE) $(BUILD_OPTS); \
	fi

run-quiet: ## Run a Zig example quietly in ReleaseSafe mode
	@$(MAKE) run BUILD_TYPE=$(RELEASE_MODE) EXAMPLE=$(EXAMPLE)

run-elz: build ## Run a Lisp example (e.g. 'make run-elz ELZ_EXAMPLE=e1-cons-car-cdr')
	@if [ "$(ELZ_EXAMPLE)" = "all" ]; then \
	   echo "--> Running all Lisp examples..."; \
	   fail=0; \
	   for ex in $(ELZ_EXAMPLES); do \
	      echo ""; \
	      echo "--> Running '$$ex'"; \
	      GC_PRINT_STATS=$(GC_PRINT_STATS) ./zig-out/bin/elz-repl --file $$ex || { echo "FAILED: $$ex"; fail=1; }; \
	   done; \
	   exit $$fail; \
	else \
	   echo "--> Running Lisp example: $(ELZ_EXAMPLE)"; \
	   GC_PRINT_STATS=$(GC_PRINT_STATS) ./zig-out/bin/elz-repl --file examples/elz/$(ELZ_EXAMPLE).elz; \
	fi

run-elz-quiet: ## Run a Lisp example quietly in ReleaseSafe mode
	@$(MAKE) run-elz BUILD_TYPE=$(RELEASE_MODE) ELZ_EXAMPLE=$(ELZ_EXAMPLE)

repl: ## Start the REPL
	@echo "Starting the REPL..."
	@$(ZIG) build repl $(BUILD_OPTS)

test: ## Run tests
	@echo "Running tests..."
	@$(ZIG) build test $(BUILD_OPTS) -j$(JOBS) $(TEST_FLAGS)

release: ## Build in Release mode
	@echo "Building the project in Release mode..."
	@$(MAKE) build BUILD_TYPE=$(RELEASE_MODE)

clean: ## Remove docs, build artifacts, and cache directories
	@echo "Removing build artifacts, cache, generated docs, and junk files..."
	@rm -rf $(BUILD_DIR) $(CACHE_DIR) $(JUNK_FILES) docs/api public

lint: ## Check code style and formatting of Zig files
	@echo "Running code style checks..."
	@$(ZIG) fmt --check $(SRC_DIR) $(EXAMPLES_DIR)

format: ## Format Zig files
	@echo "Formatting Zig files..."
	@$(ZIG) fmt .

docs: ## Generate API documentation
	@echo "Generating API documentation..."
	@$(ZIG) build docs

serve-docs: ## Serve the generated documentation on a local server
	@echo "Serving API documentation locally..."
	@cd docs/api && python3 -m http.server 8000

install-deps: ## Install system dependencies (for Debian-based systems)
	@echo "Installing system dependencies..."
	@sudo apt-get update
	@sudo apt-get install -y make llvm snapd
	@sudo snap install zig --beta --classic

setup-hooks: ## Install Git hooks (pre-commit and pre-push)
	@echo "Setting up Git hooks..."
	@if ! command -v pre-commit &> /dev/null; then \
	   echo "pre-commit not found. Please install it using 'pip install pre-commit'"; \
	   exit 1; \
	fi
	@pre-commit install --hook-type pre-commit
	@pre-commit install --hook-type pre-push
	@pre-commit install-hooks

test-hooks: ## Test Git hooks on all files
	@echo "Testing Git hooks..."
	@pre-commit run --all-files --show-diff-on-failure
