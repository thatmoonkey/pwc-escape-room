class_name DeckBuilder
extends Node3D

## Shared base for the one-off interior authoring tools - author_deck1.gd and
## author_stairwell.gd. Each is run once through its own scenes/dev entry scene
## and SAVES a real scene under res://scenes/world. The game never calls any of
## it.
##
## WHY TOOLS RATHER THAN HAND-TYPED SCENES. The interior is a few hundred
## instanced prefabs carrying 12-float transforms, and typing that scene text by
## hand invites exactly the silent geometry errors this base class can instead
## check and report - a wall placed flat, a run that is not a whole number of
## panels, a subtree that packs as an empty shell. The saved scene is ordinary
## editor-authorable nodes: hand-edit it afterwards, and re-run the tool only if
## the layout itself has to change.
##
## WHAT BELONGS HERE. Only what is true of every part of the interior: how a
## prefab is instanced and owned, how a run of the pack's wall panels is laid, how
## a slab of floor or ceiling tiles covers a whole number of tiles, and the
## receipt. Coordinates, room names and system wiring belong in the layout file.
##
## THE PACK'S GRID. Wall panels are 3.50 x 4.06 x 0.295 and floor and ceiling
## tiles are 3.50 x 3.50, so every wall run here is a WHOLE NUMBER of panels with
## no scaling at all and every footprint a whole number of tiles. The deck was
## raised to 4.06 m precisely so this kit needs no scale correction, and
## stretching a panel would break both its seams and its collision, so nothing is
## ever stretched. _finish reports how many nodes ended up non-uniformly scaled,
## and it has to stay zero.
##
## WALL ORIENTATION. A panel is 3.50 wide on X, 4.06 tall on Y and 0.295 thick on
## Z, pivot at the centre of its base. So it is placed unrotated in a wall whose
## face points along Z, and yawed 90 degrees in a wall whose face points along X.
## Its CollisionShape3D is a matching box, so a wall blocks the moment it lands.
##
## FLOOR AND CEILING TILES pivot the same way as a panel, with the visible surface
## AT the pivot. So a floor tile placed at a deck's floor level has its walking
## surface exactly there and needs no correction, and a ceiling tile is turned
## over to face down and sits at the ceiling height.
##
## OWNERSHIP. PackedScene.pack() drops every sub-node whose owner is not the
## packed root, so a subtree built in code saves as an empty shell unless owner is
## stamped down it. _own() does that, and deliberately stops at an instanced
## scene's own children: claiming those would save a second copy of the prefab's
## geometry into the level instead of a reference to the prefab.

const M := 3.5          ## the pack's module, in metres
const H := 4.06         ## the pack's wall height, which is the deck height
const WALL_T := 0.295   ## a wall panel's thickness, i.e. its thin side

const P_WALL := "res://scenes/prefabs/interior/Wall_01.tscn"
const P_FLOOR := "res://scenes/prefabs/interior/FloorTile_01.tscn"
const P_CEILING := "res://scenes/prefabs/interior/Ceiling_01.tscn"

## The palette material for anything built here rather than taken from the pack,
## so a built piece can never come out in the importer's grey. wall_upper
## resolves to #AD2323, the same colour the ember shader maps the pack's own wall
## panels onto, so a built bulkhead sits beside a panelled wall without reading as
## a different finish.
const M_WALL := "res://materials/wall_upper.tres"
const M_STEP := "res://materials/trim_black.tres"

var _root: Node3D
var _count: Dictionary = {}
var _problems: Array[String] = []
var _out: String = ""
var _tag: String = ""
## The world Y this deck's floor sits at: 0 for deck 1, negative for anything
## below it. See _begin.
var _floor_y: float = 0.0


func _begin(root_name: String, out_path: String, tag: String, floor_y: float = 0.0) -> void:
	_out = out_path
	_tag = tag
	## The height THIS deck's floor sits at in world space. Deck 1's is 0 by
	## definition of the whole interior, so only a lower deck has to say; every
	## piece placed from a floor - a doorway, a flank, a sealed door - reads it
	## from here rather than carrying a height through every call.
	_floor_y = floor_y
	_root = Node3D.new()
	_root.name = root_name
	add_child(_root)


## Saves, then prints the receipt. A part whose walls were stretched, or which
## quietly placed nothing, looks exactly like a part that built correctly from
## inside the game, so the numbers that would differ are printed instead.
func _finish(extra: String = "") -> void:
	_save()
	var parts: Array[String] = []
	var keys := _count.keys()
	keys.sort()
	for key in keys:
		parts.append("%s n=%d" % [String(key), int(_count[key])])
	var nodes := 0
	var scaled := 0
	for node in _walk(_root):
		nodes += 1
		var n3 := node as Node3D
		if n3 == null:
			continue
		if not n3.transform.basis.get_scale().is_equal_approx(Vector3.ONE):
			scaled += 1
	print("[%s] %s | nodes=%d | non_uniform_scale=%d%s | problems=%d" % [
		_tag, ", ".join(parts), nodes, scaled, extra, _problems.size()])
	for problem in _problems:
		print("[%s] PROBLEM: %s" % [_tag, problem])
	print("[%s] wrote %s (%d bytes)" % [_tag, _out, _size(_out)])


## The world Y range of the layer-2 bodies sitting directly under the named group
## nodes - walls and bulkheads rather than floor. Walls placed flat, or not placed
## at all, read a fraction of a deck here instead of a full 4.06 m, which is the
## exact failure this line exists to catch. It measures each body's ORIGIN, and a
## panel's origin is the centre of its base, so the span is origin to origin + H.
func _span_under(names: Array) -> String:
	var count := 0
	var low := INF
	var high := -INF
	for node in _walk(_root):
		var parent := node.get_parent()
		if parent == null or not (String(parent.name) in names):
			continue
		var body := node as StaticBody3D
		if body == null or body.collision_layer != 2:
			continue
		count += 1
		## Measured from each body's real collision box rather than from its
		## origin, because the two kinds of piece here put the origin in different
		## places: an instanced panel pivots on the centre of its base, while a box
		## built by _block carries its origin at its own centre. Reading the origin
		## would report a built box as a whole deck too tall.
		var measured := false
		for child in body.get_children():
			var shape := child as CollisionShape3D
			if shape == null or not (shape.shape is BoxShape3D):
				continue
			var half: float = (shape.shape as BoxShape3D).size.y * 0.5
			var mid: float = (body.global_transform * shape.position).y
			low = minf(low, mid - half)
			high = maxf(high, mid + half)
			measured = true
		if not measured:
			low = minf(low, body.global_position.y)
			high = maxf(high, body.global_position.y + H)
	if count == 0:
		return " | walls=none"
	return " | walls=%d y=%.2f..%.2f" % [count, low, high]


## A plain grouping node under the level root.
func _node(node_name: String, parent: Node3D) -> Node3D:
	var node := Node3D.new()
	node.name = node_name
	parent.add_child(node)
	node.owner = _root
	return node


## Instances one prefab into the level. Only the instance root is owned: its own
## children belong to the prefab, and claiming them here would save a duplicate
## copy of the geometry into the scene instead of keeping the instance.
func _place(prefab_path: String, parent: Node3D, node_name: String,
		basis: Basis, origin: Vector3) -> Node3D:
	var scene: PackedScene = load(prefab_path)
	if scene == null:
		_problems.append("prefab did not load: " + prefab_path)
		return null
	var inst: Node3D = scene.instantiate()
	inst.name = node_name
	parent.add_child(inst)
	inst.transform = Transform3D(basis, origin)
	inst.owner = _root
	var key := prefab_path.get_file()
	_count[key] = int(_count.get(key, 0)) + 1
	return inst


## A solid box built here, for a piece the pack has no module for: a shaft wall
## taller than a 4.06 m panel, a bulkhead of an odd height. Mesh and collision are
## built together so the piece can never be visible but not solid.
func _block(parent: Node3D, node_name: String, size: Vector3, centre: Vector3,
		material_path: String) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.collision_layer = 2
	body.collision_mask = 0
	var mesh_node := MeshInstance3D.new()
	mesh_node.name = "Model"
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_node.mesh = mesh
	var material: Material = load(material_path) as Material
	if material == null:
		_problems.append("%s material did not load: %s" % [node_name, material_path])
	else:
		mesh_node.material_override = material
	body.add_child(mesh_node)
	body.add_child(_box(size, Vector3.ZERO))
	parent.add_child(body)
	body.transform = Transform3D(Basis(), centre)
	_own(body)
	return body


## A collision-only box: the same shape as a _block, with no mesh, for somewhere
## the visible geometry is already drawn - the stair's walkable ramp over its own
## step boxes. It is a body of its own rather than a second shape on the visible
## one, so the piece that is drawn and the piece that is walked on stay
## separately changeable.
func _collider(parent: Node3D, node_name: String, size: Vector3, basis: Basis,
		centre: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.collision_layer = 2
	body.collision_mask = 0
	body.add_child(_box(size, Vector3.ZERO))
	parent.add_child(body)
	body.transform = Transform3D(basis, centre)
	_own(body)
	return body


## A mesh-only box, for a piece whose collision is carried by something else. The
## stair's step boxes are these: as colliders they would be 26 horizontal ledges
## standing through the ramp the crew actually walk on.
func _deco(parent: Node3D, node_name: String, size: Vector3, centre: Vector3,
		material_path: String) -> MeshInstance3D:
	var mesh_node := MeshInstance3D.new()
	mesh_node.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_node.mesh = mesh
	var material: Material = load(material_path) as Material
	if material == null:
		_problems.append("%s material did not load: %s" % [node_name, material_path])
	else:
		mesh_node.material_override = material
	parent.add_child(mesh_node)
	mesh_node.position = centre
	mesh_node.owner = _root
	return mesh_node


## One floor slab over a footprint that is a whole number of tiles.
func _floor_slab(parent: Node3D, x_from: float, x_to: float,
		z_from: float, z_to: float, y: float, tag: String) -> void:
	_tile(parent, x_from, x_to, z_from, z_to, y, tag, "F", false)


## One ceiling slab. A ceiling tile is turned over to face down and sits at the
## ceiling height, so its underside is the visible surface.
func _ceiling_slab(parent: Node3D, x_from: float, x_to: float,
		z_from: float, z_to: float, y: float, tag: String) -> void:
	_tile(parent, x_from, x_to, z_from, z_to, y, tag, "C", true)


func _tile(parent: Node3D, x_from: float, x_to: float, z_from: float, z_to: float,
		y: float, tag: String, prefix: String, upside_down: bool) -> void:
	var nx := int(round((x_to - x_from) / M))
	var nz := int(round((z_to - z_from) / M))
	if absf(nx * M - (x_to - x_from)) > 0.01 or absf(nz * M - (z_to - z_from)) > 0.01:
		_problems.append("%s footprint is not a whole number of tiles: %.2f x %.2f" % [
			tag, x_to - x_from, z_to - z_from])
		return
	var basis := Basis(Vector3.RIGHT, PI) if upside_down else Basis()
	var prefab := P_CEILING if upside_down else P_FLOOR
	for ix in nx:
		for iz in nz:
			_place(prefab, parent, "%s_%s%d%d" % [tag, prefix, ix, iz], basis,
				Vector3(x_from + M * (ix + 0.5), y, z_from + M * (iz + 0.5)))


## A wall along Z at a fixed X, i.e. a wall whose face points along X. Its panels
## are yawed 90 degrees so their 3.50 m width runs fore-and-aft.
func _wall_run_z(parent: Node3D, x: float, y: float, z_from: float, z_to: float,
		openings: Array, tag: String) -> void:
	var count := _whole(z_to - z_from, tag)
	var yaw := Basis(Vector3.UP, PI * 0.5)
	for i in count:
		var a := z_from + M * i
		if _blocked(a, a + M, openings):
			continue
		_place(P_WALL, parent, "%s_%02d" % [tag, i], yaw, Vector3(x, y, a + M * 0.5))
	_wall_frame(parent, true, z_from, count, x, y, openings, tag)


## A wall along X at a fixed Z, i.e. a wall whose face points along Z. Its panels
## need no yaw: the pack authors the panel's width on X already.
func _wall_run_x(parent: Node3D, z: float, y: float, x_from: float, x_to: float,
		openings: Array, tag: String) -> void:
	var count := _whole(x_to - x_from, tag)
	for i in count:
		var a := x_from + M * i
		if _blocked(a, a + M, openings):
			continue
		_place(P_WALL, parent, "%s_%02d" % [tag, i], Basis(),
			Vector3(a + M * 0.5, y, z))
	_wall_frame(parent, false, x_from, count, z, y, openings, tag)


## How many whole panels a run takes, reporting a run that is not a whole number
## of them instead of silently stretching or leaving a gap.
func _whole(length: float, tag: String) -> int:
	var count := int(round(length / M))
	if absf(count * M - length) > 0.01:
		_problems.append("%s run is not a whole number of panels: %.3f" % [tag, length])
		return 0
	return count


## True when a panel spanning a..b would sit in an opening.
func _blocked(a: float, b: float, openings: Array) -> bool:
	for opening in openings:
		var lo: float = minf(opening[0], opening[1])
		var hi: float = maxf(opening[0], opening[1])
		if b > lo + 0.001 and a < hi - 0.001:
			return true
	return false


## The stretches of a run that panels actually occupy: the whole tiles no opening
## dropped, grouped into contiguous runs, each as [from, to]. The frame follows
## these exactly, because these ARE the panels.
func _wall_spans(from: float, count: int, openings: Array) -> Array:
	var spans: Array = []
	var span: Array = []
	for i in count:
		var a := from + M * i
		if _blocked(a, a + M, openings):
			if not span.is_empty():
				spans.append(span)
				span = []
			continue
		if span.is_empty():
			span = [a, a + M]
		else:
			span[1] = a + M
	if not span.is_empty():
		spans.append(span)
	return spans


## THE WALL FRAME, and why every wall needs one.
##
## Wall_01 is an open shell, not a box: its mesh carries a front face, a back face
## and a chamfer at the top and the bottom, and nothing at all on its two 1.75 m
## ends. Two consequences, and neither is a placement error:
##
##   - the chamfers mean the back face stops 0.386 m short of the floor and the
##     ceiling, so along every floor line and every ceiling line there is a wedge
##     of open wall between the panel and the deck;
##   - a panel END - at the end of a wall run, and at each side of every opening -
##     is an open slot 0.295 m deep and a full deck tall, looking straight out.
##
## A skirting at the floor, a cove at the ceiling and a post at each end of every
## stretch of wall closes both. It is done per RUN rather than per panel, so the
## trim also bridges the joint between two panels and has no seam of its own. The
## trim is 0.02 m prouder than the wall so it reads as a band rather than as the
## wall having moved, and it carries NO collision: it is only ever flush against a
## wall face, and the panels' own collision boxes already block the crew.
func _wall_frame(parent: Node3D, along_z: bool, from: float, count: int,
		plane: float, base_y: float, openings: Array, tag: String) -> void:
	var index := 0
	for span in _wall_spans(from, count, openings):
		var lo: float = span[0]
		var hi: float = span[1]
		var length := hi - lo
		var mid := (lo + hi) * 0.5
		for band in [0, 1]:
			var at: float = base_y + BAND_H * 0.5 + float(band) * (H - BAND_H)
			var size := Vector3(BAND_T, BAND_H, length) if along_z else Vector3(length, BAND_H, BAND_T)
			var pos := Vector3(plane, at, mid) if along_z else Vector3(mid, at, plane)
			_deco(parent, "%s_%s%02d" % [tag, "Skirt" if band == 0 else "Cove", index],
				size, pos, M_STEP)
		## Each post sits INSIDE its own span, never centred on the edge. Centred,
		## half of it would stand in the opening - which at a window eats 0.16 m of
		## the glass and at a doorway narrows the clear walk-through. Inside the
		## span it still abuts the panel's open end and, being wider than the
		## wall's 0.295 m thickness, still closes the slot across its whole depth.
		for edge in [lo, hi]:
			var at_lo: bool = is_equal_approx(edge, lo)
			var post: float = edge + BAND_T * 0.5 if at_lo else edge - BAND_T * 0.5
			var post_at := Vector3(plane, base_y + H * 0.5, post) if along_z else Vector3(post, base_y + H * 0.5, plane)
			_deco(parent, "%s_Post%02d%s" % [tag, index, "A" if at_lo else "B"],
				Vector3(BAND_T, H, BAND_T), post_at, M_STEP)
		index += 1


func _box(size: Vector3, pos: Vector3) -> CollisionShape3D:
	var shape := BoxShape3D.new()
	shape.size = size
	var node := CollisionShape3D.new()
	node.shape = shape
	node.position = pos
	return node


## An even warm light. One per room, high, so a room reads as lit space rather
## than as a dark corridor with a glow in it.
func _light(parent: Node3D, node_name: String, pos: Vector3) -> void:
	var light := OmniLight3D.new()
	light.name = node_name
	light.position = pos
	light.light_color = Color(1.0, 0.82, 0.62, 1.0)
	light.light_energy = 2.2
	light.omni_range = 9.0
	light.shadow_enabled = true
	parent.add_child(light)
	light.owner = _root


## One floor and one ceiling slab over a footprint that is a whole number of
## tiles, at THIS deck's own two heights: the floor at the deck's floor, the
## ceiling one deck height above it.
func _deck_slab(floors: Node3D, ceilings: Node3D, x_from: float, x_to: float,
		z_from: float, z_to: float, tag: String) -> void:
	_floor_slab(floors, x_from, x_to, z_from, z_to, _floor_y, tag)
	_ceiling_slab(ceilings, x_from, x_to, z_from, z_to, _floor_y + H, tag)


## ---- the interactive pieces every deck is made of ----
##
## A doorway in a spine wall, the wall either side of it that the frame does not
## reach, a console the crew can aim at, the sealed door that gates a bay, and the
## floor trigger that greets them on arrival. These are shared by every deck: a
## second deck needs every one of them, and a second copy is exactly what the
## inheritance exists to prevent.

const P_DOORWAY := "res://scenes/prefabs/interior/Doorway_01.tscn"
const P_KIOSK := "res://assets/library/shooter-scifi/futuristic-free-standing-terminal.glb"
const P_DESK := "res://assets/library/shooter-scifi/sci-fi-computer-desk-console.glb"

const S_CONSOLE := "res://scripts/interact/console_interactable.gd"
const S_TRIGGER := "res://scripts/world/bay_trigger.gd"
const S_DOOR := "res://scripts/world/locked_door.gd"
const M_HIGHLIGHT := "res://materials/highlight.tres"
const M_DOOR := "res://materials/door_locked.tres"
## The finish a closed window's shutter carries. Deliberately not the wall's own
## material, so a shutter coming down reads as something happening rather than as
## the wall shifting; the engineering bay's is the bulkhead door, as it always was.
const M_PANEL := "res://materials/panel_light.tres"

## THE WINDOW CONTRACT. window_wall.gd hides the shutter and builds the glass and
## its sill light; the level supplies the opening and the shutter's body.
const S_WINDOW := "res://scripts/world/window_wall.gd"
const WIN_H := 2.4      ## the glass's own height, sill to header
const WIN_SILL := 0.85  ## floor to the bottom of the glass
const WIN_T := 0.06     ## glass thickness
## The solid strip each side of the glass, filling the opening's OWN edge.
##
## The pack's wall panel is an OPEN shell, not a box: its mesh carries eight
## vertices and six triangles - the inner surface and its two chamfered ends -
## and no side face and no outer face at all (read straight off the prefab:
## normals (0,-0.61,-0.79), (0,0,-1), (0,0.61,-0.79), nothing else). So a panel
## that is CUT by an opening leaves a hole clean through the wall's 0.295 m
## thickness, and the crew look straight out at space down each side of the
## glass. The sill and header already cap the opening's top and bottom because
## both are solid blocks; these two jambs do the same job on the sides, exactly
## the way _flank_doorway caps the panels a doorway straddles.
const WIN_JAMB := 0.12

## THE WALL FRAME. See _frame: the pack's wall panel is an open shell with no side
## faces and a chamfer at the top and the bottom, so every stretch of wall gets a
## skirting at the floor, a cove at the ceiling and a post at each end, which
## closes the chamfers and the open panel ends. The trim is a shade prouder than
## the wall so it reads as a band rather than as the wall having moved.
const BAND_H := 0.42           ## how tall the skirting and the cove are
const BAND_T := WALL_T + 0.02  ## the wall's own thickness, 0.02 m proud each side

## DOORWAY GEOMETRY. Doorway_01 is 0.314 thick on X and 4.089 wide on Z, i.e. a
## frame for a wall whose face points along X - which is every spine wall - so it
## needs no rotation there.
const DOOR_HALF := 2.045    ## half the opening the frame needs
const DOOR_W := 4.089       ## the frame's native width
const FRAME_T := 0.314      ## the frame's depth, its thin side on X
const JAMB_W := 0.16        ## one upright, so the clear gap between them is the rest
const DOOR_H := 3.87        ## the pack's own door panel height, i.e. the clear opening
const PANEL_T := 0.24       ## a door panel's thickness, inside the frame's 0.314
const DOOR_PROMPT := "Sealed bay"
## The clear opening between the two jambs, which is what a door has to fill.
const CLEAR_W := DOOR_W - JAMB_W * 2.0

## The doorway frame's mesh, read out of the prefab once and reused.
var _frame: Mesh = null


func _opening(centre: float) -> Array:
	return [centre - DOOR_HALF, centre + DOOR_HALF]


## A door frame standing in a spine wall, its opening clear to walk through.
##
## The pack's frame carries ONE solid CollisionShape3D across the whole opening,
## which would make the doorway impassable, and that box cannot be switched off
## from code: a property override on a child of an instanced scene is something
## only the editor's own "editable children" flow writes, and pack() either drops
## such a child or turns it into a second, local node that leaves the prefab's own
## active box underneath it. Either way the room comes back sealed. So the frame's
## MESH is taken from the prefab and given a body of its own whose collision is the
## two uprights. Nothing about the prefab on disk is touched.
func _doorway(parent: Node3D, x: float, z: float, node_name: String) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = Vector3(x, _floor_y, z)
	body.collision_layer = 2
	body.collision_mask = 0
	var model := MeshInstance3D.new()
	model.name = "Model"
	model.mesh = _frame_mesh()
	body.add_child(model)
	for edge in [-1.0, 1.0]:
		var jamb := _box(
			Vector3(FRAME_T, H, JAMB_W),
			Vector3(0.0, H * 0.5, edge * (DOOR_W - JAMB_W) * 0.5))
		jamb.name = "Jamb_A" if edge < 0.0 else "Jamb_B"
		body.add_child(jamb)
	parent.add_child(body)
	_own(body)
	_count["Doorway_01.tscn"] = int(_count.get("Doorway_01.tscn", 0)) + 1


## Fills the wall either side of a doorway, because the frame is narrower than the
## hole the panels leave.
##
## The opening cut in a wall run is DOOR_HALF either side of the door's centre, but
## the run drops whole 3.50 m panels, so the cleared gap is wider than the frame
## that fills it. Measured on a door centred at z 10.5: the panels [7.0, 10.5] and
## [10.5, 14.0] both go - 7.0 m cleared - and the 4.089 m frame reaches only
## 8.4555 .. 12.5445, leaving 1.4555 m of floor-to-ceiling hole at each side. A bay
## the crew can walk around the door into is not sealed at all, which is the entire
## point of the five bays, so each remainder is filled with the wall's own
## thickness.
func _flank_doorway(parent: Node3D, tag: String, x: float, z: float,
		z_from: float, z_to: float) -> void:
	var lo := z - DOOR_HALF
	var hi := z + DOOR_HALF
	var count := _whole(z_to - z_from, tag)
	for i in count:
		var a := z_from + M * i
		var b := a + M
		if not _blocked(a, b, [[lo, hi]]):
			continue
		## The length of this panel the frame does not reach, at each end.
		if lo > a + 0.001:
			_fill(parent, "%s_%02d_A" % [tag, i], x, a, minf(b, lo))
		if hi < b - 0.001:
			_fill(parent, "%s_%02d_B" % [tag, i], x, maxf(a, hi), b)


## One solid length of wall between two Z values, on a wall plane at a fixed X. No
## yaw: the box is WALL_T on X, which is the orientation a spine wall has.
func _fill(parent: Node3D, node_name: String, x: float, z_from: float, z_to: float) -> void:
	var length := z_to - z_from
	if length < 0.01:
		return
	_block(parent, node_name, Vector3(WALL_T, H, length),
		Vector3(x, _floor_y + H * 0.5, (z_from + z_to) * 0.5), M_WALL)
	_count["Flank"] = int(_count.get("Flank", 0)) + 1


## The frame's mesh, read out of the prefab once and reused for every doorway. It
## is copied into the saved scene by value, which is what building the collision
## here costs: a re-extract of the pack would need this level rebuilt.
func _frame_mesh() -> Mesh:
	if _frame == null:
		var scene := load(P_DOORWAY) as PackedScene
		if scene != null:
			var temp := scene.instantiate()
			var model := temp.get_node_or_null("Model") as MeshInstance3D
			if model != null:
				_frame = model.mesh
			temp.free()
		if _frame == null:
			_problems.append("could not read the doorway frame mesh from " + P_DOORWAY)
	return _frame


## A terminal the crew can aim at: the body, its model, the aim volume and the
## highlight, matching the contract in console_interactable.gd, which fits the box
## and the highlight to the model at load.
##
## Every console on these decks is turned a half turn from the way it was built,
## so each one now faces the opposite way round and the crew meet the working
## side of it instead of the back.
##
## WHY THE HALF TURN IS ADDED TO A STATED BASE YAW rather than worked out from
## which side of the ship the console is on. That rule almost holds - the room
## desks on the port side were built one way round and the starboard ones the
## other - but the two junction kiosks are freestanding terminals rather than
## desks on a wall, and they were built the other way round again. So the base
## yaw is named per console and the turn is the same for all of them: a console
## whose base is wrong is then visibly wrong in one place, and a new console has
## to say which of the three it is.
func _console_yaw(base_yaw: float) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, base_yaw + HALF_TURN), Vector3.ZERO)


## A quarter turn and a half turn about the vertical axis. The two are named
## because the consoles were built on quarter turns and the change is a half one:
## writing the sum out is what stops the half turn being quietly applied as a
## quarter turn again.
const QUARTER_TURN := PI * 0.5
const HALF_TURN := PI

## The yaws the consoles were originally built with, per kind of console.
## A room desk stands off the spine wall and is used from the room's centreline
## side, which is a different quarter turn on each side of the ship.
const PORT_ROOM_YAW := -QUARTER_TURN
const STARBOARD_ROOM_YAW := QUARTER_TURN
## The junction kiosks: freestanding terminals, built the starboard way round on
## both decks even though deck 1's stands on the port side of the junction.
const KIOSK_YAW := QUARTER_TURN


## The puzzle node is created here but left scriptless: which puzzle it is, and
## its system wiring, is the layout's business (see _puzzle).
func _console(parent: Node3D, node_name: String, pos: Vector3, model_path: String,
		model_xform: Transform3D, puzzle_name: String, prompt: String,
		shape_size: Vector3) -> Node3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = pos
	body.collision_layer = 4
	body.collision_mask = 1
	body.set_script(load(S_CONSOLE))
	body.set("puzzle_path", NodePath(puzzle_name))
	body.set("prompt", prompt)
	parent.add_child(body)

	var model_scene: PackedScene = load(model_path)
	if model_scene == null:
		_problems.append("%s model did not load: %s" % [node_name, model_path])
	else:
		var model: Node3D = model_scene.instantiate()
		model.name = "Model"
		body.add_child(model)
		model.transform = model_xform
		model.owner = _root
		_count[model_path.get_file()] = int(_count.get(model_path.get_file(), 0)) + 1

	var shape_node := CollisionShape3D.new()
	shape_node.name = "Shape"
	shape_node.position = Vector3(0.0, shape_size.y * 0.5, 0.0)
	var box := BoxShape3D.new()
	box.size = shape_size
	shape_node.shape = box
	body.add_child(shape_node)

	var highlight := MeshInstance3D.new()
	highlight.name = "Highlight"
	highlight.visible = false
	highlight.position = Vector3(0.0, shape_size.y * 0.5, 0.0)
	highlight.scale = shape_size * 1.05
	var unit := BoxMesh.new()
	unit.size = Vector3.ONE
	highlight.mesh = unit
	highlight.material_override = load(M_HIGHLIGHT)
	body.add_child(highlight)

	var puzzle := Node.new()
	puzzle.name = puzzle_name
	body.add_child(puzzle)

	_own(body)
	return body


## Hands a console's puzzle node its script and its exported wiring. One helper
## for every system: the only thing a deck has to state is which script, and which
## values that system's puzzle declares.
func _puzzle(console: Node3D, node_name: String, script_path: String,
		fields: Dictionary) -> void:
	if console == null:
		return
	var puzzle := console.get_node_or_null(node_name)
	if puzzle == null:
		_problems.append("%s has no puzzle node '%s' to wire" % [console.name, node_name])
		return
	var script: Script = load(script_path) as Script
	if script == null:
		_problems.append("puzzle script did not load: " + script_path)
		return
	puzzle.set_script(script)
	for key in fields:
		puzzle.set(String(key), fields[key])
	_own(puzzle)


## A bay door, shaped to the pack's doorway rather than to the old 3.4 m corridor:
## the clear opening between the two jambs is 3.769 m wide and 3.87 m tall, so the
## panel is cut to that and sits at the door's own centre height.
##
## It is a LockedDoor, so it carries the three children that script drives: Panel
## (hidden when open), Shape (disabled when open) and Highlight (aim outline). The
## highlight is given its SIZE as a mesh rather than as a scale, so no non-uniform
## scale is saved into the scene.
func _door(parent: Node3D, node_name: String, x: float, z: float,
		system_id: String) -> Node3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = Vector3(x, _floor_y, z)
	body.collision_layer = 4
	body.collision_mask = 1
	body.set_script(load(S_DOOR))
	body.set("system_id", system_id)
	body.set("prompt", DOOR_PROMPT)
	parent.add_child(body)

	var size := Vector3(PANEL_T, DOOR_H, CLEAR_W)
	var centre := Vector3(0.0, DOOR_H * 0.5, 0.0)

	var panel := MeshInstance3D.new()
	panel.name = "Panel"
	var panel_mesh := BoxMesh.new()
	panel_mesh.size = size
	panel.mesh = panel_mesh
	panel.material_override = load(M_DOOR)
	panel.position = centre
	body.add_child(panel)

	var shape_node := CollisionShape3D.new()
	shape_node.name = "Shape"
	var box := BoxShape3D.new()
	box.size = size
	shape_node.shape = box
	shape_node.position = centre
	body.add_child(shape_node)

	var highlight := MeshInstance3D.new()
	highlight.name = "Highlight"
	highlight.visible = false
	highlight.position = centre
	var unit := BoxMesh.new()
	unit.size = size * 1.05
	highlight.mesh = unit
	highlight.material_override = load(M_HIGHLIGHT)
	body.add_child(highlight)

	_own(body)
	_count["Door"] = int(_count.get("Door", 0)) + 1
	return body


## The span a window clears in a wall run: exactly one module, centred on a PANEL
## of it. Unlike a doorway, which needs 4.089 m of a 3.500 m module and so leaves a
## hole to flank, this is the module itself - so the panels either side are the
## window's own jambs and nothing else has to be built to frame it.
##
## `run_from` is the end the run is laid from, and the centre is snapped onto the
## panel that contains it. That is not politeness: an opening centred on a panel
## BOUNDARY is 3.500 m wide across TWO panels, so the wall drops both and leaves a
## 7.000 m hole with the window standing in the middle of it. Handed a boundary it
## snaps to the forward panel and says so in the receipt.
func _win_open(run_from: float, centre: float) -> Array:
	var middle: float = run_from + floorf((centre - run_from) / M) * M + M * 0.5
	if absf(centre - middle) > 0.001:
		_problems.append("window centre %.2f is not a panel centre of the run starting at %.2f; a window clears exactly one panel, so it was snapped to %.2f" % [centre, run_from, middle])
	return [middle - M * 0.5, middle + M * 0.5]


## One window in a room's outer wall.
##
## `axis` is which way the wall faces: 0 for a wall whose face points along X,
## which is every outer port and starboard wall on these decks, and 1 for one that
## points along Z. `plane` is the wall's own position on that axis and `along` the
## opening's centre on the other one. The caller has already dropped the panel
## with _win_open.
##
## WindowWall builds the glass and its sill light at load, and hides the SHUTTER
## while the window is open, which is how taking a system back shows the crew the
## outside. The shutter's collision stays either way, so an open window is
## something to look through rather than something to walk through.
func _window(parent: Node3D, node_name: String, axis: int, plane: float, along: float,
		system_id: String, is_door: bool, starts_open: bool,
		shutter_material: String) -> void:
	var wide := M
	var thick := WALL_T
	## Axis 0 is the pane's own frame already - thin on X, wide on Z - so only a
	## wall facing along Z is turned a quarter turn.
	var yaw := Basis() if axis == 0 else Basis(Vector3.UP, PI * 0.5)
	## The glass is set between the two jambs and reaches 2 cm into each, so its
	## own edges are buried inside them instead of meeting them in a coplanar
	## face, which would z-fight.
	var pane_w: float = wide - WIN_JAMB * 2.0
	var glass_y: float = _floor_y + WIN_SILL + WIN_H * 0.5

	## The opening is filled above and below the glass with the wall's own
	## thickness and colour, so a window reads as a hole cut in the wall rather
	## than as a frame standing in it.
	var sill_size := Vector3(thick, WIN_SILL, wide) if axis == 0 else Vector3(wide, WIN_SILL, thick)
	var sill_at := Vector3(plane, _floor_y + WIN_SILL * 0.5, along) if axis == 0 else Vector3(along, _floor_y + WIN_SILL * 0.5, plane)
	_block(parent, node_name + "_Sill", sill_size, sill_at, M_WALL)

	var head_h: float = H - WIN_SILL - WIN_H
	var head_size := Vector3(thick, head_h, wide) if axis == 0 else Vector3(wide, head_h, thick)
	var head_at := Vector3(plane, _floor_y + H - head_h * 0.5, along) if axis == 0 else Vector3(along, _floor_y + H - head_h * 0.5, plane)
	_block(parent, node_name + "_Header", head_size, head_at, M_WALL)

	## The two jambs. They stand between the sill and the header and fill the
	## opening's own edges, so the four blocks together close the wall's full
	## thickness right round the opening. Without them the cut panels either
	## side show space down the edges of the glass.
	for edge in [-1.0, 1.0]:
		var jamb_size := Vector3(thick, WIN_H, WIN_JAMB) if axis == 0 else Vector3(WIN_JAMB, WIN_H, thick)
		var jamb_at := Vector3(plane, glass_y, along + edge * (wide * 0.5 - WIN_JAMB * 0.5)) if axis == 0 else Vector3(along + edge * (wide * 0.5 - WIN_JAMB * 0.5), glass_y, plane)
		_block(parent, "%s_Jamb_%s" % [node_name, "A" if edge < 0.0 else "B"], jamb_size, jamb_at, M_WALL)

	## The window node's origin is the CENTRE of its glass, which is what
	## window_wall.gd draws the pane around, so it is placed by the wall's plane
	## and the opening's centre height - not at the floor.
	var root := Node3D.new()
	root.name = node_name
	root.set_script(load(S_WINDOW))
	var glass_at := Vector3(plane, _floor_y + WIN_SILL + WIN_H * 0.5, along) if axis == 0 else Vector3(along, _floor_y + WIN_SILL + WIN_H * 0.5, plane)
	root.transform = Transform3D(yaw, glass_at)
	root.set("system_id", system_id)
	root.set("is_door", is_door)
	root.set("starts_open", starts_open)
	root.set("opening", Vector3(WIN_T, WIN_H, pane_w + 0.04))
	parent.add_child(root)

	## The shutter the script hides, cut to the wall's own thickness so a closed
	## window reads as a panel rather than as a hole in the wall.
	var shutter := StaticBody3D.new()
	shutter.name = "Shutter"
	shutter.collision_layer = 2
	shutter.collision_mask = 0
	var model := MeshInstance3D.new()
	model.name = "Model"
	var mesh := BoxMesh.new()
	## Cut 1 cm inside the jambs, so the panel that comes down when SHIPMIND
	## closes a window does not z-fight along their shared edges.
	mesh.size = Vector3(thick, WIN_H, pane_w - 0.02)
	model.mesh = mesh
	var material: Material = load(shutter_material) as Material
	if material == null:
		_problems.append("%s shutter material did not load: %s" % [node_name, shutter_material])
	else:
		model.material_override = material
	shutter.add_child(model)
	shutter.add_child(_box(mesh.size, Vector3.ZERO))
	root.add_child(shutter)
	root.set("shutter_path", NodePath("Shutter"))
	_own(root)
	_count["Window"] = int(_count.get("Window", 0)) + 1


func _trigger(parent: Node3D, node_name: String, pos: Vector3, size: Vector3,
		lines: PackedStringArray) -> void:
	var area := Area3D.new()
	area.name = node_name
	area.position = pos
	area.set_script(load(S_TRIGGER))
	var shape := CollisionShape3D.new()
	shape.name = "Shape"
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	area.add_child(shape)
	parent.add_child(area)
	area.set("lines", lines)
	_own(area)


## One crate of loose stock, standing on THIS deck's floor.
##
## The position is given as a plan coordinate (x, z) rather than a full Vector3,
## because the height is not the caller's to choose: it is the deck floor _begin
## was told, so a crate can never be left floating or buried by a height that
## disagrees with the deck it is on. The yaw is in radians.
##
## The pack's crates pivot on their base centre and carry their own collision on
## layer 2, so placing one at that floor's own height stands it on the deck with
## nothing else to line up.
func _stock(parent: Node3D, node_name: String, prefab_path: String, xz: Vector2,
		yaw: float) -> Node3D:
	return _place(prefab_path, parent, "Crate_" + node_name, Basis(Vector3.UP, yaw),
		Vector3(xz.x, _floor_y, xz.y))


## Owns a node and everything under it. For nodes built here rather than
## instanced: PackedScene.pack() drops every sub-node whose owner is not the
## packed root, so an unstamped subtree saves as an empty shell.
func _own(node: Node) -> void:
	node.owner = _root
	## An instanced scene keeps its own children: claiming them here would save a
	## second copy of its geometry into the level instead of a reference to it.
	if node.scene_file_path != "":
		return
	for child in node.get_children():
		_own(child)


func _save() -> void:
	var packed := PackedScene.new()
	var err := packed.pack(_root)
	if err != OK:
		_problems.append("pack failed: %d" % err)
		return
	err = ResourceSaver.save(packed, _out)
	if err != OK:
		_problems.append("save failed: %d" % err)
		return
	if not FileAccess.file_exists(_out):
		_problems.append("saved but the file is not there: " + _out)


func _walk(node: Node) -> Array[Node]:
	var out: Array[Node] = [node]
	for child in node.get_children():
		out.append_array(_walk(child))
	return out


func _size(path: String) -> int:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return 0
	var bytes := file.get_length()
	file.close()
	return bytes
