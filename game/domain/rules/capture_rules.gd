class_name CaptureRules
extends RefCounted
## Правила за взимане на противникова пионка (docs/V1_ARCHITECTURE.md, раздел 4;
## docs/V1_GAME_DESIGN.md §3.1–3.2).
##
## Единична незащитена противникова пионка се взима при стъпване върху нея (#113).
## Взетата пионка се връща в свободна позиция в базата на своя играч (#114).
## Пионки в home stretch / BASE / FINISHED са защитени от взимане.
## Купчина от 2 е имунизирана — противник не може да стъпи на клетката (#111).
##
## Occupancy query: CellOccupancy (#107). Stack detection: StackRules / CellOccupancy.
## Прилагане на взимане + PawnCapturedEvent → #113–#115.


var _stack_rules: StackRules


func _init(stack_rules: StackRules = null) -> void:
	_stack_rules = stack_rules if stack_rules != null else StackRules.new()


## True ако клетката има противникова купчина от 2 — имунна срещу взимане/кацане (#111).
func is_immune_stack(
		state: GameState,
		cell_id: StringName,
		attacking_player_id: StringName
) -> bool:
	if state == null or cell_id == &"" or attacking_player_id == &"":
		return false
	return _stack_rules.is_enemy_stack(state, cell_id, attacking_player_id)


## True ако кацане на MAIN_PATH клетка е забранено заради имунна купчина (#111).
func blocks_landing(
		state: GameState,
		cell_id: StringName,
		landing_player_id: StringName
) -> bool:
	return is_immune_stack(state, cell_id, landing_player_id)
