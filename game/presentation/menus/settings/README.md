# menus/settings/

Екран с настройки (docs/V1_GAME_DESIGN.md, раздел 8.1).

Настройки:
- Music (on/off + volume)
- Sound Effects (on/off + volume)
- Haptics (on/off)
- Auto-move при единствен валиден ход (on/off)
- Colorblind режим (on/off)

Всичко записва чрез `SettingsService` autoload — не директно в `user://`.

Имплементация: задача "Създаване на Settings сцена".
