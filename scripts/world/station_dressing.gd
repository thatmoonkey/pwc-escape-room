class_name StationDressing
extends Node3D

## WHAT THE CORRIDOR IS MADE OF, VERSUS WHAT IS IN IT
##
## KitShell builds the room: walls, door frames, window units, the lower band.
## This builds the working detail that makes it read as a ship rather than a
## set - conduit runs, junction boxes, ceiling cable trays and light fixtures,
## deck thresholds, floor grilles, service columns and the cargo and signage
## props.
##
## WHY IT IS BUILT IN CODE RATHER THAN AUTHORED AS SCENE NODES. Same reason the
## kit is: the conduit has to stop where a doorway begins, and the light
## fixtures have to land on the lights that are already in the scene. Every
## position here is derived from KitShell's own published constants, read at
## load rather than retyped, so the dressing and the shell cannot drift apart
## the first time a bay moves. The alternative is roughly two hundred hand
## placed boxes that silently go wrong together.
##
## WHAT IT DELIBERATELY DOES NOT DO. It adds no collision of its own except for
## the loose props, which are solid because they are objects the crew would
## walk into. Conduits, boxes, trays and fixtures are wall dressing and stay
## non-solid, so nothing here can trap the player or narrow a doorway.
##
## The receipt at the end reports one count per category. Detail that silently
## fails to build looks exactly like detail that was never added, and nothing
## else in the game would say which of those happened.

## The palette. Filenames are historical - accent_amber holds the dark gold,
## panel_light the warm mid brown. They are referenced by path because scenes
## and other scripts already do.
const TRIM := "res://materials/trim_black.tres"
const PLATE := "res://materials/panel_light.tres"
const PANEL := "res://materials/panel_blue.tres"
const ACCENT := "res://materials/accent_amber.tres"
const GROUND := "res://materials/floor_dark.tres"

## Props, from the pinned shooter-scifi collection. All of these are already in
## the project, so this scene adds no new dependency.
const PROP_DIR := "res://assets/library/shooter-scifi/"
const CRATE := "sci-fi-triangle-container.glb"
const BARREL := "sci-fi-barrel.glb"
const TURRET := "sci-fi-turret-poly-surface1308.glb"
const SIGN_CLEAR := "sci-fi-hallway-assetpack-free-too-cube-piece-015.glb"
const SIGN_DANGER := "sci-fi-hallway-assetpack-free-too-cube-piece-013.glb"

## Conduit heights. The trunk runs at 2.70, which is below the door lintels at
## 3.15 and above the lower wall band, which tops out at 1.05, so it crosses
## neither; the thin line sits under it at 2.40.
const TRUNK_Y := 2.70
const TRUNK_H := 0.22
const TRUNK_D := 0.16
const LINE_Y := 2.40
const LINE_S := 0.07
const BOX_Y := 1.78
## Longest single conduit mesh. Segmenting the run keeps one node covering
## several metres instead of one node per wall module.
const SEG_MAX := 9.0
const CLAMP_STEP := 3.6
## Where the corridor ceiling lights actually are, so the fixtures land on them.
const LIGHT_STEP := 4.0
const LIGHT_TOP := 16.0
const LIGHT_BOTTOM := -17.0

var _face := 0.0
var _run_end := 0.0
var _opening_w := 0.0
var _height := 0.0
var _bays: Array = []
var _solid: PropCollider = null
var _counts: Dictionary = {}
var _props: int = 0


func _ready() -> void:
	add_to_group("station_dressing")
	_read_corridor()
	_build_conduits()
	_build_junction_boxes()
	_build_service_columns()
	_build_ceiling_tray()
	_build_ceiling_lights()
	_build_deck()
	_build_floor_grilles()
	## The props are made children of the collider BEFORE it enters the tree,
	## because PropCollider scans its children once, in _ready. Adding them
	## afterwards would leave every crate walk-through.
	_solid = PropCollider.new()
	_solid.name = "DressProps"
	_build_props()
	_build_bay_props()
	add_child(_solid)
	_report()


## Reads the corridor's real numbers from the shell that built it instead of
## restating them here.
func _read_corridor() -> void:
	_run_end = KitShell.RUN_END
	_opening_w = KitShell.OPENING_W
	_height = KitShell.HEIGHT
	## The inner face of a side wall: the wall centre line less half its
	## thickness. Every wall-mounted piece hangs off this one number.
	_face = KitShell.WALL_C - KitShell.WALL_T * 0.5
	for bay in KitShell.BAYS:
		_bays.append({
			"id": String(bay["id"]),
			"side": float(bay["side"]),
			"z": float(bay["z"]),
		})


## The stretches of side wall on one side of the corridor, between the bay
## openings. This mirrors the spans KitShell cuts its wall modules into, so
## wall dressing and wall modules cover exactly the same ground.
func _spans_for(side: float) -> Array:
	var openings: Array = []
	for bay in _bays:
		if is_equal_approx(float(bay["side"]), side):
			openings.append(float(bay["z"]))
	openings.sort()
	var spans: Array = []
	var cursor := -_run_end
	for z in openings:
		spans.append([cursor, z - _opening_w * 0.5])
		cursor = z + _opening_w * 0.5
	spans.append([cursor, _run_end])
	return spans


## A span cut into even pieces no longer than SEG_MAX, as [centre_z, length]
## pairs. Even pieces rather than a long one and a stub, so no 20 cm sliver of
## conduit is ever drawn.
func _segments(from_z: float, to_z: float) -> Array:
	var length: float = to_z - from_z
	var out: Array = []
	if length < 0.30:
		return out
	var parts: int = maxi(1, int(ceil(length / SEG_MAX)))
	var piece: float = length / float(parts)
	for index in range(parts):
		out.append([from_z + piece * (float(index) + 0.5), piece])
	return out


func _build_conduits() -> void:
	var made := 0
	for side in [-1.0, 1.0]:
		for span in _spans_for(side):
			for segment in _segments(float(span[0]), float(span[1])):
				var z: float = segment[0]
				var length: float = segment[1]
				_box("Trunk", Vector3(TRUNK_D, TRUNK_H, length),
					Vector3(side * (_face - TRUNK_D * 0.5), TRUNK_Y, z), TRIM)
				_box("Line", Vector3(LINE_S, LINE_S, length),
					Vector3(side * (_face - LINE_S * 0.5), LINE_Y, z), ACCENT)
				var clamps: int = maxi(1, int(length / CLAMP_STEP))
				for index in range(clamps):
					var cz: float = z - length * 0.5 + length * (float(index) + 0.5) / float(clamps)
					_box("Clamp", Vector3(0.10, 0.46, 0.11),
						Vector3(side * (_face - 0.04), 2.55, cz), PLATE)
				made += 1
	_bump("conduits", made)


## One access box per wall stretch, spaced along it. The drop ties the box into
## the trunk above it so the two read as one system rather than as stickers.
func _build_junction_boxes() -> void:
	var made := 0
	for side in [-1.0, 1.0]:
		for span in _spans_for(side):
			var from_z: float = float(span[0])
			var length: float = float(span[1]) - from_z
			if length < 1.6:
				continue
			var slots: int = maxi(1, int(length / 5.5))
			for index in range(slots):
				var z: float = from_z + length * (float(index) + 0.5) / float(slots)
				_junction_box(side, z)
				made += 1
	_bump("junction_boxes", made)


func _junction_box(side: float, z: float) -> void:
	_box("JBoxFrame", Vector3(0.10, 0.92, 0.68),
		Vector3(side * (_face - 0.05), BOX_Y, z), TRIM)
	_box("JBoxFace", Vector3(0.06, 0.78, 0.56),
		Vector3(side * (_face - 0.08), BOX_Y, z), PANEL)
	_box("JBoxPip", Vector3(0.05, 0.06, 0.10),
		Vector3(side * (_face - 0.10), BOX_Y + 0.30, z - 0.18), ACCENT)
	var drop_top: float = TRUNK_Y - TRUNK_H * 0.5 + 0.05
	var drop_bottom: float = BOX_Y + 0.46
	_box("JBoxDrop", Vector3(0.07, drop_top - drop_bottom, 0.07),
		Vector3(side * (_face - 0.035), (drop_top + drop_bottom) * 0.5, z), TRIM)


## Service columns framing each bay doorway, clear of the kit door jambs, which
## reach 1.70 out from the bay centre.
func _build_service_columns() -> void:
	var made := 0
	for bay in _bays:
		var side: float = bay["side"]
		var z: float = bay["z"]
		for edge in [-1.0, 1.0]:
			var ez: float = z + edge * (_opening_w * 0.5 + 0.49)
			_box("Column", Vector3(0.14, _height, 0.34),
				Vector3(side * (_face - 0.07), _height * 0.5, ez), TRIM)
			_box("ColumnStrip", Vector3(0.05, _height - 0.90, 0.05),
				Vector3(side * (_face - 0.155), _height * 0.5, ez), ACCENT)
			made += 1
	_bump("columns", made)


## Cable trays along both flanks of the ceiling. They are held at 1.55 and 1.95
## so they clear the light fixtures, which are 1.62 wide on the centre line.
func _build_ceiling_tray() -> void:
	var made := 0
	for segment in _segments(-(_run_end - 0.4), _run_end - 0.4):
		var z: float = segment[0]
		var length: float = segment[1]
		for side in [-1.0, 1.0]:
			_box("TrayRail", Vector3(0.07, 0.13, length), Vector3(side * 1.55, 3.30, z), TRIM)
			_box("TrayRail", Vector3(0.07, 0.13, length), Vector3(side * 1.95, 3.30, z), TRIM)
			_box("TrayCable", Vector3(0.28, 0.07, length), Vector3(side * 1.75, 3.24, z), PLATE)
		made += 1
	_bump("ceiling_tray_segments", made)


## Light fixtures on the centre line, one for every corridor light the scene
## already has, so the light the player sees has something emitting it.
func _build_ceiling_lights() -> void:
	var made := 0
	var z := LIGHT_TOP
	while z > LIGHT_BOTTOM:
		_box("LightBezel", Vector3(1.62, 0.12, 1.62), Vector3(0.0, 3.34, z), TRIM)
		_box("LightPanel", Vector3(1.34, 0.05, 1.34), Vector3(0.0, 3.255, z), PANEL)
		made += 1
		z -= LIGHT_STEP
	_bump("ceiling_lights", made)


## Threshold plates on the deck at each bay opening and at the bridge gate: the
## floor treatment that tells the crew where a doorway is before they look up.
func _build_deck() -> void:
	var made := 0
	for bay in _bays:
		var side: float = bay["side"]
		var z: float = bay["z"]
		_box("Sill", Vector3(0.52, 0.012, _opening_w),
			Vector3(side * (_face - 0.26), 0.006, z), TRIM)
		_box("SillLine", Vector3(0.06, 0.014, _opening_w),
			Vector3(side * (_face - 0.49), 0.007, z), ACCENT)
		made += 1
	var gate_z: float = _run_end - 0.55
	_box("Sill", Vector3(2.90, 0.012, 0.52), Vector3(0.0, 0.006, gate_z), TRIM)
	_box("SillLine", Vector3(2.90, 0.014, 0.06),
		Vector3(0.0, 0.007, gate_z + 0.23), ACCENT)
	_bump("deck_thresholds", made + 1)


## Framed deck grilles down both sides, clear of the barrels and the loose
## props that already sit against the walls.
func _build_floor_grilles() -> void:
	var made := 0
	for z in [12.0, 5.0, -1.0, -8.0]:
		for side in [-1.0, 1.0]:
			var x: float = side * 2.35
			_box("Grille", Vector3(1.10, 0.014, 1.30), Vector3(x, 0.007, z), TRIM)
			_box("GrilleFace", Vector3(0.90, 0.016, 1.10), Vector3(x, 0.008, z), PLATE)
			made += 1
	_bump("floor_grilles", made)


func _build_props() -> void:
	for spot in [
		[CRATE, Vector3(2.42, 0.0, -7.4), 12.0],
		[CRATE, Vector3(2.44, 0.0, -8.4), -20.0],
		[CRATE, Vector3(-2.45, 0.0, -5.2), 30.0],
		[CRATE, Vector3(-2.40, 0.0, -15.4), -12.0],
		[CRATE, Vector3(2.40, 0.0, 3.6), 8.0],
		[BARREL, Vector3(2.42, 0.0, -12.8), 0.0],
		[BARREL, Vector3(-2.42, 0.0, -3.2), 0.0],
		[TURRET, Vector3(2.35, 0.0, 16.4), -140.0],
	]:
		_place_prop(String(spot[0]), spot[1], float(spot[2]), _solid)
	_bump("corridor_props", 8)
	## Deck signage. Flat, so it sits just above the floor and carries no
	## collision; the sign itself is the texture, not the plate.
	for spot in [
		[SIGN_CLEAR, Vector3(0.0, 0.02, 17.0), 0.0],
		[SIGN_DANGER, Vector3(-2.0, 0.02, -13.9), 0.0],
	]:
		_place_prop(String(spot[0]), spot[1], float(spot[2]), self)
	_bump("deck_signage", 2)


## One crate in a corner of each bay, so the rooms a crew member walks into are
## not four bare walls and a console.
func _build_bay_props() -> void:
	## Every one of these is placed against a bay's own geometry: at x of 4.6 the
	## crate is clear of the bay back wall at 11.0 and of the doorway at 3.15, and
	## its z sits well off the bay centre line, which is where the console and the
	## walk-up to it are. The bay side walls are at bay centre +/- 3.5, so nothing
	## here is closer to one than 2.4 m and no crate is ever half inside a wall.
	for spot in [
		[Vector3(-4.6, 0.0, 15.4), 22.0],
		[Vector3(-4.6, 0.0, 10.4), 40.0],
		[Vector3(4.6, 0.0, 9.4), -16.0],
		[Vector3(-4.6, 0.0, 3.4), 34.0],
		[Vector3(4.6, 0.0, -2.6), -8.0],
		[Vector3(-4.6, 0.0, -9.4), 18.0],
	]:
		_place_prop(CRATE, spot[0], float(spot[1]), _solid)
	_bump("bay_props", 6)


## Instances one library prop. The collection's props arrive mesh-only, which is
## why they go under the PropCollider rather than straight onto this node.
func _place_prop(file: String, pos: Vector3, yaw_deg: float, holder: Node3D) -> void:
	var packed: PackedScene = load(PROP_DIR + file) as PackedScene
	if packed == null:
		push_warning("StationDressing: '%s' did not load; that prop is missing." % file)
		return
	var instance: Node3D = packed.instantiate() as Node3D
	if instance == null:
		push_warning("StationDressing: '%s' did not instantiate as a Node3D." % file)
		return
	_props += 1
	instance.name = "%s_%02d" % [file.get_basename().substr(0, 16), _props]
	instance.position = pos
	instance.rotation_degrees = Vector3(0.0, yaw_deg, 0.0)
	holder.add_child(instance)


## One palette box. Sizes are exact, because every one of them was chosen
## against a wall face or a doorway edge.
func _box(box_name: String, size: Vector3, centre: Vector3, material_path: String) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var node := MeshInstance3D.new()
	node.name = box_name
	node.mesh = mesh
	node.position = centre
	var material: Material = load(material_path) as Material
	if material == null:
		push_warning("StationDressing: palette material '%s' did not load." % material_path)
	else:
		node.material_override = material
	add_child(node)


func _bump(key: String, value: int) -> void:
	_counts[key] = int(_counts.get(key, 0)) + value


## A one-line receipt. Every category is counted, because a run of conduit that
## silently failed to build is invisible in exactly the same way as conduit that
## was never asked for.
func _report() -> void:
	var parts: Array[String] = []
	var keys: Array = _counts.keys()
	keys.sort()
	for key in keys:
		parts.append("%s=%d" % [String(key), int(_counts[key])])
	print("[Dressing] props=%d | %s" % [_props, ", ".join(parts)])
