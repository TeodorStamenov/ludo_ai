# content/boards/

Дефиниции на дъски като Godot Resource файлове (`.tres`).

## Планирани файлове

| Файл                  | Описание |
|---|---|
| `classic_15x15.tres`  | Стандартна 15×15 изометрична дъска за 2/3/4 играчи |

## Структура на BoardDefinition Resource

```
board_id          : StringName
cells             : Dictionary[StringName, CellDefinition]
main_loop         : Array[StringName]   # cell_id последователност
player_definitions: Array[PlayerBoardDefinition]
  spawn_cell            : StringName
  start_loop_index      : int
  home_entry_loop_index : int
  home_stretch          : Array[StringName]
  base_cells            : Array[StringName]
```

`.tres` файловете се създават в Godot Editor.
Domain не зарежда файлове директно — BoardDefinition се валидира и
преобразува при старт от content loader.

Имплементация: задачи "Създаване на BoardDefinition модел" и сродните.
