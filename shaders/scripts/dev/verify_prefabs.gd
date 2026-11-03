extends Node3D

## Verification pass over an extracted prefab folder.
##
## WHY: the extractor reports how many scenes it SAVED, which proves only that
## ResourceSaver returned OK. A saved scene can still fail to load later - a
## broken ext_resource, a mesh that did not serialise, a collision shape whose
## class was written wrong - and every one of those is invisible until something
## instantiates it. So this loads each prefab, instantiates it, and checks that
## the two nodes every prefab must carry are really there: a mesh to see and a
## collision shape to walk into.
##
## It also reports the mesh's own vertical AABB, because the pivot convention is
## the thing that makes a prefab placeable: a mesh whose box starts at y=0 sits
## on the floor it is placed at.
##
## Reads only. Changes no file.

const FOLDER := "res://scenes/prefabs/interior"
## A prefab whose mesh is smaller than this on its longest axis is suspect.
const MIN_LONGEST := 0.05


func _ready() -> void:
	var files: Array[String] = []
	var dir := DirAccess.open(FOLDER)
	if dir == null:
		print("[Verify] cannot open %s" % FOLDER)
		return
	for name in dir.get_files():
		if name.ends_with(".tscn"):
			files.append(name)
	files.sort()

	var ok := 0
	var bad := 0
	var no_mesh := 0
	var no_shape := 0
	var base_pivots := 0
	var other_pivots := 0

	for name in files:
		var path := "%s/%s" % [FOLDER, name]
		var packed: PackedScene = load(path) as PackedScene
		if packed == null:
			print("[Verify] FAIL %s - did not load" % name)
			bad += 1
			continue
		var root: Node = packed.instantiate()
		if root == null:
			print("[Verify] FAIL %s - did not instantiate" % name)
			bad += 1
			continue
		add_child(root)

		var mesh_node: MeshInstance3D = null
		var shape_node: CollisionShape3D = null
		for child in root.get_children():
			if child is MeshInstance3D and mesh_node == null:
				mesh_node = child as MeshInstance3D
			elif child is CollisionShape3D and shape_node == null:
				shape_node = child as CollisionShape3D

		var note := ""
		if mesh_node == null or mesh_node.mesh == null:
			no_mesh += 1
			note += " NO_MESH"
		if shape_node == null or shape_node.shape == null:
			no_shape += 1
			note += " NO_SHAPE"

		var extent := "?"
		var low_y := 0.0
		if mesh_node != null and mesh_node.mesh != null:
			var box: AABB = mesh_node.mesh.get_aabb()
			var longest: float = maxf(box.size.x, maxf(box.size.y, box.size.z))
			if longest < MIN_LONGEST:
				note += " TINY"
			if absf(box.position.y) <= 0.01:
				base_pivots += 1
			else:
				other_pivots += 1
			low_y = box.position.y
			extent = "%.2f x%.2f x%.2f" % [box.size.x, box.size.y, box.size.z]

		if note.is_empty():
			ok += 1
		else:
			bad += 1
		print("[Verify] %-24s %s  low_y=%6.2f  layer=%d%s" % [
			name, extent, low_y, root.collision_layer if root is CollisionObject3D else -1, note])
		root.queue_free()

	print("[Verify] folder=%s files=%d good=%d problems=%d | no_mesh=%d no_shape=%d | pivot base=%d other=%d" % [
		FOLDER, files.size(), ok, bad, no_mesh, no_shape, base_pivots, other_pivots])
