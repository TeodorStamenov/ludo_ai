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
| `common/`        | AnimationQueue, AudioFeedback, HapticFeedback |

## Ключов договор

```text
MatchSession.events_published(sequence, events)
    → GamePresenter → AnimationQueue (проиграва последователно)
    → AnimationQueue.all_done(sequence)
    → GamePresenter → MatchSession.events_presented(sequence)
```

Domain не чака tween. Presentation потвърждава след всяка анимация.

## .tscn сцени

Сцените (`.tscn` файлове) се създават в Godot Editor.  
`.gd` скриптовете тук са scaffold с документирани отговорности.
