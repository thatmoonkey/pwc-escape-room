class_name BayTrigger
extends Area3D

## Invisible floor trigger that fires once when the crew member walks into a
## bay, so SHIPMIND can greet them on arrival. Reused by every room.

signal speak(lines: PackedStringArray)

@export var lines: PackedStringArray = PackedStringArray()
@export var one_shot: bool = true

var _fired: bool = false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	monitoring = true
	add_to_group("bay_trigger")
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if _fired and one_shot:
		return
	if not body.is_in_group("player"):
		return
	_fired = true
	speak.emit(lines)
