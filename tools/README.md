# tools/board_runner.py, tools/claude_board_runner.py

Автоматизирани **Dev-only pipeline** скриптове за GitHub Projects v2 — два
взаимозаменяеми runner-а, различаващи се само по dev агента:

| Скрипт                      | Dev агент | SDK               |
|------------------------------|-----------|-------------------|
| `board_runner.py`            | Cursor    | `cursor-sdk`      |
| `claude_board_runner.py`     | Claude    | `claude-agent-sdk` |

Споделената логика (GitHub Projects GraphQL, git, import/scene/test проверки,
prompt текстове, целият orchestration loop) живее в `tools/pipeline_common.py`
— и двата скрипта я преизползват, за да не се разминава политиката между тях.

**Не пускай двата скрипта едновременно срещу един и същ `PROJECT_NUMBER`** —
и двата местят items Ready → In progress → Done по същия board; паралелно
изпълнение ще доведе до състезание за едни и същи issue-та.

## Поток (идентичен и за двата)

```
За всяка задача в «Ready» (или остатъци в «In review»):

  Ready ──► In Progress
              │
              ▼
         [Dev агент]
              │
              ▼
         Import check
         Scene load check
              │
         ┌───┴───────────────────────────────────┐
         │ OK                                     │ FAIL (до 3 пъти)
         ▼                                        ▼
    commit + push                         ↩ In Progress
    Done (API)                             Dev агент + feedback
    следваща задача

След последния таск:
  Existing test suite (веднъж) — FAIL → exit 4
```

Няма per-task Review агент. Batch code review се прави ръчно на всеки 20–30 таска.

Бранч: `feature/issues_N1_N2_N3` (един за целия batch).
Commit: `feat: <title>\n\ncloses #N` — затваря issue при merge в `main`.

---

## Инсталация (еднократно, покрива и двата скрипта)

```bash
# 1. Python 3.12 (ако не е наличен)
sudo apt-get install -y python3.12 python3.12-venv

# 2. Virtual environment
python3.12 -m venv tools/.venv
source tools/.venv/bin/activate
pip install -r tools/requirements.txt

# 3. GitHub CLI с project scopes
gh auth refresh -s read:project -s project
```

`claude-agent-sdk` носи вграден Claude Code CLI бинарник в самия пакет —
не е нужна отделна `npm install -g @anthropic-ai/claude-code` инсталация.

---

## Употреба — Cursor (`board_runner.py`)

```bash
source tools/.venv/bin/activate

export CURSOR_API_KEY="cursor_..."          # от cursor.com/dashboard/integrations
export PROJECT_NUMBER=N                     # числото от GitHub Projects URL

# По желание — ако Godot не е на стандартното място:
export GODOT_BIN=/path/to/godot

python tools/board_runner.py
# или: python tools/board_runner.py --dry-run
```

Credentials могат да са и в `tools/.env` (`CURSOR_API_KEY`, `PROJECT_NUMBER`, `GODOT_BIN`).

## Употреба — Claude (`claude_board_runner.py`)

```bash
source tools/.venv/bin/activate

export ANTHROPIC_API_KEY="sk-ant-..."       # от console.anthropic.com
export PROJECT_NUMBER=N                     # числото от GitHub Projects URL
export GODOT_BIN=/path/to/godot             # по желание

python tools/claude_board_runner.py
# или: python tools/claude_board_runner.py --dry-run
```

Credentials могат да са и в `tools/.env` (`ANTHROPIC_API_KEY`, `PROJECT_NUMBER`, `GODOT_BIN`).

---

## Конфигурация

| Константа    | board_runner.py       | claude_board_runner.py | Env var     |
|--------------|------------------------|-------------------------|-------------|
| Dev модел    | `claude-sonnet-5`     | `claude-sonnet-5`       | —           |
| Max retries  | 3                      | 3                        | —           |
| Godot binary | `../../godot` (от repo root → бинарникът) | същото | `GODOT_BIN` |

---

## Проверки

**След всеки таск:**
1. **Import** — `godot --headless --import`
2. **Scene load** — `tests/scene_load_test.gd` (главната сцена)

**Веднъж в края на batch-а:**
3. **Existing suite** — regression gate

Test policy в Dev prompt: само business-critical game logic; без UI/DTO/getters/тривиални helpers.

---

## Exit кодове

| Код | Смисъл                                                    |
|-----|-----------------------------------------------------------|
| 0   | Всички задачи завършени успешно                           |
| 1   | Конфигурационна/мрежова грешка (прекратяване)             |
| 2   | Агентска грешка (Dev) — провери ръчно                     |
| 3   | Задача не мина Import/Scene след MAX_RETRIES              |
| 4   | Batch test suite FAIL в края — не мърджвай преди fix      |
