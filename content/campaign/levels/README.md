# content/campaign/levels/

Дефиниции на отделните campaign нива като Godot Resource файлове (`.tres`).

## Структура на CampaignLevelDefinition Resource

```
level_id       : StringName
theme_id       : StringName
ai_count       : int          # 1, 2 или 3 AI противника
ai_difficulty  : int          # AIDifficulty enum стойност
modifiers      : Array        # напр. "gifts_double_frequency"
xp_reward_win  : int
xp_reward_loss : int
unlock_reward? : StringName   # animal_id или theme_id при достигнат праг
```

## Планирани нива

- **Jungle тема** — нива jungle_01 … jungle_N → отключва rabbit/dog/etc.
- **Desert тема** — нива desert_01 … desert_N → отключва desert_theme

Имплементация: задачи "Създаване на jungle/desert campaign нива".
