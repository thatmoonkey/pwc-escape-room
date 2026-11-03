class_name InputRouter
extends RefCounted

## Platform-agnostic input bus.
##
## Gameplay and puzzle code read only three things: the InputMap actions
## (move_forward / move_back / move_left / move_right / interact), this look
## delta, and the interact edge. Desktop mouse, touch drag, and an XR controller
## all feed the SAME two values, so no puzzle or room script ever needs to know
## which platform is running.
##
## Static by design: no autoload entry, nothing to wire in project.godot.

static var look_delta: Vector2 = Vector2.ZERO
static var interact_just_pressed: bool = false
static var ui_blocking: bool = false


static func add_look(delta: Vector2) -> void:
	look_delta += delta


static func consume_look() -> Vector2:
	var delta: Vector2 = look_delta
	look_delta = Vector2.ZERO
	return delta


static func queue_interact() -> void:
	interact_just_pressed = true


static func consume_interact() -> bool:
	var pressed: bool = interact_just_pressed
	interact_just_pressed = false
	return pressed


static func set_ui_blocking(value: bool) -> void:
	ui_blocking = value
	if value:
		look_delta = Vector2.ZERO
		interact_just_pressed = false
