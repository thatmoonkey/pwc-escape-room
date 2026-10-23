class_name Player
extends CharacterBody3D

## The crew member. First person, no jump, no crouch - it is a ship, not a
## shooter. Reads only InputMap actions and InputRouter, so the touch layer and
## the XR rig drive the exact same body.

@export var walk_speed: float = 3.4
@export var acceleration: float = 12.0
@export var look_scale: float = 1.0
@export var bob_strength: float = 0.03
@export var pitch_limit_degrees: float = 82.0

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var interactor: Interactor = $Head/Camera3D/Interactor

var _pitch: float = 0.0
var _bob_time: float = 0.0
var _gravity: float = 9.8


func _ready() -> void:
	add_to_group("player")
	_gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = 0.0

	if InputRouter.ui_blocking:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return

	_apply_look()
	_apply_movement(delta)
	_apply_bob(delta)
	move_and_slide()


func _apply_look() -> void:
	var look: Vector2 = InputRouter.consume_look() * look_scale
	if is_zero_approx(look.x) and is_zero_approx(look.y):
		return
	# Yaw on the body, pitch on the head - never both on the camera.
	rotate_y(-look.x)
	var limit: float = deg_to_rad(pitch_limit_degrees)
	_pitch = clampf(_pitch - look.y, -limit, limit)
	head.rotation.x = _pitch


func _apply_movement(delta: float) -> void:
	var input: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction: Vector3 = (transform.basis * Vector3(input.x, 0.0, input.y))
	direction.y = 0.0
	direction = direction.normalized()
	if direction.length_squared() > 0.001:
		velocity.x = lerpf(velocity.x, direction.x * walk_speed, acceleration * delta)
		velocity.z = lerpf(velocity.z, direction.z * walk_speed, acceleration * delta)
	else:
		velocity.x = lerpf(velocity.x, 0.0, acceleration * delta)
		velocity.z = lerpf(velocity.z, 0.0, acceleration * delta)


func _apply_bob(delta: float) -> void:
	var speed: float = Vector2(velocity.x, velocity.z).length()
	if speed < 0.4 or not is_on_floor():
		camera.position = camera.position.lerp(Vector3.ZERO, 8.0 * delta)
		return
	_bob_time += delta * 9.0
	camera.position.y = sin(_bob_time) * bob_strength
	camera.position.x = sin(_bob_time * 0.5) * bob_strength * 0.5


func get_interactor() -> Interactor:
	return interactor


func on_ui_closed() -> void:
	## Called when a terminal or card closes, so the desktop player gets the
	## mouse back instead of being left with a free cursor.
	var desktop := get_node_or_null("DesktopInput")
	if desktop != null and desktop.has_method("grab_mouse"):
		desktop.grab_mouse()
