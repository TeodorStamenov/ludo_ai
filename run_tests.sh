#!/usr/bin/env bash
# Стартира headless тестовете на Cosy Ludo v1.
#
# Употреба:
#   ./run_tests.sh              — пълен suite (GUT domain + legacy runner)
#   ./run_tests.sh domain       — само tests/unit/domain/ чрез GUT CLI
#   ./run_tests.sh legacy       — само tests/test_runner.gd (всички слоеве)
#   ./run_tests.sh import       — само import на проекта (без тестове)
#
# Средата може да зада GODOT_BIN=/path/to/godot за различна инсталация.
# За обратна съвместимост се поддържа и GODOT като алиас.

set -euo pipefail

# ── Намиране на Godot изпълним файл ────────────────────────────────────────
find_godot() {
    # GODOT_BIN е конвенцията на проекта (tools/README.md, tools/board_runner.py)
    if [[ -n "${GODOT_BIN:-}" && -x "$GODOT_BIN" ]]; then
        echo "$GODOT_BIN"
        return
    fi
    # GODOT е алиас за обратна съвместимост
    if [[ -n "${GODOT:-}" && -x "$GODOT" ]]; then
        echo "$GODOT"
        return
    fi
    for candidate in \
            godot4 godot \
            /usr/local/bin/godot \
            /usr/bin/godot \
            "$HOME/godot/godot" \
            "$HOME/.local/share/godot/godot"; do
        if command -v "$candidate" &>/dev/null 2>&1; then
            echo "$(command -v "$candidate")"
            return
        fi
        if [[ -x "$candidate" ]]; then
            echo "$candidate"
            return
        fi
    done
    echo ""
}

GODOT_BIN="$(find_godot)"
if [[ -z "$GODOT_BIN" ]]; then
    echo "ERROR: Godot изпълнимият файл не е намерен." >&2
    echo "  Задайте GODOT_BIN=/path/to/godot или добавете godot в PATH." >&2
    exit 1
fi

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
MODE="${1:-all}"

echo "=== Cosy Ludo — Headless Tests ==="
echo "Godot : $GODOT_BIN"
echo "Mode  : $MODE"
echo "Dir   : $PROJECT_DIR"
echo ""

cd "$PROJECT_DIR"

# ── Import (зарежда class_name декларациите) ───────────────────────────────
run_import() {
    echo "--- Import project ---"
    "$GODOT_BIN" --headless --import 2>&1 || true
}

# ── GUT CLI — само domain тестове (.gutconfig.json: dirs=[unit/domain/]) ──
run_domain() {
    echo "--- GUT CLI: unit/domain/ ---"
    "$GODOT_BIN" --headless -s addons/gut/gut_cmdln.gd 2>&1
}

# ── Legacy runner — пълен suite (domain + application + platform + simulation)
run_legacy() {
    echo "--- Legacy runner: full suite ---"
    "$GODOT_BIN" --headless --script tests/test_runner.gd 2>&1
}

case "$MODE" in
    import)
        run_import
        ;;
    domain)
        run_import
        run_domain
        ;;
    legacy)
        run_import
        run_legacy
        ;;
    all)
        run_import
        run_domain
        echo ""
        run_legacy
        ;;
    *)
        echo "ERROR: Непознат режим '$MODE'. Позволени: all | domain | legacy | import" >&2
        exit 1
        ;;
esac
