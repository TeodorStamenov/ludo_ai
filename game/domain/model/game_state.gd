class_name GameState
extends RefCounted
## Единственият source of truth за активния мач (docs/V1_ARCHITECTURE.md, раздел 4.1).
##
## Минимални полета:
##   schema_version, match_id, match_config, board_id, phase,
##   players[], active_player_index, turn, dice, gifts[], ranking[],
##   rng_state, command_sequence
##
## Важно: не съдържа Vector2, NodePath или editor-generated имена.
## Presentation преобразува cell_id към изометрична позиция.
##
## Пълната имплементация е обхваната от задачи:
##   - "Създаване на GameState модел като единствен източник на gameplay state"
##   - "Добавяне на schema_version към GameState"
##   - "Добавяне на command sequence към GameState"
##   - "Добавяне на RNG state към GameState"
##   - "Създаване на сериализация и десериализация на GameState"
##   - "Създаване на стабилен state hash"
