# content/

Data-driven конфигурации за Cosy Ludo v1 като Godot Resource файлове (`.tres`),
съгласно `docs/V1_ARCHITECTURE.md` (раздели 7 и 13).

## Ключово правило

`.tres` файловете са **authoring формат** — създават се в Godot Editor.  
При старт на приложението се валидират и преобразуват до domain definitions.  
**Domain не зарежда файлове директно** — content loader го прави.

```text
content/*.tres  →  [content loader + validator]  →  Domain definitions
                                                         ↑
                                              Domain ги получава инжектирани
```

## Структура

| Директория    | Съдържание |
|---|---|
| `boards/`     | `BoardDefinition` — 15×15 геометрия, клетки, маршрути |
| `themes/`     | `BoardThemeDefinition` — текстури, цветове, звуци (само presentation) |
| `animals/`    | `AnimalDefinition` — 5–6 животни с пасивни умения |
| `power_ups/`  | `PowerUpDefinition` — 4 v1 ефекта с resolver скриптове |
| `campaign/`   | `CampaignDefinition` + `CampaignLevelDefinition` нива |

## Важно за теми

`BoardThemeDefinition` съдържа само presentation данни.  
Смяната на тема **не влияе на gameplay правилата**.
