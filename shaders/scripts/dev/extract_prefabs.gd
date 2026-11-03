extends Node3D

## One-time prefab extractor for the three kits in res://assets/kit.
##
## WHY THIS EXISTS
## All three GLBs are Sketchfab DISPLAY ARRANGEMENTS: each lays its parts out in
## a showroom grid at its own offsets, so instancing a whole GLB in the level
## produces floating geometry rather than a room. The floor kit alone spans
## 6900 x 5300 units. Every usable part therefore has to be lifted out into its
## own prefab scene, re-originned so its pivot sits where a placement can use it,
## scaled by the factor its own units need, and given collision on layer 2.
##
## WHAT IT WRITES
## res://scenes/prefabs/<folder>/<Name>.tscn - real editor-authorable scenes: a
## StaticBody3D root, a Model child carrying the geometry, and a CollisionShape3D
## on layer 2. Nothing is built at load time. This runs ONCE. It stays in dev/ so
## the set can be re-extracted if a kit is swapped, but the game never calls it.
##
## It reads the kits and writes only into res://scenes/prefabs. It changes no
## existing scene, script or material.

const OUT_ROOT := "res://scenes/prefabs"
## Layer 2 is the layer the station's own collision already uses.
const COLLISION_LAYER := 2
## Below this many parts at one level, the walker descends looking for the level
## that actually carries the pieces.
const MIN_PARTS := 8
## A part thinner than this in any axis cannot carry a usable collision shape.
const MIN_EXTENT := 0.0005
## A single prefab above this size gets a printed note, because it means the mesh
## data was inlined into the scene file rather than referenced.
const BIG_FILE_KB := 512.0

## The kit root's inverse transform, set once per kit. A part must be measured
## and copied in the KIT'S OWN frame, not in its holder's: these holders carry
## large import scales (the floor kit's plates are ~800 units in the root frame
## and ~8 in their holder), so measuring in the holder frame silently divides the
## prefab by exactly that factor and it arrives 100x too small.
var _to_root := Transform3D.IDENTITY

## kit, output folder, scale, pivot and how its parts are taken.
##
## The scale factors are MEASURED, not guessed - see res://docs/interior-kits.md:
##   floor    units are centimetres: 800-1000 unit plates -> 8-10 m at x0.01
##   terminal parts run 7.45-29.23 units -> 0.75-2.9 m at x0.1
##   corridor the kit's own interior height is 0.44 units, so x7.7 lands its
##            ceiling on our 3.4 m deck height; the corridor is one joined
##            interior, so it is taken whole rather than part by part
##
## The pivot is where the prefab's origin sits on the part:
##   top  - the part's upper face. Right for a deck plate: a 0.64 m slab placed
##          at a deck's floor level then has its walking surface exactly there,
##          instead of 0.64 m above where it was placed.
##   base - the part's underside. Right for anything that stands on a floor.
const JOBS := [
	{
		"kit": "res://assets/kit/modular_sci-fi_floor.glb",
		"folder": "floor",
		"scale": 0.01,
		"pivot": "top",
		"naming": "prefix",
		"prefix": "DeckPlate",
		"single_name": "",
		"whole": false,
		"collision": "box",
	},
	{
		"kit": "res://assets/kit/sci-fi_modular_terminal_toolkit.glb",
		"folder": "terminal",
		"scale": 0.1,
		"pivot": "base",
		"naming": "original",
		"prefix": "",
		"single_name": "",
		"whole": false,
		"collision": "box",
	},
	{
		"kit": "res://assets/kit/spaceship_interior.glb",
		"folder": "corridor",
		"scale": 7.7,
		"pivot": "base",
		"naming": "prefix",
		"prefix": "Corridor",
		"single_name": "Corridor_Segment",
		"whole": true,
		"collision": "trimesh",
	},
]


func _ready() -> void:
	var saved := 0
	for job in JOBS:
		saved += _extract(job)
	print("[Extract] finished: %d prefab(s) written under %s" % [saved, OUT_ROOT])
	print("[Extract] Reopen the FileSystem dock to see them. These are the level's building blocks.")


func _extract(job: Dictionary) -> int:
	var kit := String(job["kit"])
	var packed := load(kit) as PackedScene
	if packed == null:
		print("[Extract] FAILED to load %s" % kit)
		return 0
	var root := packed.instantiate() as Node3D
	if root == null:
		print("[Extract] %s did not instantiate as a Node3D" % kit)
		return 0
	add_child(root)
	## Hidden: this measures and copies, it does not present. Drawing the showroom
	## grids would fill the viewport with geometry thousands of units wide.
	root.visible = false

	_to_root = root.global_transform.affine_inverse()
	var whole := bool(job["whole"])
	var factor := float(job["scale"])
	var parts: Array = [root] if whole else _part_level(root)
	var folder := "%s/%s" % [OUT_ROOT, String(job["folder"])]
	_make_dir(folder)
	print("[Extract] ===== %s | parts=%d scale=%.4f" % [kit.get_file(), parts.size(), factor])

	## Measure every part first, so they can be named in size order: the largest
	## piece of a kit is generally the most useful, and a stable number beats a
	## raw Cube_014 in a scene tree.
	var rows: Array = []
	for part in parts:
		var holder := part as Node3D
		if holder == null:
			continue
		var measured := _measure(holder)
		if measured.is_empty():
			continue
		var box: AABB = measured["box"]
		var longest: float = maxf(box.size.x, maxf(box.size.y, box.size.z)) * factor
		rows.append({
			"holder": holder,
			"box": box,
			"meshes": measured["meshes"],
			"longest": longest,
		})
	rows.sort_custom(_by_longest_desc)

	var index := 0
	var built := 0
	## Two parts can fold to the same node-safe name once FBXASC codes are
	## removed, and a silent overwrite would quietly cost us a prefab.
	var used: Dictionary = {}
	for row in rows:
		var name := ""
		if whole:
			name = String(job["single_name"])
		elif String(job["naming"]) == "prefix":
			index += 1
			name = "%s_%02d" % [String(job["prefix"]), index]
		else:
			name = _sanitize(String((row["holder"] as Node3D).name))
		name = _unique(name, used)
		if _build(row, job, folder, name):
			built += 1
	print("[Extract] %s: built %d of %d" % [kit.get_file(), built, rows.size()])
	root.queue_free()
	return built


## Turns one measured part into a prefab scene.
##
## The pivot is the whole point. A part arrives with its geometry wherever its
## author left it, so the Model child is offset by exactly the amount that puts
## the box's X/Z centre on the origin and one of its faces at y=0.
func _build(row: Dictionary, job: Dictionary, folder: String, name: String) -> bool:
	var holder: Node3D = row["holder"]
	var box: AABB = row["box"]
	var meshes: Array = row["meshes"]
	var factor := float(job["scale"])
	var pivot := String(job["pivot"])
	var size := box.size * factor

	if size.x < MIN_EXTENT or size.y < MIN_EXTENT or size.z < MIN_EXTENT:
		print("[Extract]   skip %s (degenerate %.4f x %.4f x %.4f)" % [name, size.x, size.y, size.z])
		return false

	var to_part := _to_root

	var body := StaticBody3D.new()
	body.name = name
	body.collision_layer = COLLISION_LAYER
	body.collision_mask = 0

	var lift := -factor * box.position.y
	if pivot == "top":
		lift -= factor * box.size.y

	var model := Node3D.new()
	model.name = "Model"
	model.scale = Vector3.ONE * factor
	model.position = Vector3(
		-factor * box.get_center().x,
		lift,
		-factor * box.get_center().z)
	body.add_child(model)

	var tris := 0
	var copies := 0
	for entry in meshes:
		var source := entry as MeshInstance3D
		if source == null or source.mesh == null:
			continue
		var copy := MeshInstance3D.new()
		copy.name = source.name
		copy.mesh = source.mesh
		copy.transform = to_part * source.global_transform
		copy.cast_shadow = source.cast_shadow
		model.add_child(copy)
		tris += source.mesh.get_faces().size() / 3
		copies += 1

	var shape := CollisionShape3D.new()
	shape.name = "Collision"
	if String(job["collision"]) == "trimesh":
		## A joined corridor cannot take a single box: the box would fill the
		## passage and seal the crew out of it. A concave shape built from the
		## geometry itself is exact, and is legal on a StaticBody3D.
		var faces := PackedVector3Array()
		var model_xform := Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * factor), model.position)
		for entry in meshes:
			var source := entry as MeshInstance3D
			if source == null or source.mesh == null:
				continue
			var to_prefab := model_xform * (to_part * source.global_transform)
			for vertex in source.mesh.get_faces():
				faces.append(to_prefab * vertex)
		var concave := ConcavePolygonShape3D.new()
		concave.set_faces(faces)
		shape.shape = concave
		shape.position = Vector3.ZERO
	else:
		var cube := BoxShape3D.new()
		cube.size = size
		shape.shape = cube
		## The box is centred on its own middle, while the pivot is on one face.
		var half := size.y * 0.5
		shape.position = Vector3(0.0, half if pivot == "base" else -half, 0.0)
	body.add_child(shape)

	## PackedScene.pack ignores any sub-node not OWNED by the packed root, so a
	## tree built with add_child() alone packs as a bare root with no children.
	_own(body, body)

	var scene := PackedScene.new()
	if scene.pack(body) != OK:
		body.free()
		print("[Extract]   pack failed for %s" % name)
		return false
	var path := "%s/%s.tscn" % [folder, name]
	var err := ResourceSaver.save(scene, path)
	body.free()
	if err != OK:
		print("[Extract]   save failed for %s (error %d)" % [path, err])
		return false

	var kb := _file_kb(path)
	print("[Extract]   %-26s %6.2f x%6.2f x%6.2f m  tris=%6d meshes=%2d  %5.0f KB" % [
		name, size.x, size.y, size.z, tris, copies, kb])
	if kb > BIG_FILE_KB:
		print("[Extract]   NOTE %s is %.0f KB: its mesh data is inlined in the scene file." % [name, kb])
	return true


## PackedScene.pack() silently drops every sub-node whose owner is not the packed
## root. Nodes made with .new() and add_child() have no owner at all, so without
## this the prefab saves as an empty shell - which is exactly what the first run
## produced: 127-byte files holding a StaticBody3D and nothing else.
func _own(node: Node, root: Node) -> void:
	for child in node.get_children():
		child.owner = root
		_own(child, root)


func _by_longest_desc(a: Dictionary, b: Dictionary) -> bool:
	return float(a["longest"]) > float(b["longest"])


## Two parts can fold to the same node-safe name. A silent overwrite would cost
## a prefab with no error anywhere, so the second one is numbered.
func _unique(name: String, used: Dictionary) -> String:
	if not used.has(name):
		used[name] = true
		return name
	var index := 2
	while used.has("%s_%d" % [name, index]):
		index += 1
	var out := "%s_%d" % [name, index]
	used[out] = true
	return out


## The part's own bounds and the meshes under it, measured in the KIT ROOT frame.
## The part's own transform is deliberately excluded, because where the showroom
## parked the piece is not part of a prefab - but the root frame is kept, because
## it carries the kit's authored scale.
func _measure(part: Node3D) -> Dictionary:
	var meshes: Array[MeshInstance3D] = []
	_collect(part, meshes)
	var to_part := _to_root
	var box := AABB()
	var first := true
	for mesh in meshes:
		if mesh.mesh == null:
			continue
		var here: AABB = to_part * (mesh.global_transform * mesh.get_aabb())
		box = here if first else box.merge(here)
		first = false
	if first:
		return {}
	return {"meshes": meshes, "box": box}


## The level of the tree that actually holds the models. A kit exported as one
## wrapper per model has them directly under the root; one exported as a single
## merged node has fewer, so this descends until it finds the level with pieces.
func _part_level(node: Node) -> Array:
	var level: Array = []
	for child in node.get_children():
		if child is Node3D:
			level.append(child)
	if level.size() >= MIN_PARTS:
		return level
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


## Sketchfab encodes reserved characters in node names as FBXASC###. Only the
## three codes these kits use are translated; anything else becomes a separator,
## because a wrong glyph in a node name is worse than a plain underscore.
func _decode_fbx(raw: String) -> String:
	var out := ""
	var index := 0
	while index < raw.length():
		if raw.substr(index, 6) == "FBXASC" and index + 9 <= raw.length():
			var digits := raw.substr(index + 6, 3)
			if digits.is_valid_int():
				if digits == "032":
					out += " "
				elif digits == "035":
					out += "#"
				else:
					out += "_"
				index += 9
				continue
		out += raw[index]
		index += 1
	return out


## A node-safe name. German part names survive intact ("Modulare Konsole 45"
## becomes Modulare_Konsole_45), which is worth keeping because it says what the
## piece is, unlike the floor kit's Cube_014.
func _sanitize(raw: String) -> String:
	var decoded := _decode_fbx(raw)
	var out := ""
	var last_separator := false
	for index in decoded.length():
		var glyph := decoded[index]
		var keep := (glyph >= "a" and glyph <= "z") \
			or (glyph >= "A" and glyph <= "Z") \
			or (glyph >= "0" and glyph <= "9")
		if keep:
			out += glyph
			last_separator = false
		elif not last_separator:
			out += "_"
			last_separator = true
	while out.begins_with("_"):
		out = out.substr(1)
	while out.ends_with("_"):
		out = out.substr(0, out.length() - 1)
	if out.is_empty():
		out = "Part"
	return out


func _make_dir(path: String) -> void:
	var dir := DirAccess.open("res://")
	if dir == null:
		print("[Extract] cannot open res:// to create %s" % path)
		return
	dir.make_dir_recursive(path.trim_prefix("res://"))


func _file_kb(path: String) -> float:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return 0.0
	var length := file.get_length()
	file.close()
	return float(length) / 1024.0
