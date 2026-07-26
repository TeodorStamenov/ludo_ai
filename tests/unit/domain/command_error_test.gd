class_name CommandErrorTest
extends TestCase
## Unit тестове за CommandError (Task #81 / docs/V1_ARCHITECTURE.md, §4.3 / §12).
##
## Покрива критични инварианти:
##   - Domain: extends RefCounted, път game/domain/model/.
##   - Стабилни CODE_* / ALL_CODES за UI / journal / reject.
##   - is_valid(): само известен непразен code.
##   - Фабрики create / not_implemented / wrong_player / illegal_move.


# ── Архитектурни изисквания ───────────────────────────────────────────────────

func test_command_error_extends_ref_counted() -> void:
	var err := CommandError.new()
	assert_true(err is RefCounted,
			"CommandError трябва да extends RefCounted, не Node")


func test_command_error_is_not_node() -> void:
	var err: Object = CommandError.new()
	assert_false(err is Node,
			"CommandError не трябва да extends Node — domain слой е без сцени")


func test_command_error_script_path_is_in_domain_model() -> void:
	var err := CommandError.new()
	var path: String = err.get_script().resource_path
	assert_true(path.contains("game/domain/model/"),
			"CommandError трябва да е в game/domain/model/")


func test_to_dict_has_no_presentation_fields() -> void:
	var err := CommandError.illegal_move("stack would exceed 2")
	var d := err.to_dict()
	assert_false(d.has("position"), "Vector2 position не е част от CommandError")
	assert_false(d.has("node_path"), "NodePath не е част от CommandError")
	assert_false(d.has("texture"), "texture не е част от domain CommandError")
	assert_false(d.has("accepted"), "accepted е в CommandResult, не в CommandError")
	assert_false(d.has("state"), "state е в CommandResult, не в CommandError")


# ── Стабилни кодове ───────────────────────────────────────────────────────────

func test_code_constants_are_stable_string_names() -> void:
	assert_eq(CommandError.CODE_NOT_IMPLEMENTED, &"not_implemented")
	assert_eq(CommandError.CODE_INVALID_COMMAND, &"invalid_command")
	assert_eq(CommandError.CODE_WRONG_MATCH, &"wrong_match")
	assert_eq(CommandError.CODE_WRONG_PLAYER, &"wrong_player")
	assert_eq(CommandError.CODE_WRONG_PHASE, &"wrong_phase")
	assert_eq(CommandError.CODE_ILLEGAL_MOVE, &"illegal_move")
	assert_eq(CommandError.CODE_UNKNOWN_PAWN, &"unknown_pawn")
	assert_eq(CommandError.CODE_MATCH_NOT_ACTIVE, &"match_not_active")
	assert_eq(CommandError.CODE_MATCH_FINISHED, &"match_finished")
	assert_eq(CommandError.CODE_SEQUENCE_MISMATCH, &"sequence_mismatch")


func test_all_codes_lists_every_known_code_once() -> void:
	assert_eq(CommandError.ALL_CODES.size(), 10)
	var seen: Dictionary = {}
	for code in CommandError.ALL_CODES:
		assert_true(CommandError.is_known_code(code),
				"ALL_CODES елемент трябва да е known: %s" % String(code))
		assert_false(seen.has(code), "дублиран code в ALL_CODES: %s" % String(code))
		seen[code] = true


func test_is_known_code_rejects_unknown() -> void:
	assert_false(CommandError.is_known_code(&""))
	assert_false(CommandError.is_known_code(&"not_a_real_error"))
	assert_true(CommandError.is_known_code(CommandError.CODE_ILLEGAL_MOVE))


# ── is_valid() ────────────────────────────────────────────────────────────────

func test_default_fields_are_invalid() -> void:
	var err := CommandError.new()
	assert_eq(err.code, &"")
	assert_eq(err.message, "")
	assert_false(err.is_valid(),
			"празен code → is_valid() == false")


func test_is_valid_requires_known_code() -> void:
	var known := CommandError.create(CommandError.CODE_WRONG_PHASE, "awaiting roll")
	assert_true(known.is_valid())
	var unknown := CommandError.create(&"custom_future_code", "x")
	assert_false(unknown.is_valid(),
			"неизвестен code не е валиден (като DomainEvent.is_known_type)")
	var empty_msg := CommandError.create(CommandError.CODE_WRONG_PLAYER, "")
	assert_true(empty_msg.is_valid(),
			"празен message е позволен — UI мапва code")


# ── Фабрики ───────────────────────────────────────────────────────────────────

func test_create_sets_code_and_message() -> void:
	var err := CommandError.create(CommandError.CODE_WRONG_MATCH, "match_id mismatch")
	assert_eq(err.code, CommandError.CODE_WRONG_MATCH)
	assert_eq(err.message, "match_id mismatch")
	assert_true(err.is_valid())


func test_convenience_factories_use_stable_codes() -> void:
	assert_eq(CommandError.not_implemented().code, CommandError.CODE_NOT_IMPLEMENTED)
	assert_eq(CommandError.invalid_command("bad seq").code,
			CommandError.CODE_INVALID_COMMAND)
	assert_eq(CommandError.wrong_player().code, CommandError.CODE_WRONG_PLAYER)
	assert_eq(CommandError.wrong_phase("AWAITING_MOVE").code,
			CommandError.CODE_WRONG_PHASE)
	assert_eq(CommandError.illegal_move("third pawn on cell").code,
			CommandError.CODE_ILLEGAL_MOVE)
	assert_true(CommandError.not_implemented().is_valid())
	assert_true(CommandError.illegal_move().is_valid())


func test_equals_and_duplicate_error() -> void:
	var original := CommandError.wrong_player("not active")
	var copy := original.duplicate_error()
	assert_true(original.equals(copy))
	copy.message = "changed"
	assert_false(original.equals(copy))
	assert_eq(original.message, "not active",
			"duplicate_error не трябва да споделя референция")
	assert_false(original.equals(null))
