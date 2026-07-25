#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# Изисква Python 3.10+. Виж tools/README.md.
"""
board_runner.py — Dev + Review автоматизиран pipeline за Cosy Ludo v1.

Поток за всяка задача в «Ready»:
  Ready → In progress
        → [Dev агент: claude-sonnet-4-6]
        → In review
        → [Review агент: claude-sonnet-5-thinking-high]
             ↓ PASS                  ↓ FAIL (до 3 пъти)
         commit + push           ↩ In progress → Dev агент с feedback
         Done                         ↓ след 3 FAIL
         следваща задача             STOP

Бранч: feature/issues_N1_N2_N3  (един за целия batch run)

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

import json
import os
import subprocess
import sys
from pathlib import Path

# Ако скриптът не се изпълнява от venv Python-а, рестартира себе си с него.
def _ensure_venv():
    venv_root = Path(__file__).resolve().parent / ".venv"
    # Windows: Scripts\python.exe  /  Unix: bin/python
    venv_python = (
        venv_root / "Scripts" / "python.exe"
        if sys.platform == "win32"
        else venv_root / "bin" / "python"
    )
    if sys.version_info < (3, 10):
        if venv_python.exists():
            sys.exit(subprocess.run([str(venv_python)] + sys.argv).returncode)
        sys.exit(
            "ГРЕШКА: Нужен е Python 3.10+. Текуща версия: %s\n"
            "Създай venv: python3.12 -m venv tools/.venv && "
            "pip install -r tools/requirements.txt" % sys.version
        )
    if venv_python.exists() and Path(sys.executable).resolve() != venv_python.resolve():
        # os.execv не е надеждно на Windows — ползваме subprocess + exit
        sys.exit(subprocess.run([str(venv_python)] + sys.argv).returncode)

_ensure_venv()

# Зарежда tools/.env автоматично (ако съществува)
def _load_dotenv() -> None:
    env_file = Path(__file__).resolve().parent / ".env"
    if not env_file.exists():
        return
    try:
        from dotenv import load_dotenv
        load_dotenv(env_file, override=False)
    except ImportError:
        # Ръчен fallback ако python-dotenv не е инсталиран
        with open(env_file, encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith("#") or "=" not in line:
                    continue
                key, _, val = line.partition("=")
                key = key.strip()
                val = val.strip().strip('"').strip("'")
                os.environ.setdefault(key, val)

_load_dotenv()

# ── Константи ──────────────────────────────────────────────────────────────────

REPO_OWNER = "TeodorStamenov"

DEV_MODEL    = "claude-sonnet-4-6"
REVIEW_MODEL = "claude-sonnet-5"
MAX_RETRIES  = 3

STATUS_READY       = "Ready"
STATUS_IN_PROGRESS = "In progress"
STATUS_IN_REVIEW   = "In review"
STATUS_DONE        = "Done"

PROJECT_ROOT = Path(__file__).resolve().parent.parent

# Godot binary — override чрез GODOT_BIN env var
_default_godot = PROJECT_ROOT.parent.parent / "godot" / "godot"
GODOT_BIN = Path(os.environ.get("GODOT_BIN", str(_default_godot)))
TEST_SCRIPT = "tests/test_runner.gd"


# ── GitHub Projects v2 GraphQL ─────────────────────────────────────────────────

def gh_graphql(query: str, variables: dict | None = None) -> dict:
    body = json.dumps({"query": query, "variables": variables or {}})
    result = subprocess.run(
        ["gh", "api", "graphql", "--input", "-"],
        input=body, capture_output=True, text=True, encoding="utf-8",
    )
    if result.returncode != 0:
        raise RuntimeError(
            f"gh api graphql грешка (exit {result.returncode}):\n{result.stderr.strip()}\n"
            "Провери: gh auth refresh -s read:project -s project"
        )
    data = json.loads(result.stdout)
    if "errors" in data:
        raise RuntimeError(
            f"GraphQL грешки:\n{json.dumps(data['errors'], ensure_ascii=False, indent=2)}"
        )
    return data


def get_project_metadata(project_number: int) -> dict:
    """Връща project_id, status_field_id и {option_name: option_id}."""
    query = """
    query($owner: String!, $number: Int!) {
      user(login: $owner) {
        projectV2(number: $number) {
          id
          title
          fields(first: 30) {
            nodes {
              ... on ProjectV2SingleSelectField {
                id
                name
                options { id name }
              }
            }
          }
        }
      }
    }
    """
    data = gh_graphql(query, {"owner": REPO_OWNER, "number": project_number})
    project = data["data"]["user"]["projectV2"]
    if project is None:
        raise RuntimeError(
            f"Проект #{project_number} не е намерен за '{REPO_OWNER}'.\n"
            "Провери PROJECT_NUMBER (числото в URL-а на проекта)."
        )
    print(f"  Проект: «{project['title']}» (id={project['id']})")
    status_field = next(
        (f for f in project["fields"]["nodes"] if f.get("name") == "Status"),
        None,
    )
    if status_field is None:
        raise RuntimeError("Полето 'Status' не е намерено в проекта.")
    options = {opt["name"]: opt["id"] for opt in status_field["options"]}
    return {
        "project_id":      project["id"],
        "status_field_id": status_field["id"],
        "options":         options,
    }


def get_items_by_status(project_id: str, status_field_id: str, status: str) -> list[dict]:
    """Връща всички project items с даден статус."""
    query = """
    query($projectId: ID!) {
      node(id: $projectId) {
        ... on ProjectV2 {
          items(first: 100) {
            nodes {
              id
              fieldValues(first: 20) {
                nodes {
                  ... on ProjectV2ItemFieldSingleSelectValue {
                    name
                    field { ... on ProjectV2SingleSelectField { id } }
                  }
                }
              }
              content {
                ... on Issue {
                  number
                  title
                  body
                  url
                }
              }
            }
          }
        }
      }
    }
    """
    data = gh_graphql(query, {"projectId": project_id})
    items = data["data"]["node"]["items"]["nodes"]
    result = []
    for item in items:
        for fv in item["fieldValues"]["nodes"]:
            if (fv.get("name") == status
                    and fv.get("field", {}).get("id") == status_field_id):
                issue = item.get("content") or {}
                if issue.get("number"):
                    result.append({
                        "item_id":      item["id"],
                        "issue_number": issue["number"],
                        "title":        issue["title"],
                        "body":         issue.get("body", ""),
                        "url":          issue.get("url", ""),
                    })
                break
    return result


def move_item_status(
    project_id: str,
    item_id: str,
    field_id: str,
    option_id: str,
    label: str,
) -> None:
    query = """
    mutation($projectId: ID!, $itemId: ID!, $fieldId: ID!, $optionId: String!) {
      updateProjectV2ItemFieldValue(
        input: {
          projectId:  $projectId
          itemId:     $itemId
          fieldId:    $fieldId
          value: { singleSelectOptionId: $optionId }
        }
      ) { projectV2Item { id } }
    }
    """
    gh_graphql(query, {
        "projectId": project_id,
        "itemId":    item_id,
        "fieldId":   field_id,
        "optionId":  option_id,
    })
    print(f"  ✓ Статус → «{label}»")


# ── Git helpers ────────────────────────────────────────────────────────────────

MAIN_BRANCH = "main"


def current_branch() -> str:
    r = subprocess.run(
        ["git", "rev-parse", "--abbrev-ref", "HEAD"],
        cwd=PROJECT_ROOT, capture_output=True, text=True, encoding="utf-8", check=True,
    )
    return r.stdout.strip()


def checkout_main_and_pull() -> None:
    """
    Гарантира, че сме на main с последните промени преди нов batch.
    - Ако има uncommitted промени → грешка (не можем безопасно да switch-нем).
    - Ако сме на друг бранч → автоматично checkout main.
    - Винаги пула от origin/main.
    """
    # Uncommitted промени блокират checkout — проверяваме първо
    status = subprocess.run(
        ["git", "status", "--porcelain"],
        cwd=PROJECT_ROOT, capture_output=True, text=True, encoding="utf-8", check=True,
    )
    if status.stdout.strip():
        raise RuntimeError(
            "Има uncommitted промени — не мога да превключа към main.\n"
            "Commit или stash ги преди да стартираш скрипта:\n"
            + status.stdout.strip()
        )

    branch = current_branch()
    if branch != MAIN_BRANCH:
        print(f"  Текущ бранч: «{branch}» → превключвам към «{MAIN_BRANCH}»…")
        subprocess.run(
            ["git", "checkout", MAIN_BRANCH],
            cwd=PROJECT_ROOT, check=True,
        )

    print(f"  git pull origin {MAIN_BRANCH}…")
    result = subprocess.run(
        ["git", "pull", "origin", MAIN_BRANCH],
        cwd=PROJECT_ROOT, capture_output=True, text=True, encoding="utf-8",
    )
    if result.returncode != 0:
        raise RuntimeError(
            f"git pull се провали:\n{result.stderr.strip()}\n{result.stdout.strip()}"
        )
    summary = (result.stdout.strip().splitlines() or [""])[-1]
    print(f"  ✓ {summary}")


def create_branch(issue_numbers: list[int]) -> str:
    """Създава (или превключва към) feature/issues_N1_N2_N3."""
    nums   = "_".join(str(n) for n in issue_numbers)
    branch = f"feature/issues_{nums}"

    r = subprocess.run(
        ["git", "checkout", "-b", branch],
        cwd=PROJECT_ROOT, capture_output=True, text=True, encoding="utf-8",
    )
    if r.returncode != 0:
        # Бранчът вероятно вече съществува — превключи
        subprocess.run(
            ["git", "checkout", branch],
            cwd=PROJECT_ROOT, check=True,
        )
    print(f"  ✓ Бранч: {branch}")
    return branch


def git_stage_all() -> None:
    subprocess.run(["git", "add", "."], cwd=PROJECT_ROOT, check=True)


def git_unstage_all() -> None:
    """Unstage всичко (нови и модифицирани файлове), работното копие остава."""
    subprocess.run(["git", "reset", "."], cwd=PROJECT_ROOT, check=True)


def git_has_staged_changes() -> bool:
    r = subprocess.run(
        ["git", "diff", "--staged", "--quiet"],
        cwd=PROJECT_ROOT,
    )
    return r.returncode != 0  # returncode 1 = има промени


def get_staged_files() -> list[str]:
    r = subprocess.run(
        ["git", "diff", "--staged", "--name-status"],
        cwd=PROJECT_ROOT, capture_output=True, text=True, encoding="utf-8", check=True,
    )
    lines = []
    for line in r.stdout.splitlines():
        line = line.strip()
        if line:
            lines.append(line)  # напр. "M game/domain/rng/random_source.gd"
    return lines


def git_commit_and_push(issue_number: int, title: str, branch: str) -> None:
    if not git_has_staged_changes():
        print(f"  ⚠ Няма staged промени за #{issue_number}")
        return
    # Conventional commit + "closes #N" за GitHub auto-close при merge в main
    message = f"feat: {title}\n\ncloses #{issue_number}"
    subprocess.run(["git", "commit", "-m", message], cwd=PROJECT_ROOT, check=True)
    subprocess.run(["git", "push", "-u", "origin", branch], cwd=PROJECT_ROOT, check=True)
    print(f"  ✓ Commit + push → {branch}")


# ── Test suite ─────────────────────────────────────────────────────────────────

def run_test_suite() -> tuple[bool, str]:
    """
    Стартира godot --headless --script tests/test_runner.gd.
    Връща (all_passed, output_text).
    """
    if not GODOT_BIN.exists():
        msg = (
            f"Godot не е намерен на {GODOT_BIN}.\n"
            "Задай GODOT_BIN=/path/to/godot env var."
        )
        return False, msg

    try:
        result = subprocess.run(
            [str(GODOT_BIN), "--headless", "--script", TEST_SCRIPT],
            cwd=PROJECT_ROOT, capture_output=True, text=True, encoding="utf-8", timeout=120,
        )
    except subprocess.TimeoutExpired:
        return False, "ГРЕШКА: тест suite надхвърли timeout от 120 секунди."

    output = (result.stdout + result.stderr).strip()
    return result.returncode == 0, output


# ── Prompt константи ───────────────────────────────────────────────────────────

_PROJECT_CONTEXT = """\
Работиш по Godot 4 / GDScript проекта "Cosy Ludo v1" (директория: ai_ludo/).
Ключови документи:
  docs/V1_ARCHITECTURE.md        — пълна целева архитектура
  docs/V1_GAME_DESIGN.md         — game design спецификация
  docs/CURRENT_YELLOW_BEHAVIOR.md — референтни сценарии на прототипа
  tests/                         — headless test runner (test_runner.gd + test_case.gd)
"""

_ARCH_RULES = """\
АРХИТЕКТУРНИ ПРАВИЛА (задължителни — всяко нарушение = FAIL):
- Нови unit тестове се добавят САМО в tests/unit/domain/.
  Тестовете за application/, platform/ и presentation/ са замразени.
  Stub, Null и Adapter класове не се тестват.
- game/domain/     → само `extends RefCounted`. Никога Node/сцени.
                     Не импортира от application/, presentation/, platform/, app/.
- game/application/→ може да импортира от game/domain/ и content/ САМО.
                     Не импортира от game/presentation/.
- game/presentation/→ може да използва Node/Control/Node2D.
                     Не прилага gameplay правила, не извиква GameEngine директно.
- Dependency посока: Presentation → Application → Domain (стрелките навътре).
- Всеки нов .gd файл: `class_name` в PascalCase, съответстващ на filename.
"""

_QUALITY_RULES = """\
ПРАВИЛА ЗА КАЧЕСТВО НА КОДА:
- Без коментари, преразказващи какво прави кодът ред по ред.
- Коментари само за неочевидно намерение, trade-offs или ограничения.
- Типизирани параметри и return типове навсякъде.
- StringName (&"...") за стабилни идентификатори, не обикновен String.
- Публичният API на клас е минимален — само необходимото за потребителите.
"""


# ── Cursor SDK агенти ──────────────────────────────────────────────────────────

def _run_agent(prompt: str, model: str, api_key: str, label: str) -> str:
    """
    Общ wrapper за Agent.prompt(). Връща result.result (финален текст).
    Хвърля RuntimeError при провал.
    """
    try:
        from cursor_sdk import Agent, AgentOptions, LocalAgentOptions, CursorAgentError
    except ImportError:
        raise RuntimeError(
            "cursor-sdk не е инсталиран.\n"
            "Изпълни: source tools/.venv/bin/activate && pip install -r tools/requirements.txt"
        )

    from cursor_sdk import Agent, AgentOptions, LocalAgentOptions, CursorAgentError

    print(f"  → {label} ({model})…")
    try:
        result = Agent.prompt(
            prompt,
            AgentOptions(
                api_key=api_key,
                model=model,
                local=LocalAgentOptions(cwd=str(PROJECT_ROOT)),
            ),
        )
    except CursorAgentError as err:
        raise RuntimeError(
            f"{label} не стартира: {err.message} [повторим={err.is_retryable}]"
        )

    if result.status == "error":
        raise RuntimeError(f"{label} върна грешка (run_id={result.id}).")

    print(f"  ✓ {label} завърши — статус: {result.status}")
    return (result.result or "").strip()


def run_dev_agent(item: dict, api_key: str, review_feedback: str | None = None) -> None:
    feedback_block = ""
    if review_feedback:
        feedback_block = f"""
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
ПРЕДИШНОТО РЕВЮ ОТКРИ ПРОБЛЕМИ — ТРЯБВА ДА ГИ ПОПРАВИШ:

{review_feedback}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
"""

    prompt = f"""{_PROJECT_CONTEXT}
{_ARCH_RULES}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
ЗАДАЧА #{item['issue_number']}: {item['title']}
{item['url']}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

{item['body'].strip() if item['body'] else '(Виж заглавието.)'}
{feedback_block}
ИНСТРУКЦИИ:
1. Прочети релевантния раздел от docs/V1_ARCHITECTURE.md.
2. Имплементирай задачата изцяло.
3. Не създавай .tscn файлове освен ако задачата изрично го изисква.
4. Не питай за потвърждение — имплементирай всичко в един pass.
5. Накрая напиши кратко резюме (1–3 изречения) на направеното.
"""
    label = "Dev агент" + (" (retry)" if review_feedback else "")
    output = _run_agent(prompt, DEV_MODEL, api_key, label)
    if output:
        print(f"  Резюме: {output[:400]}")


def run_review_agent(
    item: dict,
    staged_files: list[str],
    test_passed: bool,
    test_output: str,
    api_key: str,
) -> tuple[bool, str]:
    """
    Стартира review агента. Връща (passed, feedback).
    feedback е непразен само при passed=False.
    """
    test_label  = "✓ ВСИЧКИ ТЕСТОВЕ МИНАХА" if test_passed else "✗ ТЕСТОВЕТЕ НЕ МИНАХА"
    files_block = (
        "\n".join(f"  {f}" for f in staged_files)
        if staged_files else "  (няма засегнати файлове)"
    )
    # Последните 3000 символа от теста (за да не препълним контекста)
    test_excerpt = test_output[-3000:] if len(test_output) > 3000 else test_output

    prompt = f"""{_PROJECT_CONTEXT}
{_ARCH_RULES}
{_QUALITY_RULES}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
ЗАДАЧА ЗА РЕВЮ #{item['issue_number']}: {item['title']}
{item['url']}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Описание на задачата:
{item['body'].strip() if item['body'] else '(Виж заглавието.)'}

ЗАСЕГНАТИ ФАЙЛОВЕ (git staged):
{files_block}

РЕЗУЛТАТ ОТ TEST SUITE:
{test_label}
{test_excerpt}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
ИНСТРУКЦИИ ЗА РЕВЮТО:
1. Прочети всеки засегнат файл от списъка по-горе.
2. Провери АРХИТЕКТУРНИ ПРАВИЛА — всяко нарушение = задължителен FAIL.
3. Провери ПРАВИЛА ЗА КАЧЕСТВО.
4. Провери дали задачата е изпълнена пълно спрямо описанието и архитектурата.
5. Ако тестовете не минаха → задължителен FAIL.

Завърши отговора си ТОЧНО с един от следните блокове:

При успех:
VERDICT: PASS

При неуспех:
VERDICT: FAIL
ISSUES:
- [architecture|quality|tests|incomplete] Конкретен проблем (файл, ред, причина)
- ...

Не пропускай реда VERDICT — скриптът го парси автоматично.
"""
    output = _run_agent(prompt, REVIEW_MODEL, api_key, "Review агент")

    passed  = _parse_verdict(output)
    feedback = "" if passed else _extract_feedback(output)

    status = "PASS ✓" if passed else "FAIL ✗"
    print(f"  Ревю: {status}")
    if not passed and feedback:
        # Показва само първите 600 символа от feedback в конзолата
        excerpt = feedback[:600] + ("…" if len(feedback) > 600 else "")
        print(f"  Проблеми:\n{excerpt}")

    return passed, feedback


def _parse_verdict(text: str) -> bool:
    """Търси последния VERDICT ред. Без намерен → False (по-безопасно)."""
    for line in reversed(text.splitlines()):
        stripped = line.strip()
        if stripped.upper().startswith("VERDICT:"):
            return "PASS" in stripped.upper()
    print("  ⚠ Не намерих VERDICT ред — третирам като FAIL")
    return False


def _extract_feedback(text: str) -> str:
    """Връща съдържанието след 'VERDICT: FAIL'."""
    lines     = text.splitlines()
    capturing = False
    result    = []
    for line in lines:
        if line.strip().upper().startswith("VERDICT:"):
            capturing = True
            continue
        if capturing:
            result.append(line)
    feedback = "\n".join(result).strip()
    # Fallback: ако feedback е празен, върни последните 1500 символа от целия output
    return feedback if feedback else text[-1500:]


# ── Предварителни проверки ─────────────────────────────────────────────────────

def check_prerequisites() -> tuple[str, int]:
    errors: list[str] = []

    api_key = os.environ.get("CURSOR_API_KEY", "").strip()
    if not api_key:
        errors.append("CURSOR_API_KEY не е зададен (cursor.com/dashboard/integrations)")

    project_number = 0
    pn = os.environ.get("PROJECT_NUMBER", "").strip()
    if not pn:
        errors.append(
            "PROJECT_NUMBER не е зададен\n"
            "  (числото от URL-а: github.com/users/TeodorStamenov/projects/N)"
        )
    else:
        try:
            project_number = int(pn)
        except ValueError:
            errors.append(f"PROJECT_NUMBER трябва да е цяло число, получено: '{pn}'")

    if errors:
        print("ГРЕШКА — липсващи условия:", file=sys.stderr)
        for e in errors:
            print(f"  • {e}", file=sys.stderr)
        sys.exit(1)

    return api_key, project_number


# ── Main ───────────────────────────────────────────────────────────────────────

def main() -> None:
    print("=" * 66)
    print("  board_runner.py — Dev + Review pipeline | Cosy Ludo v1")
    print("=" * 66)

    api_key, project_number = check_prerequisites()

    # 1. Метаданни на проекта
    print(f"\n▸ Зареждам project #{project_number}…")
    try:
        meta = get_project_metadata(project_number)
    except RuntimeError as e:
        sys.exit(f"\nГРЕШКА: {e}")

    options = meta["options"]
    for needed in [STATUS_READY, STATUS_IN_PROGRESS, STATUS_IN_REVIEW, STATUS_DONE]:
        if needed not in options:
            sys.exit(
                f"\nГРЕШКА: Статус «{needed}» не е намерен в проекта.\n"
                f"Налични: {list(options.keys())}"
            )

    # 2. Взимам items — първо "In Review" (resume), после "Ready" (нови)
    print(f"\n▸ Търся items в «{STATUS_IN_REVIEW}» и «{STATUS_READY}»…")
    try:
        review_items = get_items_by_status(
            meta["project_id"], meta["status_field_id"], STATUS_IN_REVIEW
        )
        ready_items = get_items_by_status(
            meta["project_id"], meta["status_field_id"], STATUS_READY
        )
    except RuntimeError as e:
        sys.exit(f"\nГРЕШКА: {e}")

    if not review_items and not ready_items:
        print(f"  Няма items в «{STATUS_IN_REVIEW}» или «{STATUS_READY}». Нищо за правене.")
        return

    if review_items:
        print(f"  Resume — {len(review_items)} item(s) в «{STATUS_IN_REVIEW}»:")
        for it in review_items:
            print(f"    #{it['issue_number']}: {it['title']}")
    if ready_items:
        print(f"  Нови — {len(ready_items)} item(s) в «{STATUS_READY}»:")
        for it in ready_items:
            print(f"    #{it['issue_number']}: {it['title']}")

    # 3. Бранч — при resume ползваме текущия; при нови batch: pull main + нов бранч
    all_items = review_items + ready_items
    print(f"\n▸ Бранч…")
    if review_items and not ready_items:
        # Само resume — оставаме на текущия feature бранч
        branch = current_branch()
        print(f"  ✓ Текущ бранч (resume): {branch}")
    else:
        # Нов batch — превключваме към main (ако не сме) и пулваме
        try:
            checkout_main_and_pull()
        except RuntimeError as e:
            sys.exit(f"\nГРЕШКА: {e}")
        issue_numbers = [it["issue_number"] for it in all_items]
        try:
            branch = create_branch(issue_numbers)
        except (subprocess.CalledProcessError, RuntimeError) as e:
            sys.exit(f"\nГРЕШКА при git checkout: {e}")

    # 4. Обработвам всеки item поред
    for idx, item in enumerate(all_items, 1):
        is_resume = item in review_items

        print(f"\n{'─' * 66}")
        print(f"[{idx}/{len(all_items)}] #{item['issue_number']}: {item['title']}"
              + (" [resume]" if is_resume else ""))
        print(f"{'─' * 66}")

        if not is_resume:
            # → In Progress (само за нови items)
            try:
                move_item_status(
                    meta["project_id"], item["item_id"],
                    meta["status_field_id"], options[STATUS_IN_PROGRESS], STATUS_IN_PROGRESS,
                )
            except RuntimeError as e:
                sys.exit(f"\nГРЕШКА: {e}")

        review_feedback: str | None = None
        task_done = False

        for attempt in range(1, MAX_RETRIES + 1):
            print(f"\n  ── Опит {attempt}/{MAX_RETRIES} ──")

            # ── Dev агент (пропускаме при resume на първи опит) ──
            if is_resume and attempt == 1:
                print(f"  ↩ Resume — пропускам Dev агент, директно към ревю")
            else:
                try:
                    run_dev_agent(item, api_key, review_feedback)
                except RuntimeError as e:
                    print(f"\nГРЕШКА (Dev агент): {e}", file=sys.stderr)
                    print(
                        f"Item #{item['issue_number']} остава в «{STATUS_IN_PROGRESS}».\n"
                        "Провери ръчно.",
                        file=sys.stderr,
                    )
                    sys.exit(2)

            if not (is_resume and attempt == 1):
                # → In Review
                try:
                    move_item_status(
                        meta["project_id"], item["item_id"],
                        meta["status_field_id"], options[STATUS_IN_REVIEW], STATUS_IN_REVIEW,
                    )
                except RuntimeError as e:
                    sys.exit(f"\nГРЕШКА: {e}")

            # Stage всички промени преди ревюто
            git_stage_all()
            staged = get_staged_files()

            if not staged:
                print("  ⚠ Dev агентът не е направил промени — третирам като FAIL")
                review_feedback = (
                    "Dev агентът не е направил никакви промени по файловете. "
                    "Задачата не е имплементирана."
                )
                git_unstage_all()
                if attempt < MAX_RETRIES:
                    try:
                        move_item_status(
                            meta["project_id"], item["item_id"],
                            meta["status_field_id"],
                            options[STATUS_IN_PROGRESS], STATUS_IN_PROGRESS,
                        )
                    except RuntimeError as e:
                        sys.exit(f"\nГРЕШКА: {e}")
                continue

            # ── Тест suite ──
            print(f"  → Стартирам тест suite…")
            test_passed, test_output = run_test_suite()
            print(f"  {'✓' if test_passed else '✗'} Тестове: {'PASS' if test_passed else 'FAIL'}")

            # ── Review агент ──
            try:
                passed, review_feedback = run_review_agent(
                    item, staged, test_passed, test_output, api_key,
                )
            except RuntimeError as e:
                print(f"\nГРЕШКА (Review агент): {e}", file=sys.stderr)
                git_unstage_all()
                sys.exit(2)

            if passed:
                # ── Commit + push ──
                try:
                    git_commit_and_push(item["issue_number"], item["title"], branch)
                except subprocess.CalledProcessError as e:
                    sys.exit(f"\nГРЕШКА при git commit/push: {e}")

                # → Done (явно чрез API; `closes #N` в commit затваря issue при merge)
                try:
                    move_item_status(
                        meta["project_id"], item["item_id"],
                        meta["status_field_id"], options[STATUS_DONE], STATUS_DONE,
                    )
                except RuntimeError as e:
                    sys.exit(f"\nГРЕШКА при местене в Done: {e}")

                print(f"  ✓ #{item['issue_number']} завършен успешно!")
                task_done = True
                break

            else:
                # ── Review FAIL → unstage, обратно In progress ──
                git_unstage_all()
                if attempt < MAX_RETRIES:
                    print(f"  ↩ Връщам в «{STATUS_IN_PROGRESS}» за поправка…")
                    try:
                        move_item_status(
                            meta["project_id"], item["item_id"],
                            meta["status_field_id"],
                            options[STATUS_IN_PROGRESS], STATUS_IN_PROGRESS,
                        )
                    except RuntimeError as e:
                        sys.exit(f"\nГРЕШКА: {e}")

        if not task_done:
            print(
                f"\n✗ #{item['issue_number']} не мина ревю след {MAX_RETRIES} опита.\n"
                f"  Item остава в «{STATUS_IN_REVIEW}».\n"
                "  Провери ръчно, поправи и пусни скрипта отново.",
                file=sys.stderr,
            )
            sys.exit(3)

    # 5. Финален summary
    print(f"\n{'=' * 66}")
    print(f"  ✓ Всички {len(ready_items)} задачи завършени успешно!")
    print(f"  Бранч: {branch}")
    print()
    print("  Следваща стъпка:")
    print("    Провери бранча → отвори PR → мърджни към main.")
    print("    GitHub затваря issues (closes #N) → Projects → Done.")
    print(f"{'=' * 66}")


if __name__ == "__main__":
    main()
