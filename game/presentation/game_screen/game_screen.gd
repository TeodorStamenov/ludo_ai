class_name GameScreen
extends Node
## Корен на Game екрана (docs/V1_ARCHITECTURE.md, раздел 6).
##
## Единственият му вход е MatchConfig — не знае нищо за менютата.
## При старт инициализира GamePresenter с MatchSession от MatchFactory.
##
## Поток:
##   AppFlow.navigate_to_game(config)
##     → GameScreen._on_match_config_received(config)
##     → MatchFactory.build(config)  → MatchSession
##     → GamePresenter.bind(session)
##
## Пълната имплементация е обхваната от задача "Създаване на Game Screen сцена".
