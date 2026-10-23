extends Node3D

## READ-ONLY DIAGNOSTIC. "The stairs can only be walked down" is a physics
## question, so it is answered by driving one: a capsule the size of the crew is
## placed at the foot of each flight, pushed along it, and its position logged
## until it stops. Whatever it stops against is printed by name.
##
##   run scenes/dev/probe_ascent.tscn -> read the console
##
## It changes nothing. The walker is added to a copy of the station under this
## probe scene and freed again; no saved scene or script is touched.

const RADIUS := 0.35
const HEIGHT := 1.8
const SPEED := 2.2
const LEG_SECONDS := 4.0

## [name, start, push direction]. The lower flight rises AFT from deck 2's floor;
## the upper flight rises FORWARD from the turn, because the crew come up the
## lower flight, cross the landing, and turn back the other way.
var _legs: Array = [
	["lower, up from deck 2", Vector3(0.875, -4.80, -30.5), Vector3(0.0, 0.0, -1.0)],
	["upper, up from the turn", Vector3(-0.875, -2.35, -34.6), Vector3(0.0, 0.0, 1.0)],
]

var _walker: CharacterBody3D = null
var _leg: int = 0
var _elapsed: float = 0.0
var _start: Vector3 = Vector3.ZERO
var _hit: String = "nothing"


func _ready() -> void:
	await get_tree().process_frame
	_next()


func _next() -> void:
	if _leg >= _legs.size():
		print("[Ascent] all legs finished")
		return
	var leg: Array = _legs[_leg]
	var start: Vector3 = leg[1]
	_start = start
	_hit = "nothing"
	_walker = CharacterBody3D.new()
	_walker.name = "AscentProbe"
	_walker.collision_layer = 1
	_walker.collision_mask = 6
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = RADIUS
	capsule.height = HEIGHT
	shape.shape = capsule
	shape.position = Vector3(0.0, HEIGHT * 0.5, 0.0)
	_walker.add_child(shape)
	add_child(_walker)
	_walker.global_position = start
	_elapsed = 0.0
	print("[Ascent] leg %d - %s - start %s" % [_leg, leg[0], str(start)])


func _physics_process(delta: float) -> void:
	if _walker == null or not is_instance_valid(_walker):
		return
	var leg: Array = _legs[_leg]
	var push: Vector3 = leg[2]
	_walker.velocity.x = push.x * SPEED
	_walker.velocity.z = push.z * SPEED
	if _walker.is_on_floor():
		_walker.velocity.y = 0.0
	else:
		_walker.velocity.y -= 9.8 * delta
	_walker.move_and_slide()
	## What it is touching, so a stop can be named rather than guessed at.
	for i in _walker.get_slide_collision_count():
		var collider: Object = _walker.get_slide_collision(i).get_collider()
		if collider is Node3D:
			_hit = "%s (scene %s) at %s" % [collider.name, (collider as Node3D).scene_file_path,
				str((collider as Node3D).global_position)]
	_elapsed += delta
	if _elapsed < LEG_SECONDS:
		return
	var end: Vector3 = _walker.global_position
	print("[Ascent] leg %d END %s | moved %.2f m | on_floor=%s | last touched %s" % [
		_leg, str(end), (end - _start).length(), str(_walker.is_on_floor()), _hit])
	_walker.queue_free()
	_walker = null
	_leg += 1
	_next()
