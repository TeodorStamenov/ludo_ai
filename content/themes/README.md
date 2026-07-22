# content/themes/

Визуални теми за дъската като Godot Resource файлове (`.tres`).

## Планирани файлове

| Файл               | Статус               |
|---|---|
| `jungle_theme.tres`| v1 начална тема      |
| `desert_theme.tres`| v1 — отключва се чрез кампанията |

## Структура на BoardThemeDefinition Resource

```
theme_id       : StringName
tile_textures  : Dictionary    # cell_type → Texture2D
gift_visual    : PackedScene
ambience_audio : AudioStream
sfx_set        : Dictionary    # event_name → AudioStream
```

Темата съдържа САМО presentation данни — текстури, цветове, particles, звуци.
Промяната на тема не влияе на gameplay правилата.

Имплементация: задача "Създаване на BoardThemeDefinition модел".
