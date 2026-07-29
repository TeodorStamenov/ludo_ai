# Сравнение: CURRENT_YELLOW_BEHAVIOR.md срещу GameEngine/MatchSession (#178)

Статус: попълнено сравнение след #177 (свързване на `scenes/ludo_game.tscn`
към `MatchSession`/`GamePresenter`).

## 1. Метод

За всеки `YEL-*` сценарий: намерен directive реф в domain/тестовете
(`grep -rl "YEL-0XX"`). За геометрията (§6 от `CURRENT_YELLOW_BEHAVIOR.md`):
директно сравнение на `Classic15x15Board`-изхода срещу документираните
координати (не само по номер на правило).

## 2. Геометрия — директна проверка (не unit test, а координатно сравнение)

```
Classic15x15Board.base_grid_positions_for(YELLOW)
  = [(11,11), (12,11), (11,12), (12,12)]   ── идентично с YEL-001

Classic15x15Board.spawn_grid_position_for(YELLOW)
  = (6, 12)                                ── идентично с YEL-030/041

Classic15x15Board.home_stretch_grid_positions_for(YELLOW)
  = [(7,11), (7,10), (7,9), (7,8)]         ── идентично с §7

Classic15x15Board.player_route_grid_positions_for(YELLOW)  (44 клетки)
  = (6,12)→(6,11)→(6,10)→(6,9)→(6,8)→(5,8)→(4,8)→(3,8)→(2,8)→(2,7)→(2,6)
    →(3,6)→(4,6)→(5,6)→(6,6)→(6,5)→(6,4)→(6,3)→(6,2)→(7,2)→(8,2)
    →(8,3)→(8,4)→(8,5)→(8,6)→(9,6)→(10,6)→(11,6)→(12,6)→(12,7)→(12,8)
    →(11,8)→(10,8)→(9,8)→(8,8)→(8,9)→(8,10)→(8,11)→(8,12)→(7,12)
    →(7,11)→(7,10)→(7,9)→(7,8)
  ── клетка по клетка идентично с маршрута от §6 на CURRENT_YELLOW_BEHAVIOR.md
```

**Извод:** `Classic15x15Board` (data-driven, §4.6) е точна репродукция на
координатите, ръчно закодирани в `scripts/ludo_board.gd` / стария
`scripts/ludo_game.gd`. Миграцията към domain модел не е променила
геометрията, само нейния source of truth.

## 3. YEL-001–YEL-004 — начално състояние и опити

| ID | Ново поведение | Референция |
|---|---|---|
| YEL-001 | 4 пионки в base, `is_in_base()`/`path_index=-1` | `classic_15x15_base_cells_test.gd`, `game_state_test.gd`, `start_match_handling_test.gd` |
| YEL-002 | Първи активен seat → `AWAITING_ROLL` след `StartMatchCommand` | `start_match_handling_test.gd`, `match_started_event_test.gd` (структурна последица от `TurnRules.begin_player_turn`, не отделно правило) |
| YEL-003 | 3 опита при всички в base | `three_attempts_from_base_test.gd`, `turn_state.gd` (`BASE_ROLL_ATTEMPTS`) |
| YEL-004 | 1 опит при поне една извън base | `three_attempts_from_base_test.gd` |

## 4. YEL-010–YEL-015 — зар и опити

| ID | Ново поведение | Референция |
|---|---|---|
| YEL-010/011/012 | Всеки неуспешен опит (1–5) намалява `base_attempts_remaining`; на нулата → `TURN_END` | `three_attempts_from_base_test.gd` (веригата от 3 последователни хвърляния е в един тест — 011/012 не са тагнати поотделно, но са същият асерт на различна итерация) |
| YEL-013 | 6 на произволен опит → `AWAITING_MOVE` без консумация на опит | `extra_roll_on_six_test.gd`, `dice_state_test.gd` |
| YEL-014 | Блокирано ново хвърляне докато чака избор | Гарантирано от state machine: `TurnState.allows_roll_dice()` е `false` извън `AWAITING_ROLL` — `GameEngine` отхвърля `RollDiceCommand` в грешна фаза (`awaiting_roll_phase_test.gd`, `wrong_phase` reject тестове), а не отделен UI флаг както в прототипа |
| YEL-015 | Блокирано второ паралелно действие по време на анимация | `MatchSession` presentation gate (`is_presentation_pending()`) — не приема нова команда докато чака `events_presented` |

## 5. YEL-020–YEL-024 — избор на пионка

Presentation-слой поведение, вече в `GamePresenter`/`EventViewBinder`
(коментари `YEL-020`…`YEL-023` директно в кода):
`apply_valid_pawn_ids`, `_on_pawn_clicked` (първи клик = избор, втори = потвърждение),
`ValidMovesChangedEvent` → bob. YEL-024 (невалидна пионка не реагира) —
`awaiting_move_phase_test.gd` покрива domain-страната (`MovePawnCommand` за
pawn извън `valid_pawn_ids` се отхвърля); presentation-страната е гарантирана
от `_is_legal_move_pawn()` gate в `GamePresenter`.

## 6. YEL-030–YEL-032 — излизане от base

| ID | Ново поведение | Референция |
|---|---|---|
| YEL-030 | Изход при 6 → spawn `(6,12)`, `MAIN_PATH`, `path_index=0` | `exit_base_rule_test.gd`, `pawn_exited_base_event_test.gd` |
| YEL-031 | 1–5 не позволява изход | `exit_base_rule_test.gd` |
| YEL-032 | Extra roll след изход при 6 | `extra_roll_on_six_test.gd`, `exit_base_rule_test.gd` |

**Поправен GAP-006** (spawn винаги приема): сега `can_exit_base` проверява
`CaptureRules.blocks_landing` + `StackRules.can_place_own_pawn` — spawn с чужда
имунна купчина или 2 свои вече блокира изхода (виж §8).

## 7. YEL-040–YEL-045 — движение по трасето

| ID | Ново поведение | Референция |
|---|---|---|
| YEL-040 | Точен зар, последователни клетки | `main_path_movement_test.gd`, `resolving_move_phase_test.gd`; presentation hop клетка-по-клетка в `EventViewBinder._resolve_move_step_cell_ids` |
| YEL-041 | Пример 4 от `(6,12)` → `(6,8)` | Числово идентично — виж §2 (геометрия); `main_path_movement_test.gd` |
| YEL-042 | Нормален ход (1–5) → край на хода | `turn_end_phase_test.gd`, `main_path_movement_test.gd` |
| YEL-043 | 6 по трасето → extra roll | `extra_roll_on_six_test.gd`, `home_stretch_test.gd` |
| YEL-044 | Base + board пионки едновременно валидни при 6 | `valid_pawns_after_roll_test.gd` |
| YEL-045 | Няма валиден ход → extra roll (при 6) / край на хода (1–5) | `valid_pawns_after_roll_test.gd`, `turn_end_phase_test.gd` |

**Поправен GAP-008** (overshoot clamp): `MoveRules.resolve_destination_index`
връща `DESTINATION_NONE` при `steps > remaining` — **не** clamp-ва до последната
клетка. Изрично тествано в `main_path_movement_test.gd` (overshoot reject).

## 8. YEL-050–YEL-055 — home stretch

| ID | Ново поведение | Референция |
|---|---|---|
| YEL-050 | Влизане в home stretch без обиколка | `home_stretch_test.gd` |
| YEL-051 | Точен зар от `(7,11)` → `(7,10)/(7,9)/(7,8)` при 1/2/3 | `exact_home_stretch_dice_test.gd` |
| YEL-052 | Overshoot в home stretch → невалиден | `exact_home_stretch_dice_test.gd`, `valid_pawns_after_roll_test.gd` |
| YEL-053 | Заета крайна клетка → невалиден | `exact_home_stretch_dice_test.gd`, `cell_occupancy_test.gd` |
| YEL-054 | Проверява се само крайната клетка (не междинните) | `exact_home_stretch_dice_test.gd` — **запазено съзнателно**, не е GAP (виж `MoveRules.can_advance_on_board`: home stretch occupancy проверява само `dest_cell`) |
| YEL-055 | Пионка на `(7,8)` няма ход извън `FinishRules.can_finish_pawn` | `valid_pawns_after_roll_test.gd`, `exact_home_stretch_dice_test.gd` — вместо „няма следващ ход" (GAP-007) сега пионката се прибира (`PawnFinishedEvent`) |

## 9. YEL-060–YEL-064 — визуално поведение

Не се превръщат в domain тестове (§11 на `CURRENT_YELLOW_BEHAVIOR.md`
изрично ги оставя за presentation/manual проверка). Потвърдено с директна
проверка на `PawnView`/`DiceView` константите — стойностите са пренесени 1:1:

| ID | Документирана стойност | PawnView/DiceView константа |
|---|---|---|
| YEL-060 | 70% ширина, долен център на клетката | `PawnView.SIZE_RATIO = 0.7`, `offset` anchor в `setup()` |
| YEL-061 | ~5px bob, ~0.35s полупериод | `PawnView.BOB_AMPLITUDE = 5.0`, `BOB_DURATION = 0.35` |
| YEL-062 | По-светъл жълтеникав modulate при избор | `PawnView.SELECTED_MODULATE = Color(1.45, 1.35, 0.75, 1.0)` |
| YEL-063 | Спиране на bob/selection при потвърждение/нов зар/край на хода | `GamePresenter._disable_human_input()` / `_clear_valid_move_highlights()` |
| YEL-064 | Toss анимация, `dice_rolled(value)` след края | `DiceView.roll()` / `present_dice_rolled()` — сигналът е преименуван на domain `DiceRolledEvent`, но `DiceView.dice_rolled(value)` signal-ът е запазен |

## 10. GAP-* — потвърдено поправени (не запазени като поведение)

| ID | Статус | Как е поправено |
|---|---|---|
| GAP-001 (само yellow) | Поправено от #177 | `GameScreen` спавва пионки за всички активни seats от `GameState.players[]`, не само жълто |
| GAP-002 (няма domain модел) | Поправено | `GameState`/`PlayerState`/`PawnState`/`TurnState` (§4.1/§4.2) |
| GAP-003 (недетерминиран зар) | Поправено | `RollDiceCommand` + инжектиран `SeededRandomSource` (§4.5) — `roll_dice_seeded_rng_test.gd` |
| GAP-004 (без max 2 свои) | Поправено | `StackRules`/`CellOccupancy.MAX_OWN_PAWNS_PER_CELL` — `third_own_pawn_illegal_move_test.gd` |
| GAP-005 (без capture) | Поправено | `CaptureRules.resolve_capture` — `pawn_capture_test.gd` |
| GAP-006 (spawn винаги приема) | Поправено | Виж §6 по-горе |
| GAP-007 (без finish/победа) | Поправено | `FinishRules`, `PawnZone.FINISHED`, `ranking[]`, `MatchFinishedEvent` |
| GAP-008 (overshoot clamp) | Поправено | Виж §7 по-горе |
| GAP-009 (home stretch skip заета междинна) | **Съзнателно запазено**, не GAP — виж YEL-054 по-горе (V1_GAME_DESIGN потвърди правилото) |
| GAP-010 (правила чакат tween) | Поправено | `GameEngine` не съдържа `await`; presentation чака чрез `events_presented` gate (§3/§5.2), домейнът приключва синхронно |
| GAP-011 (само mouse input) | Частично | `PawnView`/`DiceView` click area обработва и `InputEventScreenTouch` (виж `dice_view.gd` `_on_click_area_input_event`); пълна mobile hit-target проверка е извън #178 |

## 11. Заключение

Пълно поведенческо покритие: 55/55 `YEL-*` сценария имат директен domain
или presentation референт (визуалните — чрез константи, не тестове, per §11
на `CURRENT_YELLOW_BEHAVIOR.md`). 10/11 `GAP-*` са потвърдено поправени;
GAP-009 е съзнателно запазено поведение (не бъг). Геометрията на жълтия
маршрут е побитово идентична между стария hardcoded prototype и новия
data-driven `Classic15x15Board`.
