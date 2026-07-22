extends Node
## Навигация и payload между екраните на приложението
## (`docs/V1_ARCHITECTURE.md`, раздел 8):
##
##   BOOT → MAIN_MENU → MATCH_SETUP/CAMPAIGN → GAME → RESULTS
##                            ▲                          │
##                            └────────── REMATCH ────────┘
##
## `AppFlow` е единствената точка, която познава преходите между екраните;
## самите екрани не навигират директно едни към други и не създават
## `MatchSession` — те произвеждат/консумират `MatchConfig` и `MatchSummary`.
##
## Този файл е scaffold за целевата директория `app/`. Регистрацията като
## autoload и пълната имплементация са обхванати от отделна задача
## ("Създаване на AppFlow autoload").
