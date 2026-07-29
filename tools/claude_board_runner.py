#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# Изисква Python 3.10+. Виж tools/README.md.
"""
claude_board_runner.py — Dev-only автоматизиран pipeline за Cosy Ludo v1
(Claude агент, чрез claude-agent-sdk).

Идентичен поток на tools/board_runner.py (Cursor), но dev агентът е Claude —
вграденият Claude Code CLI бинарник, носен от claude-agent-sdk (без нужда от
отделна Node.js/npm инсталация). Не пускай двата скрипта едновременно срещу
един и същ PROJECT_NUMBER — местят едни и същи items по board-а.

  Ready → In progress
        → [Dev агент: Claude]
        → Import check + Scene load
             ↓ OK                     ↓ FAIL (до 3 пъти)
         commit + push           ↩ In progress → Dev с feedback
         Done                         ↓ след 3 FAIL → STOP

След последния таск в batch-а: Existing test suite (веднъж) — FAIL → STOP.

Споделената GitHub Projects / git / checks / prompt логика е в
tools/pipeline_common.py.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
УПОТРЕБА:
  export ANTHROPIC_API_KEY="sk-ant-..."
  export PROJECT_NUMBER=N
  python tools/claude_board_runner.py

ПРЕДВАРИТЕЛНО (еднократно):
  sudo apt-get install -y python3.12 python3.12-venv
  python3.12 -m venv tools/.venv
  source tools/.venv/bin/activate
  pip install -r tools/requirements.txt
  gh auth refresh -s read:project -s project
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

import anyio  # noqa: E402

# ── Константи ──────────────────────────────────────────────────────────────────

DEV_MODEL = "claude-sonnet-5"

_AGENT_RETRIES = 3


# ── claude-agent-sdk агент ──────────────────────────────────────────────────────

async def _query_once(prompt: str, model: str) -> str:
    """Едно query() извикване; връща финалния ResultMessage.result.
    RuntimeError при is_error=True или ако не дойде ResultMessage изобщо."""
    from claude_agent_sdk import ClaudeAgentOptions, ResultMessage, query

    options = ClaudeAgentOptions(
        cwd=str(pipeline_common.PROJECT_ROOT),
        model=model,
        # Headless batch run без interactive approver — същото ниво на
        # доверие, което Cursor local agent-ът вече има днес.
        permission_mode="bypassPermissions",
        system_prompt={"type": "preset", "preset": "claude_code"},
    )

    result_text = ""
    saw_result = False
    async for message in query(prompt=prompt, options=options):
        if isinstance(message, ResultMessage):
            saw_result = True
            if message.is_error:
                raise RuntimeError(
                    f"Claude агент завърши с грешка (subtype={message.subtype}): "
                    f"{(message.result or '').strip() or '(без съобщение)'}"
                )
            result_text = (message.result or "").strip()

    if not saw_result:
        raise RuntimeError("Claude агент не върна ResultMessage — прекъснат stream.")
    return result_text


def _run_agent(prompt: str, model: str, label: str) -> str:
    """
    Wrapper за query(). Връща финалния текст. Хвърля RuntimeError при провал.
    Retryable CLI грешки (connection/process/JSON decode) — до _AGENT_RETRIES
    опита; липсващ вграден CLI е фатално веднага.
    """
    try:
        from claude_agent_sdk import (
            CLIConnectionError,
            CLIJSONDecodeError,
            CLINotFoundError,
            ProcessError,
        )
    except ImportError:
        raise RuntimeError(
            "claude-agent-sdk не е инсталиран.\n"
            "Изпълни: source tools/.venv/bin/activate && pip install -r tools/requirements.txt"
        )

    print(f"  → {label} ({model})…")
    last_err: Exception | None = None

    for attempt in range(1, _AGENT_RETRIES + 1):
        try:
            output = anyio.run(_query_once, prompt, model)
        except CLINotFoundError as err:
            raise RuntimeError(
                f"{label}: вграденият Claude Code CLI не е намерен.\n"
                f"Провери инсталацията на claude-agent-sdk: {err}"
            )
        except (CLIConnectionError, ProcessError, CLIJSONDecodeError) as err:
            last_err = err
            if attempt < _AGENT_RETRIES:
                print(f"  ⚠ CLI грешка (опит {attempt}/{_AGENT_RETRIES}): {err}")
                print("  → Опитвам отново…")
                time.sleep(2)
                continue
            raise RuntimeError(f"{label} не стартира: {err}")
        else:
            print(f"  ✓ {label} завърши")
            return output

    raise RuntimeError(f"{label} не стартира след {_AGENT_RETRIES} опита: {last_err}")


def run_dev_agent(item: dict, retry_feedback: str | None = None) -> None:
    prompt = pipeline_common.build_dev_prompt(item, retry_feedback)
    label = "Dev агент (Claude)" + (" (retry)" if retry_feedback else "")
    output = _run_agent(prompt, DEV_MODEL, label)
    if output:
        print(f"  Резюме: {output[:400]}")


# ── Предварителни проверки ─────────────────────────────────────────────────────

def check_prerequisites(dry_run: bool = False) -> int:
    api_key = os.environ.get("ANTHROPIC_API_KEY", "").strip()
    if not api_key and not dry_run:
        sys.exit(
            "ГРЕШКА: ANTHROPIC_API_KEY не е зададен (console.anthropic.com)"
        )
    return pipeline_common.require_project_number(dry_run)


# ── Main ───────────────────────────────────────────────────────────────────────

def main() -> None:
    print("=" * 66)
    print("  claude_board_runner.py — Dev pipeline (Claude) | Cosy Ludo v1")
    print("=" * 66)

    dry_run = "--dry-run" in sys.argv
    project_number = check_prerequisites(dry_run=dry_run)

    pipeline_common.run_pipeline(
        dry_run=dry_run,
        project_number=project_number,
        dev_agent_label="Dev агент (Claude)",
        run_dev_agent=run_dev_agent,
    )


if __name__ == "__main__":
    main()
