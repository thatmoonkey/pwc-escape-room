class_name ShipExterior
extends Node3D

## Everything outside the windows, in one place.
##
## Placed at the ship's origin, so the outside world lines up correctly whichever
## window the crew member looks through: the same field passes every bay, which
## is what makes the ship feel like one vessel rather than five rooms with five
## separate backdrops.
##
## The station is DOCKED rather than distant. It sits off the port side with its
## long axis parallel to the corridor, its hull about 8 m beyond the port bay
## windows, and is joined to the corridor by structural arms. So the crew do not
## look out at a station on the horizon - they look out at the structure they are
## standing in, which is the point of the change.
##
## The sky itself is a shader (res://shaders/deep_space.gdshader) on
## station.tscn's Environment: black space with the soft swirls of distant
## galaxies refracting light, computed rather than photographed - it costs no
## texture memory and its density can be tuned by hand.
##
## The ship reads as moving. A near-star field drifts slowly past the windows
## (not warp speed - a quiet rate of knots), and rocks spawn ahead of the ship
## and drift past until they are recycled behind it, in one loop.

const STATION_SCENE := "res://assets/exterior/low-poly_space_station_-_3december.glb"

@export var orbit_period: float = 240.0
## Docked, not distant. At this scale the hull runs the whole length of the
## corridor and passes about 8 m off the port bay windows.
@export var station_scale: float = 5.0
@export var station_position: Vector3 = Vector3(-30.0, -1.5, -3.5)
## Unrotated, so the model's own long axis runs parallel to the corridor. The
## station no longer rotates: it is bolted to the ship, and a hull turning under
## fixed structural arms reads as clipping.
@export var station_rotation_degrees: Vector3 = Vector3(0.0, 0.0, 0.0)
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

## WHERE THE DOCKING ARMS STOP, and the one number that matters about them.
##
## This was -3.4, the old corridor's own port wall, and the arms started there.
## The interior is two decks of fully enclosed rooms now, whose port-most surface
## is deck 1's room wall at X -8.75 - so arms starting at the old corridor wall
## ran five metres INTO the life support room as three black beams straight
## through it. An arm may never cross into the interior at all.
##
## It now stops just outboard of the SHIP's own port flank, which the hull model
## measures at X -16.28, so the arms span the real gap between the station hull at
## -18.4 and the ship. The ship's flank is the honest source for this, not the
## station: ship_hull.gd's own receipt puts the widest half beam at 16.3 and the
## interior cutout at 16.5.
const ARM_STOP_X := -16.6
## Arm stations along Z. They no longer have to dodge anything: the arms end
## outside the ship, so they cross no window and no wall whatever their Z. They
## are kept as three parallel arms because that is what makes the docking read as
## one structure rather than as a single beam.
const ARM_Z: Array[float] = [-3.5, -5.5, -7.5]

var _sun_pivot: Node3D = null
var _station: Node3D = null
var _stars: MultiMeshInstance3D = null
var _star_offsets: PackedVector3Array = []
var _star_speeds: PackedFloat32Array = []
var _rocks: Array[MeshInstance3D] = []
var _rock_speeds: PackedFloat32Array = []
var _time: float = 0.0


func _ready() -> void:
	_build_sun()
	_build_station()
	_build_docking_arms()
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


# --- Station ------------------------------------------------------------------

func _build_station() -> void:
	var scene: PackedScene = load(STATION_SCENE) as PackedScene
	if scene == null:
		push_warning("ShipExterior: could not load %s" % STATION_SCENE)
		return
	_station = scene.instantiate()
	# Sketchfab exports can carry a preview camera and light; strip them so they
	# cannot fight the ship's own lighting or shadow the crew.
	for node in _collect_by_class(_station, "Camera3D") + _collect_by_class(_station, "Light3D"):
		node.queue_free()
	_station.scale = Vector3.ONE * station_scale
	_station.position = station_position
	_station.rotation_degrees = station_rotation_degrees
	add_child(_station)


## The ship is a module bolted to the station, and this is what makes that read
## from inside: three structural arms running from the ship's port flank out to
## the station hull, plus a rail joining their outer ends so the connection reads
## as one structure rather than three loose beams.
##
## The hull face is READ from the station's real bounds rather than assumed, so
## the arms still land on the hull if the scale or position above is changed.
##
## This replaces the previous running-light markers. Those were eight emissive
## spheres placed on the station's bounding-box corners, and because they were
## children of the station node - which is scaled up - each came out about five
## metres across and read as a ring of red spheres around the station. That was
## the reported glitch. They are removed rather than shrunk: a navigation light
## the size of a shuttle is no more convincing smaller.
func _build_docking_arms() -> void:
	if _station == null:
		return
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.085, 0.07, 0.062)
	metal.metallic = 0.7
	metal.roughness = 0.45

	var box: AABB = _merged_bounds(_station)
	var hull_x: float = box.position.x + box.size.x
	var span: float = absf(hull_x - ARM_STOP_X)
	if span < 1.0:
		push_warning("ShipExterior: station hull is only %.2f m from the ship's flank; no arms built." % span)
		return

	for z in ARM_Z:
		var arm := MeshInstance3D.new()
		var arm_mesh := BoxMesh.new()
		arm_mesh.size = Vector3(span, 0.5, 0.8)
		arm.mesh = arm_mesh
		arm.material_override = metal
		arm.name = "DockingArm"
		arm.position = Vector3((ARM_STOP_X + hull_x) * 0.5, 1.7, z)
		## Grouped so the departure cutscene can retract the arms as the ship
		## leaves. Left in place they stay welded to the station and appear to
		## stretch across the gap once the ship has moved away from it.
		arm.add_to_group("docking_arms")
		add_child(arm)

	var rail := MeshInstance3D.new()
	var rail_mesh := BoxMesh.new()
	rail_mesh.size = Vector3(0.4, 0.6, absf(ARM_Z[0] - ARM_Z[2]) + 8.0)
	rail.mesh = rail_mesh
	rail.material_override = metal
	rail.name = "DockingRail"
	rail.position = Vector3(hull_x + 0.3, 1.7, (ARM_Z[0] + ARM_Z[2]) * 0.5)
	rail.add_to_group("docking_arms")
	add_child(rail)

	print("[Exterior] station hull_x=%.2f span=%.2f arms=%d station_box=(%.1f..%.1f x, %.1f..%.1f y, %.1f..%.1f z)" % [
		hull_x, span, ARM_Z.size(),
		box.position.x, box.position.x + box.size.x,
		box.position.y, box.position.y + box.size.y,
		box.position.z, box.position.z + box.size.z])


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
		_star_offsets[i] = _field_point(rng, star_radius, star_length, true)
		_star_speeds[i] = rng.randf_range(0.6, 1.4)
		multi.set_instance_transform(i, Transform3D(Basis(), _star_offsets[i]))
	_stars = MultiMeshInstance3D.new()
	_stars.name = "StarField"
	_stars.multimesh = multi
	_stars.material_override = material
	add_child(_stars)


## The rocks: a sparse handful of dark shapes drifting past the windows, each
## on its own line so they pass at different heights and speeds. Spawned ahead
## of the ship and recycled behind it, in one loop.
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
		rock.position = _field_point(rng, rock_radius, rock_length, false)
		add_child(rock)
		_rocks.append(rock)
		_rock_speeds.append(rng.randf_range(0.8, 1.3))


## One point in the drift band. `sparse_port` is true for the stars: the band
## is full everywhere, but thins on the port side where the station hull fills
## the view - so nothing drifts through the docking arms or the hull.
func _field_point(rng: RandomNumberGenerator, radius: float, length: float,
		sparse_port: bool) -> Vector3:
	var x: float
	if sparse_port and rng.randf() < 0.35:
		# The station fills port; a star here would read as inside the hull.
		x = rng.randf_range(-radius * 0.4, radius * 0.4)
	else:
		x = rng.randf_range(-radius, radius)
		if absf(x) < 4.0:
			x = signf(x if x != 0.0 else 1.0) * rng.randf_range(4.0, radius)
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
			rock.position.z += rock_length * 1.5
			rock.position.x = randf_range(-rock_radius, rock_radius)
			rock.position.y = randf_range(-rock_radius * 0.4, rock_radius * 0.4)


# --- Helpers ------------------------------------------------------------------

func _merged_bounds(root: Node) -> AABB:
	var bounds := AABB()
	var first: bool = true
	for mesh in _collect_meshes(root):
		var box: AABB = mesh.global_transform * mesh.get_aabb()
		if first:
			bounds = box
			first = false
		else:
			bounds = bounds.merge(box)
	return bounds


func _collect_meshes(node: Node) -> Array[MeshInstance3D]:
	var found: Array[MeshInstance3D] = []
	if node is MeshInstance3D:
		found.append(node)
	for child in node.get_children():
		found.append_array(_collect_meshes(child))
	return found


func _collect_by_class(node: Node, klass: String) -> Array[Node]:
	var found: Array[Node] = []
	if node.is_class(klass):
		found.append(node)
	for child in node.get_children():
		found.append_array(_collect_by_class(child, klass))
	return found


func _find_by_name(node: Node, fragment: String) -> Node3D:
	var wanted: String = fragment.to_lower()
	if node is Node3D and wanted in String(node.name).to_lower():
		return node as Node3D
	for child in node.get_children():
		var hit: Node3D = _find_by_name(child, fragment)
		if hit != null:
			return hit
	return null


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var hit: AnimationPlayer = _find_animation_player(child)
		if hit != null:
			return hit
	return null
