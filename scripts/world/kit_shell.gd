class_name KitShell
extends Node3D

## Rebuilds the station shell from the modular kit in res://assets/kit/modules.
##
## WHY THE KIT IS WRAPPED, AND WHY IT IS MEASURED RATHER THAN ASSUMED
## The first version of this file placed each module by writing rotation.y and
## scale.x straight onto the instanced scene root. That silently discarded
## whatever orientation the exporter had put on that root, and the kit does NOT
## arrive with its height on the Y axis: it is authored Z-up, so the height lives
## on the module's local Z. Overwriting the rotation left every wall lying flat -
## 2 m of length, 0.33 m of thickness standing up, and the 3.4 m of height
## running along the corridor instead of up it. With the old blockout meshes
## hidden behind that, the corridor read as a see-through box full of slabs.
##
## So a module is now parented UNTOUCHED inside a plain Node3D wrapper, and only
## the wrapper's transform is written. The module keeps its own root transform,
## which means no exported orientation can be destroyed by accident.
##
## The wrapper is then oriented from MEASUREMENT, not assumption: the module's
## local bounding box is taken once, and its three axes are matched against the
## footprint the kit manifest declares (length, height, thickness). Whichever
## axis measures the declared height is rotated upright, whether that axis is Y
## or Z. Nothing here depends on the exporter agreeing with us.
##
## COLLISION IS DELIBERATELY UNTOUCHED
## The existing Shell box SHAPES stay exactly where they are; only the old box
## MESHES are hidden. So the player capsule, the five consoles, the door
## triggers, the bay triggers and the exterior windows all keep working, and this
## node contributes no collision of its own.
##
## Corridor coordinates, read from the scene rather than assumed:
##   old side wall boxes are 0.30 m thick centred on x = +/-3.15, so 3.15 is a
##   CENTRE line and the interior is 6.0 m wide
##   floor top y = 0, ceiling underside y = 3.4
##   five bay openings, each 2.8 m wide and the full 3.4 m height

const MODULE_DIR := "res://assets/kit/modules/"
const WALL_MODULE := "Wall_Run.glb"
const DOOR_FRAME := "Door_Frame.glb"
const DOOR_PANEL := "Door_Panel.glb"
const WINDOW_UNIT := "Window_Unit.glb"

## The two tones of the wall, plus the finish the rest of the kit is painted in.
## The kit ships its own grey baked into each GLB, and these modules are created
## at runtime, so nothing saved in the scene can ever repaint them: the material
## has to be assigned here, at the one place a module is placed.
const WALL_FACE := "res://materials/wall_upper.tres"
const WALL_BASE := "res://materials/wall_lower.tres"
const TRIM_MAT := "res://materials/trim_black.tres"
const DOOR_MAT := "res://materials/door_locked.tres"

## module file -> the palette material every mesh in that module is painted with.
const PAINT := {
	WALL_MODULE: WALL_FACE,
	DOOR_FRAME: TRIM_MAT,
	DOOR_PANEL: DOOR_MAT,
	WINDOW_UNIT: TRIM_MAT,
}

## The lower band of the two-tone wall: how tall it stands, and how far it stands
## proud of the wall face it is laid against.
const WAINSCOT_H := 1.05
const WAINSCOT_T := 0.06

## The footprint each module declares in the kit manifest, as
## (length, height, thickness). Used only to work out which of a module's
## measured axes is which - never to size anything by assumption.
const FOOTPRINT := {
	WALL_MODULE: Vector3(2.0, 3.4, 0.33),
	DOOR_FRAME: Vector3(3.4, 3.4, 0.385),
	DOOR_PANEL: Vector3(3.0, 3.3, 0.24),
	WINDOW_UNIT: Vector3(7.6, 3.4, 0.385),
}

## The side wall centre line. The kit wall is 0.33 m thick, so sharing this line
## puts its inner face at 2.985 against the collision face at 3.0 - within 15 mm,
## rather than the 150 mm invisible gap that centring it on the interior would
## open.
const WALL_C := 3.15
const WALL_T := 0.33
const HEIGHT := 3.4
const HALF_L := 18.0
const RUN_END := HALF_L + WALL_T * 0.5
const END_C := HALF_L + WALL_T * 0.5

## Bays, and the one opening width they all share.
const BAY_W := 7.0
const BAY_BACK_INNER := 11.0
const BAY_BACK_C := BAY_BACK_INNER + WALL_T * 0.5
const OPENING_W := 2.8
## Bay side walls are buried at both ends: they start inside the corridor wall and
## finish inside the bay back wall, so neither end face ever lands on a wall
## plane. WALL_C + 0.10 sits inside the kit wall's 2.985 .. 3.315 span, and
## BAY_BACK_INNER + 0.25 sits inside the bay back wall's 11.0 .. 11.33 span.
const SIDE_IN := WALL_C + 0.10
const SIDE_OUT := BAY_BACK_INNER + 0.25

## The longest kit wall module. Runs are cut into spans no longer than this.
const MAX_SPAN := 2.0

const BAYS := [
	{"id": "navigation", "side": -1.0, "z": 13.0},
	{"id": "life_support", "side": 1.0, "z": 7.0},
	{"id": "comms", "side": -1.0, "z": 1.0},
	{"id": "cargo", "side": 1.0, "z": -5.0},
	{"id": "engineering", "side": -1.0, "z": -12.0},
]

## The four bays that start sealed. Navigation has no door: SHIPMIND left it
## unlocked so the crew could review its work.
const DOORS := {
	"life_support": "SealedDoor_LifeSupport",
	"comms": "SealedDoor_Comms",
	"cargo": "SealedDoor_Cargo",
	"engineering": "SealedDoor_Engineering",
}

var _cache: Dictionary = {}
## file name -> the module's local bounding box, measured once on first use.
var _native: Dictionary = {}
## file name -> Array of world AABBs for every module of that type placed.
var _placed: Dictionary = {}
## How many wainscot bands were laid. Reported in the boot receipt, because a
## two-tone wall whose lower band silently failed to build looks exactly like a
## one-tone wall, and no other evidence would say so.
var _wainscots: int = 0
## How many old blockout meshes stood down, and how many kit meshes were actually
## repainted, per material path. A shell whose modules built but whose paint never
## reached them looks exactly like a shell that was never painted at all: both
## leave the corridor reading in whatever colour the module was authored in, and
## the only place that difference is visible is here.
var _retired: int = 0
var _painted: Dictionary = {}


func _ready() -> void:
	## Grouped so anything that needs the corridor's real numbers can read them
	## from one place instead of repeating them and drifting.
	add_to_group("kit_shell")
	_retire_old_shell()
	_build_side_walls()
	_build_end_walls()
	_build_bays()
	_report()


## Hides the old blockout meshes and hands the flat surfaces the kit's finish.
## Nothing is deleted: every CollisionShape3D under Shell stays in force.
func _retire_old_shell() -> void:
	var shell := get_parent().get_node_or_null("Shell")
	if shell != null:
		for child in shell.get_children():
			if not (child is MeshInstance3D):
				continue
			var mesh_name := String(child.name)
			## Floor and ceiling are kept and merely re-finished. The kit's 2 m
			## floor and ceiling tiles would be roughly 450 more nodes for no
			## visible gain over the two slabs already here.
			if mesh_name == "FloorMesh" or mesh_name == "CeilingMesh":
				continue
			## The bay back walls are not blockout: they are WindowWall's
			## shutters, and that script shows and hides them itself. Hiding one
			## here would break the shutter the player is meant to see come down.
			if mesh_name.contains("BayBack"):
				continue
			(child as MeshInstance3D).visible = false
			_retired += 1
	_set_material(shell, "FloorMesh", "res://materials/floor_dark.tres")
	_set_material(shell, "CeilingMesh", "res://materials/panel_light.tres")

	## The accent and skirting strips authored before the kit arrived would sit
	## inside the kit's own panel detailing, so they stand down.
	var detail := get_parent().get_node_or_null("WallDetail")
	if detail is Node3D:
		(detail as Node3D).visible = false

	## The old door boxes are replaced by the kit's door panels. The Panel node
	## itself stays, because LockedDoor drives and hides it.
	for door_name in DOORS.values():
		var door := get_parent().get_node_or_null("Interactables/%s" % door_name)
		if door == null:
			continue
		var panel := door.get_node_or_null("Panel") as MeshInstance3D
		if panel != null:
			panel.mesh = null


func _set_material(shell: Node, node_name: String, path: String) -> void:
	if shell == null:
		return
	var node := shell.get_node_or_null(node_name) as MeshInstance3D
	if node == null:
		return
	var material: Material = load(path) as Material
	if material != null:
		node.material_override = material


## The two corridor walls, run between their bay openings.
func _build_side_walls() -> void:
	for side in [-1.0, 1.0]:
		var openings: Array = []
		for bay in BAYS:
			if is_equal_approx(float(bay["side"]), side):
				openings.append(float(bay["z"]))
		openings.sort()
		var cursor := -RUN_END
		for opening in openings:
			_wall_run(
				Vector3(side * WALL_C, 0.0, cursor),
				Vector3(side * WALL_C, 0.0, float(opening) - OPENING_W * 0.5))
			cursor = float(opening) + OPENING_W * 0.5
		_wall_run(
			Vector3(side * WALL_C, 0.0, cursor),
			Vector3(side * WALL_C, 0.0, RUN_END))


## The two end walls. They reach past the inner corner so their end faces sit
## inside the side walls rather than on the same plane, and the side walls run
## past them for the same reason.
func _build_end_walls() -> void:
	var reach := WALL_C + 0.10
	## The FORWARD end wall carries the cockpit doorway. The helm is the last room
	## in the game, so it opens into the corridor the same way a bay does - the
	## crew can see the bridge from the far end of the walk before they earn it.
	var half := OPENING_W * 0.5
	_wall_run(Vector3(-reach, 0.0, END_C), Vector3(-half, 0.0, END_C))
	_wall_run(Vector3(half, 0.0, END_C), Vector3(reach, 0.0, END_C))
	## The AFT end wall stays solid: the game has one way out, and it is forward.
	_wall_run(Vector3(-reach, 0.0, -END_C), Vector3(reach, 0.0, -END_C))


func _build_bays() -> void:
	for bay in BAYS:
		var side: float = bay["side"]
		var z: float = bay["z"]

		## The back wall is the window: a kit frame around the pane that
		## WindowWall already builds and owns.
		_window_unit(side * BAY_BACK_C, z)

		## Side walls, buried at both ends.
		for edge in [z - BAY_W * 0.5 - WALL_T * 0.5, z + BAY_W * 0.5 + WALL_T * 0.5]:
			## The room on this side of a bay wall is the bay itself, so the band
			## goes on the face looking into the bay, not into the wall.
			_wall_run(
				Vector3(side * SIDE_IN, 0.0, edge),
				Vector3(side * SIDE_OUT, 0.0, edge),
				Vector3(side * (SIDE_IN + SIDE_OUT) * 0.5, 0.0, z))

		_door_frame(side * WALL_C, z)
		var door_name: String = String(DOORS.get(String(bay["id"]), ""))
		if door_name != "":
			_door_panel(door_name)


## Places one wall run as a chain of kit modules between two points on the floor.
## Each module is stretched along its own length so the run lands exactly, with
## no gap at one end and no overshoot into whatever it meets at the other.
## `room_centre` is a point inside the room the wall belongs to. It is used for
## one thing only: deciding which of the wall's two faces is the inner one, when
## the wainscot band is laid against it.
func _wall_run(from: Vector3, to: Vector3, room_centre: Vector3 = Vector3.ZERO) -> void:
	var delta: Vector3 = to - from
	var length: float = delta.length()
	if length < 0.02:
		return
	var dir: Vector3 = delta / length
	var travelled: float = 0.0
	while travelled < length - 0.01:
		var span: float = minf(MAX_SPAN, length - travelled)
		var anchor: Vector3 = from + dir * (travelled + span * 0.5)
		if _place(WALL_MODULE, self, anchor, dir, span) == null:
			return
		_wainscot(anchor, dir, span, room_centre)
		travelled += span


func _door_frame(x: float, z: float) -> void:
	## Native width on purpose: the frame is 3.4 m around a 2.8 m opening, so its
	## jambs overlap the wall run by 300 mm and the seam can never open up.
	_place(DOOR_FRAME, self, Vector3(x, 0.0, z), Vector3(0.0, 0.0, 1.0), 0.0)


## The kit door panel is parented to the existing Panel node, so the open and
## close behaviour keeps working without touching the LockedDoor script. The
## anchor is the centre of the opening at floor level, in WORLD space, and the
## wrapper converts itself into Panel's frame because Panel is at mid-height.
func _door_panel(door_name: String) -> void:
	var door := get_parent().get_node_or_null("Interactables/%s" % door_name)
	if door == null:
		return
	var panel := door.get_node_or_null("Panel") as MeshInstance3D
	if panel == null:
		return
	var centre: Vector3 = panel.global_position
	_place(DOOR_PANEL, panel, Vector3(centre.x, 0.0, centre.z), Vector3(0.0, 0.0, 1.0), 0.0)


func _window_unit(x: float, z: float) -> void:
	var wrapper := _place(WINDOW_UNIT, self, Vector3(x, 0.0, z), Vector3(0.0, 0.0, 1.0), 0.0)
	if wrapper == null:
		return
	## The kit ships its own pane, but WindowWall already builds and owns the glass
	## for this opening and two coincident transparent surfaces blend badly. The
	## frame is kept and the kit's own pane is switched off, not deleted, so the
	## module on disk is never modified.
	for node in wrapper.find_children("*", "MeshInstance3D", true, false):
		if String(node.name).to_lower().contains("glass"):
			(node as Node3D).visible = false


## Places one module so the centre of its BASE sits on `anchor` in world space,
## with its length pointing down `run_dir`. A `span` above zero stretches the
## length to exactly that many metres; zero keeps the module's native width.
##
## Returns the wrapper, or null if the module could not be loaded.
func _place(file: String, hold: Node3D, anchor: Vector3, run_dir: Vector3, span: float) -> Node3D:
	var inst: Node3D = _module(file)
	if inst == null:
		return null
	var wrapper := Node3D.new()
	wrapper.name = file.get_basename()
	hold.add_child(wrapper)
	## Untouched: the module keeps whatever transform the exporter gave it.
	wrapper.add_child(inst)
	_paint(wrapper, String(PAINT.get(file, "")))

	var box: AABB = _native.get(file, AABB())
	var size: Vector3 = box.size
	var world_box: Array = _placed.get(file, [])
	if size == Vector3.ZERO:
		wrapper.global_position = anchor
		world_box.append(AABB(anchor, Vector3.ZERO))
		_placed[file] = world_box
		return wrapper

	var axes: Vector3i = _axes_for(file, size)
	var length_axis: int = axes.x
	var height_axis: int = axes.y

	## Standing the module upright. When its height is already on Y the kit
	## arrives as Godot expects and no rotation is needed; when the height is on Z
	## the module is Z-up, and -90 degrees about X takes +Z to +Y. The X case is
	## only here so an entirely different kit cannot fail silently.
	var stand := Basis()
	if height_axis == 2:
		stand = Basis(Vector3.RIGHT, -PI * 0.5)
	elif height_axis == 0:
		stand = Basis(Vector3.BACK, PI * 0.5)

	## Where the module's length points once it is standing, then the yaw that
	## carries that onto the run. Both angles use the same convention, so the
	## difference is the rotation needed and it holds for any length axis.
	var length_vector := Vector3.RIGHT
	if length_axis == 2:
		length_vector = Vector3.BACK
	elif length_axis == 1:
		length_vector = Vector3.UP
	var length_dir: Vector3 = stand * length_vector
	var yaw: float = _heading(run_dir) - _heading(length_dir)
	var rot := Basis(Vector3.UP, yaw) * stand

	var scale := Vector3.ONE
	if span > 0.0:
		var native_length: float = _axis_of(size, length_axis)
		if native_length > 0.001:
			scale = _set_axis(scale, length_axis, span / native_length)
	## Always normalise the height to the corridor's own 3.4 m, so a module that
	## arrives a centimetre off its declared size still meets both the floor and
	## the ceiling exactly.
	var native_height: float = _axis_of(size, height_axis)
	if native_height > 0.001:
		scale = _set_axis(scale, height_axis, HEIGHT / native_height)

	## The module pivots on its base centre, so the source point that has to land
	## on the anchor is the centre of the box's base face in the module's frame.
	var base_centre: Vector3 = box.get_center()
	base_centre = _set_axis(base_centre, height_axis, _axis_of(box.position, height_axis))

	## Wrapper basis is (rotation * scale): the scale is read in the module's own
	## frame, which is exactly what stretching its length and height mean.
	var basis := Basis(rot.x * scale.x, rot.y * scale.y, rot.z * scale.z)
	var desired := Transform3D(basis, anchor - basis * base_centre)
	if hold == self:
		wrapper.transform = desired
	else:
		wrapper.transform = hold.global_transform.affine_inverse() * desired

	world_box.append(wrapper.global_transform * box)
	_placed[file] = world_box
	return wrapper


## Repaints a placed module in the palette.
##
## This is the only place a kit module's own material can be replaced. The kit's
## grey is not a scene material that can be overridden from the editor - it is
## baked into the mesh inside each GLB, and the modules do not exist at all until
## this node builds them at runtime.
func _paint(wrapper: Node3D, path: String) -> void:
	if path == "":
		return
	var material: Material = load(path) as Material
	if material == null:
		push_warning("KitShell: palette material '%s' did not load; modules keep their authored look." % path)
		return
	var painted: int = 0
	for node in wrapper.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh == null:
			continue
		## The window module carries its own pane, and that pane is switched off
		## because WindowWall builds the glass for that opening. It keeps its
		## material, so the module on disk is never contradicted.
		if String(mesh.name).to_lower().contains("glass"):
			continue
		mesh.material_override = material
		painted += 1
	_painted[path] = int(_painted.get(path, 0)) + painted


## The lower tone of the two-tone wall.
##
## The kit's wall module is a single full-height panel, so a second tone cannot
## come from splitting it in two. The band is its own thin slab laid flat against
## the panel's inner face, and which face that is gets worked out rather than
## assumed: the run's perpendicular is derived from the run's own direction, and
## the band goes on whichever side of the wall the room is on. That one rule is
## correct for the corridor's side walls, both end walls, and the bay side walls,
## whose inner faces point along three different axes.
##
## It carries no collision. KitShell contributes none at all, and the band sits
## on the room side of the wall's face but still behind the Shell collision
## plane, so the crew can never walk into it.
func _wainscot(anchor: Vector3, run_dir: Vector3, span: float, room_centre: Vector3) -> void:
	var perp := Vector3(-run_dir.z, 0.0, run_dir.x)
	var side := signf((room_centre - anchor).dot(perp))
	if is_zero_approx(side):
		side = 1.0
	var mesh := BoxMesh.new()
	## A centimetre of overlap at each end, so consecutive bands in one run meet
	## without a hairline of unpainted wall showing through the joint.
	mesh.size = Vector3(span + 0.02, WAINSCOT_H, WAINSCOT_T)
	var band := MeshInstance3D.new()
	band.name = "Wainscot"
	band.mesh = mesh
	band.material_override = load(WALL_BASE) as Material
	## Basis(UP, _heading(dir)) maps local X onto the run and local Z onto perp,
	## so the offset toward the room is written straight along the band's own Z.
	band.transform = Transform3D(
		Basis(Vector3.UP, _heading(run_dir)),
		anchor + perp * (side * (WALL_T * 0.5 + WAINSCOT_T * 0.5)) + Vector3(0.0, WAINSCOT_H * 0.5, 0.0))
	add_child(band)
	_wainscots += 1


## Which measured axis carries the length, the height and the thickness, decided
## by matching the box against the footprint the manifest declares. Returned as
## (length_axis, height_axis, thickness_axis) with 0 = X, 1 = Y, 2 = Z.
func _axes_for(file: String, size: Vector3) -> Vector3i:
	var want: Vector3 = FOOTPRINT.get(file, Vector3(2.0, 3.4, 0.33))
	var height_on_z: bool = absf(size.z - want.y) < absf(size.y - want.y)
	var length_on_z: bool = absf(size.z - want.x) < absf(size.x - want.x)
	var length_axis := 2 if length_on_z else 0
	var height_axis := 2 if height_on_z else 1
	if length_axis == height_axis:
		## Two measurements are too close together to separate - a square module.
		## Fall back to how the kit is authored: length on X, height on Y.
		return Vector3i(0, 1, 2)
	return Vector3i(length_axis, height_axis, 3 - length_axis - height_axis)


## The heading of a direction in the XZ plane, in the same sense as
## Basis(Vector3.UP, angle), so two headings can simply be subtracted.
func _heading(dir: Vector3) -> float:
	return atan2(-dir.z, dir.x)


func _axis_of(v: Vector3, axis: int) -> float:
	if axis == 0:
		return v.x
	if axis == 1:
		return v.y
	return v.z


func _set_axis(v: Vector3, axis: int, value: float) -> Vector3:
	if axis == 0:
		v.x = value
	elif axis == 1:
		v.y = value
	else:
		v.z = value
	return v


## A one-line receipt. The modules are created at runtime and never appear in the
## saved scene, so without this there is no way to tell a shell that built from
## one that silently placed nothing or placed it flat.
##
## It reports the measured NATIVE size of each module and which axes were read as
## length and height, so a wrong axis reading is visible rather than inferred. It
## then reports the world Y range the placed modules actually occupy: if the
## walls were lying flat again this would read about 0.00..0.33 instead of
## 0.00..3.40, which is the exact failure this line exists to catch. The range is
## per module type, because a door panel standing upright would otherwise mask a
## flat wall in a single combined figure.
func _report() -> void:
	var total := 0
	var parts: Array[String] = []
	for file in _native.keys():
		var key := String(file)
		var size: Vector3 = (_native[file] as AABB).size
		var axes: Vector3i = _axes_for(key, size)
		var boxes: Array = _placed.get(key, [])
		total += boxes.size()
		var low := 0.0
		var high := 0.0
		if not boxes.is_empty():
			low = INF
			high = -INF
			for box in boxes:
				low = minf(low, (box as AABB).position.y)
				high = maxf(high, (box as AABB).end.y)
		parts.append("%s native=%.2fx%.2fx%.2f L%d H%d n=%d y=%.2f..%.2f" % [
			key.get_basename(), size.x, size.y, size.z,
			axes.x, axes.y, boxes.size(), low, high])
	var paint_parts: Array[String] = []
	for path in _painted.keys():
		paint_parts.append("%s n=%d" % [String(path).get_file().get_basename(), int(_painted[path])])
	print("[KitShell] modules=%d wainscots=%d retired=%d | face=%s base=%s | painted %s | %s" % [
		total, _wainscots, _retired, _albedo(WALL_FACE), _albedo(WALL_BASE),
		"none" if paint_parts.is_empty() else ", ".join(paint_parts), " | ".join(parts)])


## The colour a palette material actually resolves to, or FAILED when it does not
## load at all. A wall painted the wrong colour and a wall whose material never
## loaded look identical from inside the corridor, so the receipt states the
## colour itself rather than the path it came from.
func _albedo(path: String) -> String:
	var material: Material = load(path)
	if material is StandardMaterial3D:
		return (material as StandardMaterial3D).albedo_color.to_html(false)
	return "FAILED"


## Loads and caches a kit module, measuring its local bounding box on first use.
func _module(file_name: String) -> Node3D:
	if not _cache.has(file_name):
		var loaded: PackedScene = load(MODULE_DIR + file_name) as PackedScene
		if loaded == null:
			push_warning("KitShell: kit module '%s' did not load." % file_name)
			return null
		_cache[file_name] = loaded
	var scene: PackedScene = _cache[file_name]
	var inst: Node3D = scene.instantiate() as Node3D
	if inst != null and not _native.has(file_name):
		_native[file_name] = _measure(inst)
	return inst


## The module's bounding box in the space its own transform maps from, which is
## the space the wrapper will scale and rotate. Starting from IDENTITY and
## multiplying in the root's own transform is the point: this measures the module
## as Godot actually imported it, not as the exporter meant it.
func _measure(root: Node3D) -> AABB:
	var boxes: Array = []
	_collect(root, Transform3D.IDENTITY, boxes)
	if boxes.is_empty():
		return AABB()
	var box: AABB = boxes[0]
	for i in range(1, boxes.size()):
		box = box.merge(boxes[i])
	return box


func _collect(node: Node3D, base: Transform3D, out: Array) -> void:
	var here: Transform3D = base * node.transform
	var mesh_node := node as MeshInstance3D
	if mesh_node != null and mesh_node.mesh != null:
		out.append(here * mesh_node.get_aabb())
	for child in node.get_children():
		if child is Node3D:
			_collect(child as Node3D, here, out)
