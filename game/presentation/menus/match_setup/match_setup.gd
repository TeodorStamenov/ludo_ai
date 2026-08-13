class_name MatchSetup
extends Control
## Екран „Нова игра" (docs/V1_GAME_DESIGN.md §8.1; #290).
##
## Избор на брой играчи (2/3/4), тип за всяко активно място (Human/AI),
## AI difficulty при AI места, отключено животно, отключена тема.
## Произвежда MatchConfig и го предава на AppFlow.navigate_to_game(config).
##
## Достъпва AppFlow.animal_registry/theme_registry, за да покаже само
## животни/теми с реално съдържание (.tres) — този екран винаги се достига
## през AppFlow (Main Menu → „Нова игра"), затова не пада към локални
## fallback инстанции както GameScreen прави за standalone F6 run.
##
## Unlock-филтър (AppFlow.save_repository.is_unlocked) съзнателно НЕ се
## прилага тук — Campaign екранът (единственият източник на unlocks) е
## отделна, все още несъздадена задача, така че нищо никога не би могло да
## се отключи и играчът би бил заклещен само с PIG завинаги. Когато Campaign
## съществува, филтърът трябва да се върне.

const _SEAT_NAMES := {
	&"green": "Зелен",
	&"orange": "Оранжев",
	&"yellow": "Жълт",
	&"cyan": "Циан",
}
const _CONTROLLER_LABELS := ["Човек", "AI"]
const _DIFFICULTY_LABELS := ["Лесно", "Средно", "Трудно"]

@onready var _count_buttons: Dictionary = {
	2: $Panel/PlayerCountRow/Count2Button,
	3: $Panel/PlayerCountRow/Count3Button,
	4: $Panel/PlayerCountRow/Count4Button,
}
@onready var _theme_option: OptionButton = $Panel/ThemeRow/ThemeOption
@onready var _seats_container: VBoxContainer = $Panel/SeatsContainer
@onready var _error_label: Label = $Panel/ErrorLabel
@onready var _back_button: Button = $Panel/ActionsRow/BackButton
@onready var _start_button: Button = $Panel/ActionsRow/StartButton

var _app_flow: Node = null
var _player_count: int = 2
## player_id → {controller: OptionButton, difficulty: OptionButton, animal: OptionButton}
var _seat_controls: Dictionary = {}
## player_id → животното, което мястото имаше ПРЕДИ последната промяна — нужно
## за swap-ване (виж _on_animal_selected). Няма signal за "старата" стойност,
## затова се пази ръчно.
var _previous_animal_by_seat: Dictionary = {}
var _available_animal_ids: Array[StringName] = []
var _available_theme_ids: Array[StringName] = []


func _ready() -> void:
	_app_flow = get_node(^"/root/AppFlow")
	_available_animal_ids = _available_ids(AnimalId.ALL, _app_flow.animal_registry)
	_available_theme_ids = _available_ids(ThemeId.ALL, _app_flow.theme_registry)

	for count in _count_buttons:
		var button: Button = _count_buttons[count]
		button.pressed.connect(_on_player_count_pressed.bind(count))

	_populate_theme_options()
	_back_button.pressed.connect(_on_back_pressed)
	_start_button.pressed.connect(_on_start_pressed)

	_set_player_count(2)


## id-та от `all_ids`, за които регистърът има реално съдържание (.tres).
## Content без .tres (напр. rabbit/dog животни, desert тема) не се показва —
## по-добре отсъстващ избор, отколкото счупен.
func _available_ids(all_ids: Array, registry: Object) -> Array[StringName]:
	var result: Array[StringName] = []
	for id in all_ids:
		if registry.has_definition(id):
			result.append(id)
	return result


func _populate_theme_options() -> void:
	_theme_option.clear()
	for theme_id in _available_theme_ids:
		_theme_option.add_item(String(theme_id).capitalize())
		_theme_option.set_item_metadata(_theme_option.item_count - 1, theme_id)
	if _theme_option.item_count > 0:
		_theme_option.selected = 0


func _on_player_count_pressed(count: int) -> void:
	_set_player_count(count)


func _set_player_count(count: int) -> void:
	_player_count = count
	for c in _count_buttons:
		var button: Button = _count_buttons[c]
		button.button_pressed = (c == count)
	_rebuild_seat_rows()


func _rebuild_seat_rows() -> void:
	for child in _seats_container.get_children():
		_seats_container.remove_child(child)
		child.free()
	_seat_controls.clear()

	var seat_ids: Array = MatchConfig.default_seats_for_count(_player_count)
	for i in seat_ids.size():
		var player_id: StringName = seat_ids[i]
		_seats_container.add_child(_build_seat_row(player_id, i))
	_capture_animal_selections()


func _build_seat_row(player_id: StringName, seat_index: int) -> HBoxContainer:
	var row := HBoxContainer.new()

	var name_label := Label.new()
	name_label.text = _SEAT_NAMES.get(player_id, String(player_id).capitalize())
	name_label.custom_minimum_size = Vector2(72, 0)
	row.add_child(name_label)

	var controller_option := OptionButton.new()
	for label in _CONTROLLER_LABELS:
		controller_option.add_item(label)
	row.add_child(controller_option)

	var difficulty_option := OptionButton.new()
	for label in _DIFFICULTY_LABELS:
		difficulty_option.add_item(label)
	row.add_child(difficulty_option)

	var animal_option := OptionButton.new()
	for animal_id in _available_animal_ids:
		var definition: AnimalDefinition = _app_flow.animal_registry.definition_for(animal_id)
		var label := (
				definition.display_name if definition != null
				else String(animal_id).capitalize())
		animal_option.add_item(label)
		animal_option.set_item_metadata(animal_option.item_count - 1, animal_id)
	if not _available_animal_ids.is_empty():
		animal_option.selected = seat_index % _available_animal_ids.size()
	animal_option.item_selected.connect(_on_animal_selected.bind(player_id))
	row.add_child(animal_option)

	# Първо място е човек по подразбиране (single-player срещу AI, огледално
	# на GameScreen._default_match_config()); останалите — AI/Лесно.
	controller_option.selected = 0 if seat_index == 0 else 1
	difficulty_option.selected = 0
	difficulty_option.visible = controller_option.selected == 1
	controller_option.item_selected.connect(
			func(index: int) -> void: difficulty_option.visible = index == 1)

	_seat_controls[player_id] = {
		"controller": controller_option,
		"difficulty": difficulty_option,
		"animal": animal_option,
	}
	return row


## Записва текущия избор на всяко място в _previous_animal_by_seat — базовата
## линия, от която _on_animal_selected познава кое животно се "освобождава"
## при swap. Вика се веднъж след rebuild на местата.
func _capture_animal_selections() -> void:
	_previous_animal_by_seat.clear()
	for player_id in _seat_controls:
		var animal_option: OptionButton = _seat_controls[player_id]["animal"]
		if animal_option.selected >= 0:
			_previous_animal_by_seat[player_id] = animal_option.get_item_metadata(animal_option.selected)


## Две места не могат да имат едно и също животно (различни животни правят
## страните разпознаваеми — виж GameScreen._default_match_config()), затова
## вместо да блокира вече заетите животни, разменя ги: ако избереш животно,
## което друго място вече има, това място получава животното, което ти
## тъкмо остави — винаги остава биекция без нужда от disable/blocked items.
func _on_animal_selected(_index: int, player_id: StringName) -> void:
	var animal_option: OptionButton = _seat_controls[player_id]["animal"]
	var new_animal_id: StringName = animal_option.get_item_metadata(animal_option.selected)
	var old_animal_id: Variant = _previous_animal_by_seat.get(player_id)

	if new_animal_id == old_animal_id:
		return

	for other_id in _seat_controls:
		if other_id == player_id:
			continue
		if _previous_animal_by_seat.get(other_id) == new_animal_id:
			var other_option: OptionButton = _seat_controls[other_id]["animal"]
			_select_animal_by_id(other_option, old_animal_id)
			_previous_animal_by_seat[other_id] = old_animal_id
			break

	_previous_animal_by_seat[player_id] = new_animal_id


## OptionButton.select() не излъчва item_selected — безопасно е да сменяме
## чужд OptionButton програмно тук без рекурсивно да тригерираме swap-а пак.
func _select_animal_by_id(option: OptionButton, animal_id: Variant) -> void:
	if animal_id == null:
		return
	for idx in option.item_count:
		if option.get_item_metadata(idx) == animal_id:
			option.select(idx)
			return


func _selected_theme_id() -> StringName:
	if _theme_option.item_count == 0:
		return ThemeId.DEFAULT
	return _theme_option.get_item_metadata(_theme_option.selected)


func _on_back_pressed() -> void:
	_app_flow.navigate_to_main_menu()


func _on_start_pressed() -> void:
	var config := MatchConfig.create_with_seat_count(_player_count)
	config.set_theme(_selected_theme_id())

	for player_id in _seat_controls:
		var controls: Dictionary = _seat_controls[player_id]
		var controller_option: OptionButton = controls["controller"]
		var animal_option: OptionButton = controls["animal"]
		var controller_type := (
				MatchConfig.ControllerType.HUMAN if controller_option.selected == 0
				else MatchConfig.ControllerType.AI)
		var animal_id: StringName = (
				animal_option.get_item_metadata(animal_option.selected) if animal_option.item_count > 0
				else AnimalId.DEFAULT)
		var difficulty_option: OptionButton = controls["difficulty"]
		config.configure_seat(player_id, controller_type, animal_id, difficulty_option.selected)

	if not config.is_valid():
		_error_label.text = "Невалидна конфигурация — опитай пак."
		return

	_error_label.text = ""
	_app_flow.navigate_to_game(config)
