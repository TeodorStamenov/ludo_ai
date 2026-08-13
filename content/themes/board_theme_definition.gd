@tool
class_name BoardThemeDefinition
extends Resource
## Authoring формат за визуална тема на дъската (docs/V1_ARCHITECTURE.md §6.2 / §7;
## content/themes/README.md).
##
## .tres файловете тук се валидират и зареждат от Application слоя при старт —
## Domain никога не зарежда тези файлове сам (§7). Темата е presentation-only:
## текстури, цветове, particles, звуци и gift skin — смяната ѝ не променя
## gameplay правилата (docs/V1_GAME_DESIGN.md §2 / §5.1; ThemeId).
##
## CENTER и PATH клетки нямат собственик — по едно теглo за целия борд.
## BASE/SPAWN/HOME клетки визуално не се различават по под-тип, само по
## собственик (BoardView._player_chip_path преди тази задача) — затова се
## теглят по PlayerId, не по CellType. CellType.type_name() остава стабилният
## идентификатор за bъдещ per-type skin, ако дизайнът го поиска по-късно.
##
## gift_visual/ambience_audio/sfx_set са presentation-only и НЕ участват в
## BoardThemeDefinitionValidator (същият прецедент като
## AnimalDefinition.sprite/colorblind_icon) — липсващ звук не бива да пречи на
## зареждането на тема, чиито основни тайлове са налични.
##
## @tool е задължителен: BoardView е @tool (изпълнява се и в editor контекст),
## а Godot отказва да извиква методи на non-tool Resource скрипт от @tool
## контекст — вместо истинска инстанция получаваш placeholder и "Attempt to
## call a method on a placeholder instance" при всеки метод. Без @tool тук
## дъската не се изобразява при headless --import (editor-ът презарежда
## отворени сцени по време на импорта).

@export var theme_id: StringName = &""
## Единствената CENTER клетка на дъската.
@export var center_texture: Texture2D = null
## Всички PATH (main loop) клетки.
@export var path_texture: Texture2D = null
## player_id (PlayerId) → Texture2D за BASE/SPAWN/HOME клетки, собственост на
## този играч.
@export var player_textures: Dictionary = {}
@export var gift_visual: PackedScene = null
@export var ambience_audio: AudioStream = null
## event_name (StringName) → AudioStream.
@export var sfx_set: Dictionary = {}


func is_valid() -> bool:
	return BoardThemeDefinitionValidator.validate(self).ok


## Текстурата за player_id, или null ако темата няма запис за него.
func texture_for_player(player_id: StringName) -> Texture2D:
	return player_textures.get(player_id) as Texture2D
