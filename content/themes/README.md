# content/themes/

Визуални теми за дъската като Godot Resource файлове (`.tres`).

## Състояние (v1: 2 теми)

| Файл          | Тема   | Съдържание |
|---|---|---|
| `jungle.tres` | Jungle | `rss/CHIP/*.png` (текущата дъска) — ✅ пълна |
| `desert.tres` | Desert | ❌ липсва арт/звук — отключва се чрез кампанията |

2 теми в v1 (`ThemeId.ALL`); Jungle е налична от старта (`ThemeId.STARTER`).

⚠️ Desert още няма спрайтове/звук, затова няма `.tres` запис —
`BoardThemeRegistry.definition_for()` връща `null` за нея, а
`definition_for_or_default()` пада към `ThemeId.DEFAULT` (Jungle).
`BoardThemeDefinitionValidator.validate_roster()` ще я рапортува като
`ERR_MISSING_THEME`, докато не се появят ресурси.

**Добавяне на нова тема = само нов ред в `BoardThemeRegistry._DEFINITION_PATHS`
+ нов `.tres` с текстури/звук — без промяна в `BoardView` или друга логика.**

## Структура на BoardThemeDefinition Resource

```
theme_id        : StringName
center_texture  : Texture2D              # единствената CENTER клетка
path_texture    : Texture2D              # всички PATH (main loop) клетки
player_textures : Dictionary             # PlayerId → Texture2D (BASE/SPAWN/HOME по собственик)
gift_visual     : PackedScene            # още неизползвано от GiftView
ambience_audio  : AudioStream            # още неизползвано
sfx_set         : Dictionary             # event_name → AudioStream, още неизползвано
```

`center_texture`/`path_texture`/`player_textures` са единствените
задължителни полета за `BoardThemeDefinitionValidator` — те са функционалният
минимум, без който дъската не може да се изобрази. BASE/SPAWN/HOME клетки не
се различават визуално по под-тип, само по собственик (`PlayerId`), затова се
теглят по играч, не по `CellType` — виж коментара в `board_theme_definition.gd`.

`gift_visual`/`ambience_audio`/`sfx_set` са presentation-only и НЕ участват
във валидацията (същият прецедент като `AnimalDefinition.sprite`/
`colorblind_icon`) — липсващ звук не бива да пречи на зареждането на тема,
чиито основни тайлове са налични.

Темата съдържа САМО presentation данни. Промяната на тема не влияе на
gameplay правилата.

Имплементация: `board_theme_definition.gd`; валидация:
`board_theme_definition_validator.gd`; търсене по `theme_id`:
`board_theme_registry.gd`. `BoardView.theme_id` (export) избира темата;
`GameScreen.start_match()` я задава от `MatchConfig.theme_id`.
