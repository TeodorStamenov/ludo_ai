class_name GameStateInvariantChecker
extends RefCounted
## Runtime проверки на критичните GameState инварианти
## (docs/V1_ARCHITECTURE.md §12; roadmap #142).
##
## Допълва GameState.is_valid() със board/rules инварианти, които structural
## валидацията не покрива: occupancy (max 2 own), без чужди на home stretch,
## класиран играч не е активен, ranking ↔ PlayerState.rank.
##
## Domain-only: без Node / telemetry / application. MatchSession /
## MatchSimulator викат validate_runtime() след приета команда.


const ERR_NULL_STATE := &"null_state"
const ERR_INVALID_STATE := &"invalid_state"
const ERR_OWN_STACK_OVERFLOW := &"own_stack_overflow"
const ERR_MIXED_OCCUPANCY := &"mixed_occupancy"
const ERR_FOREIGN_HOME_STRETCH := &"foreign_home_stretch"
const ERR_RANKED_ACTIVE := &"ranked_active"
const ERR_RANKING_MISMATCH := &"ranking_mismatch"


## Резултат от проверка: ok + наредени error codes (+ съобщения за дебъг).
class Result extends RefCounted:
	var ok: bool = true
	var error_codes: Array[StringName] = []
	var error_messages: Array[String] = []

	func is_ok() -> bool:
		return ok

	func is_invalid() -> bool:
		return not ok

	func has_error(code: StringName) -> bool:
		return error_codes.has(code)

	func first_error_code() -> StringName:
		if error_codes.is_empty():
			return &""
		return error_codes[0]

	func first_error_message() -> String:
		if error_messages.is_empty():
			return ""
		return error_messages[0]

	func add_error(code: StringName, message: String) -> void:
		ok = false
		error_codes.append(code)
		error_messages.append(message)


## Пълна проверка: structural is_valid() + runtime board/rules инварианти.
static func validate(state: GameState) -> Result:
	var result := Result.new()
	if state == null:
		result.add_error(ERR_NULL_STATE, "GameState is null")
		return result
	if not state.is_valid():
		result.add_error(ERR_INVALID_STATE, "GameState.is_valid() failed")
		# Без nested модели не можем надеждно да продължим board checks.
		return result
	_append_runtime_checks(state, result)
	return result


## Mid-match проверки след приета команда (#142): occupancy, home stretch,
## ranked≠active, ranking sync. Без is_valid() — stub/orchestration state
## в тестове няма пълен модел; production MatchFactory state минава и двете.
static func validate_runtime(state: GameState) -> Result:
	var result := Result.new()
	if state == null:
		result.add_error(ERR_NULL_STATE, "GameState is null")
		return result
	_append_runtime_checks(state, result)
	return result


static func is_valid(state: GameState) -> bool:
	return validate(state).is_ok()


static func is_runtime_valid(state: GameState) -> bool:
	return validate_runtime(state).is_ok()


## Кратък низ за telemetry / journal (код + първо съобщение).
static func describe_first_violation(state: GameState) -> String:
	var result := validate(state)
	if result.is_ok():
		return ""
	return "%s: %s" % [String(result.first_error_code()), result.first_error_message()]


static func describe_first_runtime_violation(state: GameState) -> String:
	var result := validate_runtime(state)
	if result.is_ok():
		return ""
	return "%s: %s" % [String(result.first_error_code()), result.first_error_message()]


static func _append_runtime_checks(state: GameState, result: Result) -> void:
	# §12: 4 пионки / една зона — покрити от GameState.is_valid() в validate().
	_check_board_occupancy(state, result)
	_check_home_stretch_protection(state, result)
	_check_ranked_not_active(state, result)
	_check_ranking_consistency(state, result)


static func _check_board_occupancy(state: GameState, result: Result) -> void:
	var occupancy := CellOccupancy.from_state(state)
	for cell_id in occupancy.occupied_cell_ids():
		var pawns: Array = occupancy.get_pawns_at(cell_id)
		var by_owner: Dictionary = {}
		for entry in pawns:
			var pawn := entry as PawnState
			if pawn == null:
				continue
			var owner := String(pawn.get_player_id())
			by_owner[owner] = int(by_owner.get(owner, 0)) + 1

		if by_owner.size() > 1:
			result.add_error(
					ERR_MIXED_OCCUPANCY,
					"cell '%s' has pawns from multiple players" % String(cell_id))

		for owner_key in by_owner.keys():
			var count: int = int(by_owner[owner_key])
			if count > CellOccupancy.MAX_OWN_PAWNS_PER_CELL:
				result.add_error(
						ERR_OWN_STACK_OVERFLOW,
						"cell '%s' has %d pawns of '%s' (max %d)" % [
							String(cell_id),
							count,
							str(owner_key),
							CellOccupancy.MAX_OWN_PAWNS_PER_CELL])


static func _check_home_stretch_protection(state: GameState, result: Result) -> void:
	for player_entry in state.players:
		var player := player_entry as PlayerState
		if player == null:
			continue
		for pawn_entry in player.pawns:
			var pawn := pawn_entry as PawnState
			if pawn == null or not pawn.is_on_board():
				continue
			var home_owner := Classic15x15Board.home_stretch_owner(pawn.cell_id)
			if home_owner == &"":
				continue
			if home_owner != player.player_id:
				result.add_error(
						ERR_FOREIGN_HOME_STRETCH,
						"pawn '%s' on foreign home stretch cell '%s' (owner '%s')" % [
							String(pawn.pawn_id),
							String(pawn.cell_id),
							String(home_owner)])


static func _check_ranked_not_active(state: GameState, result: Result) -> void:
	if not state.is_in_progress():
		return
	var active := state.get_active_player()
	if active == null:
		return
	if active.is_ranked() or state.is_ranked(active.player_id):
		result.add_error(
				ERR_RANKED_ACTIVE,
				"ranked player '%s' is active during IN_PROGRESS" % String(
						active.player_id))


static func _check_ranking_consistency(state: GameState, result: Result) -> void:
	for i in state.ranking.size():
		var player_id := StringName(str(state.ranking[i]))
		var expected_rank: int = i + PlayerState.RANK_FIRST
		var player := state.get_player(player_id)
		if player == null:
			result.add_error(
					ERR_RANKING_MISMATCH,
					"ranking entry '%s' has no PlayerState" % String(player_id))
			continue
		if player.rank != expected_rank:
			result.add_error(
					ERR_RANKING_MISMATCH,
					"player '%s' rank %d != ranking slot %d" % [
						String(player_id), player.rank, expected_rank])
		if not player.is_ranked():
			result.add_error(
					ERR_RANKING_MISMATCH,
					"player '%s' in ranking[] but is_ranked() is false" % String(
							player_id))

	for player_entry in state.players:
		var player := player_entry as PlayerState
		if player == null:
			continue
		if player.is_ranked() and not state.is_ranked(player.player_id):
			result.add_error(
					ERR_RANKING_MISMATCH,
					"player '%s' has rank %d but missing from ranking[]" % [
						String(player.player_id), player.rank])
