class_name TouchControls
extends CanvasLayer

## Mobile input layer: left-half drag is a floating movement stick, right-half
## drag is look, tap or the on-screen button is interact. It feeds the same
## InputMap actions and the same InputRouter look delta as the mouse, so no room
## or puzzle script changes for mobile.
##
## Set force_visible = true to exercise the mobile layout on desktop (mouse drag
## drives it too).

@export var force_visible: bool = false
@export var look_sensitivity: float = 0.22
@export var stick_radius: float = 68.0
@export var knob_radius: float = 26.0
@export var dead_zone: float = 0.22

@onready var root: Control = $Root
@onready var stick: Control = $Root/Stick
@onready var knob: Panel = $Root/Stick/Knob
@onready var interact_button: Button = $Root/InteractButton

const MOVE_ACTIONS: Array[String] = ["move_left", "move_right", "move_forward", "move_back"]

var _move_touch: int = -1
var _look_touch: int = -1
var _move_center: Vector2 = Vector2.ZERO
var _look_last: Vector2 = Vector2.ZERO
var _look_travel: float = 0.0


func _ready() -> void:
	root.visible = force_visible or DisplayServer.is_touchscreen_available()
	stick.visible = false
	if not root.visible:
		return
	interact_button.pressed.connect(func() -> void: InputRouter.queue_interact())


func _input(event: InputEvent) -> void:
	if not root.visible or InputRouter.ui_blocking:
		return
	if event is InputEventScreenTouch:
		_handle_press(event.index, event.position, event.pressed)
	elif event is InputEventScreenDrag:
		_handle_drag(event.index, event.position)
	elif force_visible and event is InputEventMouseButton:
		_handle_press(-2, event.position, event.pressed)
	elif force_visible and event is InputEventMouseMotion \
			and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		_handle_drag(-2, event.position)


func _handle_press(index: int, position: Vector2, pressed: bool) -> void:
	if interact_button.get_global_rect().has_point(position):
		return
	if pressed:
		if position.x < get_viewport().get_visible_rect().size.x * 0.45 and _move_touch == -1:
			_move_touch = index
			_move_center = position
			stick.position = position - Vector2(stick_radius, stick_radius)
			stick.visible = true
			_center_knob()
		elif _look_touch == -1:
			_look_touch = index
			_look_last = position
			_look_travel = 0.0
		return
	if index == _move_touch:
		_move_touch = -1
		stick.visible = false
		_set_move(Vector2.ZERO)
	elif index == _look_touch:
		_look_touch = -1
		if _look_travel < 14.0:
			InputRouter.queue_interact()


func _handle_drag(index: int, position: Vector2) -> void:
	if index == _move_touch:
		var offset: Vector2 = (position - _move_center) / stick_radius
		if offset.length() > 1.0:
			offset = offset.normalized()
		knob.position = _knob_home() + offset * (stick_radius - knob_radius - 4.0)
		_set_move(offset)
	elif index == _look_touch:
		var delta: Vector2 = position - _look_last
		_look_last = position
		_look_travel += delta.length()
		InputRouter.add_look(delta * look_sensitivity)


func _knob_home() -> Vector2:
	return Vector2(stick_radius - knob_radius, stick_radius - knob_radius)


func _center_knob() -> void:
	knob.position = _knob_home()


func _set_move(vector: Vector2) -> void:
	_action("move_left", vector.x < -dead_zone)
	_action("move_right", vector.x > dead_zone)
	_action("move_forward", vector.y < -dead_zone)
	_action("move_back", vector.y > dead_zone)


func _action(action: StringName, pressed: bool) -> void:
	var is_on: bool = Input.is_action_pressed(action)
	if pressed and not is_on:
		Input.action_press(action)
	elif not pressed and is_on:
		Input.action_release(action)


func _exit_tree() -> void:
	for action in MOVE_ACTIONS:
		if Input.is_action_pressed(action):
			Input.action_release(action)
