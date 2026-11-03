class_name ShipHull
extends Node3D

## The user's starship, placed as the hull the crew module sits inside.
##
## MEASURED, NOT ASSUMED. The model is measured on load before anything is
## placed, and every constant below is either read off that measurement or
## derived from it:
##   X is the long axis, and the model arrives 1.14 m long
##   Y is up, 0.38 m, with the keel sitting exactly on Y = 0
##   Z is width, 0.33 m
##   it imports as ONE mesh with ONE surface
##
## WHY THE HULL IS SCALED UP RATHER THAN PLACED AS IMPORTED. The model's own
## root carries a scale of about a hundredth, so it lands as a 1.1 m object - a
## speck beside a 47 m crew module, and the fit check said so in exactly those
## words. The hull is therefore scaled from its own MEASURED longest axis up to
## HULL_LENGTH, which puts it back at its authored size. Deriving the factor
## means a model authored at a different scale, or an importer that stops
## applying this one, both still land at the size this file expects.
##
## WHY THE HULL IS CUT WITH A SHADER. Because there is no interior to remove: one
## closed mesh has no named interior node and no separate interior geometry. The
## hull is therefore discarded wherever it falls inside a box, per fragment - see
## shaders/hull_cutout.gdshader. The model file is never modified.
##
## THE CUT IS TWO FAMILIES OF BOX, and the difference between them is the whole of
## this file's geometry problem:
##
##   the interiors   one box per region the crew can stand in (INTERIOR_BOXES,
##                   below). These remove the hull that was crossing the
##                   corridors and rooms - the ship's own plating standing in a
##                   compartment it has no business being in. Each box stops at
##                   the interior's OUTER SURFACE, not at a wall centre line, and
##                   every one of them is inside the ship's own skin - so what
##                   they remove is hull the crew could see from inside and
##                   nobody can see from outside. The receipt proves both halves
##                   of that claim rather than asserting it: it counts the hull
##                   vertices inside each box and measures the ship's own width
##                   across it.
##
##   the windows     one box per bay window, read off the WindowWall nodes, each
##                   extruded OUTWARD past the hull's measured skin. These are
##                   the only boxes that deliberately open the exterior, because
##                   a window IS meant to be a hole in the ship.
##
## WHAT THIS REPLACED. The cut was first one box around the whole crew module, out
## to the 16.5 m half beam. That let the bays see out but took the ship apart
## along its middle - the same idea taken too far. It was then narrowed to the
## windows alone, which put the exterior back but left the ship's plating crossing
## the compartments. It is now both, which is the only pair of boxes that is right
## in both directions at once: absent from every room, whole everywhere else.
##
## ORIENTATION. The hull is turned so its long axis runs along the corridor's
## own, and the ship's head faces the way the cockpit looks. That is one number,
## YAW_DEGREES, and it is the only thing that has to move if this model's bow
## turns out to be at the other end. Everything derived from the hull's shape -
## the fit check, the cutout box, the band measurement - reads the transformed
## geometry, so none of it needs to know which way round the ship is.
##
## It is left at a quarter turn, which is what puts the model's long X axis onto
## the corridor's Z. What reverses the ship is a half turn about the VERTICAL
## axis: a half turn about X would do the same thing plus a roll, leaving it
## keel up with its superstructure hanging beneath the corridor.
##
## THE FIT. The interior is two decks now rather than one corridor: it needs
## roughly 32 x 9 x 70 m where the corridor needed 23.2 x 4.2 x 47.0. At its
## authored size the ship is 114 m long, 38 m tall and 32 m in beam, and it is
## widest low down, which is exactly why the decks stack DOWNWARD from the crew
## floor rather than up. So the module sits INSIDE the hull and the crew are
## genuinely inside the vessel rather than beside it, and the receipt below
## reports that fit honestly. It measures the hull's real cross-section at the
## module's own height rather than its bounding box, and because it measures
## transformed geometry it stays true however the hull is moved.

const MODEL := "res://assets/exterior/PWC_Spaceship.glb"
const CUTOUT_SHADER := "res://shaders/hull_cutout.gdshader"
## Used only if the imported material carries no texture of its own, so the hull
## can never come out untextured white.
const FALLBACK_TEXTURE := "res://assets/exterior/PWC_Spaceship_texture_20250901.png"

## The heading, about the vertical axis. See ORIENTATION above.
const YAW_DEGREES := 90.0

## How long the hull is once it has been scaled back to its authored size. The
## model's own dimensions are read from it on load and the scale is derived from
## them, so this is the one place the ship's real size is stated.
const HULL_LENGTH := 114.0

## How far the hull is dropped below the crew floor.
##
## The ship is widest low down - its measured slices hold the full 32 m of beam
## only in the band the crew module occupies - so the module is NOT dropped to
## the hull's keel. Lifting it 12 m puts the module's own 4.2 m band at model Y
## 11.4..15.6, where that beam is, and leaves the keel 12 m below the crew's
## floor. Dropping it less leaves the bays hanging out of the ship's underside,
## which is exactly what a bounding-box check fails to catch.
const HULL_DROP := 12.0

## The volume the crew module occupies, in world space, taken from the authored
## scenes rather than from the old runtime builders:
##   deck 1    y 0.00 .. 4.06    rooms reach X +/-9.0, spine Z -28.0 .. 17.5
##   deck 2    y -4.86 .. -0.80  cargo hold reaches X +15.9, spine to Z 17.5
##   stairwell Z -42.0 .. -28.0  dropping deck 1 to deck 2
##   cockpit   Z 17.5 .. 28.15   forward of deck 1's spine
## The module's own extent in Y and Z. The cut no longer uses it - the openings
## are the windows' own - but the fit receipt still measures the hull against it,
## because "is the crew module inside the ship" is a question about the module
## whatever the cut does.
const MODULE_MIN := Vector3(-16.0, -4.86, -42.0)
const MODULE_MAX := Vector3(16.0, 4.06, 28.2)

## THE CREW'S OWN VOLUME, as the authored decks actually built it: one world-space
## box per region the crew can stand in, sized to the interior's OUTER SURFACE
## rather than to a wall centre line, so plating flush against a room's outer wall
## goes with the room and not just the plating further in.
##
##   deck 1        y  0.00 ..  4.06   x +/-8.90 (the port-most interior surface is
##                                     X -8.8975), z -28.0 .. 17.5
##   stairwell     y -4.86 ..  4.06   x +/-1.90 (the switchback's 3.205 m clear
##                                     width plus its walls), z -39.0 .. -28.0
##
## The stairwell's box stops at z -39.0 rather than at the -42.0 its floor slab
## reaches, and that is deliberate. The crew cannot go aft of the stairwell's own
## AftFace at -38.5, so nothing behind it is a space to clear - and the hull's
## stern at deck 2's height ends at -41.0, so a box reaching -42.0 would discard
## the ship's own rear plating and open the stern of an otherwise whole vessel.
## The cut follows the CREW, not the slabs.
##    deck 2       y -4.86 .. -0.80   x -5.55 .. 15.90 (the port junction wall to
##                                     the cargo hold's 15.9), z -31.5 .. 17.5
##   bridge/cockpit y 0.00 ..  3.40   x +/-2.99, z 17.5 .. 28.15
##
## These are the boxes that stop the ship standing in its own corridors. They are
## also the reason the receipt exists: a box wider than the ship's skin at that
## height would open the exterior rather than close the interior, and that is a
## number, not an opinion - see _report_interior.
const INTERIOR_BOXES := [
	AABB(Vector3(-8.90, 0.0, -28.0), Vector3(17.80, 4.06, 45.50)),
	AABB(Vector3(-1.90, -4.86, -39.0), Vector3(3.80, 8.92, 11.00)),
	AABB(Vector3(-5.55, -4.86, -31.50), Vector3(21.45, 4.06, 49.00)),
	AABB(Vector3(-2.99, 0.0, 17.50), Vector3(5.98, 3.40, 10.65)),
]

## The one tuning knob. It grows each window's opening outboard, past the hull's
## own skin, so the hull is never left standing a few centimetres in front of a
## pane. It is derived from the opening's real depth rather than typed in, so
## this only has to be a sensible fraction of that depth.
@export_range(0.0, 2.0, 0.05) var opening_padding: float = 0.8

## The most cut boxes the shader can carry, fixed because a uniform array is. Nine
## exist - the five windows plus the four interior boxes - and sixteen is the cap,
## which leaves room for three more windows and a room or two more. A box past the
## cap is reported rather than silently left uncut.
const MAX_CUTS := 16

## Used only if the hull cannot be measured at the windows' height. The openings
## then run out to this half beam, which is wide enough to clear any plating this
## model has, so a measurement failure opens the windows rather than blacking
## them out.
const FALLBACK_HULL_REACH := 17.0

var _ship: Node3D = null
## The factor the hull was scaled by, kept for the receipt: a hull placed at the
## wrong scale still loads, still textures, and still reports a mesh count, so
## the one number that says whether it is a ship or a speck has to be printed.
var _hull_scale: float = 1.0


func _ready() -> void:
	add_to_group("ship_hull")
	_place()


func _place() -> void:
	var packed: PackedScene = load(MODEL) as PackedScene
	if packed == null:
		push_warning("ShipHull: could not load %s" % MODEL)
		return
	_ship = packed.instantiate() as Node3D
	if _ship == null:
		push_warning("ShipHull: %s did not instantiate as a Node3D" % MODEL)
		return
	_ship.name = "Hull"
	## Added BEFORE any transform is written, so the measurement below is taken in
	## the model's own frame. That is the only frame in which the scale, the yaw
	## and the drop can be chosen from measurement rather than guessed at.
	add_child(_ship)
	## The scale goes on FIRST, before the yaw and the drop, and it is derived
	## from the measurement rather than typed in: the model arrives at about a
	## hundredth of its authored size, and this is what puts it back to HULL_LENGTH.
	_hull_scale = _scale_for(_merged(_ship).size)
	_ship.scale = Vector3.ONE * _hull_scale
	_ship.rotation_degrees = Vector3(0.0, YAW_DEGREES, 0.0)
	_ship.position = Vector3(0.0, -HULL_DROP, 0.0)

	var material: ShaderMaterial = _build_material()
	if material != null:
		for node in _meshes(_ship):
			node.material_override = material
	_report()


## A shader material carrying the model's own texture, roughness and metallic
## across, plus the world-space box whose inside is discarded. The hull therefore
## keeps the look it was authored with; nothing here repaints it into the crew
## module's palette, because it is not part of the interior.
func _build_material() -> ShaderMaterial:
	var shader: Shader = load(CUTOUT_SHADER) as Shader
	if shader == null:
		push_warning("ShipHull: could not load %s" % CUTOUT_SHADER)
		return null
	var material := ShaderMaterial.new()
	material.shader = shader
	_adopt_source_look(material)
	var cuts := _cut_boxes()
	var mins: Array[Vector3] = []
	var maxs: Array[Vector3] = []
	for cut in cuts:
		mins.append(cut.position)
		maxs.append(cut.end)
	## The arrays are always full size, because a shader uniform array is fixed.
	## A slot past the count is left as an empty box, which nothing can be strictly
	## inside, so it cuts nothing.
	while mins.size() < MAX_CUTS:
		mins.append(Vector3.ZERO)
		maxs.append(Vector3.ZERO)
	material.set_shader_parameter("cut_count", cuts.size())
	material.set_shader_parameter("cut_min", mins)
	material.set_shader_parameter("cut_max", maxs)
	return material


## The openings in the hull: one world-space box per bay window, read off the
## WindowWall nodes the decks actually built rather than kept as a second copy of
## their positions here.
##
## A window's own frame IS its opening: X along the wall's normal, Z along the
## wall, Y up, and an opening only a few centimetres thick across the wall. That
## thinness is the problem - the hull's skin is up to 16.3 m out, so a box the
## thickness of the wall would open a slot on the inside face and leave ship
## standing in front of the glass. So each opening is extruded OUTWARD along X,
## away from the ship's centreline, until it is well past the skin:
##
##   hull_out = the hull's own measured extent on the window's side, plus pad
##
## so the cut always reaches the far side of the ship's plating however the hull
## is placed or scaled, and pad is the only number that has to be sensible.
func _openings() -> Array[AABB]:
	var found: Array[AABB] = []
	var pad: float = maxf(opening_padding, 0.0)
	var walls: Array[WindowWall] = []
	for node in get_tree().get_nodes_in_group("window_wall"):
		var wall := node as WindowWall
		if wall != null:
			walls.append(wall)
	for wall in walls:
		## The interior boxes are always cut, so the window boxes share the cap with
		## them rather than using it up first.
		if found.size() >= MAX_CUTS - INTERIOR_BOXES.size():
			push_warning("ShipHull: more than %d windows; the extra openings are not cut and hull will stand in front of them." % (MAX_CUTS - INTERIOR_BOXES.size()))
			break
		var here: Vector3 = wall.global_position
		var xform: Transform3D = wall.global_transform
		var half: Vector3 = wall.opening * 0.5
		## The opening's own two lateral axes, taken from the node's frame so a
		## window in a wall that faces along Z works without a special case.
		var along_wall: Vector3 = xform.basis.z
		var up: Vector3 = xform.basis.y
		var thin: Vector3 = xform.basis.x
		## Which way is out: away from the ship's centreline on the window's own
		## side. Every bay window sits off the spine, so X decides it.
		var out: float = -1.0 if here.x < 0.0 else 1.0
		## MAGNITUDES on both sides of the max: _hull_reach returns a signed
		## world coordinate (-16.2 on the port side, +16.4 on the starboard one),
		## so taking it as a positive distance without absf() let the port side
		## lose the max against the window's own 8.75 m and open a 0.1 m slot
		## inside the wall instead of a bore out through the hull. The starboard
		## side hid it, because there the signed value is already positive.
		var reach: float = maxf(absf(_hull_reach(out)) + pad, absf(here.x))
		var box_min: Vector3 = here - along_wall * half.z - up * half.y
		var box_max: Vector3 = here + along_wall * half.z + up * half.y
		var a: Vector3 = Vector3(minf(box_min.x, box_max.x), minf(box_min.y, box_max.y), minf(box_min.z, box_max.z))
		var b: Vector3 = Vector3(maxf(box_min.x, box_max.x), maxf(box_min.y, box_max.y), maxf(box_min.z, box_max.z))
		## The thin axis is the wall's normal, so the box is opened from just
		## inside the wall to well past the hull's plating on that side.
		a.x = here.x - absf(thin.x) * half.x - 0.1
		b.x = out * reach
		if a.x > b.x:
			var swap: float = a.x
			a.x = b.x
			b.x = swap
		found.append(AABB(a, b - a))
	return found


## Every box the hull is discarded inside: the crew's own volume first, because
## those are the boxes that must always be cut, then one outboard opening per bay
## window. Order matters only against the cap, and the interiors take priority.
func _cut_boxes() -> Array[AABB]:
	var found: Array[AABB] = []
	for box in INTERIOR_BOXES:
		found.append(box)
	for opening in _openings():
		if found.size() >= MAX_CUTS:
			push_warning("ShipHull: more than %d cut boxes; some hull will be left standing in the ship." % MAX_CUTS)
			break
		found.append(opening)
	return found


## The hull's own extent on one side of the centreline, at the windows' height.
## A measurement rather than a constant, so the openings reach the far side of
## the plating even if the model, its scale or its drop ever change.
func _hull_reach(side: float) -> float:
	var band: AABB = _band(-1.0, 5.0)
	if band.size == Vector3.ZERO:
		## No hull measured: fall back to the widest half beam this model is
		## known to have, so the openings still clear the wall rather than
		## opening nothing.
		return FALLBACK_HULL_REACH
	return band.position.x if side < 0.0 else band.end.x


func _adopt_source_look(material: ShaderMaterial) -> void:
	var found_texture := false
	for node in _meshes(_ship):
		if node.mesh == null:
			continue
		for surface in node.mesh.get_surface_count():
			var source: StandardMaterial3D = node.mesh.surface_get_material(surface) as StandardMaterial3D
			if source == null:
				continue
			if source.albedo_texture != null:
				material.set_shader_parameter("albedo_tex", source.albedo_texture)
				material.set_shader_parameter("use_texture", true)
				found_texture = true
			material.set_shader_parameter("albedo_color", source.albedo_color)
			material.set_shader_parameter("hull_roughness", source.roughness)
			material.set_shader_parameter("hull_metallic", source.metallic)
	if found_texture:
		return
	## The importer produced a material this script cannot read. The hull is far
	## too large a surface to leave untextured, so the named texture file is used
	## directly rather than silently drawing a white ship.
	var fallback: Texture2D = load(FALLBACK_TEXTURE) as Texture2D
	if fallback == null:
		push_warning("ShipHull: no texture on the model and %s did not load." % FALLBACK_TEXTURE)
		return
	material.set_shader_parameter("albedo_tex", fallback)
	material.set_shader_parameter("use_texture", true)


## A receipt, because the ship is built at runtime and never appears in the saved
## scene: without this there is no way to tell a hull that placed correctly from
## one that failed to load.
##
## The fit is measured against the hull's REAL cross-section, not its bounding
## box. An earlier version compared the module against the hull's AABB and
## reported a healthy positive clearance while the module was in fact hanging out
## of the ship's underside - the ship tapers, so its underside is about 16 m wide
## even though its widest slice is 28 m, and a box test cannot see that. The
## band figure below is the hull's actual extent at the module's own height, and
## "fitted" is the honest answer to whether the module is inside the ship.
func _report() -> void:
	if not OS.is_debug_build():
		return
	var box: AABB = _merged(_ship)
	var low: Vector3 = box.position
	var high: Vector3 = box.end
	var band: AABB = _band(MODULE_MIN.y, MODULE_MAX.y)
	## What the cut actually is: the crew's own volume plus the window openings.
	## The receipt prints the boxes, because "how many, and how wide" is the
	## difference between a ship with five windows and a ship split open along its
	## middle.
	var cuts: Array[AABB] = _cut_boxes()
	var cut_line: String = "NONE - the hull is closed and every window shows plating"
	if not cuts.is_empty():
		var parts: Array[String] = []
		for cut in cuts:
			parts.append("X %.1f..%.1f" % [cut.position.x, cut.end.x])
		cut_line = " | ".join(parts)
	var texture: bool = bool(_first_material() != null and _first_material().get_shader_parameter("use_texture") == true)
	print("[ShipHull] yaw=%.0f drop=%.1f scale=%.1f pad=%.2f meshes=%d texture=%s | hull X %.1f..%.1f Y %.1f..%.1f Z %.1f..%.1f | hull at module height X %.1f..%.1f Y %.1f..%.1f Z %.1f..%.1f | module X %.1f..%.1f Y %.1f..%.1f Z %.1f..%.1f | fitted X %s Z %s | window cutouts %d [%s]" % [
		YAW_DEGREES, HULL_DROP, _hull_scale, opening_padding, _meshes(_ship).size(),
		"yes" if texture else "no",
		low.x, high.x, low.y, high.y, low.z, high.z,
		band.position.x, band.end.x, band.position.y, band.end.y, band.position.z, band.end.z,
		MODULE_MIN.x, MODULE_MAX.x, MODULE_MIN.y, MODULE_MAX.y, MODULE_MIN.z, MODULE_MAX.z,
		"yes" if band.position.x <= MODULE_MIN.x and band.end.x >= MODULE_MAX.x else "NO",
		"yes" if band.position.z <= MODULE_MIN.z and band.end.z >= MODULE_MAX.z else "NO",
		cuts.size(), cut_line])
	_report_interior()
	_report_profile()


## WHAT THE INTERIOR BOXES ACTUALLY DID, measured rather than asserted. For each
## box this reports three things:
##
##   inside    how many hull triangles have a box overlapping it - hull the crew
##             would otherwise see standing in that compartment. Counted by
##             triangle rather than by vertex because a coarse panel can cross a
##             room with no vertex inside it; see _probe_interior. A non-zero
##             count means there IS hull surface here, and the shader discards it.
##   hull X    the ship's own X extent across that box's Y and Z window, which is
##             what the box's width has to be compared against.
##   the note  whether the box is inside the ship's skin there. A box WIDER THAN
##             THE HULL opens the exterior rather than closing the interior, and
##             that is the one failure this cut can have, so it is named in the
##             receipt instead of being found later in the departure shot.
func _report_interior() -> void:
	var lines: Array[String] = []
	for box in INTERIOR_BOXES:
		var probe: Dictionary = _probe_interior(box)
		var span: AABB = probe["span"]
		var note: String = "inside the ship's skin"
		if span.size == Vector3.ZERO:
			note = "no hull measured in this window"
		elif span.position.x > box.position.x or span.end.x < box.end.x:
			note = "WIDER THAN THE HULL - this cut opens the exterior"
		lines.append("X %.1f..%.1f Y %.1f..%.1f Z %.1f..%.1f | hull X %.1f..%.1f | inside %d | %s" % [
			box.position.x, box.end.x, box.position.y, box.end.y, box.position.z, box.end.z,
			span.position.x, span.end.x, int(probe["inside"]), note])
	print("[ShipHull] interior boxes | %s" % "  ||  ".join(lines))


## One pass over the hull for one interior box: how much hull SURFACE overlaps it,
## and the ship's own extent across that box's Y and Z window.
##
## COUNTED BY TRIANGLE, NOT BY VERTEX, and that distinction was a real bug in the
## first version of this measurement. A vertex count only finds hull that has a
## corner inside the compartment, and this hull is coarse: a whole panel of
## plating can cross a corridor with every one of its vertices outside it, so the
## count read zero while the ship was still standing in the room. A triangle's
## own box is tested instead, which is a cheap over-approximation of the surface
## crossing the box - it counts a triangle that merely grazes the boundary, so a
## non-zero count is "there may be hull here", and zero is the reliable answer.
func _probe_interior(box: AABB) -> Dictionary:
	var crossing: int = 0
	var span := AABB()
	var first: bool = true
	for node in _meshes(_ship):
		if node.mesh == null:
			continue
		var xform: Transform3D = node.global_transform
		for surface in node.mesh.get_surface_count():
			var arrays: Array = node.mesh.surface_get_arrays(surface)
			var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var index: int = 0
			while index + 2 < points.size():
				var here: AABB = _tri_box(
					xform * points[index], xform * points[index + 1], xform * points[index + 2])
				index += 3
				## Only hull in this box's own Y and Z window is of interest, and
				## that window is also what the ship's span is measured across.
				if here.position.y > box.end.y or here.end.y < box.position.y:
					continue
				if here.position.z > box.end.z or here.end.z < box.position.z:
					continue
				if first:
					span = here
					first = false
				else:
					span = span.merge(here)
				if here.position.x <= box.end.x and here.end.x >= box.position.x:
					crossing += 1
	return {"inside": crossing, "span": span}


## The world box around one triangle. Cheaper than three separate axis tests and
## the same answer for an overlap question.
func _tri_box(a: Vector3, b: Vector3, c: Vector3) -> AABB:
	var low := Vector3(minf(a.x, minf(b.x, c.x)), minf(a.y, minf(b.y, c.y)), minf(a.z, minf(b.z, c.z)))
	var high := Vector3(maxf(a.x, maxf(b.x, c.x)), maxf(a.y, maxf(b.y, c.y)), maxf(a.z, maxf(b.z, c.z)))
	return AABB(low, high - low)


## The hull's own vertical profile: how wide and how long it is at each deck
## height, as one line per candidate deck floor.
##
## This exists because the ship is NOT a box. It tapers and it is widest low
## down, so how much room a second deck has is a MEASUREMENT rather than an
## assumption - and the interior is currently one 4.2 m slab sitting inside a
## 38 m tall hull, using about a tenth of the height it is given. A rebuild that
## uses the height has to know what the hull actually offers at each level
## before a single room is placed on it.
##
## Each band is one deck's height, centred on a candidate deck floor in world
## space, so the figures are what a floor at that height would actually get: X
## is beam, Z is fore-and-aft run. A band with a wide X and a long Z can hold
## rooms; a narrow one can only hold a service crawl or nothing.
func _report_profile() -> void:
	## Candidate deck floors on a 3.7 m deck-to-deck pitch about the existing
	## crew floor at Y 0: two levels above it and three below.
	var lines: Array[String] = []
	for centre in [9.1, 5.4, 1.7, -2.0, -5.7, -9.4]:
		var band: AABB = _band(float(centre) - 1.7, float(centre) + 1.7)
		if band.size == Vector3.ZERO:
			lines.append("y=%.1f empty" % float(centre))
			continue
		lines.append("y=%.1f X %.1f..%.1f (%.1f beam) Z %.1f..%.1f (%.1f run)" % [
			float(centre), band.position.x, band.end.x, band.size.x,
			band.position.z, band.end.z, band.size.z])
	print("[ShipHull] profile | %s" % " | ".join(lines))


## The scale that puts the hull back at its authored size, taken from the model's
## own measured longest axis rather than typed in beside it. This model arrives
## with about a hundredth of a scale on its root, so it lands 1.14 m long against
## a 47 m crew module; deriving the factor means a different model, or an
## importer that stops applying that scale, both still land at the expected size.
func _scale_for(raw: Vector3) -> float:
	var longest: float = maxf(raw.x, maxf(raw.y, raw.z))
	if longest < 0.001:
		return 1.0
	return HULL_LENGTH / longest


## The hull's actual extent at a given height: the world box around every hull
## vertex that falls inside that Y band. This is the measurement the fit has to
## be judged on, because the ship is not a box - it tapers, so a slice near its
## keel is far narrower than one through its middle.
func _band(min_y: float, max_y: float) -> AABB:
	return _band_axis(1, min_y, max_y)


func _band_axis(axis: int, low: float, high: float) -> AABB:
	var box := AABB()
	var first: bool = true
	for node in _meshes(_ship):
		if node.mesh == null:
			continue
		var xform: Transform3D = node.global_transform
		for surface in node.mesh.get_surface_count():
			var arrays: Array = node.mesh.surface_get_arrays(surface)
			var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			## Every second vertex is plenty to bound a cross-section.
			for index in range(0, points.size(), 2):
				var p: Vector3 = xform * points[index]
				var v: float = _axis_of(p, axis)
				if v < low or v > high:
					continue
				if first:
					box = AABB(p, Vector3.ZERO)
					first = false
				else:
					box = box.expand(p)
	return box


func _axis_of(v: Vector3, axis: int) -> float:
	if axis == 0:
		return v.x
	if axis == 1:
		return v.y
	return v.z


func _first_material() -> ShaderMaterial:
	for node in _meshes(_ship):
		var material := node.material_override as ShaderMaterial
		if material != null:
			return material
	return null


func _meshes(node: Node) -> Array[MeshInstance3D]:
	var found: Array[MeshInstance3D] = []
	if node is MeshInstance3D:
		found.append(node as MeshInstance3D)
	for child in node.get_children():
		found.append_array(_meshes(child))
	return found


func _merged(node: Node) -> AABB:
	var box := AABB()
	var first: bool = true
	for mesh in _meshes(node):
		var here: AABB = mesh.global_transform * mesh.get_aabb()
		if first:
			box = here
			first = false
		else:
			box = box.merge(here)
	return box
