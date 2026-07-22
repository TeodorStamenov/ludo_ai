# app/

Bootstrap и навигационен слой на приложението, съгласно
`docs/V1_ARCHITECTURE.md` (раздел 8 и 13).

- `bootstrap.gd` — стартова инициализация преди показването на първия екран
  (фаза `BOOT`): platform adapters, autoload услуги, content validation.
- `app_flow.gd` — навигация и payload между екраните:
  `BOOT → MAIN_MENU → MATCH_SETUP/CAMPAIGN → GAME → RESULTS`.

Тази директория не съдържа gameplay логика. `game/domain` и
`game/application` не зависят от нея; тя единствено свързва Presentation
екраните в единен поток.

Файловете тук са scaffold. Пълната имплементация на Bootstrap сцената и
AppFlow autoload-а е обхваната от следващи задачи от roadmap-а.
