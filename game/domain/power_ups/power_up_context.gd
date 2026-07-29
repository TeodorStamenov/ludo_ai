class_name PowerUpContext
extends RefCounted
## Контекст, подаван на PowerUpResolver.resolve() (docs/V1_ARCHITECTURE.md §4.7).
##
## Съдържа вземащия играч, пионка, клетка, command_sequence (за stamp на
## произведените DomainEvent) и активните ModifierPipeline модификатори
## (animal passives) — резолверите четат оттук, не от отделни позиционни
## аргументи, за да остане resolve() сигнатурата стабилна при добавяне на
## нови контекстни полета.

var player_id: StringName = &""
var pawn_id: StringName = &""
var cell_id: StringName = &""
var command_sequence: int = DomainEvent.COMMAND_SEQUENCE_UNSET
var modifiers: ModifierPipeline = null


static func create(
		p_player_id: StringName,
		p_pawn_id: StringName,
		p_cell_id: StringName,
		p_command_sequence: int = DomainEvent.COMMAND_SEQUENCE_UNSET,
		p_modifiers: ModifierPipeline = null
) -> PowerUpContext:
	var ctx := PowerUpContext.new()
	ctx.player_id = p_player_id
	ctx.pawn_id = p_pawn_id
	ctx.cell_id = p_cell_id
	ctx.command_sequence = p_command_sequence
	ctx.modifiers = p_modifiers if p_modifiers != null else ModifierPipeline.new()
	return ctx
