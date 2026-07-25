# tools/board_runner.py

Автоматизиран **Dev + Review pipeline** за GitHub Projects v2.

## Поток

```
За всяка задача в «Ready»:

  Ready ──► In Progress
              │
              ▼
         [Dev агент]          (claude-sonnet-4-6)
              │
              ▼
           In Review
              │
              ▼
         [Review агент]        (claude-sonnet-5-thinking-high)
              │
         ┌───┴───────────────────────────────────┐
         │ PASS                                   │ FAIL (до 3 пъти)
         ▼                                        ▼
    commit + push                         ↩ In Progress
    Done (API)                             Dev агент + feedback
    следваща задача
```

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
```

---

## Конфигурация

| Константа      | Стойност по подразбиране           | Env var         |
|----------------|------------------------------------|-----------------|
| Dev модел      | `claude-sonnet-4-6`                | —               |
| Review модел   | `claude-sonnet-5-thinking-high`    | —               |
| Max retries    | 3                                  | —               |
| Godot binary   | `../../godot/godot` (от repo root) | `GODOT_BIN`     |

---

## Review критерии

Review агентът проверява три точки:

- **(A) Архитектурни правила** — layer isolation, dependency direction, `class_name` конвенция.
- **(B) Качество на кода** — типизация, коментари, минимален public API.
- **(C) Тест suite** — `godot --headless --script tests/test_runner.gd` трябва да минат всички тестове.

При FAIL: Dev агентът получава структуриран feedback и прави нов опит (до 3 общо).

---

## Exit кодове

| Код | Смисъл                                               |
|-----|------------------------------------------------------|
| 0   | Всички задачи завършени успешно                      |
| 1   | Конфигурационна/мрежова грешка (прекратяване)        |
| 2   | Агентска грешка (Dev или Review) — провери ръчно     |
| 3   | Задача не мина ревю след MAX_RETRIES — провери ръчно |
