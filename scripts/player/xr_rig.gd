class_name XRRig
extends CharacterBody3D

## OpenXR input layer: head-tracked camera, thumbstick locomotion with snap
## turn, and one Interactor ray per controller.
##
## The controllers drive the SAME InputRouter the mouse and touch layers use, so
## aiming and using a console is identical code on every platform. This layer is
## OFF by default: it only loads when xr/openxr/enabled is true (see the notes
## in res://docs/adding-a-system.md).

@export var move_speed: float = 2.2
@export var snap_turn_degrees: float = 30.0
@export var turn_threshold: float = 0.7

@onready var origin: XROrigin3D = $XROrigin3D
@onready var camera: XRCamera3D = $XROrigin3D/XRCamera3D
@onready var left_hand: XRController3D = $XROrigin3D/LeftHand
@onready var right_hand: XRController3D = $XROrigin3D/RightHand

var _gravity: float = 9.8
var _turn_armed: bool = true


func _ready() -> void:
	add_to_group("player")
	_gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
	left_hand.button_pressed.connect(_on_button_pressed)
	right_hand.button_pressed.connect(_on_button_pressed)
	_connect_recenter()


## The headset's own recenter has to be answered by the game.
##
## This project runs the Stage reference space, and Godot's XR docs are explicit
## about what that means: when the player recenters, the runtime does NOT move
## the origin, the interface emits pose_recentered instead, and it is the game's
## job to react - "not doing so will prevent your game from being accepted on
## various stores". Nothing was listening, so a recenter did nothing at all.
func _connect_recenter() -> void:
	var xr_interface: XRInterface = XRServer.primary_interface
	if xr_interface == null:
		return
	if not xr_interface.pose_recentered.is_connected(_on_pose_recentered):
		xr_interface.pose_recentered.connect(_on_pose_recentered)


## Keeping the player's height (the second argument) is what matches a crew
## member standing on the ship's deck: the alternative drops the camera to the
## origin, which would put the crew's eyes on the floor plates.
func _on_pose_recentered() -> void:
	XRServer.center_on_hmd(XRServer.RESET_BUT_KEEP_TILT, true)


## The BOOL actions, not "trigger" and "primary": in the action map those two are
## a Float and a Vector2 action, and XRController3D only raises button_pressed for
## Bool ones. Listening for them meant only the A/X button ever fired, so pulling
## the trigger could not use a console - which is the whole game.
func _on_button_pressed(button: StringName) -> void:
	match String(button):
		"trigger_click", "primary_click", "ax_button":
			InputRouter.queue_interact()


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

	var stick: Vector2 = left_hand.get_vector2("primary")
	var forward: Vector3 = -camera.global_transform.basis.z
	var right: Vector3 = camera.global_transform.basis.x
	forward.y = 0.0
	right.y = 0.0
	var direction: Vector3 = right * stick.x + forward * -stick.y
	if direction.length() > 0.15:
		direction = direction.normalized()
	else:
		direction = Vector3.ZERO
	velocity.x = direction.x * move_speed
	velocity.z = direction.z * move_speed

	var turn: float = right_hand.get_vector2("primary").x
	if absf(turn) < turn_threshold:
		_turn_armed = true
	elif _turn_armed:
		_turn_armed = false
		origin.rotate_y(-signf(turn) * deg_to_rad(snap_turn_degrees))

	move_and_slide()


func on_ui_closed() -> void:
	pass
