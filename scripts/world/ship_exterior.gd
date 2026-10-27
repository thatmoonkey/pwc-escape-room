class_name ShipExterior
extends Node3D

## Everything outside the windows, in one place.
##
## Placed at the ship's origin, so the outside world lines up correctly whichever
## window the crew member looks through: the same planet is in the same
## direction from every bay, which is what makes the ship feel like one vessel
## rather than five rooms with five separate backdrops.
##
## The station is DOCKED rather than distant. It sits off the port side with its
## long axis parallel to the corridor, its hull about 8 m beyond the port bay
## windows, and is joined to the corridor by structural arms. So the crew do not
## look out at a station on the horizon - they look out at the structure they are
## standing in, which is the point of the change.
##
## Adapted from the user's space_window_test_v2 prototype - the sun cycle, planet
## orbit, cloud rotation and debris pass are that prototype's pipeline, promoted
## from a SubViewport test into the real world.
##
## The starfield background deliberately lives on station.tscn's Environment
## rather than here, so the ship keeps a single environment and its fog, glow and
## SSAO are untouched by this node.

const EARTH_SCENE := "res://assets/exterior/earth.glb"
const STATION_SCENE := "res://assets/exterior/low-poly_space_station_-_3december.glb"

@export var orbit_period: float = 240.0
@export var earth_radius: float = 45.0
@export var earth_distance: float = 190.0
@export var earth_height: float = -20.0
## Docked, not distant. At this scale the hull runs the whole length of the
## corridor and passes about 8 m off the port bay windows.
@export var station_scale: float = 5.0
@export var station_position: Vector3 = Vector3(-30.0, -1.5, -3.5)
## Unrotated, so the model's own long axis runs parallel to the corridor. The
## station no longer rotates: it is bolted to the ship, and a hull turning under
## fixed structural arms reads as clipping.
@export var station_rotation_degrees: Vector3 = Vector3(0.0, 0.0, 0.0)
@export var close_debris_period: float = 80.0

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
var _earth_pivot: Node3D = null
var _clouds: Node3D = null
var _station: Node3D = null
var _close_debris: MeshInstance3D = null
var _time: float = 0.0


func _ready() -> void:
	_build_sun()
	_build_earth()
	_build_station()
	_build_docking_arms()
	_build_far_debris()
	_build_close_debris()


func _process(delta: float) -> void:
	_time += delta
	var angle: float = (_time / maxf(orbit_period, 1.0)) * TAU

	# The sun sweeps the whole scene, so the terminator walks across the planet
	# and the station drops into shadow over orbit_period.
	if _sun_pivot != null:
		_sun_pivot.rotation.y = angle
	# The planet orbits the ship the other way, so it drifts past each window.
	if _earth_pivot != null:
		_earth_pivot.rotation.y = -angle
	if _clouds != null:
		_clouds.rotate_y(delta * 0.02)

	_update_close_debris()


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


# --- Planet -------------------------------------------------------------------

func _build_earth() -> void:
	var scene: PackedScene = load(EARTH_SCENE) as PackedScene
	if scene == null:
		push_warning("ShipExterior: could not load %s" % EARTH_SCENE)
		return
	_earth_pivot = Node3D.new()
	_earth_pivot.name = "EarthPivot"
	add_child(_earth_pivot)
	var earth: Node3D = scene.instantiate()
	_earth_pivot.add_child(earth)

	# Normalise the imported model to earth_radius whatever it was authored at,
	# then recentre it on the target, because a Sketchfab pivot is rarely at the
	# middle of the model.
	var bounds: AABB = _merged_bounds(earth)
	var half: float = maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z)) * 0.5
	var factor: float = 1.0
	if half > 0.001:
		factor = earth_radius / half
	earth.scale = Vector3.ONE * factor
	var target := Vector3(earth_distance, earth_height, 0.0)
	earth.position = target - bounds.get_center() * factor

	_clouds = _find_by_name(earth, "nuages")
	if _clouds == null:
		_clouds = _find_by_name(earth, "cloud")
	var animation := _find_animation_player(earth)
	if animation != null and animation.has_animation("Take 001"):
		animation.play("Take 001")


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


# --- Debris -------------------------------------------------------------------

## The field the navigation bay argues about, pushed well out and given a dark
## rock finish. Without a material these boxes took the default white, and 160
## white boxes lit by the sun read as a cloud of floating lights rather than as
## debris - which is how they were reported. Dark, small and far away reads as
## rock; that is the whole difference.
func _build_far_debris() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var rock := BoxMesh.new()
	rock.size = Vector3(0.9, 0.6, 0.75)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.035, 0.032, 0.03)
	material.roughness = 1.0
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = rock
	var count: int = 160
	multi.instance_count = count
	for index in count:
		var angle: float = rng.randf() * TAU
		var radius: float = rng.randf_range(420.0, 700.0)
		var transform := Transform3D(
			Basis.from_euler(Vector3(rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU)),
			Vector3(cos(angle) * radius, rng.randf_range(-60.0, 60.0), sin(angle) * radius))
		transform.basis = transform.basis.scaled(Vector3.ONE * rng.randf_range(2.0, 7.0))
		multi.set_instance_transform(index, transform)
	var band := MultiMeshInstance3D.new()
	band.name = "FarDebris"
	band.multimesh = multi
	band.material_override = material
	add_child(band)


func _build_close_debris() -> void:
	var rock := BoxMesh.new()
	rock.size = Vector3(1.4, 0.9, 1.1)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.07, 0.062, 0.058)
	material.roughness = 1.0
	_close_debris = MeshInstance3D.new()
	_close_debris.name = "CloseDebris"
	_close_debris.mesh = rock
	_close_debris.material_override = material
	add_child(_close_debris)
	_update_close_debris()


## A tumbling rock that drifts past the starboard windows every few minutes - the
## K-7 field the navigation bay argues about, seen from inside.
##
## It runs on the starboard side because the station now fills the port side, and
## a rock crossing the docking arms would read as clipping rather than as debris.
func _update_close_debris() -> void:
	if _close_debris == null:
		return
	var phase: float = fmod(_time, close_debris_period) / maxf(close_debris_period, 1.0)
	var from := Vector3(26.0, -4.0, -48.0)
	var to := Vector3(26.0, 9.0, 48.0)
	_close_debris.position = from.lerp(to, phase)
	_close_debris.rotation = Vector3(_time * 0.7, _time * 0.5, _time * 0.3)
	_close_debris.scale = Vector3.ONE * (0.5 + 0.8 * sin(phase * PI))


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
