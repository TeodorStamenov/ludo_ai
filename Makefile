# Cosy Ludo v1 — Makefile
#
# Команди за headless тестване:
#   make test           — пълен suite (GUT domain + legacy runner)
#   make test-domain    — само tests/unit/domain/ чрез GUT CLI
#   make test-legacy    — само tests/test_runner.gd
#   make import         — само import на проекта
#
# GODOT_BIN е конвенцията на проекта (tools/README.md, tools/board_runner.py).
# За обратна съвместимост се поддържа и GODOT като алиас:
#   make test GODOT_BIN=/path/to/godot

# Открива Godot по GODOT_BIN → GODOT → PATH кандидати
_GODOT_FIND = $(shell \
	if [ -n "$$GODOT_BIN" ] && [ -x "$$GODOT_BIN" ]; then echo $$GODOT_BIN; exit 0; fi; \
	if [ -n "$$GODOT" ] && [ -x "$$GODOT" ]; then echo $$GODOT; exit 0; fi; \
	for c in godot4 godot /usr/local/bin/godot /usr/bin/godot \
	          $(HOME)/godot/godot $(HOME)/.local/share/godot/godot; do \
		if command -v $$c >/dev/null 2>&1; then command -v $$c; exit 0; fi; \
		if [ -x "$$c" ]; then echo $$c; exit 0; fi; \
	done)
GODOT_BIN ?= $(_GODOT_FIND)

.PHONY: import test-domain test-legacy test

import:
	@echo "--- Import project ---"
	@$(GODOT_BIN) --headless --import 2>&1 || true

## GUT CLI — автоматично открива тестовете по .gutconfig.json
test-domain: import
	@echo "--- GUT CLI: unit/domain/ ---"
	$(GODOT_BIN) --headless -s addons/gut/gut_cmdln.gd 2>&1

## Legacy runner — пълен suite (domain + application + platform + simulation)
test-legacy: import
	@echo "--- Legacy runner: full suite ---"
	$(GODOT_BIN) --headless --script tests/test_runner.gd 2>&1

## Пълен suite: GUT domain след това legacy runner
test: import test-domain test-legacy
