class_name TouchControls
extends CanvasLayer

## Mobile input layer: two joysticks and the action buttons.
##
## The sticks TELEPORT: tap the lower half of the screen and the nearest
## stick centres under your thumb, so you never have to hunt for it. The
## JUMP button floats above the right stick and tapping it never moves the
## stick - a button is a button, not a joystick.
##
## LEFT thumb: the move stick - a ring with a smaller knob you drag inside
## it. The ring's edge is the limit of travel.
##
## RIGHT thumb: the look stick - the same kind of ring. This is what replaces
## the old raw drag-look: the knob's deflection is a RATE, not a delta, so the
## view turns smoothly and never whips - and when you let go the knob springs
## home and the view stops.
##
## A TAP on the world (not on a stick, not on a button) is interact: the
## tap casts to whatever the crew is looking at, so the whole screen is the
## interact surface and no button is needed.
##
## It feeds the same InputMap actions and the same InputRouter look delta as
## the mouse, so no room or puzzle script changes for mobile.

@export var force_visible: bool = false

## The move stick. The ring is how far the knob can travel; dead zone is the
## fraction of the ring that counts as rest. The stick sits at the bottom-left
## until a touch claims it.
@export var move_radius: float = 80.0
@export var move_knob_radius: float = 32.0
@export var move_dead_zone: float = 0.18
@export var stick_margin: Vector2 = Vector2(34, 34)
## The sticks only teleport within the lower half of the screen: a tap higher
## up is a look drag, not a stick claim.
@export var stick_grab_region: float = 0.5

## The look stick. The knob's deflection is a turn RATE in radians per second
## at full deflection - slow enough to keep the view readable, fast enough to
## turn when you mean it.
@export var look_radius: float = 80.0
@export var look_knob_radius: float = 32.0
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
@onready var jump_button: Button = $Root/JumpButton

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
	_layout_sticks()
	_center_knob(move_knob, move_radius, move_knob_radius)
	_center_knob(look_knob, look_radius, look_knob_radius)
	if root.visible:
		jump_button.button_down.connect(func() -> void: Input.action_press("jump"))
		jump_button.button_up.connect(func() -> void: Input.action_release("jump"))
	get_viewport().size_changed.connect(_layout_sticks)


## The sticks rest at the bottom corners, and teleport to under a thumb that
## claims them in the lower half of the screen.
func _layout_sticks() -> void:
	if root == null or not root.visible:
		return
	if _move_touch != -1 or _look_touch != -1:
		return
	var view: Vector2 = get_viewport().get_visible_rect().size
	move_base.position = Vector2(stick_margin.x,
		view.y - stick_margin.y - move_radius * 2.0)
	look_base.position = Vector2(view.x - stick_margin.x - look_radius * 2.0,
		view.y - stick_margin.y - look_radius * 2.0)


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
	elif event is InputEventMouseButton:
		_handle_press(-2, event.position, event.pressed)
	elif event is InputEventMouseMotion \
			and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		_handle_drag(-2, event.position)


var _pending_touch: int = -1
var _pending_start: Vector2 = Vector2.ZERO
## A tap that travels this far is a drag, not a tap, so the finger wobbling
## while it touches never counts as a use.
const TAP_MAX_TRAVEL := 18.0


func _handle_press(index: int, position: Vector2, pressed: bool) -> void:
	if jump_button != null and jump_button.get_global_rect().has_point(position):
		return
	if pressed:
		# Every touch is a candidate tap first: it only becomes a stick once the
		# thumb moves, so a quick touch-and-release is always a use, never a
		# stick that briefly appeared.
		_pending_touch = index
		_pending_start = position
		return
	if index == _pending_touch:
		var is_tap: bool = position.distance_to(_pending_start) < TAP_MAX_TRAVEL
		_pending_touch = -1
		if is_tap and _move_touch == -1 and _look_touch == -1:
			InputRouter.queue_interact()
		return
	if index == _move_touch:
		_move_touch = -1
		_move_dir = Vector2.ZERO
		_set_move(Vector2.ZERO)
		_center_knob(move_knob, move_radius, move_knob_radius)
		_return_stick(move_base, move_radius, true)
	elif index == _look_touch:
		_look_touch = -1
		_look_dir = Vector2.ZERO
		_center_knob(look_knob, look_radius, look_knob_radius)
		_return_stick(look_base, look_radius, false)


func _handle_drag(index: int, position: Vector2) -> void:
	# A pending touch that has moved is a stick, not a tap: claim the nearest
	# one and start dragging, so the first pixel of movement already moves.
	if index == _pending_touch and position.distance_to(_pending_start) > TAP_MAX_TRAVEL:
		_claim_stick(index, position)
		_pending_touch = -1
	if index == _move_touch:
		_move_dir = _stick_input(position - _move_center, move_radius, move_dead_zone)
		_set_knob(move_knob, move_radius, move_knob_radius, _move_dir)
		_set_move(_move_dir)
	elif index == _look_touch:
		_look_dir = _stick_input(position - _look_center, look_radius, look_dead_zone)
		_set_knob(look_knob, look_radius, look_knob_radius, _look_dir)


## A drag in the lower half of the screen claims the nearest stick and centres
## it under the thumb, so the stick is under the finger the moment it starts
## to move - not under the finger it has to hunt for.
func _claim_stick(index: int, position: Vector2) -> void:
	var view: Vector2 = get_viewport().get_visible_rect().size
	var in_grab: bool = position.y > view.y * (1.0 - stick_grab_region)
	if in_grab and _move_touch == -1 and position.x < view.x * 0.5:
		_move_touch = index
		_move_center = position
		move_base.position = position - Vector2(move_radius, move_radius)
		_center_knob(move_knob, move_radius, move_knob_radius)
	elif in_grab and _look_touch == -1 and position.x >= view.x * 0.5:
		_look_touch = index
		_look_center = position
		look_base.position = position - Vector2(look_radius, look_radius)
		_center_knob(look_knob, look_radius, look_knob_radius)


## A released stick glides back to its corner instead of staying where the
## thumb left it, so the layout resets itself for the next tap.
func _return_stick(base: Control, radius: float, _left: bool) -> void:
	var view: Vector2 = get_viewport().get_visible_rect().size
	var target := Vector2(stick_margin.x, view.y - stick_margin.y - radius * 2.0)
	if not _left:
		target.x = view.x - stick_margin.x - radius * 2.0
	var tween := create_tween()
	tween.tween_property(base, "position", target, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


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
## Both knobs come home too, so the buttons and the sticks cannot outlive the
## touch that was driving them.
func _release_all() -> void:
	_move_touch = -1
	_look_touch = -1
	_pending_touch = -1
	_move_dir = Vector2.ZERO
	_look_dir = Vector2.ZERO
	_set_move(Vector2.ZERO)
	_center_knob(move_knob, move_radius, move_knob_radius)
	_center_knob(look_knob, look_radius, look_knob_radius)
	Input.action_release("jump")
	_return_stick(move_base, move_radius, true)
	_return_stick(look_base, look_radius, false)


func _exit_tree() -> void:
	_release_all()
