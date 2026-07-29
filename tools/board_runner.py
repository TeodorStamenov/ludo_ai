#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# Изисква Python 3.10+. Виж tools/README.md.
"""
board_runner.py — Dev-only автоматизиран pipeline за Cosy Ludo v1 (Cursor агент).

Поток за всяка задача в «Ready» (или остатъци в «In review»):
  Ready → In progress
        → [Dev агент: Cursor]
        → Import check + Scene load
             ↓ OK                     ↓ FAIL (до 3 пъти)
         commit + push           ↩ In progress → Dev с feedback
         Done                         ↓ след 3 FAIL → STOP

След последния таск в batch-а:
  → Existing test suite (веднъж) — FAIL → STOP (ръчна поправка)

Няма per-task Review агент. Batch code review се прави ръчно на всеки 20–30 таска.

Бранч: feature/issues_N1_N2_N3  (един за целия batch run)

Споделената GitHub Projects / git / checks / prompt логика е в
tools/pipeline_common.py — този файл съдържа само Cursor-специфичното
(cursor_sdk agent invocation). Аналогичен Claude runner: claude_board_runner.py.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
УПОТРЕБА:
  export CURSOR_API_KEY="cursor_..."
  export PROJECT_NUMBER=N
  python tools/board_runner.py

ПРЕДВАРИТЕЛНО (еднократно):
  sudo apt-get install -y python3.12 python3.12-venv
  python3.12 -m venv tools/.venv
  source tools/.venv/bin/activate
  pip install -r tools/requirements.txt
  gh auth refresh -s read:project -s project

СЛЕД ПРИКЛЮЧВАНЕ:
  Провери бранча и отвори PR / мърджни към main.
  GitHub затваря issues (closes #N) → Projects automation → Done.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
"""

from __future__ import annotations

import os
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import pipeline_common  # noqa: E402

pipeline_common.ensure_venv(__file__)
pipeline_common.load_dotenv()

# ── Константи ──────────────────────────────────────────────────────────────────

DEV_MODEL = "claude-sonnet-5"

_AGENT_BRIDGE_RETRIES = 3


# ── Cursor SDK агент ────────────────────────────────────────────────────────────

def _run_agent(prompt: str, model: str, api_key: str, label: str) -> str:
    """
    Общ wrapper за Agent.prompt(). Връща result.result (финален текст).
    Хвърля RuntimeError при провал.
    При мъртъв bridge (WinError 10061 и др. повторими грешки) рестартира
    default client-а и опитва отново.
    """
    try:
        from cursor_sdk import (
            Agent, AgentOptions, LocalAgentOptions, CursorAgentError,
            close_default_client,
        )
    except ImportError:
        raise RuntimeError(
            "cursor-sdk не е инсталиран.\n"
            "Изпълни: source tools/.venv/bin/activate && pip install -r tools/requirements.txt"
        )

    print(f"  → {label} ({model})…")
    last_err: Exception | None = None

    for attempt in range(1, _AGENT_BRIDGE_RETRIES + 1):
        try:
            result = Agent.prompt(
                prompt,
                AgentOptions(
                    api_key=api_key,
                    model=model,
                    local=LocalAgentOptions(cwd=str(pipeline_common.PROJECT_ROOT)),
                ),
            )
        except CursorAgentError as err:
            last_err = err
            if err.is_retryable and attempt < _AGENT_BRIDGE_RETRIES:
                print(
                    f"  ⚠ Bridge грешка (опит {attempt}/{_AGENT_BRIDGE_RETRIES}): "
                    f"{err.message}"
                )
                print("  → Рестартирам bridge и опитвам отново…")
                try:
                    close_default_client()
                except Exception:
                    pass
                time.sleep(2)
                continue
            raise RuntimeError(
                f"{label} не стартира: {err.message} [повторим={err.is_retryable}]"
            )

        if result.status == "error":
            raise RuntimeError(
                f"{label} върна грешка (run_id={result.id}).\n"
                f"  Детайл: {(result.result or '').strip() or '(празен result)'}"
            )

        print(f"  ✓ {label} завърши — статус: {result.status}")
        return (result.result or "").strip()

    raise RuntimeError(f"{label} не стартира след {_AGENT_BRIDGE_RETRIES} опита: {last_err}")


def run_dev_agent(item: dict, api_key: str, retry_feedback: str | None = None) -> None:
    prompt = pipeline_common.build_dev_prompt(item, retry_feedback)
    label = "Dev агент" + (" (retry)" if retry_feedback else "")
    output = _run_agent(prompt, DEV_MODEL, api_key, label)
    if output:
        print(f"  Резюме: {output[:400]}")


# ── Предварителни проверки ─────────────────────────────────────────────────────

def check_prerequisites(dry_run: bool = False) -> tuple[str, int]:
    api_key = os.environ.get("CURSOR_API_KEY", "").strip()
    if not api_key and not dry_run:
        sys.exit(
            "ГРЕШКА: CURSOR_API_KEY не е зададен (cursor.com/dashboard/integrations)"
        )
    project_number = pipeline_common.require_project_number(dry_run)
    return api_key, project_number


# ── Main ───────────────────────────────────────────────────────────────────────

def main() -> None:
    print("=" * 66)
    print("  board_runner.py — Dev pipeline (Cursor) | Cosy Ludo v1")
    print("=" * 66)

    dry_run = "--dry-run" in sys.argv
    api_key, project_number = check_prerequisites(dry_run=dry_run)

    pipeline_common.run_pipeline(
        dry_run=dry_run,
        project_number=project_number,
        dev_agent_label="Dev агент",
        run_dev_agent=lambda item, feedback: run_dev_agent(item, api_key, feedback),
    )


if __name__ == "__main__":
    main()
