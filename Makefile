# Agent Workspace — Makefile
#
# Uses stamp-file dependencies so setup is idempotent from a fresh clone.
# See ADR-0007 for rationale.
#
# Stamp chain:
#   setup-dev.done  — venv + pre-commit installed
#   git-bug.done    — git-bug identity + GitHub bridge configured
#   project.done    — project/ configured (cloned or symlinked)
#
# Target tiers:
#   Tier 1 — Setup chain (stamp-based, mostly invisible)
#   Tier 2 — Developer workflow (what users type)
#   Tier 3 — Agent/maintenance utilities

SHELL := /bin/bash

# --- Workspace root resolution ---
# When running from a worktree, resolve back to main workspace root.
#   .workspace-worktrees/<name>/   → 2 levels up
#   project/worktrees/<name>/      → 3 levels up
ifneq ($(findstring /project/worktrees/,$(CURDIR)),)
  MAIN_ROOT := $(abspath $(CURDIR)/../../..)
else ifneq ($(findstring /.workspace-worktrees/,$(CURDIR)),)
  MAIN_ROOT := $(abspath $(CURDIR)/../..)
else
  MAIN_ROOT := $(CURDIR)
endif

# --- Stamp directory ---
STAMP    := $(MAIN_ROOT)/.make
VENV_DIR := $(MAIN_ROOT)/.venv
VENV_BIN := $(VENV_DIR)/bin
PRE_COMMIT := $(VENV_BIN)/pre-commit

# --- Phony targets ---
.PHONY: help setup build test lint clean dashboard validate sync lock unlock revert-feature pr-triage generate-skills skip-git-bug repair

# =============================================================================
# Tier 2 — Developer workflow
# =============================================================================

help:
	@echo "Agent Workspace - Makefile"
	@echo ""
	@echo "Setup:"
	@echo "  make setup            Full setup (venv + pre-commit + project clone)"
	@echo "  make lint             Install and run pre-commit on all files"
	@echo "  make validate         Check workspace configuration is valid"
	@echo "  make repair           Fix stale venv/hooks after workspace rename"
	@echo ""
	@echo "Development:"
	@echo "  make build            Run BUILD_CMD from .agent/project_config.sh"
	@echo "  make test             Run TEST_CMD from .agent/project_config.sh"
	@echo "  make dashboard        Show workspace + project status"
	@echo "  make sync             Fetch/pull workspace + project repos"
	@echo ""
	@echo "Worktrees:"
	@echo "  .agent/scripts/worktree_create.sh --issue <N> --type workspace"
	@echo "  .agent/scripts/worktree_create.sh --issue <N> --type project"
	@echo "  .agent/scripts/worktree_list.sh"
	@echo ""
	@echo "Utilities:"
	@echo "  make lock             Lock workspace (prevent concurrent agent work)"
	@echo "  make unlock           Unlock workspace"
	@echo "  make pr-triage        Show PR status across workspace + project"
	@echo "  make revert-feature ISSUE=<N>   Revert commits for issue <N>"
	@echo "  make generate-skills  Regenerate /make_* slash commands"
	@echo "  make skip-git-bug     Skip git-bug setup (mark stamp without running configuration)"
	@echo "  make clean            Remove stamp files (forces re-setup)"
	@echo ""

setup: $(STAMP)/project.done $(STAMP)/git-bug.done
	@echo "✅ Setup complete."

build: $(STAMP)/setup-dev.done
	@$(MAIN_ROOT)/.agent/scripts/build.sh

test: $(STAMP)/setup-dev.done
	@$(MAIN_ROOT)/.agent/scripts/test.sh

lint: $(STAMP)/setup-dev.done
	$(PRE_COMMIT) run --all-files

clean:
	rm -rf $(STAMP)
	@echo "Stamp files removed. Run 'make setup' to re-initialize."

dashboard:
	@$(MAIN_ROOT)/.agent/scripts/dashboard.sh

validate:
	python3 $(MAIN_ROOT)/.agent/scripts/validate_workspace.py --verbose

repair:
	@echo "--- Repairing venv and pre-commit hook ---"
	$(VENV_BIN)/python3 -m pip install --quiet --force-reinstall -r $(MAIN_ROOT)/requirements.txt
	cd $(MAIN_ROOT) && $(PRE_COMMIT) install
	@rm -f $(STAMP)/setup-dev.done
	@$(MAKE) --no-print-directory $(STAMP)/setup-dev.done
	@echo "✅ Repair complete. Run 'make validate' to verify."

sync:
	python3 $(MAIN_ROOT)/.agent/scripts/sync_project.py

lock:
	@$(MAIN_ROOT)/.agent/scripts/lock.sh

unlock:
	@$(MAIN_ROOT)/.agent/scripts/unlock.sh

pr-triage:
	@$(MAIN_ROOT)/.agent/scripts/pr_status.sh --all-repos

revert-feature:
	@if [ -z "$(ISSUE)" ]; then echo "Usage: make revert-feature ISSUE=<N>"; exit 1; fi
	@$(MAIN_ROOT)/.agent/scripts/revert_feature.sh --issue $(ISSUE)

generate-skills:
	@$(MAIN_ROOT)/.agent/scripts/generate_make_skills.sh

skip-git-bug:
	@mkdir -p $(STAMP)
	@touch $(STAMP)/git-bug.done
	@echo "git-bug setup marked as done. Run 'make clean' to reset."

# =============================================================================
# Tier 1 — Setup chain (stamp-based)
# =============================================================================

$(STAMP):
	mkdir -p $(STAMP)

# setup-dev: install venv + pre-commit
$(STAMP)/setup-dev.done: requirements.txt | $(STAMP)
	@echo "--- Setting up dev tools ---"
	python3 -m venv $(VENV_DIR)
	$(VENV_BIN)/pip install --quiet --upgrade pip
	$(VENV_BIN)/pip install --quiet -r $(MAIN_ROOT)/requirements.txt
	$(PRE_COMMIT) install
	touch $@

# git-bug: configure identity + GitHub bridge
$(STAMP)/git-bug.done: $(STAMP)/setup-dev.done
	@mkdir -p $(STAMP)
	@$(MAIN_ROOT)/.agent/scripts/git_bug_setup.sh
	@touch $@

# project: configure project/ directory
$(STAMP)/project.done: $(STAMP)/setup-dev.done
	@echo "--- Configuring project ---"
	@if [ -d "$(MAIN_ROOT)/project" ] && git -C "$(MAIN_ROOT)/project" rev-parse --git-dir &>/dev/null; then \
	    echo "project/ already configured."; \
	else \
	    $(MAIN_ROOT)/.agent/scripts/setup_project.sh; \
	fi
	touch $@
