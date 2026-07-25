class_name Classic15x15CellIdsTest
extends TestCase
## Unit тестове за стабилните cell ID стойности на classic_15x15 (Task #38).
##
## Покрива docs/V1_ARCHITECTURE.md §4.1 / §4.6:
##   - Domain ползва стабилни cell_id, не NodePath / editor-generated имена.
##   - Всяка заета клетка има уникален CellId формат "c_{col}_{row}".
##   - Classic15x15Board.all_cell_ids() е авторитетният каталог (CELL_COUNT=73).
## base — Task #39; spawn — Task #40; main_loop / home — Tasks #41–#42.


# ── Каталог all_cell_ids ──────────────────────────────────────────────────────

func test_all_cell_ids_count_matches_cell_count() -> void:
	var ids := Classic15x15Board.all_cell_ids()
	assert_eq(ids.size(), Classic15x15Board.CELL_COUNT)
	assert_eq(ids.size(), 73)


func test_all_cell_ids_are_unique() -> void:
	var ids := Classic15x15Board.all_cell_ids()
	var seen: Dictionary = {}
	for cell_id in ids:
		assert_false(seen.has(cell_id), "дублиран cell_id: %s" % cell_id)
		seen[cell_id] = true
	assert_eq(seen.size(), Classic15x15Board.CELL_COUNT)


func test_all_cell_ids_are_valid_cell_id_format() -> void:
	for cell_id in Classic15x15Board.all_cell_ids():
		assert_true(CellId.is_valid(cell_id),
				"%s трябва да е валиден CellId" % cell_id)
		assert_true(String(cell_id).begins_with(CellId.PREFIX),
				"%s трябва да започва с %s" % [cell_id, CellId.PREFIX])


func test_all_cell_ids_are_stable_across_calls() -> void:
	var first := Classic15x15Board.all_cell_ids()
	var second := Classic15x15Board.all_cell_ids()
	assert_eq(first.size(), second.size())
	for i in first.size():
		assert_eq(first[i], second[i],
				"ред %d: нестабилен cell_id (%s ≠ %s)" % [i, first[i], second[i]])


func test_all_cell_ids_deterministic_row_major_order() -> void:
	var ids := Classic15x15Board.all_cell_ids()
	var prev := Vector2i(-1, -1)
	for cell_id in ids:
		var pos := CellId.to_vec(cell_id)
		var ordered := pos.y > prev.y or (pos.y == prev.y and pos.x > prev.x)
		assert_true(ordered,
				"all_cell_ids трябва да е row-major: %s след (%d,%d)" % [
					cell_id, prev.x, prev.y])
		prev = pos


func test_all_cell_ids_match_build_cells_keys() -> void:
	var catalog := Classic15x15Board.all_cell_ids()
	var cells := Classic15x15Board.build_cells()
	assert_eq(catalog.size(), cells.size())
	for cell_id in catalog:
		assert_true(cells.has(cell_id),
				"build_cells липсва каталожен id %s" % cell_id)
	for key in cells.keys():
		var cell_id := StringName(key)
		assert_true(catalog.has(cell_id),
				"каталогът липсва ключ от build_cells: %s" % cell_id)


func test_board_cells_keys_equal_cell_definition_ids() -> void:
	var board := Classic15x15Board.create()
	for key in board.cells.keys():
		var cell := board.cells[key] as CellDefinition
		assert_true(cell != null)
		assert_eq(StringName(key), cell.cell_id,
				"ключът на Dictionary трябва да съвпада с cell.cell_id")
		assert_eq(cell.cell_id, CellId.from_grid(cell.grid_col, cell.grid_row))


func test_no_editor_generated_or_node_path_cell_ids() -> void:
	for cell_id in Classic15x15Board.all_cell_ids():
		var s := String(cell_id)
		assert_false(s.contains("@"), "cell_id не трябва да съдържа @: %s" % s)
		assert_false(s.contains("/"), "cell_id не трябва да е NodePath: %s" % s)
		assert_false(s.begins_with("Sprite"), "cell_id не трябва да е node име: %s" % s)


# ── cell_id_at и известни стойности ───────────────────────────────────────────

func test_cell_id_at_occupied_matches_from_grid() -> void:
	assert_eq(Classic15x15Board.cell_id_at(7, 7), CellId.CENTER)
	assert_eq(Classic15x15Board.cell_id_at(8, 2), &"c_8_2")
	assert_eq(Classic15x15Board.cell_id_at(12, 8), &"c_12_8")
	assert_eq(Classic15x15Board.cell_id_at(6, 12), &"c_6_12")
	assert_eq(Classic15x15Board.cell_id_at(2, 6), &"c_2_6")


func test_cell_id_at_empty_returns_empty() -> void:
	assert_eq(Classic15x15Board.cell_id_at(0, 0), &"")
	assert_eq(Classic15x15Board.cell_id_at(1, 1), &"")
	assert_eq(Classic15x15Board.cell_id_at(14, 14), &"")
	assert_eq(Classic15x15Board.cell_id_at(-1, 0), &"")
	assert_eq(Classic15x15Board.cell_id_at(15, 0), &"")


func test_center_is_in_catalog() -> void:
	var ids := Classic15x15Board.all_cell_ids()
	assert_true(ids.has(CellId.CENTER), "CENTER трябва да е в all_cell_ids")
	assert_true(CellId.is_center(CellId.CENTER))


func test_prototype_reference_cell_ids_are_in_catalog() -> void:
	# Референтни стойности от ludo_board.gd — само наличие на ID-тата (не seat grouping).
	var expected: Array[StringName] = [
		&"c_8_2", &"c_12_8", &"c_6_12", &"c_2_6",  # spawn
		&"c_2_2", &"c_3_3", &"c_11_2", &"c_12_12",  # base samples
		&"c_7_11", &"c_7_8", &"c_8_7", &"c_3_7",  # home samples
		&"c_6_12", &"c_6_8", &"c_2_8", &"c_8_6",  # path samples
	]
	var catalog := Classic15x15Board.all_cell_ids()
	for cell_id in expected:
		assert_true(catalog.has(cell_id),
				"референтен cell_id %s трябва да е в каталога" % cell_id)


func test_empty_corners_are_not_in_catalog() -> void:
	var catalog := Classic15x15Board.all_cell_ids()
	var empty: Array[StringName] = [
		&"c_0_0", &"c_1_0", &"c_0_1",
		&"c_14_0", &"c_0_14", &"c_14_14",
		&"c_4_4", &"c_10_10",
	]
	for cell_id in empty:
		assert_false(catalog.has(cell_id),
				"празна позиция %s не трябва да е логическа клетка" % cell_id)


func test_every_catalog_id_roundtrips_grid() -> void:
	for cell_id in Classic15x15Board.all_cell_ids():
		var grid := CellId.to_vec(cell_id)
		assert_eq(CellId.from_grid(grid.x, grid.y), cell_id,
				"roundtrip за %s" % cell_id)
		assert_eq(Classic15x15Board.cell_id_at(grid.x, grid.y), cell_id)


func test_board_has_cell_for_every_catalog_id() -> void:
	var board := Classic15x15Board.create()
	for cell_id in Classic15x15Board.all_cell_ids():
		assert_true(board.has_cell(cell_id),
				"BoardDefinition трябва да съдържа %s" % cell_id)
		var cell := board.get_cell(cell_id)
		assert_true(cell != null)
		assert_true(cell.is_valid())
