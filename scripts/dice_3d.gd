extends Node3D

signal roll_finished(result: int)

@onready var mesh: MeshInstance3D = $MeshInstance3D

var is_rolling: bool = false
var roll_duration: float = 1.0

# Face rotations in Radians
# Assuming standard mesh orientation where 1 is top (0,0,0)
const FACE_ROTATIONS = {
	1: Vector3(0, 0, 0),
	6: Vector3(PI, 0, 0),
	2: Vector3(-PI/2, 0, 0),
	5: Vector3(PI/2, 0, 0),
	3: Vector3(0, 0, PI/2),
	4: Vector3(0, 0, -PI/2)
}

func _ready() -> void:
	# Start with a random face
	var start_face = randi_range(1, 6)
	mesh.rotation = FACE_ROTATIONS[start_face]

func roll() -> void:
	if is_rolling:
		return
	
	is_rolling = true
	var result: int = randi_range(1, 6)
	var target_rot: Vector3 = FACE_ROTATIONS[result]
	
	# Add multiple full rotations for effect
	var extra_rotations := Vector3(
		TAU * randi_range(2, 4),
		TAU * randi_range(2, 4),
		TAU * randi_range(2, 4)
	)
	
	var final_rot := target_rot + extra_rotations
	
	var tween := create_tween()
	tween.set_parallel(true)
	
	# Rotation animation
	tween.tween_property(mesh, "rotation", final_rot, roll_duration)\
		.set_trans(Tween.TRANS_QUART)\
		.set_ease(Tween.EASE_OUT)
	
	# Jump animation
	var jump_height := 2.0
	tween.tween_property(mesh, "position:y", jump_height, roll_duration / 2.0)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_OUT)
	tween.tween_property(mesh, "position:y", 0.0, roll_duration / 2.0)\
		.set_delay(roll_duration / 2.0)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN)
		
	await tween.finished
	
	# Reset rotation to base (non-accumulated) for the next roll
	mesh.rotation = target_rot
	
	is_rolling = false
	roll_finished.emit(result)
