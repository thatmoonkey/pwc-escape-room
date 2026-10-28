class_name TouchControls
extends CanvasLayer

## Mobile input layer: two joysticks and the action buttons.
##
## LEFT thumb: the move stick - a fixed ring on the left of the screen, with a
## smaller knob you drag inside it. The ring's edge is the limit of travel, so
## the stick never runs away from the thumb and the movement never exceeds the
## walk cap.
##
## RIGHT thumb: the look stick - the same kind of ring on the right. This is
## what replaces the old raw drag-look: the knob's deflection is a RATE, not a
## delta, so the view turns smoothly and never whips - and when you let go the
## knob springs home and the view stops.
##
## The action buttons sit beside the right stick, within reach of the right
## thumb while the left thumb is on the move stick.
##
## It feeds the same InputMap actions and the same InputRouter look delta as
## the mouse, so no room or puzzle script changes for mobile.

@export var force_visible: bool = false

## The move stick. The ring is how far the knob can travel; dead zone is the
## fraction of the ring that counts as rest.
@export var move_radius: float = 70.0
@export var move_knob_radius: float = 30.0
@export var move_dead_zone: float = 0.18

## The look stick. The knob's deflection is a turn RATE in radians per second
## at full deflection - slow enough to keep the view readable, fast enough to
## turn when you mean it. The ring and dead zone are the same as the move stick.
@export var look_radius: float = 70.0
@export var look_knob_radius: float = 30.0
@export var look_dead_zone: float = 0.16
@export var look_yaw_speed: float = 2.3
@export var look_pitch_speed: float = 1.7
## The knob springs home this fast when you let go - fast enough to feel like
## it centres, slow enough not to snap.
@export var stick_return_speed: float = 10.0

@onready var root: Control = $Root
@onready var move_base: Control = $Root/MoveStick
@onready var move_knob: Control = $Root/MoveStick/Knob
@onready var look_base: Control = $Root/LookStick
@onready var look_knob: Control = $Root/LookStick/Knob
@onready var interact_button: Button = $Root/InteractButton
@onready var jump_button: Button = $Root/JumpButton
@onready var sprint_button: Button = $Root/SprintButton

const MOVE_ACTIONS: Array[String] = ["move_left", "move_right", "move_forward", "move_back"]

var _move_touch: int = -1
var _look_touch: int = -1
var _move_center: Vector2 = Vector2.ZERO
var _look_center: Vector2 = Vector2.ZERO
var _move_dir: Vector2 = Vector2.ZERO
var _look_dir: Vector2 = Vector2.ZERO
var _active_override: bool = false


func _ready() -> void:
	_refresh_visibility()
	move_base.visible = false
	look_base.visible = false
	if root.visible:
		interact_button.pressed.connect(func() -> void: InputRouter.queue_interact())
		jump_button.button_down.connect(func() -> void: Input.action_press("jump"))
		jump_button.button_up.connect(func() -> void: Input.action_release("jump"))
		sprint_button.toggled.connect(func(on: bool) -> void:
			if on:
				Input.action_press("sprint")
			else:
				Input.action_release("sprint"))


## The station controller's mode switch. On a desktop the override also lets
## the mouse drive the sticks, because a test is only useful if it can actually
## be driven.
func set_active(value: bool) -> void:
	if value == _active_override:
		return
	_active_override = value
	_refresh_visibility()
	if not root.visible:
		_release_all()


func _refresh_visibility() -> void:
	root.visible = force_visible or _active_override \
		or DisplayServer.is_touchscreen_available()


func _mouse_drives() -> bool:
	if force_visible:
		return true
	return _active_override and not DisplayServer.is_touchscreen_available()


func _process(delta: float) -> void:
	# The look stick is a rate, not a delta: every frame the view turns by the
	# knob's deflection, so it turns smoothly and stops dead when you let go.
	if root.visible and _look_dir.length_squared() > 0.0001:
		InputRouter.add_look(Vector2(_look_dir.x * look_yaw_speed,
			_look_dir.y * look_pitch_speed) * delta)
	# A released stick glides home instead of snapping, which reads as the
	# knob settling rather than disappearing.
	_ease_knob(move_knob, move_radius, delta)
	_ease_knob(look_knob, look_radius, delta)


func _ease_knob(knob: Control, radius: float, delta: float) -> void:
	if knob == null or knob.visible == false:
		return
	var home := Vector2(radius - (knob.size.x * 0.5), radius - (knob.size.y * 0.5))
	var from: Vector2 = knob.position
	if (home - from).length() < 0.5:
		knob.position = home
		return
	knob.position = from.lerp(home, 1.0 - exp(-stick_return_speed * delta))


func _input(event: InputEvent) -> void:
	if not root.visible or InputRouter.ui_blocking:
		return
	if event is InputEventScreenTouch:
		_handle_press(event.index, event.position, event.pressed)
	elif event is InputEventScreenDrag:
		_handle_drag(event.index, event.position)
	elif _mouse_drives() and event is InputEventMouseButton:
		_handle_press(-2, event.position, event.pressed)
	elif _mouse_drives() and event is InputEventMouseMotion \
			and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		_handle_drag(-2, event.position)


func _handle_press(index: int, position: Vector2, pressed: bool) -> void:
	for button: Button in [interact_button, jump_button, sprint_button]:
		if button.get_global_rect().has_point(position):
			return
	var half := get_viewport().get_visible_rect().size.x * 0.5
	if pressed:
		if position.x < half and _move_touch == -1:
			_move_touch = index
			_move_center = position
			_place_stick(move_base, move_knob, position, move_radius, move_knob_radius)
			move_base.visible = true
		elif position.x >= half and _look_touch == -1:
			_look_touch = index
			_look_center = position
			_place_stick(look_base, look_knob, position, look_radius, look_knob_radius)
			look_base.visible = true
		return
	if index == _move_touch:
		_move_touch = -1
		move_base.visible = false
		_move_dir = Vector2.ZERO
		_set_move(Vector2.ZERO)
	elif index == _look_touch:
		_look_touch = -1
		look_base.visible = false
		_look_dir = Vector2.ZERO


func _handle_drag(index: int, position: Vector2) -> void:
	if index == _move_touch:
		_move_dir = _stick_input(position - _move_center, move_radius, move_dead_zone)
		_set_knob(move_knob, move_radius, move_knob_radius, _move_dir)
		_set_move(_move_dir)
	elif index == _look_touch:
		_look_dir = _stick_input(position - _look_center, look_radius, look_dead_zone)
		_set_knob(look_knob, look_radius, look_knob_radius, _look_dir)


## Normalised stick input: 0..1 inside the dead zone, then a smooth ramp to
## full deflection at the ring's edge. The dead zone keeps a resting thumb
## from drifting, and the ramp keeps small movements slow and precise.
func _stick_input(offset: Vector2, radius: float, dead_zone: float) -> Vector2:
	var v: Vector2 = offset / radius
	var mag: float = v.length()
	if mag < dead_zone:
		return Vector2.ZERO
	var scaled: float = clampf((mag - dead_zone) / (1.0 - dead_zone), 0.0, 1.0)
	return (v / mag) * scaled if mag > 0.001 else Vector2.ZERO


## The ring centres on the touch, the knob at its middle.
func _place_stick(base: Control, knob: Control, position: Vector2,
		radius: float, knob_radius: float) -> void:
	base.position = position - Vector2(radius, radius)
	_center_knob(knob, radius, knob_radius)


func _center_knob(knob: Control, radius: float, knob_radius: float) -> void:
	if knob != null:
		knob.position = Vector2(radius - knob_radius, radius - knob_radius)


func _set_knob(knob: Control, radius: float, knob_radius: float, direction: Vector2) -> void:
	if knob == null:
		return
	var travel: float = radius - knob_radius
	knob.position = Vector2(radius, radius) - Vector2(knob_radius, knob_radius) + direction * travel


func _set_move(vector: Vector2) -> void:
	_action("move_left", vector.x < -0.5)
	_action("move_right", vector.x > 0.5)
	_action("move_forward", vector.y < -0.5)
	_action("move_back", vector.y > 0.5)


func _action(action: StringName, pressed: bool) -> void:
	var is_on: bool = Input.is_action_pressed(action)
	if pressed and not is_on:
		Input.action_press(action)
	elif not pressed and is_on:
		Input.action_release(action)


## Left pressed after a deactivation would walk the crew into a wall forever.
## Both sticks come home too, so the buttons and the knobs cannot outlive the
## touch that was driving them.
func _release_all() -> void:
	_move_touch = -1
	_look_touch = -1
	_move_dir = Vector2.ZERO
	_look_dir = Vector2.ZERO
	move_base.visible = false
	look_base.visible = false
	_set_move(Vector2.ZERO)
	Input.action_release("jump")
	Input.action_release("sprint")
	if sprint_button != null and sprint_button.button_pressed:
		sprint_button.set_pressed_no_signal(false)


func _exit_tree() -> void:
	_release_all()
