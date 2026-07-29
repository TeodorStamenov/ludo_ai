#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# Изисква Python 3.10+. Виж tools/README.md.
"""
finish_task.py — приключва един GitHub Project item от текущия batch с една
команда: (In progress, ако вече не е) → import/scene checks → commit+push →
Done.

За разлика от board_runner.py/claude_board_runner.py, не пуска dev агент —
implementer-ът (Claude Code в текущата сесия, или човек) вече е направил
промените. Скриптът само automate-ва bookkeeping-а: git stage/checks/
commit/push + GitHub Projects Status. "closes #N" в commit съобщението
затваря issue-то едва при merge в main — Status→Done тук е отделен, изричен
API call (GitHub не мести Project Status сам).

УПОТРЕБА:
  python tools/finish_task.py <issue_number> "<commit title>"

Изисква PROJECT_NUMBER в средата/tools/.env, работно дърво с staged-able
промени за тази задача, и активен git бранч (не се грижи за branch checkout —
това е стъпка веднъж на batch, виж board_runner.py/checkout_main_and_pull).
"""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import pipeline_common as pc  # noqa: E402

pc.ensure_venv(__file__)
pc.load_dotenv()


def main() -> None:
    if len(sys.argv) != 3:
        sys.exit("Употреба: python tools/finish_task.py <issue_number> \"<commit title>\"")
    try:
        issue_number = int(sys.argv[1])
    except ValueError:
        sys.exit(f"ГРЕШКА: issue_number трябва да е цяло число, получено: '{sys.argv[1]}'")
    title = sys.argv[2]

    project_number = pc.require_project_number(False)
    meta = pc.get_project_metadata(project_number)
    options = meta["options"]
    for needed in [pc.STATUS_READY, pc.STATUS_IN_PROGRESS, pc.STATUS_DONE]:
        if needed not in options:
            sys.exit(f"ГРЕШКА: статус «{needed}» липсва в проекта.")

    by_status = pc.get_items_by_statuses(
        meta["project_id"], meta["status_field_id"],
        [pc.STATUS_READY, pc.STATUS_IN_PROGRESS],
    )
    item = next(
        (it for status in by_status.values() for it in status
         if it["issue_number"] == issue_number),
        None,
    )
    if item is None:
        sys.exit(
            f"ГРЕШКА: #{issue_number} не е в «{pc.STATUS_READY}» или "
            f"«{pc.STATUS_IN_PROGRESS}» — провери board-а."
        )

    if item in by_status[pc.STATUS_READY]:
        pc.move_item_status(
            meta["project_id"], item["item_id"], meta["status_field_id"],
            options[pc.STATUS_IN_PROGRESS], pc.STATUS_IN_PROGRESS,
        )

    pc.git_stage_all()
    if not pc.get_staged_files():
        sys.exit(
            f"ГРЕШКА: няма staged промени за #{issue_number}. Item остава в "
            f"«{pc.STATUS_IN_PROGRESS}» — направи промените и пусни отново."
        )

    print("  → Import check…")
    import_ok, import_out = pc.run_import_check()
    if not import_ok:
        print("  ✗ Import FAIL:")
        for ln in import_out.splitlines()[-15:]:
            print(f"    {ln}")
        pc.git_unstage_all()
        sys.exit(f"ГРЕШКА: import check провали за #{issue_number}.")
    print("  ✓ Import OK")

    print("  → Scene load check…")
    scene_ok, scene_out = pc.run_scene_load_check()
    if not scene_ok:
        print("  ✗ Scene load FAIL:")
        for ln in scene_out.splitlines()[-15:]:
            print(f"    {ln}")
        pc.git_unstage_all()
        sys.exit(f"ГРЕШКА: scene load check провали за #{issue_number}.")
    print("  ✓ Scene load OK")

    branch = pc.current_branch()
    pc.git_commit_and_push(issue_number, title, branch)

    pc.move_item_status(
        meta["project_id"], item["item_id"], meta["status_field_id"],
        options[pc.STATUS_DONE], pc.STATUS_DONE,
    )
    print(f"  ✓ #{issue_number} завършен успешно!")


if __name__ == "__main__":
    main()
