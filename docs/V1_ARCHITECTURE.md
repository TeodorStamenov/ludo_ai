# Cosy Ludo — Архитектура, Версия 1

Статус: целева архитектура  
Входна спецификация: `docs/V1_GAME_DESIGN.md`  
Платформа: Godot 4, Android, офлайн v1, подготвено за авторитативен multiplayer във v2

## 1. Цели

Архитектурата трябва да:

1. поддържа пълните правила за 2–4 играчи, AI и pass-and-play;
2. отделя детерминистичната логика от сцени, input, UI и анимации;
3. представя всеки ход като валидирана команда и поредица от домейн събития;
4. сериализира целия мач за save/restore, replay и бъдещ reconnect;
5. управлява всички случайности чрез RNG със seed;
6. позволява power-ups, животни, теми и кампании да са data-driven;
7. позволява същото ядро да работи локално във v1 и авторитативно на сървър във v2;
8. бъде удобно за автоматични тестове без стартиране на Godot сцени.

## 2. Архитектурен стил

Използваме слоеста архитектура с ясно правило за зависимостите:

```text
Presentation ───────► Application ───────► Domain
     │                      │
     └────► Platform Adapters ◄──── Ports
                            │
                         Content
```

- **Domain** — чисти правила и състояние. Не познава `Node`, сцени, сигнали, input,
  анимации, файлове, реклами или Android.
- **Application** — управлява use cases: старт на мач, подаване на команда, AI ход,
  save/restore и приключване на мач.
- **Presentation** — Godot сцени, изглед на дъската, HUD, анимации, звук и input.
- **Content** — дефиниции за дъски, power-ups, животни, кампании и теми.
- **Platform adapters** — локален save, настройки, haptics, audio, rewarded ads.

Зависимостите сочат навътре. Domain никога не импортира Presentation или Platform.

## 3. Основен runtime поток

```text
Human / AI Controller
        │
        ▼
     Command
        │
        ▼
 MatchSession (Application)
        │
        ▼
 GameEngine.validate_and_apply(state, command, rng)
        │
        ├──► нов GameState
        ├──► DomainEvent[]
        └──► CommandError (при невалиден ход)
                   │
                   ▼
 GamePresenter / BoardView / HUD
                   │
                   └──► анимации, звук, haptics
```

Presentation не мести пионка самостоятелно. То изпраща команда, получава събитие
`PawnMoved` и чак тогава анимира резултата.

## 4. Domain слой

Препоръчителна директория:

```text
game/domain/
├── model/
│   ├── game_state.gd
│   ├── player_state.gd
│   ├── pawn_state.gd
│   ├── turn_state.gd
│   ├── gift_state.gd
│   └── match_result.gd
├── commands/
│   ├── game_command.gd
│   ├── roll_dice_command.gd
│   ├── move_pawn_command.gd
│   └── start_match_command.gd
├── events/
│   ├── domain_event.gd
│   ├── dice_rolled_event.gd
│   ├── pawn_moved_event.gd
│   ├── pawn_captured_event.gd
│   ├── gift_spawned_event.gd
│   ├── power_up_resolved_event.gd
│   └── turn_changed_event.gd
├── rules/
│   ├── game_engine.gd
│   ├── move_rules.gd
│   ├── stack_rules.gd
│   ├── capture_rules.gd
│   ├── turn_rules.gd
│   └── finish_rules.gd
├── power_ups/
│   ├── power_up_resolver.gd
│   ├── teleport_effect.gd
│   ├── shield_effect.gd
│   ├── extra_turn_effect.gd
│   └── push_effect.gd
├── modifiers/
│   ├── modifier_pipeline.gd
│   └── animal_passive.gd
└── rng/
    ├── random_source.gd
    └── seeded_random_source.gd
```

### 4.1 GameState

`GameState` е единственият източник на истина за активния мач. Минималното му
съдържание е:

```text
schema_version
match_id
match_config
board_id
phase
players[]
active_player_index
turn
dice
gifts[]
ranking[]
rng_state
command_sequence
```

`PlayerState` съдържа:

```text
player_id
seat
color/team
controller_type
animal_id
pawns[]
rank
status_effects[]
```

`PawnState` съдържа логическо положение, а не пикселна позиция:

```text
pawn_id
zone: BASE | MAIN_PATH | HOME_STRETCH | FINISHED
path_index
cell_id
shield_turns_remaining
```

Важно: domain не използва `Vector2`, `NodePath` или имена като
`@Sprite2D@73591`. Използва стабилни `cell_id` и `path_index`. Presentation
преобразува `cell_id` към изометрична позиция.

### 4.2 TurnState като state machine

Ходът е изрична state machine, не набор от разпръснати boolean флагове:

```text
MATCH_START
  → AWAITING_ROLL
  → AWAITING_MOVE
  → RESOLVING_MOVE
  → RESOLVING_POWER_UP
  → TURN_END
  → AWAITING_ROLL
  → MATCH_FINISHED
```

`TurnState` пази:

- текуща фаза;
- хвърлен резултат;
- оставащи опити при всички пионки в база;
- право на допълнително хвърляне;
- валидни команди/пионки;
- пореден номер на хода.

Така input, AI и бъдещ remote player виждат един и същ набор валидни действия.

### 4.3 Команди

Всички промени минават през команди:

```text
StartMatchCommand(config)
RollDiceCommand(player_id)
MovePawnCommand(player_id, pawn_id)
```

Командата носи намерение, но не резултат. Например клиентът не изпраща
„зарът е 6“, а `RollDiceCommand`; резултатът се генерира от авторитетния RNG.

`GameEngine.apply_command()` връща:

```text
CommandResult
├── accepted: bool
├── state: GameState
├── events: Array[DomainEvent]
└── error: CommandError?
```

За v1 състоянието може да се мутира вътрешно за производителност, но публичният
договор е „команда → ново наблюдаемо състояние + събития“.

### 4.4 Домейн събития

Събитията описват вече настъпили факти:

```text
MatchStarted
DiceRolled
ValidMovesChanged
PawnMoved
PawnStackFormed
PawnCaptured
PawnSentHome
GiftSpawned
GiftCollected
PowerUpResolved
ShieldApplied
TurnChanged
PlayerRanked
MatchFinished
```

Едно движение може да произведе няколко събития в ред:

```text
PawnMoved → GiftCollected → PowerUpResolved → PawnMoved → TurnChanged
```

Presentation ги проиграва последователно. Save/statistics ги наблюдават, без да
дублират правилата.

### 4.5 Детерминиран RNG

Domain получава `RandomSource` отвън:

```text
next_int(min, max)
pick(array)
get_state()
set_state(state)
```

Един seed от `MatchConfig` управлява:

- зар;
- интервали и клетки за подаръци;
- съдържание на подаръци;
- случайни параметри на power-up.

Козметичните вариации на анимации ползват отделен presentation RNG и не влияят
върху мача.

### 4.6 BoardDefinition

Дъската е данни, не hardcoded условни проверки:

```text
board_id
cells: Dictionary[cell_id, CellDefinition]
main_loop: Array[cell_id]
player_definitions:
  spawn_cell
  start_loop_index
  home_entry_loop_index
  home_stretch[]
  base_cells[]
```

Една `BoardDefinition` обслужва 2/3/4 играчи чрез активни seats. Всеки играч има
собствен маршрут, изчислен от общия loop + неговия home stretch.

`CellDefinition` съдържа логически тип (`BASE`, `PATH`, `SPAWN`, `HOME`,
`CENTER`) и изометрични grid координати. Темата не е част от него.

### 4.7 Power-up pipeline

Power-up-ите използват общ договор:

```text
PowerUpEffect.resolve(context, state, rng) -> Array[DomainEvent]
```

`PowerUpContext` съдържа вземащия играч, пионка, клетка и активни модификатори.

Pipeline:

1. пионката завършва движение;
2. проверява се подарък на крайната клетка;
3. съдържанието се тегли чрез RNG;
4. animal passive модифицира числовите параметри;
5. ефектът се валидира;
6. състоянието се променя и се излъчват събития;
7. повторно се проверява крайна клетка само ако дизайнът изрично го позволява.

Няма `match power_up_id` из различни UI скриптове. Registry свързва `power_up_id`
с resolver.

### 4.8 Пасиви на животните

Пасивите са модификатори върху общ контекст:

```text
modify_teleport_distance()
modify_push_distance()
modify_shield_duration()
modify_gift_spawn_weight()
```

Те не местят пионки директно и не създават отделни game loops. Това пази
ограничението от game design документа.

## 5. Application слой

```text
game/application/
├── match_session.gd
├── match_factory.gd
├── match_config.gd
├── command_bus.gd
├── event_queue.gd
├── controller/
│   ├── player_controller.gd
│   ├── human_controller.gd
│   ├── ai_controller.gd
│   └── remote_controller.gd       # интерфейс/placeholder за v2
├── ai/
│   ├── ai_policy.gd
│   ├── easy_ai_policy.gd
│   ├── medium_ai_policy.gd
│   └── hard_ai_policy.gd
└── ports/
    ├── save_repository.gd
    ├── progress_repository.gd
    ├── settings_repository.gd
    ├── ads_service.gd
    └── telemetry_sink.gd
```

### 5.1 MatchConfig

И `Match Setup`, и кампанията произвеждат един договор:

```text
schema_version
mode: FREE_PLAY | CAMPAIGN
board_id
theme_id
seats[]:
  player_id
  controller_type: HUMAN | AI | REMOTE
  ai_difficulty?
  animal_id
campaign_level_id?
level_modifiers[]
pre_match_bonus?
rng_seed
```

`MatchSession.start(config)` е единственият вход към Game екрана.

### 5.2 MatchSession

`MatchSession`:

- притежава `GameState`, `GameEngine` и RNG;
- приема команди от controller;
- публикува domain events;
- блокира следваща команда, докато presentation проиграва задължителна поредица,
  без да прехвърля правилата към анимацията;
- прави snapshot след стабилна фаза;
- при `MatchFinished` произвежда `MatchSummary`.

Domain не чака tween. Presentation потвърждава `events_presented(sequence)`, за да
продължи UX потокът. На бъдещ сървър това изчакване не е необходимо.

### 5.3 Controllers

Всеки seat има `PlayerController`:

```text
request_command(state_view, legal_actions) -> GameCommand
```

- Human controller чака input от UI.
- AI controller избира команда от същите `legal_actions`.
- Remote controller във v2 преобразува мрежово съобщение към същата команда.

AI никога не мести визуални нодове и не заобикаля GameEngine.

## 6. Presentation слой

```text
game/presentation/
├── game_screen/
│   ├── game_screen.tscn
│   ├── game_screen.gd
│   ├── game_presenter.gd
│   ├── board_view.gd
│   ├── pawn_view.gd
│   ├── dice_view.gd
│   ├── gift_view.gd
│   └── game_hud.gd
├── menus/
│   ├── main_menu/
│   ├── match_setup/
│   ├── campaign/
│   ├── results/
│   └── settings/
└── common/
    ├── animation_queue.gd
    ├── audio_feedback.gd
    └── haptic_feedback.gd
```

### 6.1 GamePresenter

`GamePresenter` е мостът между domain и view:

- преобразува `GameState` до read-only view model;
- показва валидни пионки;
- преобразува клик в `MovePawnCommand`;
- обработва domain events в `AnimationQueue`;
- не решава дали даден ход е валиден.

### 6.2 BoardView

`BoardView`:

- строи 15×15 геометрията от `BoardDefinition`;
- пази `cell_id → Node2D/позиция`;
- прилага тема чрез `BoardThemeDefinition`;
- не пази текущ играч, зар или правила.

### 6.3 PawnView

`PawnView` съдържа само:

- `pawn_id`;
- визуален asset/animal/skin;
- idle, selected, move, stack, sleep/home анимации;
- colorblind marker;
- hit target за input.

Логическите `in_base`, `path_index`, shield и valid move са в `PawnState`.

### 6.4 DiceView

Зарът е presentation:

- получава резултат от `DiceRolled`;
- проиграва анимация, която завършва на този резултат;
- не генерира gameplay случайността;
- debug бутоните съществуват само в debug build и изпращат тестова команда през
  разрешен debug adapter.

## 7. Content и теми

```text
content/
├── boards/
│   └── classic_15x15.tres
├── themes/
│   ├── jungle_theme.tres
│   └── desert_theme.tres
├── animals/
│   ├── pig.tres
│   └── ...
├── power_ups/
│   ├── teleport_forward.tres
│   ├── shield.tres
│   ├── extra_turn.tres
│   └── push.tres
└── campaign/
    ├── campaign_definition.tres
    └── levels/
```

Godot `Resource` файловете са authoring формат. При старт се валидират и
преобразуват до domain definitions. Domain не зарежда файлове сам.

`BoardThemeDefinition` съдържа само presentation данни: textures, colors,
particles, sounds и визуален gift skin. Смяната на тема не променя правила.

## 8. Flow и екрани

Отделен `AppFlow` управлява:

```text
BOOT → MAIN_MENU → MATCH_SETUP/CAMPAIGN → GAME → RESULTS
                         ▲                         │
                         └──────── REMATCH ────────┘
```

Препоръчителни Autoload-и:

```text
AppFlow          # навигация и payload между екрани
ProfileService   # локален прогрес/unlocks/statistics
SettingsService  # audio/haptics/accessibility
AudioService     # music/SFX routing
PlatformService  # Android/haptics/lifecycle
```

`MatchSession` не е глобален вечен singleton. Създава се за конкретен мач и се
освобождава след Results.

## 9. Persistence

Разделяме:

1. `settings.json` — звук, музика, haptics, auto-move, colorblind;
2. `profile.json` — XP, unlocks, campaign progress, statistics;
3. `active_match.json` — snapshot за resume след прекъсване.

Всеки файл има:

```text
schema_version
saved_at
payload
checksum (по желание във v1)
```

Repository adapter използва атомичен запис: temporary file → validate → rename.
Migration functions преобразуват `schema_version N` към `N+1`.

Никоя сцена не пише директно в `user://`.

## 10. Rewarded ads и платформа

Domain не познава AdMob. Преди мач Application пита `AdsService` и при успешна
награда добавя валидиран `pre_match_bonus` към `MatchConfig`.

```text
AdsService (port)
├── StubAdsService       # editor/tests
└── AdMobAdsService      # Android export
```

Същият подход се използва за haptics и platform lifecycle.

## 11. Подготовка за v2 multiplayer

Не изграждаме networking във v1, но запазваме следните договори:

- клиентът изпраща `GameCommand`, не ново състояние;
- авторитетът валидира и прилага командата;
- всяка команда има `match_id`, `player_id`, `sequence` и по-късно auth token;
- snapshot и events са сериализируеми;
- RNG се управлява само от авторитета;
- presentation може да възстанови изглед от snapshot;
- `GameState` има стабилен hash за откриване на divergence;
- remote controller е adapter към същия command API.

Във v2 локалният:

```text
HumanController → MatchSession → GameEngine
```

се заменя с:

```text
HumanController → NetworkClient → Authoritative MatchSession → GameEngine
```

без промяна в правилата или view event обработката.

## 12. Тестова стратегия

```text
tests/
├── unit/domain/
│   ├── movement_rules_test.gd
│   ├── stack_rules_test.gd
│   ├── capture_rules_test.gd
│   ├── home_stretch_test.gd
│   ├── power_up_test.gd
│   └── turn_rules_test.gd
├── unit/application/
│   ├── match_session_test.gd
│   ├── ai_policy_test.gd
│   └── persistence_test.gd
├── simulation/
│   ├── deterministic_replay_test.gd
│   └── thousands_of_matches_test.gd
└── integration/presentation/
```

Критични инварианти:

- винаги има 4 пионки на играч;
- една пионка е точно в една зона;
- максимум 2 свои пионки на обща клетка;
- home stretch не може да бъде атакуван;
- невалидна команда не променя state или RNG;
- еднакъв seed + еднакви команди = еднакво състояние и събития;
- завършил играч не получава нов ход;
- при 3–4 играчи ranking е стабилен.

## 13. Препоръчителна структура на проекта

```text
ai_ludo/
├── app/
│   ├── app_flow.gd
│   └── bootstrap.gd
├── game/
│   ├── domain/
│   ├── application/
│   └── presentation/
├── content/
├── platform/
│   ├── persistence/
│   ├── ads/
│   ├── audio/
│   └── haptics/
├── tests/
├── docs/
└── assets/              # постепенно заменя временното rss/
```

### 13.1 Audit на текущия прототип

Текущият проект е single-scene прототип:

- `project.godot` стартира `scenes/ludo_game.tscn`;
- `scripts/ludo_game.gd` смесва turn state, правила, input, UI и изчакване на
  анимации;
- `scripts/ludo_board.gd` смесва topology данни с procedural rendering;
- реализиран е само маршрутът на жълтия играч; cyan turn е временен UI stub;
- `Pawn` пази едновременно visual/input поведение и части от gameplay state;
- `dice.gd` генерира gameplay резултата във visual node;
- няма autoload services, persistence, tests, AI или content `Resource` типове;
- `dice_3d.gd` и `dice_3d.tscn` са неизползван legacy вариант;
- `ludo_game.tscn` съдържа стотици baked tile sprites, а board script може да ги
  построи отново, което създава двоен source of truth;
- input-ът разчита основно на mouse events и трябва да се валидира за touch.

Това не е причина да изхвърлим прототипа. Ниският брой файлове прави настоящия
момент най-подходящ за въвеждане на границите, преди AI, power-ups и четири
играча да увеличат свързаността.

**Запазваме и адаптираме:**

- изометричната математика, tile размерите и 15×15 layout от
  `scripts/ludo_board.gd`;
- координатите за бази/spawn и жълтия маршрут като шаблон за останалите;
- `pawn.gd`/`pawn.tscn` като начална версия на `PawnView`;
- `Dice.tscn`, `dice_world.tscn` и анимациите като `DiceView`;
- временното asset pipeline в `rss/`;
- mobile renderer настройките.

**Заменяме или изграждаме наново:**

- gameplay частта на `ludo_game.gd` с `GameEngine` + `MatchSession`;
- локалните boolean turn флагове с `TurnState`;
- визуалния RNG на зара със seeded domain RNG;
- yellow-only state с общ модел за 2/3/4 seats;
- node-name/cell coupling с `BoardDefinition` и стабилни `cell_id`;
- директните tween awaits в rule flow с domain events + animation queue;
- директния UI orchestration с presenter/controllers;
- липсващите flow, persistence, campaign, AI и platform adapters.

## 14. Миграция от текущия прототип

Не правим big-bang rewrite. Използваме поетапна замяна:

### Етап A — стабилен домейн скелет

1. Създаваме `MatchConfig`, `GameState`, `BoardDefinition`, RNG и command/event
   базовите типове.
2. Кодираме пътищата на четирите играча като данни.
3. Пишем тестове за движение, база, home stretch и допълнителен ход при 6.

### Етап B — правила на класическото Ludo

1. Преместваме логиката от `scripts/ludo_game.gd` в `GameEngine`.
2. Добавяме stacks, capture, ranking и 2/3/4 seats.
3. Текущата сцена става временен presenter към новите events.

### Етап C — presentation разделяне

1. `ludo_board.gd` става `BoardView` и спира да пази gameplay state.
2. `pawn.gd` става `PawnView`.
3. `dice.gd` става `DiceView`; резултатът идва от domain.
4. Премахваме legacy `dice_3d` след потвърден parity.

### Етап D — AI и pass-and-play

1. Human/AI controllers.
2. Match Setup произвежда `MatchConfig`.
3. Easy/medium/hard AI върху legal actions.

### Етап E — power-ups и content

1. Gift spawn и collection.
2. Четирите v1 resolver-а.
3. Animal modifiers и content validation.

### Етап F — campaign/platform

1. Campaign definitions, XP и unlocks.
2. Save migrations, settings, results.
3. Rewarded ads adapter, consent, Android lifecycle.

## 15. Решения и ограничения

### Приети решения

- Един 15×15 board model за 2/3/4 играчи.
- State + commands + events, без full event-sourcing като задължение.
- Seeded deterministic RNG.
- Data-driven content; code-driven effect resolvers.
- Offline-first v1; network-ready contracts, без premature networking.
- Темите и козметиката никога не участват в правилата.
- AI използва същите команди като човека.

### Избягваме

- gameplay логика в scene scripts;
- autoload „GameManager“, който прави всичко;
- идентифициране на клетки чрез editor-generated node names;
- сигнали като единствен неявен механизъм за domain orchestration;
- директен save от UI;
- отделни правила за AI;
- power-up логика чрез нарастващ `match`/`if` блок;
- смесване на gameplay RNG с визуални вариации.

## 16. Definition of Done за архитектурната основа

Основата е готова, когато:

1. цял мач може да се симулира без зареждане на сцена;
2. state може да се serialize → deserialize без загуба;
3. replay със същите seed и commands дава същия state hash;
4. human и AI могат да изпратят еднакъв `MovePawnCommand`;
5. текущата дъска анимира само domain events;
6. тестовете покриват всички правила от раздел 3 на game design документа;
7. Match Setup и Campaign стартират Game чрез един и същ `MatchConfig`.
