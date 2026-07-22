# menus/match_setup/

Екран „Нова игра" — Match Setup (docs/V1_GAME_DESIGN.md, раздел 8.1).

Позволява избор на:
- брой играчи (2 / 3 / 4)
- тип за всяко активно място (Human / AI)
- AI difficulty при AI места (Easy / Medium / Hard)
- отключено животно
- отключена тема на дъската

Произвежда `MatchConfig` и го предава на `AppFlow.navigate_to_game(config)`.

Имплементация: задача "Създаване на Match Setup сцена".
