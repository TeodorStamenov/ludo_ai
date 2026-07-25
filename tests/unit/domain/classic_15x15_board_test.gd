class_name Classic15x15BoardTest
extends TestCase
## Unit тестове за Classic15x15Board (Task #37 / docs/V1_ARCHITECTURE.md, §4.6).
##
## Покрива преместването на 15×15 grid координатите от ludo_board.gd
## в BoardDefinition.cells (изометрични col/row + CellType).
## base cells per seat — Task #39; spawn/loop/home/маршрути — Tasks #40–#43.


# ── Архитектурни изисквания ───────────────────────────────────────────────────

func test_classic_board_extends_ref_counted() -> void:
	var factory := Classic15x15Board.new()
	assert_true(factory is RefCounted,
			"Classic15x15Board трябва да extends RefCounted, не Node")


func test_classic_board_is_not_node() -> void:
	var factory: Object = Classic15x15Board.new()
	assert_false(factory is Node,
			"Classic15x15Board не трябва да extends Node — domain слой е без сцени")


func test_classic_board_script_path_is_in_domain_model() -> void:
	var factory := Classic15x15Board.new()
	var path: String = factory.get_script().resource_path
	assert_true(path.contains("game/domain/model/"),
			"Classic15x15Board трябва да е в game/domain/model/")


# ── Фабрика и константи ───────────────────────────────────────────────────────

func test_board_id_is_classic_15x15() -> void:
	assert_eq(Classic15x15Board.BOARD_ID, BoardDefinition.DEFAULT_BOARD_ID)
	assert_eq(Classic15x15Board.BOARD_ID, &"classic_15x15")
	var board := Classic15x15Board.create()
	assert_eq(board.board_id, &"classic_15x15")


func test_cell_count_matches_prototype_geometry() -> void:
	assert_eq(Classic15x15Board.CELL_COUNT, 73)
	var board := Classic15x15Board.create()
	assert_eq(board.cell_count(), Classic15x15Board.CELL_COUNT)


func test_create_leaves_main_loop_and_players_for_later_tasks() -> void:
	# Tasks #40–#42 попълват seats/loop; base клетките са в Classic15x15Board API (#39).
	var board := Classic15x15Board.create()
	assert_eq(board.main_loop_length(), 0)
	assert_eq(board.player_definition_count(), 0)


# ── Grid координати във всяка клетка ──────────────────────────────────────────

func test_every_cell_has_valid_grid_coordinates() -> void:
	var board := Classic15x15Board.create()
	for key in board.cells.keys():
		var cell := board.cells[key] as CellDefinition
		assert_true(cell != null)
		assert_true(cell.is_valid(),
				"%s трябва да е валидна CellDefinition" % key)
		assert_eq(cell.grid_col, CellId.to_vec(cell.cell_id).x)
		assert_eq(cell.grid_row, CellId.to_vec(cell.cell_id).y)
		assert_true(cell.grid_col >= 0 and cell.grid_col < BoardDefinition.BOARD_SIZE)
		assert_true(cell.grid_row >= 0 and cell.grid_row < BoardDefinition.BOARD_SIZE)


func test_get_cell_at_grid_matches_cell_definition() -> void:
	var board := Classic15x15Board.create()
	var yellow_spawn := board.get_cell_at_grid(6, 12)
	assert_true(yellow_spawn != null)
	assert_eq(yellow_spawn.cell_id, &"c_6_12")
	assert_eq(yellow_spawn.grid_pos(), Vector2i(6, 12))
	assert_true(yellow_spawn.is_spawn())
	assert_true(board.has_cell_at_grid(6, 12))
	assert_false(board.has_cell_at_grid(0, 0),
			"празните ъгли на 15×15 не са логически клетки")
	assert_true(board.get_cell_at_grid(0, 0) == null)
	assert_true(board.get_cell_at_grid(-1, 0) == null)
	assert_true(board.get_cell_at_grid(15, 0) == null)


func test_center_cell_grid_coordinates() -> void:
	var board := Classic15x15Board.create()
	var center := board.get_cell_at_grid(7, 7)
	assert_true(center != null)
	assert_eq(center.cell_id, CellId.CENTER)
	assert_true(center.is_center())
	assert_eq(center.grid_col, 7)
	assert_eq(center.grid_row, 7)


func test_prototype_spawn_grid_coordinates() -> void:
	# Референция: scripts/ludo_board.gd spawn_cells.
	var board := Classic15x15Board.create()
	var expected: Dictionary = {
		PlayerId.GREEN: Vector2i(8, 2),
		PlayerId.ORANGE: Vector2i(12, 8),
		PlayerId.YELLOW: Vector2i(6, 12),
		PlayerId.CYAN: Vector2i(2, 6),
	}
	for player_id in expected.keys():
		var pos: Vector2i = expected[player_id]
		var cell := board.get_cell_at_grid(pos.x, pos.y)
		assert_true(cell != null, "липсва spawn за %s" % player_id)
		assert_true(cell.is_spawn(), "%s spawn трябва да е SPAWN" % player_id)
		assert_eq(cell.grid_pos(), pos)


func test_prototype_base_grid_coordinates() -> void:
	# Референция: scripts/ludo_board.gd base_positions.
	var board := Classic15x15Board.create()
	var bases: Array[Vector2i] = [
		Vector2i(2, 2), Vector2i(3, 2), Vector2i(2, 3), Vector2i(3, 3),
		Vector2i(11, 2), Vector2i(12, 2), Vector2i(11, 3), Vector2i(12, 3),
		Vector2i(11, 11), Vector2i(12, 11), Vector2i(11, 12), Vector2i(12, 12),
		Vector2i(2, 11), Vector2i(3, 11), Vector2i(2, 12), Vector2i(3, 12),
	]
	assert_eq(bases.size(), 16)
	for pos in bases:
		var cell := board.get_cell_at_grid(pos.x, pos.y)
		assert_true(cell != null, "липсва base %s" % pos)
		assert_true(cell.is_base())
		assert_eq(cell.grid_pos(), pos)


func test_prototype_yellow_home_stretch_grid_coordinates() -> void:
	# Референция: scripts/ludo_board.gd home_stretch_positions[&"yellow"].
	var board := Classic15x15Board.create()
	var home: Array[Vector2i] = [
		Vector2i(7, 11), Vector2i(7, 10), Vector2i(7, 9), Vector2i(7, 8),
	]
	for pos in home:
		var cell := board.get_cell_at_grid(pos.x, pos.y)
		assert_true(cell != null, "липсва yellow home %s" % pos)
		assert_true(cell.is_home())
		assert_eq(cell.grid_pos(), pos)


# ── Типове и покритие спрямо layout ───────────────────────────────────────────

func test_cell_type_counts_match_geometry() -> void:
	var board := Classic15x15Board.create()
	var counts: Dictionary = {
		CellType.PATH: 0,
		CellType.BASE: 0,
		CellType.HOME: 0,
		CellType.SPAWN: 0,
		CellType.CENTER: 0,
	}
	for key in board.cells.keys():
		var cell := board.cells[key] as CellDefinition
		counts[cell.cell_type] = int(counts[cell.cell_type]) + 1
	assert_eq(counts[CellType.PATH], 36)
	assert_eq(counts[CellType.BASE], 16)
	assert_eq(counts[CellType.HOME], 16)
	assert_eq(counts[CellType.SPAWN], 4)
	assert_eq(counts[CellType.CENTER], 1)


func test_build_cells_matches_cell_type_at_for_full_grid() -> void:
	var cells := Classic15x15Board.build_cells()
	var occupied: int = 0
	for row in CellId.BOARD_SIZE:
		for col in CellId.BOARD_SIZE:
			var expected_type := Classic15x15Board.cell_type_at(col, row)
			var cell_id := CellId.from_grid(col, row)
			if expected_type < 0:
				assert_false(cells.has(cell_id),
						"празна позиция %s не трябва да е в cells" % cell_id)
			else:
				occupied += 1
				assert_true(cells.has(cell_id))
				var cell := cells[cell_id] as CellDefinition
				assert_eq(cell.cell_type, expected_type)
				assert_eq(cell.grid_col, col)
				assert_eq(cell.grid_row, row)
	assert_eq(occupied, Classic15x15Board.CELL_COUNT)


func test_has_grid_cell_agrees_with_board_definition() -> void:
	var board := Classic15x15Board.create()
	for row in CellId.BOARD_SIZE:
		for col in CellId.BOARD_SIZE:
			assert_eq(
					Classic15x15Board.has_grid_cell(col, row),
					board.has_cell_at_grid(col, row),
					"несъответствие при (%d, %d)" % [col, row])


func test_to_dict_preserves_grid_coordinates() -> void:
	var board := Classic15x15Board.create()
	var restored := BoardDefinition.from_dict(board.to_dict())
	assert_eq(restored.cell_count(), Classic15x15Board.CELL_COUNT)
	var sample := restored.get_cell_at_grid(8, 2)
	assert_true(sample != null)
	assert_eq(sample.grid_col, 8)
	assert_eq(sample.grid_row, 2)
	assert_true(sample.is_spawn())
	assert_true(board.equals(restored))


func test_no_theme_fields_in_serialized_classic_board() -> void:
	var d := Classic15x15Board.create().to_dict()
	assert_false(d.has("theme_id"))
	assert_false(d.has("texture"))
	assert_false(d.has("color"))
