class_name Interactor
extends RayCast3D

## Aim-based interaction.
##
## Parent it to the Camera3D for desktop and touch, or to an XRController3D for
## VR: the ray, the highlight, and the interact call are identical on every
## platform, which is what keeps the puzzle logic platform-agnostic.

signal target_changed(target: Interactable)

## Generous on purpose: the crew should be able to use a console from where it
## reads well, not from one exact spot on the floor.
@export var reach: float = 4.2

var current: Interactable = null


func _ready() -> void:
	target_position = Vector3(0.0, 0.0, -reach)
	collision_mask = 4
	collide_with_areas = false
	collide_with_bodies = true
	enabled = true


func _physics_process(_delta: float) -> void:
	if InputRouter.ui_blocking:
		InputRouter.consume_interact()
		_set_target(null)
		return
	force_raycast_update()
	var found: Interactable = get_collider() as Interactable
	if found != null and not found.can_interact(self):
		found = null
	_set_target(found)
	if current != null and InputRouter.consume_interact():
		current.interact(self)


func _set_target(next: Interactable) -> void:
	if next == current:
		return
	if current != null and is_instance_valid(current):
		current.set_highlighted(false)
	current = next
	if current != null:
		current.set_highlighted(true)
	target_changed.emit(current)
