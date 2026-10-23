extends Node3D

## Shape-and-spread pass over the three candidate interior kits.
##
## WHY A FOURTH PASS. The histogram pass answered how BIG each part is. It did
## not answer the two things the rebuild actually turns on:
##
##   1. Are the parts FLAT PLATES or SOLID VOLUMES? A kit of flat plates is an
##      architecture kit - walls, floors, ceilings, doors, windows are all flat.
##      A kit of solid volumes is a prop kit. Two of these three kits have no
##      usable names (Cube.000, defaultMaterial, g102), so the shape mix is the
##      only reliable read on what they are for.
##
##   2. How far apart are the parts? These kits came off Sketchfab, and a kit
##      whose parts are laid out in a showroom grid spreads out when scaled.
##      That spread is what a staged render frames, so a wrong factor there
##      produces a blank frame - which is exactly what the staged render did.
##      Printing the overall bounds shows where each kit's parts really sit.
##
## Reads and prints only. Changes no existing file. Delete once reviewed.

const KITS: Array[String] = [
	"res://assets/kit/sci-fi_interior_pack_lowpoly.glb",
]
## A part whose smallest axis is under this fraction of its longest is a plate.
const PLATE_RATIO := 0.05
## Under this fraction it is a thin slab; above it, a solid volume.
const SLAB_RATIO := 0.25
## How many part names to list before summarising the rest.
const NAME_CAP := 30


func _ready() -> void:
	for path in KITS:
		_report(path)


func _report(path: String) -> void:
	var packed: PackedScene = load(path) as PackedScene
	if packed == null:
		print("[Kit] %s: NOT READY" % path.get_file())
		return
	var root: Node = packed.instantiate()
	if root == null:
		print("[Kit] %s: instantiate returned null" % path.get_file())
		return
	add_child(root)
	var kit_root: Node3D = root as Node3D
	if kit_root == null:
		print("[Kit] %s: root is not a Node3D" % path.get_file())
		return
	kit_root.visible = false
	var to_kit: Transform3D = kit_root.global_transform.affine_inverse()

	var parts: Array = _part_level(kit_root)
	var rows: Array = []
	var tris := 0
	var mesh_total := 0
	var plates := 0
	var slabs := 0
	var volumes := 0
	var base_pivots := 0
	var other_pivots := 0
	var names: Array[String] = []
	var extent := AABB()
	var first_box := true

	for node in parts:
		var holder: Node3D = node as Node3D
		if holder == null:
			continue
		var found: Array[MeshInstance3D] = []
		_collect(holder, found)
		if found.is_empty():
			continue
		var box := AABB()
		var first := true
		var part_tris := 0
		for mesh in found:
			if mesh.mesh == null:
				continue
			mesh_total += 1
			var here: AABB = to_kit * (mesh.global_transform * mesh.get_aabb())
			box = here if first else box.merge(here)
			first = false
			part_tris += mesh.mesh.get_faces().size() / 3
		tris += part_tris

		var size: Vector3 = box.size
		var longest: float = maxf(size.x, maxf(size.y, size.z))
		var smallest: float = minf(size.x, minf(size.y, size.z))
		var ratio: float = 1.0 if longest <= 0.0 else smallest / longest
		if ratio <= PLATE_RATIO:
			plates += 1
		elif ratio <= SLAB_RATIO:
			slabs += 1
		else:
			volumes += 1

		var origin: Vector3 = (to_kit * holder.global_transform).origin
		## Pivot class. A part whose own origin sits at the bottom of its own box
		## is placed by writing a floor position. Anything else needs an offset,
		## and the extractor's base-centre rule would be wrong for it.
		var pivot_tol: float = maxf(0.02, size.y * 0.02)
		if absf(origin.y - box.position.y) <= pivot_tol:
			base_pivots += 1
		else:
			other_pivots += 1
		names.append(String(holder.name))
		rows.append({
			"name": String(holder.name),
			"size": size,
			"tris": part_tris,
			"origin": origin,
			"low": box.position,
			"meshes": found.size(),
		})
		extent = box if first_box else extent.merge(box)
		first_box = false

	print("[Kit] ===== %s | parts=%d meshes=%d tris=%d" % [
		path.get_file(), rows.size(), mesh_total, tris])
	print("[Kit]   shape mix: flat_plates=%d thin_slabs=%d solid_volumes=%d | pivot base=%d other=%d" % [
		plates, slabs, volumes, base_pivots, other_pivots])
	print("[Kit]   names: %s" % _name_preview(names))
	print("[Kit]   overall bounds: min=(%.2f,%.2f,%.2f) max=(%.2f,%.2f,%.2f) extent=%.2f x %.2f x %.2f" % [
		extent.position.x, extent.position.y, extent.position.z,
		extent.position.x + extent.size.x, extent.position.y + extent.size.y,
		extent.position.z + extent.size.z,
		extent.size.x, extent.size.y, extent.size.z])

	## Every part, not just the largest two. This pack has seven parts, and the
	## one that decides the whole room's height is not necessarily the biggest.
	rows.sort_custom(_by_longest)
	for row in rows:
		var size: Vector3 = row["size"]
		var origin: Vector3 = row["origin"]
		var low: Vector3 = row["low"]
		print("[Kit]   %-22s %6.2f x%6.2f x%6.2f | pivot=(%.2f,%.2f,%.2f) box_low_y=%.2f | m=%d tris=%d" % [
			String(row["name"]).substr(0, 22), size.x, size.y, size.z,
			origin.x, origin.y, origin.z, low.y,
			int(row["meshes"]), int(row["tris"])])


## A capped, sorted list of part names. Opaque names (Cube.000, g102) say the
## kit has no vocabulary; real names (Wall, Door_Frame) say what it is for.
func _name_preview(names: Array[String]) -> String:
	if names.is_empty():
		return "none"
	names.sort()
	if names.size() <= NAME_CAP:
		return "%d: %s" % [names.size(), ", ".join(names)]
	var head: Array[String] = []
	for index in range(NAME_CAP):
		head.append(names[index])
	return "%d: %s ... (+%d more)" % [names.size(), ", ".join(head), names.size() - NAME_CAP]


func _by_longest(a: Dictionary, b: Dictionary) -> bool:
	var sa: Vector3 = a["size"]
	var sb: Vector3 = b["size"]
	return maxf(sa.x, maxf(sa.y, sa.z)) < maxf(sb.x, maxf(sb.y, sb.z))


## The level of the tree holding the models: the level with the most Node3D
## children.
func _part_level(node: Node) -> Array:
	var level: Array = []
	for child in node.get_children():
		if child is Node3D:
			level.append(child)
	var best: Array = level
	for child in level:
		var deeper: Array = _part_level(child)
		if deeper.size() > best.size():
			best = deeper
	return best


func _collect(node: Node, found: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		found.append(node as MeshInstance3D)
	for child in node.get_children():
		_collect(child, found)
