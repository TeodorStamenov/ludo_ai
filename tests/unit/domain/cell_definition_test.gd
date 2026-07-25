class_name CellDefinitionTest
extends TestCase
## Unit тестове за CellDefinition (Task #34 / docs/V1_ARCHITECTURE.md, §4.6).
##
## Покрива:
##   - Domain: extends RefCounted, път game/domain/model/, без тема.
##   - Логически тип (CellType) + изометрични grid координати.
##   - Фабрики create / create_from_grid и съгласуваност с CellId.
##   - is_valid() инварианти (id, тип, grid, CENTER).
##   - Type helpers и is_on_main_track().
##   - Сериализация to_dict / from_dict / equals / duplicate_definition.


# ── Архитектурни изисквания ───────────────────────────────────────────────────

func test_cell_definition_extends_ref_counted() -> void:
	var cell := CellDefinition.new()
	assert_true(cell is RefCounted,
			"CellDefinition трябва да extends RefCounted, не Node")


func test_cell_definition_is_not_node() -> void:
	var cell: Object = CellDefinition.new()
	assert_false(cell is Node,
			"CellDefinition не трябва да extends Node — domain слой е без сцени")


func test_cell_definition_script_path_is_in_domain_model() -> void:
	var cell := CellDefinition.new()
	var path: String = cell.get_script().resource_path
	assert_true(path.contains("game/domain/model/"),
			"CellDefinition трябва да е в game/domain/model/")


func test_to_dict_does_not_contain_theme_fields() -> void:
	var cell := CellDefinition.create_from_grid(8, 2, CellType.SPAWN)
	var d := cell.to_dict()
	assert_false(d.has("theme_id"), "темата не е част от CellDefinition")
	assert_false(d.has("texture"), "текстурата не е част от CellDefinition")
	assert_false(d.has("color"), "цветът не е част от CellDefinition")


# ── Стойности по подразбиране ─────────────────────────────────────────────────

func test_default_cell_type_is_path() -> void:
	var cell := CellDefinition.new()
	assert_eq(cell.cell_type, CellType.PATH, "default cell_type трябва да е PATH")


func test_default_cell_id_is_empty() -> void:
	var cell := CellDefinition.new()
	assert_eq(cell.cell_id, &"", "default cell_id трябва да е празен")


func test_default_grid_is_origin() -> void:
	var cell := CellDefinition.new()
	assert_eq(cell.grid_col, 0)
	assert_eq(cell.grid_row, 0)


# ── Фабрики ───────────────────────────────────────────────────────────────────

func test_create_from_grid_sets_id_type_and_coords() -> void:
	var cell := CellDefinition.create_from_grid(8, 2, CellType.SPAWN)
	assert_eq(cell.cell_id, &"c_8_2")
	assert_eq(cell.cell_type, CellType.SPAWN)
	assert_eq(cell.grid_col, 8)
	assert_eq(cell.grid_row, 2)
	assert_true(cell.is_valid())


func test_create_from_grid_center() -> void:
	var cell := CellDefinition.create_from_grid(7, 7, CellType.CENTER)
	assert_eq(cell.cell_id, CellId.CENTER)
	assert_true(cell.is_center())
	assert_true(cell.is_valid())


func test_create_from_cell_id_derives_grid() -> void:
	var cell := CellDefinition.create(&"c_12_8", CellType.SPAWN)
	assert_eq(cell.grid_col, 12)
	assert_eq(cell.grid_row, 8)
	assert_eq(cell.cell_type, CellType.SPAWN)
	assert_true(cell.is_valid())


func test_create_from_invalid_cell_id_yields_invalid_definition() -> void:
	var cell := CellDefinition.create(&"not_a_cell", CellType.PATH)
	assert_eq(cell.grid_col, -1)
	assert_eq(cell.grid_row, -1)
	assert_false(cell.is_valid())


func test_create_from_grid_out_of_bounds_yields_empty_id() -> void:
	var cell := CellDefinition.create_from_grid(15, 0, CellType.PATH)
	assert_eq(cell.cell_id, &"")
	assert_false(cell.is_valid())


func test_grid_pos_matches_col_row() -> void:
	var cell := CellDefinition.create_from_grid(6, 12, CellType.SPAWN)
	assert_eq(cell.grid_pos(), Vector2i(6, 12))


func test_create_factories_agree_on_same_cell() -> void:
	var from_grid := CellDefinition.create_from_grid(2, 6, CellType.PATH)
	var from_id := CellDefinition.create(CellId.from_grid(2, 6), CellType.PATH)
	assert_true(from_grid.equals(from_id),
			"create и create_from_grid трябва да дават еднаква клетка")


# ── Type helpers ──────────────────────────────────────────────────────────────

func test_type_helpers_for_each_cell_type() -> void:
	var base := CellDefinition.create_from_grid(0, 0, CellType.BASE)
	assert_true(base.is_base())
	assert_false(base.is_path())
	assert_false(base.is_on_main_track())

	var path := CellDefinition.create_from_grid(1, 0, CellType.PATH)
	assert_true(path.is_path())
	assert_true(path.is_on_main_track())

	var spawn := CellDefinition.create_from_grid(8, 2, CellType.SPAWN)
	assert_true(spawn.is_spawn())
	assert_true(spawn.is_on_main_track(),
			"SPAWN е част от общото трасе")

	var home := CellDefinition.create_from_grid(7, 8, CellType.HOME)
	assert_true(home.is_home())
	assert_false(home.is_on_main_track())

	var center := CellDefinition.create_from_grid(7, 7, CellType.CENTER)
	assert_true(center.is_center())
	assert_false(center.is_on_main_track())


# ── is_valid ──────────────────────────────────────────────────────────────────

func test_is_valid_accepts_well_formed_cells_of_all_types() -> void:
	for cell_type in CellType.ALL:
		var col := 3
		var row := 4
		if cell_type == CellType.CENTER:
			col = 7
			row = 7
		var cell := CellDefinition.create_from_grid(col, row, cell_type)
		assert_true(cell.is_valid(),
				"валидна клетка от тип %s трябва да минава is_valid" % CellType.type_name(cell_type))


func test_is_valid_rejects_empty_cell_id() -> void:
	var cell := CellDefinition.new()
	cell.cell_type = CellType.PATH
	assert_false(cell.is_valid(), "празен cell_id трябва да е невалиден")


func test_is_valid_rejects_unknown_cell_type() -> void:
	var cell := CellDefinition.create_from_grid(1, 1, 99)
	assert_false(cell.is_valid(), "непознат cell_type трябва да е невалиден")


func test_is_valid_rejects_mismatched_id_and_grid() -> void:
	var cell := CellDefinition.create_from_grid(8, 2, CellType.SPAWN)
	cell.grid_col = 0
	cell.grid_row = 0
	assert_false(cell.is_valid(),
			"cell_id и grid координатите трябва да са съгласувани")


func test_is_valid_rejects_center_type_on_non_center_cell() -> void:
	var cell := CellDefinition.create_from_grid(8, 2, CellType.CENTER)
	assert_false(cell.is_valid(),
			"CellType.CENTER е валиден само за CellId.CENTER")


func test_is_valid_accepts_center_on_center_cell() -> void:
	var cell := CellDefinition.create(CellId.CENTER, CellType.CENTER)
	assert_true(cell.is_valid())


func test_is_valid_rejects_out_of_bounds_grid_even_if_id_looks_ok() -> void:
	var cell := CellDefinition.new()
	cell.cell_id = &"c_0_0"
	cell.cell_type = CellType.PATH
	cell.grid_col = 15
	cell.grid_row = 0
	assert_false(cell.is_valid())


# ── Сериализация ──────────────────────────────────────────────────────────────

func test_to_dict_contains_all_schema_keys() -> void:
	var cell := CellDefinition.create_from_grid(8, 2, CellType.SPAWN)
	var d := cell.to_dict()
	assert_true(d.has("cell_id"))
	assert_true(d.has("cell_type"))
	assert_true(d.has("grid_col"))
	assert_true(d.has("grid_row"))


func test_to_dict_writes_string_cell_id_and_int_type() -> void:
	var cell := CellDefinition.create_from_grid(7, 7, CellType.CENTER)
	var d := cell.to_dict()
	assert_eq(d["cell_id"], "c_7_7")
	assert_eq(d["cell_type"], CellType.CENTER)
	assert_eq(d["grid_col"], 7)
	assert_eq(d["grid_row"], 7)


func test_from_dict_round_trip_preserves_fields() -> void:
	var original := CellDefinition.create_from_grid(6, 12, CellType.HOME)
	var restored := CellDefinition.from_dict(original.to_dict())
	assert_eq(restored.cell_id, &"c_6_12")
	assert_eq(restored.cell_type, CellType.HOME)
	assert_eq(restored.grid_col, 6)
	assert_eq(restored.grid_row, 12)
	assert_true(restored.is_valid())
	assert_true(original.equals(restored))


func test_from_dict_missing_fields_use_defaults() -> void:
	var cell := CellDefinition.from_dict({})
	assert_eq(cell.cell_id, &"")
	assert_eq(cell.cell_type, CellType.PATH)
	assert_eq(cell.grid_col, 0)
	assert_eq(cell.grid_row, 0)


func test_duplicate_definition_is_independent_copy() -> void:
	var original := CellDefinition.create_from_grid(2, 6, CellType.PATH)
	var copy := original.duplicate_definition()
	assert_true(original.equals(copy))
	copy.cell_type = CellType.SPAWN
	assert_eq(original.cell_type, CellType.PATH,
			"duplicate_definition не трябва да споделя мутабелно състояние")


func test_equals_false_for_null_and_different_cells() -> void:
	var a := CellDefinition.create_from_grid(1, 1, CellType.PATH)
	var b := CellDefinition.create_from_grid(1, 2, CellType.PATH)
	assert_false(a.equals(null))
	assert_false(a.equals(b))


func test_all_architecture_types_can_be_represented() -> void:
	# docs/V1_ARCHITECTURE.md §4.6: BASE, PATH, SPAWN, HOME, CENTER
	var samples: Array[CellDefinition] = [
		CellDefinition.create_from_grid(0, 1, CellType.BASE),
		CellDefinition.create_from_grid(5, 5, CellType.PATH),
		CellDefinition.create_from_grid(8, 2, CellType.SPAWN),
		CellDefinition.create_from_grid(7, 9, CellType.HOME),
		CellDefinition.create_from_grid(7, 7, CellType.CENTER),
	]
	assert_eq(samples.size(), CellType.COUNT)
	for cell in samples:
		assert_true(cell.is_valid(),
				"%s трябва да е валидна CellDefinition" % cell.cell_id)
