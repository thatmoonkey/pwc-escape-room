extends Node3D

## One-off diagnostic for a reported problem: list every visible mesh whose world
## box overlaps the life support room AND the space outboard of it, with the
## scene each one came from and the material it draws with. Used to find geometry
## that has no business being inside that room - and to catch the other case, a
## mesh sitting OUTSIDE the room that the crew can see because a wall there has a
## hole in it.
##
##   run scenes/dev/probe_room.tscn once and read the receipt
##
## The game never calls this, and it changes nothing. Delete it once the room is
## clean.

const SCENE := "res://scenes/world/station.tscn"

## The WHOLE interior this time, not one room: the box is the union of the four
## volumes the crew occupy - deck 1 and its rooms, the stairwell, deck 2, and the
## cockpit - with a little slack, so every mesh that overlaps a space the crew
## stand in is reported, whichever scene it came from. The point is to find
## exterior geometry (the hull, the docking arms, the station) that reaches into
## the interior, and the owning scene and material on each line say which it is.
const BOX_MIN := Vector3(-17.0, -5.2, -43.0)
const BOX_MAX := Vector3(17.0, 4.2, 29.0)

const LIMIT := 400

var _hits: int = 0


func _ready() -> void:
	var packed: PackedScene = load(SCENE) as PackedScene
	if packed == null:
		print("[Probe] could not load %s" % SCENE)
		return
	var root: Node = packed.instantiate()
	add_child(root)
	print("[Probe] scanning %s for meshes overlapping X %.2f..%.2f Y %.2f..%.2f Z %.2f..%.2f" % [
		SCENE, BOX_MIN.x, BOX_MAX.x, BOX_MIN.y, BOX_MAX.y, BOX_MIN.z, BOX_MAX.z])
	_scan(root, "")
	print("[Probe] overlapping meshes=%d" % _hits)


func _scan(node: Node, path: String) -> void:
	var here := path + "/" + String(node.name) if path != "" else String(node.name)
	var mesh_node := node as MeshInstance3D
	if mesh_node != null and mesh_node.mesh != null:
		var box: AABB = mesh_node.global_transform * mesh_node.get_aabb()
		if _overlaps(box):
			_hits += 1
			if _hits <= LIMIT:
				print("[Probe] %d %s | scene=%s | mat=%s | size=%s | world=%s..%s" % [
					_hits, here, _scene_of(mesh_node), _material_of(mesh_node),
					_v(box.size), _v(box.position), _v(box.end)])
	for child in node.get_children():
		_scan(child, here)


func _overlaps(box: AABB) -> bool:
	return box.position.x <= BOX_MAX.x and box.end.x >= BOX_MIN.x \
		and box.position.y <= BOX_MAX.y and box.end.y >= BOX_MIN.y \
		and box.position.z <= BOX_MAX.z and box.end.z >= BOX_MIN.z


## The scene a node was instanced from, if any: a prefab reads as its own .tscn
## while a node built in code reads as empty.
func _scene_of(node: Node) -> String:
	return node.scene_file_path if node.scene_file_path != "" else "-"


func _material_of(node: MeshInstance3D) -> String:
	var override := node.material_override
	if override != null:
		return override.resource_path if override.resource_path != "" else String(override.get_class())
	for surface in node.mesh.get_surface_count():
		var material := node.mesh.surface_get_material(surface)
		if material != null:
			return material.resource_path if material.resource_path != "" else String(material.get_class())
	return "none"


func _v(v: Vector3) -> String:
	return "(%.2f,%.2f,%.2f)" % [v.x, v.y, v.z]
