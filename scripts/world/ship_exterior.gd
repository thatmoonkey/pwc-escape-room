class_name ShipExterior
extends Node3D

## Everything outside the windows, in one place.
##
## Placed at the ship's origin, so the outside world lines up correctly whichever
## window the crew member looks through: the same field passes every bay, which
## is what makes the ship feel like one vessel rather than five rooms with five
## separate backdrops.
##
## THERE IS NO STATION OUTSIDE. There used to be: a docked hull off the port side
## with three structural arms tying it to the ship. It was removed, so the crew
## now look out on open space on both sides - the drifting field is the whole of
## what is out there.
##
## The sky itself is a shader (res://shaders/deep_space.gdshader) on
## station.tscn's Environment: black space with the soft swirls of distant
## galaxies refracting light, computed rather than photographed - it costs no
## texture memory and its density can be tuned by hand.
##
## The ship reads as moving. A near-star field drifts slowly past the windows
## (not warp speed - a quiet rate of knots), and rocks spawn ahead of the ship
## and drift past until they are recycled behind it, in one loop.

@export var orbit_period: float = 240.0
## The drifting field outside the windows. The ship reads as moving: stars
## pass slowly (a near-star field, not warp lines) and rocks spawn ahead of
## the ship and drift past until they are recycled behind it, in one loop.
@export var drift_speed: float = 6.5
@export var star_count: int = 240
@export var star_radius: float = 26.0
@export var star_length: float = 160.0
@export var rock_count: int = 14
@export var rock_radius: float = 15.0
@export var rock_length: float = 150.0
## The ship's own half-beam, plus a clear margin. Nothing in the field ever
## spawns inside this band on X, so debris always passes OUTSIDE the hull and
## never crosses the interior where it would read as flying past the crew's
## head.
const HULL_HALF_BEAM := 17.0

var _sun_pivot: Node3D = null
var _stars: MultiMeshInstance3D = null
var _star_offsets: PackedVector3Array = []
var _star_speeds: PackedFloat32Array = []
var _rocks: Array[MeshInstance3D] = []
var _rock_speeds: PackedFloat32Array = []
var _time: float = 0.0


func _ready() -> void:
	_build_sun()
	_build_star_field()
	_build_drifting_rocks()


func _process(delta: float) -> void:
	_time += delta
	var angle: float = (_time / maxf(orbit_period, 1.0)) * TAU

	# The sun sweeps the whole scene, so the terminator walks across the
	# station's hull over orbit_period. No planet: the sky is deep space.
	if _sun_pivot != null:
		_sun_pivot.rotation.y = angle

	_update_star_field(delta)
	_update_drifting_rocks(delta)


# --- Sun ----------------------------------------------------------------------

func _build_sun() -> void:
	_sun_pivot = Node3D.new()
	_sun_pivot.name = "SunPivot"
	_sun_pivot.rotation_degrees.x = -18.0
	add_child(_sun_pivot)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_energy = 0.45
	sun.shadow_enabled = false
	_sun_pivot.add_child(sun)


# --- The drifting field -------------------------------------------------------

## The near-star field. A few hundred dim points in a band around the ship,
## drifting slowly past the windows so the ship reads as moving. One MultiMesh
## for the whole field - one draw call, no per-star nodes.
##
## They run on both sides, but the port side thins out where the station hull
## fills the view, so the field never fights the docking arms.
func _build_star_field() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	var quad := QuadMesh.new()
	quad.size = Vector2(0.14, 0.14)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.92, 0.94, 1.0)
	material.emission_enabled = true
	material.emission = Color(0.92, 0.94, 1.0)
	material.emission_energy_multiplier = 0.6
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = quad
	multi.instance_count = star_count
	_star_offsets.resize(star_count)
	_star_speeds.resize(star_count)
	for i in star_count:
		_star_offsets[i] = _field_point(rng, star_radius, star_length)
		_star_speeds[i] = rng.randf_range(0.6, 1.4)
		multi.set_instance_transform(i, Transform3D(Basis(), _star_offsets[i]))
	_stars = MultiMeshInstance3D.new()
	_stars.name = "StarField"
	## Written every frame from _process, not by physics: interpolating it only
	## lags the drift a tick and logs a warning.
	_stars.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_stars.multimesh = multi
	_stars.material_override = material
	add_child(_stars)


## The rocks: a sparse handful of dark shapes drifting past the windows, each
## on its own line so they pass at different heights and speeds. Spawned ahead
## of the ship and recycled behind it, in one loop - and every line keeps
## outside the hull, so a rock passes the window and never the crew.
func _build_drifting_rocks() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.045, 0.042, 0.04)
	material.roughness = 1.0
	for i in rock_count:
		var rock := MeshInstance3D.new()
		rock.name = "DriftRock_%d" % i
		var mesh := BoxMesh.new()
		mesh.size = Vector3(
			rng.randf_range(0.8, 2.4),
			rng.randf_range(0.5, 1.4),
			rng.randf_range(0.7, 1.9))
		rock.mesh = mesh
		rock.material_override = material
		rock.rotation = Vector3(rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU)
		rock.position = _rock_line(rng)
		add_child(rock)
		_rocks.append(rock)
		_rock_speeds.append(rng.randf_range(0.8, 1.3))


## One rock's line: outside the hull on one side of the ship, at a height and
## depth along its run.
func _rock_line(rng: RandomNumberGenerator) -> Vector3:
	var side: float = 1.0 if rng.randf() < 0.5 else -1.0
	return Vector3(
		side * rng.randf_range(HULL_HALF_BEAM, rock_radius + HULL_HALF_BEAM),
		rng.randf_range(-rock_radius * 0.4, rock_radius * 0.4),
		rng.randf_range(-rock_length, rock_length * 0.5))


## One point in the drift band. Everything in the field stays OUTSIDE the
## hull's half-beam on X - never inside it - so a rock or a star can never
## cross the interior and read as flying past the crew's head. Both sides get
## the same field: with the station gone there is open space to port as well.
func _field_point(rng: RandomNumberGenerator, radius: float, length: float) -> Vector3:
	var side: float = 1.0 if rng.randf() < 0.5 else -1.0
	var x: float = side * rng.randf_range(HULL_HALF_BEAM, radius + HULL_HALF_BEAM)
	return Vector3(x, rng.randf_range(-radius * 0.45, radius * 0.45),
		rng.randf_range(-length, length * 0.5))


## The drift: everything moves -Z (the ship reads as flying forward, +Z). A
## point that passes behind the ship's stern is wrapped to the far front, so
## the field never thins and never accumulates.
func _update_star_field(delta: float) -> void:
	if _stars == null:
		return
	var multi := _stars.multimesh
	for i in _star_offsets.size():
		var p: Vector3 = _star_offsets[i]
		p.z -= drift_speed * _star_speeds[i] * delta
		if p.z < -star_length:
			p.z += star_length * 1.5
		_star_offsets[i] = p
		multi.set_instance_transform(i, Transform3D(Basis(), p))


func _update_drifting_rocks(delta: float) -> void:
	for i in _rocks.size():
		var rock := _rocks[i]
		rock.position.z -= drift_speed * _rock_speeds[i] * delta
		rock.rotation += Vector3(0.21, 0.13, 0.09) * delta
		if rock.position.z < -rock_length:
			# Recycle behind the bow, on a fresh line outside the hull.
			var side: float = 1.0 if randf() < 0.5 else -1.0
			rock.position = Vector3(
				side * randf_range(HULL_HALF_BEAM, rock_radius + HULL_HALF_BEAM),
				randf_range(-rock_radius * 0.4, rock_radius * 0.4),
				rock.position.z + rock_length * 1.5)
