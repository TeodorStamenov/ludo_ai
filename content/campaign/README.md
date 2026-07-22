# content/campaign/

Campaign дефиниции като Godot Resource файлове (`.tres`).

## Планирани файлове

| Файл                      | Описание |
|---|---|
| `campaign_definition.tres`| Главен списък на темите и нивата |
| `levels/`                 | Отделни CampaignLevelDefinition ресурси |

## Структура на CampaignDefinition Resource

```
campaign_id    : StringName
themes         : Array[ThemeChapter]
  theme_id     : StringName
  levels       : Array[StringName]    # level_id референции
  unlock_reward: StringName           # при завършване на темата
```

Имплементация: задача "Създаване на CampaignDefinition модел".
