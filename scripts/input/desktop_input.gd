class_name DesktopInput
extends Node

## Desktop-only input layer: captures the mouse for look, forwards motion into
## InputRouter, and puts the interact edge on the same bus the touch and VR
## layers use. Swap this node out (or disable it) on other platforms.

@export var mouse_sensitivity: float = 0.0022


func _ready() -> void:
	add_to_group("input_layer")
	## Deferred, not immediate: the launch screen claims the input state during
	## the same frame, and grabbing the cursor now would fight it for the mouse.
	call_deferred("grab_mouse_if_clear")


## Grabs the cursor unless something else owns the input - the launch screen,
## or any open overlay. Public so the launch screen can hand the cursor back
## through the "input_layer" group when the crew begins.
func grab_mouse_if_clear() -> void:
	if InputRouter.ui_blocking:
		return
	grab_mouse()


func touch_mode() -> bool:
	return DisplayServer.is_touchscreen_available()


func grab_mouse() -> void:
	if not touch_mode():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func release_mouse() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		# Escape always hands the cursor back - the player must never be trapped.
		if not InputRouter.ui_blocking:
			release_mouse()
		return

	if InputRouter.ui_blocking:
		return

	if event is InputEventMouseButton and event.pressed \
			and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		grab_mouse()
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		InputRouter.add_look(event.relative * mouse_sensitivity)

	if event.is_action_pressed("interact"):
		InputRouter.queue_interact()
