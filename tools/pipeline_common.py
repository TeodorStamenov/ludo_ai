#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# Изисква Python 3.10+. Виж tools/README.md.
"""
pipeline_common.py — споделена GitHub Projects / git / checks / prompt логика
за board_runner.py (Cursor) и claude_board_runner.py (Claude).

Чист stdlib модул (без трети library) — importable извън tools/.venv, за да
може ensure_venv() да се извика от тънките agent-специфични скриптове преди
да импортират cursor_sdk / claude_agent_sdk.

Cursor- и Claude-специфичното (агент invocation, model константа, API key
проверка) остава в съответния тънък скрипт; тук е всичко останало, което
двата споделят: GitHub Projects v2 GraphQL, git helpers, import/scene/test
проверки, prompt текстове и целият orchestration loop (run_pipeline).
"""

from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path
from typing import Callable

# ── venv / dotenv bootstrap ──────────────────────────────────────────────────

def ensure_venv(script_file: str) -> None:
    """Ако не тече под tools/.venv/bin/python, рестартира себе си с него."""
    venv_root = Path(__file__).resolve().parent / ".venv"
    venv_python = (
        venv_root / "Scripts" / "python.exe"
        if sys.platform == "win32"
        else venv_root / "bin" / "python"
    )
    if sys.version_info < (3, 10):
        if venv_python.exists():
            sys.exit(subprocess.run([str(venv_python), script_file] + sys.argv[1:]).returncode)
        sys.exit(
            "ГРЕШКА: Нужен е Python 3.10+. Текуща версия: %s\n"
            "Създай venv: python3.12 -m venv tools/.venv && "
            "pip install -r tools/requirements.txt" % sys.version
        )
    if venv_python.exists() and Path(sys.executable).resolve() != venv_python.resolve():
        sys.exit(subprocess.run([str(venv_python), script_file] + sys.argv[1:]).returncode)


def load_dotenv() -> None:
    """Зарежда tools/.env автоматично (ако съществува)."""
    env_file = Path(__file__).resolve().parent / ".env"
    if not env_file.exists():
        return
    try:
        from dotenv import load_dotenv as _load_dotenv
        _load_dotenv(env_file, override=False)
    except ImportError:
        with open(env_file, encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith("#") or "=" not in line:
                    continue
                key, _, val = line.partition("=")
                key = key.strip()
                val = val.strip().strip('"').strip("'")
                os.environ.setdefault(key, val)


# ── Константи ──────────────────────────────────────────────────────────────────

REPO_OWNER = "TeodorStamenov"

MAX_RETRIES = 3

STATUS_READY       = "Ready"
STATUS_IN_PROGRESS = "In progress"
STATUS_IN_REVIEW   = "In review"
STATUS_DONE        = "Done"

PROJECT_ROOT = Path(__file__).resolve().parent.parent

# Godot binary — override чрез GODOT_BIN env var.
# Layout: <godot-root>/godot (binary), <godot-root>/projects/<repo>.
_default_godot = PROJECT_ROOT.parent.parent / "godot"
GODOT_BIN = Path(os.environ.get("GODOT_BIN", str(_default_godot)))
TEST_SCRIPT = "tests/test_runner.gd"

MAIN_BRANCH = "main"


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


def get_items_by_statuses(
    project_id: str,
    status_field_id: str,
    statuses: list[str],
) -> dict[str, list[dict]]:
    """Връща project items групирани по статус (с pagination — board-ът >100 items)."""
    query = """
    query($projectId: ID!, $cursor: String) {
      node(id: $projectId) {
        ... on ProjectV2 {
          items(first: 100, after: $cursor) {
            pageInfo { hasNextPage endCursor }
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
    wanted = set(statuses)
    result: dict[str, list[dict]] = {s: [] for s in statuses}
    cursor = None
    while True:
        data = gh_graphql(query, {"projectId": project_id, "cursor": cursor})
        connection = data["data"]["node"]["items"]
        for item in connection["nodes"]:
            status_name = None
            for fv in item["fieldValues"]["nodes"]:
                if fv.get("field", {}).get("id") == status_field_id:
                    status_name = fv.get("name")
                    break
            if status_name not in wanted:
                continue
            issue = item.get("content") or {}
            if not issue.get("number"):
                continue
            result[status_name].append({
                "item_id":      item["id"],
                "issue_number": issue["number"],
                "title":        issue["title"],
                "body":         issue.get("body", ""),
                "url":          issue.get("url", ""),
            })
        page = connection["pageInfo"]
        if not page.get("hasNextPage"):
            break
        cursor = page.get("endCursor")
    return result


def get_items_by_status(project_id: str, status_field_id: str, status: str) -> list[dict]:
    """Връща всички project items с даден статус (paginated)."""
    return get_items_by_statuses(project_id, status_field_id, [status])[status]


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

def run_import_check() -> tuple[bool, str]:
    """
    Ниво 2: godot --headless --import
    Хваща broken resources, липсващи файлове, import грешки.
    Бърза проверка преди Review агента (~5s).
    """
    if not GODOT_BIN.exists():
        return False, (
            f"Godot не е намерен на {GODOT_BIN}.\n"
            "Задай GODOT_BIN=/path/to/godot env var."
        )
    try:
        result = subprocess.run(
            [str(GODOT_BIN), "--headless", "--import"],
            cwd=PROJECT_ROOT, capture_output=True, text=True,
            encoding="utf-8", timeout=60,
        )
    except subprocess.TimeoutExpired:
        return False, "ГРЕШКА: godot --import надхвърли timeout от 60s."
    output = (result.stdout + result.stderr).strip()
    return result.returncode == 0, output


def run_scene_load_check() -> tuple[bool, str]:
    """
    Ниво 3: godot --headless --script tests/scene_load_test.gd
    Хваща @onready crashes, missing nodes, script грешки при load на главната сцена (~1s).
    """
    if not GODOT_BIN.exists():
        return False, (
            f"Godot не е намерен на {GODOT_BIN}.\n"
            "Задай GODOT_BIN=/path/to/godot env var."
        )
    try:
        result = subprocess.run(
            [str(GODOT_BIN), "--headless", "--script", "tests/scene_load_test.gd"],
            cwd=PROJECT_ROOT, capture_output=True, text=True,
            encoding="utf-8", timeout=30,
        )
    except subprocess.TimeoutExpired:
        return False, "ГРЕШКА: scene load надхвърли timeout от 30s."
    output = (result.stdout + result.stderr).strip()
    return result.returncode == 0, output


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
АРХИТЕКТУРНИ ПРАВИЛА (задължителни):
- game/domain/     → само `extends RefCounted`. Никога Node/сцени.
                     Не импортира от application/, presentation/, platform/, app/.
- game/application/→ може да импортира от game/domain/ и content/ САМО.
                     Не импортира от game/presentation/.
- game/presentation/→ може да използва Node/Control/Node2D.
                     Не прилага gameplay правила, не извиква GameEngine директно.
- Dependency посока: Presentation → Application → Domain (стрелките навътре).
- Всеки нов .gd файл: `class_name` в PascalCase, съответстващ на filename.
"""

_TEST_POLICY = """\
ПОЛИТИКА ЗА ТЕСТОВЕ (MVP — speed over coverage):
- Пиши тестове САМО за business-critical game logic
  (правила за ход, capture, win, валидация с реални инварианти).
- НЕ пиши unit тестове за: UI, прости модели/DTO, getters/setters,
  wrappers, тривиални helpers, serialization round-trips без бизнес правило.
- Ако задачата е само модел/DTO/конфиг без критична логика → без нови тестове.
- Нови тестове (ако изобщо) САМО в tests/unit/domain/.
- Stub / Null / Adapter не се тестват.
- Приоритизирай имплементацията и playable MVP пред exhaustive coverage.
"""

_QUALITY_RULES = """\
ПРАВИЛА ЗА КАЧЕСТВО НА КОДА:
- Без коментари, преразказващи какво прави кодът ред по ред.
- Коментари само за неочевидно намерение, trade-offs или ограничения.
- Типизирани параметри и return типове навсякъде.
- StringName (&"...") за стабилни идентификатори, не обикновен String.
- Публичният API на клас е минимален — само необходимото за потребителите.
"""


def build_dev_prompt(item: dict, retry_feedback: str | None = None) -> str:
    """Съставя dev агент prompt-а за даден project item. Споделено между
    Cursor и Claude runner-ите, за да не се разминава политиката."""
    feedback_block = ""
    if retry_feedback:
        feedback_block = f"""
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
ПРЕДИШНИЯТ ОПИТ ПРОВАЛИ ПРОВЕРКИТЕ — ТРЯБВА ДА ПОПРАВИШ:

{retry_feedback}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
"""

    return f"""{_PROJECT_CONTEXT}
{_ARCH_RULES}
{_TEST_POLICY}
{_QUALITY_RULES}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
ЗАДАЧА #{item['issue_number']}: {item['title']}
{item['url']}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

{item['body'].strip() if item['body'] else '(Виж заглавието.)'}
{feedback_block}
ИНСТРУКЦИИ:
1. Прочети релевантния раздел от docs/V1_ARCHITECTURE.md.
2. Имплементирай задачата изцяло — приоритет: playable MVP, не exhaustive tests.
3. Следвай ПОЛИТИКА ЗА ТЕСТОВЕ — не генерирай тривиални тестове.
4. Не създавай .tscn файлове освен ако задачата изрично го изисква.
5. Не питай за потвърждение — имплементирай всичко в един pass.
6. Накрая напиши кратко резюме (1–3 изречения) на направеното.
"""


# ── Предварителни проверки ─────────────────────────────────────────────────────

def require_project_number(dry_run: bool = False) -> int:
    """Чете и валидира PROJECT_NUMBER env var. Агент-специфичните API key
    проверки остават в съответния тънък скрипт."""
    pn = os.environ.get("PROJECT_NUMBER", "").strip()
    if not pn:
        if dry_run:
            return 0
        sys.exit(
            "ГРЕШКА: PROJECT_NUMBER не е зададен\n"
            "  (числото от URL-а: github.com/users/TeodorStamenov/projects/N)"
        )
    try:
        return int(pn)
    except ValueError:
        sys.exit(f"ГРЕШКА: PROJECT_NUMBER трябва да е цяло число, получено: '{pn}'")


# ── Main pipeline ────────────────────────────────────────────────────────────────

def run_pipeline(
    *,
    dry_run: bool,
    project_number: int,
    dev_agent_label: str,
    run_dev_agent: Callable[[dict, str | None], None],
) -> None:
    """
    Цялата orchestration логика (project metadata → items по статус → branch
    → per-item retry loop → commit/push → status move → batch test suite →
    summary), агностична спрямо кой агент имплементира задачите.

    run_dev_agent(item, retry_feedback) трябва да хвърля RuntimeError при
    провал на самия агент (не при провалени import/scene checks — тези се
    обработват тук чрез retry_feedback на следващия опит).
    """
    if dry_run:
        print("\n  [DRY-RUN] Само четене — без агенти, без git, без GitHub статуси.\n")

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
        by_status = get_items_by_statuses(
            meta["project_id"],
            meta["status_field_id"],
            [STATUS_IN_REVIEW, STATUS_READY],
        )
        review_items = by_status[STATUS_IN_REVIEW]
        ready_items = by_status[STATUS_READY]
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

    all_items = review_items + ready_items

    if dry_run:
        issue_numbers = [it["issue_number"] for it in all_items]
        branch_name = f"feature/issues_{'_'.join(str(n) for n in issue_numbers)}"
        print(f"\n[DRY-RUN] Бранч, който би се създал: {branch_name}")
        print(f"[DRY-RUN] Items за обработка: {len(all_items)}")
        for it in all_items:
            tag = "[resume]" if it in review_items else "[нов]"
            print(f"  {tag} #{it['issue_number']}: {it['title']}")
        print("\n[DRY-RUN] Без реални промени. Края.")
        return

    # 3. Бранч — при resume ползваме текущия; при нови batch: pull main + нов бранч
    print(f"\n▸ Бранч…")
    if review_items and not ready_items:
        branch = current_branch()
        print(f"  ✓ Текущ бранч (resume): {branch}")
    else:
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

        try:
            move_item_status(
                meta["project_id"], item["item_id"],
                meta["status_field_id"], options[STATUS_IN_PROGRESS], STATUS_IN_PROGRESS,
            )
        except RuntimeError as e:
            sys.exit(f"\nГРЕШКА: {e}")

        retry_feedback: str | None = None
        task_done = False

        for attempt in range(1, MAX_RETRIES + 1):
            print(f"\n  ── Опит {attempt}/{MAX_RETRIES} ──")

            if is_resume and attempt == 1 and retry_feedback is None:
                print("  ↩ Resume — пропускам Dev агент, директно към проверки")
            else:
                try:
                    run_dev_agent(item, retry_feedback)
                except RuntimeError as e:
                    print(f"\nГРЕШКА ({dev_agent_label}): {e}", file=sys.stderr)
                    print(
                        f"Item #{item['issue_number']} остава в «{STATUS_IN_PROGRESS}».\n"
                        "Провери ръчно.",
                        file=sys.stderr,
                    )
                    sys.exit(2)

            git_stage_all()
            staged = get_staged_files()

            if not staged:
                print("  ⚠ Dev агентът не е направил промени — третирам като FAIL")
                retry_feedback = (
                    "Dev агентът не е направил никакви промени по файловете. "
                    "Задачата не е имплементирана."
                )
                git_unstage_all()
                continue

            # ── Import check ──
            print("  → Import check…")
            import_ok, import_out = run_import_check()
            if not import_ok:
                print("  ✗ Import FAIL — счупени ресурси:")
                for ln in import_out.splitlines()[-15:]:
                    print(f"    {ln}")
                retry_feedback = (
                    "Godot import check провали след промените — счупени или липсващи ресурси.\n"
                    f"Изход:\n{import_out[-800:]}"
                )
                git_unstage_all()
                continue
            print("  ✓ Import OK")

            # ── Scene load check ──
            print("  → Scene load check…")
            scene_ok, scene_out = run_scene_load_check()
            if not scene_ok:
                print("  ✗ Scene load FAIL — главната сцена крашва:")
                for ln in scene_out.splitlines()[-15:]:
                    print(f"    {ln}")
                retry_feedback = (
                    "Scene load check провали: главната сцена крашва при зареждане headless.\n"
                    f"Изход:\n{scene_out[-800:]}"
                )
                git_unstage_all()
                continue
            print("  ✓ Scene load OK")

            # ── Commit + push → Done (test suite е само в края на batch-а) ──
            try:
                git_commit_and_push(item["issue_number"], item["title"], branch)
            except subprocess.CalledProcessError as e:
                sys.exit(f"\nГРЕШКА при git commit/push: {e}")

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

        if not task_done:
            print(
                f"\n✗ #{item['issue_number']} не мина проверките след {MAX_RETRIES} опита.\n"
                f"  Item остава в «{STATUS_IN_PROGRESS}».\n"
                "  Провери ръчно, поправи и пусни скрипта отново.",
                file=sys.stderr,
            )
            sys.exit(3)

    # 5. Test suite — веднъж след целия batch
    print(f"\n▸ Batch test suite (след {len(all_items)} задачи)…")
    test_passed, test_output = run_test_suite()
    if not test_passed:
        print("  ✗ Тестове: FAIL", file=sys.stderr)
        for ln in test_output.splitlines()[-30:]:
            print(f"    {ln}", file=sys.stderr)
        print(
            f"\nГРЕШКА: Test suite провали след batch-а.\n"
            f"  Бранч: {branch}\n"
            "  Задачите са в Done, но не мърджвай преди да поправиш тестовете.",
            file=sys.stderr,
        )
        sys.exit(4)
    print("  ✓ Тестове: PASS")

    # 6. Финален summary
    print(f"\n{'=' * 66}")
    print(f"  ✓ Всички {len(all_items)} задачи завършени успешно!")
    print(f"  Бранч: {branch}")
    print()
    print("  Следваща стъпка:")
    print("    Провери бранча → отвори PR → мърджни към main.")
    print("    Batch code review: ръчно на всеки 20–30 таска.")
    print(f"{'=' * 66}")
