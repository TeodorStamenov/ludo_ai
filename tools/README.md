# tools/board_runner.py

Автоматизиран **Dev-only pipeline** за GitHub Projects v2.

## Поток

```
За всяка задача в «Ready» (или остатъци в «In review»):

  Ready ──► In Progress
              │
              ▼
         [Dev агент]          (grok-4.5)
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

## Инсталация (еднократно)

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

---

## Употреба

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

---

## Конфигурация

| Константа    | Стойност по подразбиране           | Env var     |
|--------------|------------------------------------|-------------|
| Dev модел    | `grok-4.5`                         | —           |
| Max retries  | 3                                  | —           |
| Godot binary | `../../godot` (от repo root → бинарникът) | `GODOT_BIN` |

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
