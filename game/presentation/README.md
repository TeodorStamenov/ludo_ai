# game/presentation/

Godot сцени, изгледи, анимации, звук и input — Presentation слоят,
съгласно `docs/V1_ARCHITECTURE.md` (раздели 6 и 13).

## Правило за зависимости

Presentation **може** да импортира от `game/application/` и `game/domain/`  
(read-only view models и command типове).  
**Не изпраща команди директно към GameEngine** — само към MatchSession.  
**Не мести пионки самостоятелно** — анимира само след получен DomainEvent.

## Структура

| Директория       | Съдържание |
|---|---|
| `game_screen/`   | GameScreen, GamePresenter, BoardView, PawnView, DiceView, GiftView, HUD |
| `menus/`         | Main Menu, Match Setup, Campaign, Results, Settings |
| `common/`        | AnimationQueue, AnimationFinishedGate, EventViewBinder, AudioFeedback, HapticFeedback |

## Ключов договор

```text
MatchSession.events_published(sequence, events)
    → GamePresenter → AnimationQueue.play_batch
    → EventViewBinder.present_for_playback(event)  (последователен await)
          → DiceView / PawnView / HUD …
    → AnimationQueue.all_done(sequence)
    → GamePresenter → MatchSession.events_presented(sequence)
```

Domain не чака tween. Presentation потвърждава след всяка анимация:
`AnimationQueue.play_batch` → `EventViewBinder.present_for_playback` (#168) →
`AnimationFinishedGate` чака `animation_finished(kind)` (#169) → `all_done` →
`events_presented`.

`ValidMovesChanged` (#170 / YEL-020): след `DiceRolled` binder/presenter вика
`PawnView.show_valid_move()` само за `valid_pawn_ids` (human seats); празен
списък изчиства bob-а. Невалидните пионки не подскачат.

`PawnMoved` (#171 / YEL-023): кликът праща само `MovePawnCommand`; визуалното
движение тръгва едва след приет команда → `PawnMovedEvent`.
Отхвърлена команда → `command_rejected` → input се възстановява, пионката
стои. Hop клетка по клетка по маршрута (#172 / YEL-040); `KIND_MOVE` едва
след последната клетка.

`PawnExitedBase` (#173 / YEL-030): hop от базовата клетка към spawn след
приет `MovePawnCommand` при 6; `KIND_MOVE` след кацане. Busy pawn → snap.

## .tscn сцени

Сцените (`.tscn` файлове) се създават в Godot Editor.  
`.gd` скриптовете тук са scaffold с документирани отговорности.
