extends Node3D

## Splits sci-fi_interior_pack_lowpoly.glb into individual prefabs.
##
## WHY SPLITTING IS NEEDED
## This pack names its parts well - Walls_6, Doors, Doorways, FloorCeilings_9,
## Ceiling_Straight, SlidingDoor_Window, Crates - but each name is ONE merged
## mesh holding every variant side by side in a display row. Walls_6 is a single
## mesh of 128 triangles spanning 11.30 x 8.39 x 1.26 m, and Doors is a single
## mesh 8.04 m long. Instancing a "part" would drop six walls into a room at
## once, so each part is walked triangle by triangle, grouped into connected
## islands by welding shared vertices, and written out one prefab per island.
##
## The triangle counts make this practical: the whole pack is 2,559 triangles,
## so a single wall panel really is about twenty triangles.
##
## WHAT IT WRITES
## res://scenes/prefabs/interior/<Prefix>_NN.tscn - a StaticBody3D root, a Model
## child carrying the island's baked geometry, and a CollisionShape3D box on
## layer 2. Pivot is at the base centre, so a placement writes a floor position.
##
## DRY_RUN reports each island's size and writes nothing. The scale factor for
## this pack is not known until the islands are measured - the pack looks
## metre-scale, but Walls_6 spans 8.39 m of height while a single ceiling tile is
## 3.50 x 3.50, so the real wall height has to be read off the islands, not
## guessed. Set DRY_RUN to false once that number is known.
##
## Reads the pack and writes only into res://scenes/prefabs/interior.

const PACK := "res://assets/kit/sci-fi_interior_pack_lowpoly.glb"
const OUT_ROOT := "res://scenes/prefabs/interior"
## Layer 2 is the layer the station's own collision already uses.
const COLLISION_LAYER := 2
## Report island sizes without writing anything.
const DRY_RUN := false
## Applied to every island. Left at 1.0 because the dry run showed the pack is
## already authored in real metres: wall panels 3.50 x 4.06 x 0.30, floor tiles
## 3.50 x 3.50, door panels 3.87 tall, crates about 1.6 m. See docs/interior-kits.md
## for the deck-height question this raises against the 3.4 m project rule.
const SCALE := 1.0
## Positions closer than this are treated as the same vertex.
const WELD := 0.0005
## Islands below this many triangles are dropped as slivers.
const MIN_TRIS := 1
## Rows printed per part before the rest are summarised.
const MAX_ROWS := 40
## Minimum thickness for a collision box, in metres. Deck plates, ceiling panels
## and window panes arrive as zero-thickness quads, and a box with no height is
## not a surface anyone can stand on.
const MIN_COLLISION := 0.05

## Every island is drawn through this shader, so no kit texture can put cool blue
## or green onto an interior surface. See res://docs/art-direction.md.
const RECOLOUR_SHADER := "res://shaders/ember_recolour.gdshader"

## The warm ramp per part family: what a dark panel seam becomes (low) and what a
## lit plate face becomes (high), plus the surface response and how hot the kit's
## emission map burns. Doors and windows sit brighter than the walls, because the
## art direction requires every interactable to read at a glance. Floors and
## ceilings stay dark and warm so the maroon walls carry the room.
const TINTS := {
	"Wall": {
		"low": Color("#4F1010"), "high": Color("#AD2323"),
		"metallic": 0.12, "roughness": 0.72, "glow": 0.9,
	},
	"Doorway": {
		"low": Color("#4F1010"), "high": Color("#AD2323"),
		"metallic": 0.12, "roughness": 0.72, "glow": 0.9,
	},
	"Door": {
		"low": Color("#5A1408"), "high": Color("#D04026"),
		"metallic": 0.10, "roughness": 0.62, "glow": 1.0,
	},
	"SlidingWindow": {
		"low": Color("#6B2410"), "high": Color("#F0B839"),
		"metallic": 0.05, "roughness": 0.35, "glow": 2.2,
	},
	"Crate": {
		"low": Color("#2A1F16"), "high": Color("#8A6A3A"),
		"metallic": 0.30, "roughness": 0.80, "glow": 0.5,
	},
	"FloorTile": {
		"low": Color("#1E1712"), "high": Color("#3E3229"),
		"metallic": 0.18, "roughness": 0.78, "glow": 0.6,
	},
	"Ceiling": {
		"low": Color("#1E1712"), "high": Color("#3E3229"),
		"metallic": 0.18, "roughness": 0.78, "glow": 0.6,
	},
}
## Amber, used as the glow tint for every family.
const GLOW_TINT := Color("#F0B839")

## A readable prefix per part. The pack's own names describe the family, so they
## are kept rather than replaced with generic Wall_/Prop_ labels.
const PREFIX := {
	"Walls_6": "Wall",
	"Doors": "Door",
	"Doorways": "Doorway",
	"FloorCeilings_9": "FloorTile",
	"Ceiling_Straight": "Ceiling",
	"SlidingDoor_Window": "SlidingWindow",
	"Crates": "Crate",
}

var _parts_seen := 0
var _islands_total := 0
var _written := 0
var _shader: Shader = null
## One material per (family, source textures) pair, shared across islands, so a
## prefab carries a single material rather than a fresh copy per surface.
var _materials: Dictionary = {}


func _ready() -> void:
	var packed: PackedScene = load(PACK) as PackedScene
	if packed == null:
		print("[Pack] LOAD FAILED: %s - has it finished importing?" % PACK)
		return
	var root: Node = packed.instantiate()
	if root == null:
		print("[Pack] instantiate returned null for %s" % PACK)
		return
	add_child(root)
	var kit_root: Node3D = root as Node3D
	if kit_root == null:
		print("[Pack] root is not a Node3D")
		return
	## Hidden: this measures and copies, it does not present.
	kit_root.visible = false
	var to_kit: Transform3D = kit_root.global_transform.affine_inverse()

	print("[Pack] ===== %s | dry_run=%s scale=%.4f" % [
		PACK.get_file(), "yes" if DRY_RUN else "no", SCALE])
	var parts: Array = _part_level(kit_root)
	for node in parts:
		var holder: Node3D = node as Node3D
		if holder == null:
			continue
		_split_part(holder, to_kit)
	print("[Pack] parts=%d islands=%d written=%d" % [_parts_seen, _islands_total, _written])
	if DRY_RUN:
		print("[Pack] Dry run only. Read the real wall height off the rows above, then set SCALE and DRY_RUN to write.")


## Splits one named part and either reports its islands or writes them.
func _split_part(holder: Node3D, to_kit: Transform3D) -> void:
	var meshes: Array[MeshInstance3D] = []
	_collect(holder, meshes)
	if meshes.is_empty():
		return
	_parts_seen += 1
	var prefix := String(PREFIX.get(String(holder.name), _sanitize(String(holder.name))))
	var folder := "%s" % OUT_ROOT

	var islands: Array = []
	for entry in meshes:
		var source := entry as MeshInstance3D
		if source == null or source.mesh == null:
			continue
		islands.append_array(_islands_of(source, to_kit, prefix))
	islands.sort_custom(_by_longest_desc)
	## Number per part, not per run: one global counter would name a wall
	## "Wall_11" because three door parts happened to be written before it, and
	## the numbers would shift every time a part was reordered.
	for index in islands.size():
		(islands[index] as Dictionary)["rank"] = index + 1

	print("[Pack] ----- %s -> %s_NN | islands=%d" % [
		String(holder.name), prefix, islands.size()])
	var shown := 0
	for island in islands:
		var size: Vector3 = island["size"]
		var longest: float = maxf(size.x, maxf(size.y, size.z))
		if shown < MAX_ROWS:
			shown += 1
			print("[Pack]   %s_%02d  %6.2f x%6.2f x%6.2f m  tris=%d" % [
				prefix, int(island["rank"]), size.x, size.y, size.z, int(island["tris"])])
		elif shown == MAX_ROWS:
			shown += 1
			print("[Pack]   ... (+%d more, all smaller)" % (islands.size() - MAX_ROWS))
		_islands_total += 1
		if not DRY_RUN:
			if _write(island, folder, prefix):
				_written += 1


## Every connected island of one MeshInstance3D, measured in the kit frame.
##
## Two triangles belong to the same island when they share a vertex. Vertices are
## welded by position first, because an exported mesh often stores the same
## corner several times with different normals or UVs, and without welding every
## triangle would look like its own island.
func _islands_of(source: MeshInstance3D, to_kit: Transform3D, family: String) -> Array:
	var out: Array = []
	var local: Transform3D = to_kit * source.global_transform
	var mesh: Mesh = source.mesh
	for surface in mesh.get_surface_count():
		var arrays: Array = mesh.surface_get_arrays(surface)
		if arrays.is_empty():
			continue
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		if verts.is_empty():
			continue
		## A non-indexed surface has a null index array, so read it defensively
		## rather than assigning null into a typed PackedInt32Array.
		var indices := PackedInt32Array()
		if arrays[Mesh.ARRAY_INDEX] != null:
			indices = arrays[Mesh.ARRAY_INDEX]
		if indices.is_empty():
			## A non-indexed surface lists its corners in triangle order.
			indices.resize(verts.size())
			for index in verts.size():
				indices[index] = index
		var normals: PackedVector3Array = PackedVector3Array()
		if arrays[Mesh.ARRAY_NORMAL] != null:
			normals = arrays[Mesh.ARRAY_NORMAL]
		var uvs: PackedVector2Array = PackedVector2Array()
		if arrays[Mesh.ARRAY_TEX_UV] != null:
			uvs = arrays[Mesh.ARRAY_TEX_UV]
		var material: Material = mesh.surface_get_material(surface)

		## Weld by position, then union every triangle's corners.
		var parent: Array[int] = []
		parent.resize(verts.size())
		for index in verts.size():
			parent[index] = index
		var seen: Dictionary = {}
		for index in verts.size():
			var world: Vector3 = local * verts[index]
			var key := "%.4f_%.4f_%.4f" % [
				snappedf(world.x, WELD), snappedf(world.y, WELD), snappedf(world.z, WELD)]
			if seen.has(key):
				_union(parent, index, int(seen[key]))
			else:
				seen[key] = index
		var triangles := indices.size() / 3
		for triangle in triangles:
			var base := triangle * 3
			var a := indices[base]
			var b := indices[base + 1]
			var c := indices[base + 2]
			_union(parent, a, b)
			_union(parent, b, c)

		## Collect each island's triangles by its representative vertex.
		var groups: Dictionary = {}
		for triangle in triangles:
			var base := triangle * 3
			var root_index := _find(parent, indices[base])
			## A plain Array, not a PackedInt32Array: packed arrays have value
			## semantics in GDScript, so appending through a dictionary lookup
			## writes to a temporary copy and silently leaves the entry empty.
			if not groups.has(root_index):
				groups[root_index] = []
			(groups[root_index] as Array).append(triangle)

		for root_index in groups.keys():
			var built := _build_island(
				groups[root_index], indices, verts, normals, uvs, local, material, family)
			if not built.is_empty():
				out.append(built)
	return out


## One island as a standalone mesh: its own vertices, re-indexed, with the
## pivot moved to the base centre of its own bounding box.
func _build_island(triangles: Array, indices: PackedInt32Array,
		verts: PackedVector3Array, normals: PackedVector3Array,
		uvs: PackedVector2Array, local: Transform3D, material: Material,
		family: String) -> Dictionary:
	if triangles.size() < MIN_TRIS:
		return {}
	var has_normals := normals.size() == verts.size()
	var has_uvs := uvs.size() == verts.size()

	var box := AABB()
	var first := true
	var remap: Dictionary = {}
	var out_verts := PackedVector3Array()
	var out_normals := PackedVector3Array()
	var out_uvs := PackedVector2Array()
	var out_indices := PackedInt32Array()

	for triangle in triangles:
		for corner in 3:
			var src := indices[triangle * 3 + corner]
			if not remap.has(src):
				var world: Vector3 = local * verts[src]
				remap[src] = out_verts.size()
				out_verts.append(world)
				if has_normals:
					out_normals.append((local.basis * normals[src]).normalized())
				if has_uvs:
					out_uvs.append(uvs[src])
			out_indices.append(int(remap[src]))
	if out_verts.size() < 3:
		return {}
	for vertex in out_verts:
		box = AABB(vertex, Vector3.ZERO) if first else box.expand(vertex)
		first = false

	## Base-centre pivot: the offset that puts the box's X/Z centre on the origin
	## and its floor at y=0, baked into the vertices so the Model child can sit at
	## identity.
	var offset := Vector3(-box.get_center().x, -box.position.y, -box.get_center().z)
	for index in out_verts.size():
		out_verts[index] = (out_verts[index] + offset) * SCALE

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = out_verts
	arrays[Mesh.ARRAY_INDEX] = out_indices
	if has_normals:
		arrays[Mesh.ARRAY_NORMAL] = out_normals
	if has_uvs:
		arrays[Mesh.ARRAY_TEX_UV] = out_uvs
	var island_mesh := ArrayMesh.new()
	island_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	## The pack's own textures are cool teal and blue, which the interior palette
	## rule forbids. The surface is given the ember recolour material instead, so
	## the pack's panel seams and shading survive while its hue does not.
	island_mesh.surface_set_material(0, _ember_material(family, material))

	return {
		"mesh": island_mesh,
		"size": box.size * SCALE,
		"tris": triangles.size(),
		"rank": 0,
	}


## The material an island is drawn with: the pack's own albedo and emission maps
## routed through the ember recolour shader, so the panel seams and shading
## survive while the pack's cool hue does not.
##
## The source material is read only for WHICH textures it uses. A kit material
## that uses emission keeps its emissive map, because that is what makes a door
## panel or a window strip read at a glance.
func _ember_material(family: String, source: Material) -> ShaderMaterial:
	if _shader == null:
		_shader = load(RECOLOUR_SHADER) as Shader
	var tint: Dictionary = TINTS.get(family, TINTS["Wall"])
	var albedo: Texture2D = null
	var normal: Texture2D = null
	var emissive: Texture2D = null
	if source is StandardMaterial3D:
		var standard := source as StandardMaterial3D
		albedo = standard.albedo_texture
		if standard.normal_enabled:
			normal = standard.normal_texture
		if standard.emission_enabled:
			emissive = standard.emission_texture
	var key := "%s|%s|%s|%s" % [
		family,
		_path_of(albedo), _path_of(normal), _path_of(emissive)]
	if _materials.has(key):
		return _materials[key]
	var low: Color = tint["low"]
	var high: Color = tint["high"]
	var material := ShaderMaterial.new()
	material.shader = _shader
	material.set_shader_parameter("albedo_texture", albedo)
	material.set_shader_parameter("normal_texture", normal)
	material.set_shader_parameter("emission_texture", emissive)
	material.set_shader_parameter("tint_low", Vector3(low.r, low.g, low.b))
	material.set_shader_parameter("tint_high", Vector3(high.r, high.g, high.b))
	material.set_shader_parameter("glow_tint", Vector3(GLOW_TINT.r, GLOW_TINT.g, GLOW_TINT.b))
	material.set_shader_parameter("emission_energy", tint["glow"])
	material.set_shader_parameter("param_metallic", tint["metallic"])
	material.set_shader_parameter("param_roughness", tint["roughness"])
	_materials[key] = material
	return material


## A texture's identity for the material cache key. An absent texture needs a
## stable token, because two materials that both lack a normal map are the same
## material and should share one instance.
func _path_of(texture: Texture2D) -> String:
	return "none" if texture == null else texture.resource_path


## Writes one island as a prefab scene.
func _write(island: Dictionary, folder: String, prefix: String) -> bool:
	_make_dir(folder)
	var rank := int(island["rank"])
	var name := "%s_%02d" % [prefix, rank]
	var size: Vector3 = island["size"]

	var body := StaticBody3D.new()
	body.name = name
	body.collision_layer = COLLISION_LAYER
	body.collision_mask = 0

	var model := MeshInstance3D.new()
	model.name = "Model"
	model.mesh = island["mesh"]
	body.add_child(model)
	model.owner = body

	var shape := CollisionShape3D.new()
	shape.name = "Collision"
	## This pack's deck plates, ceiling panels and window panes are zero-thickness
	## quads, and a box with no height is not a surface anyone can stand on. Every
	## shape therefore gets a minimum thickness, and the box is aligned on its TOP
	## face rather than its centre: a floor tile must keep its walking surface
	## exactly where its geometry is, not float half a box above it.
	var columns := Vector3(
		maxf(size.x, MIN_COLLISION), maxf(size.y, MIN_COLLISION), maxf(size.z, MIN_COLLISION))
	var cube := BoxShape3D.new()
	cube.size = columns
	shape.shape = cube
	shape.position = Vector3(0.0, size.y - columns.y * 0.5, 0.0)
	body.add_child(shape)
	shape.owner = body

	var scene := PackedScene.new()
	if scene.pack(body) != OK:
		body.free()
		print("[Pack]   pack failed for %s" % name)
		return false
	var path := "%s/%s.tscn" % [folder, name]
	var err := ResourceSaver.save(scene, path)
	body.free()
	if err != OK:
		print("[Pack]   save failed for %s (error %d)" % [path, err])
		return false
	return true


## Union-find with path halving. parent is mutated in place.
func _find(parent: Array[int], index: int) -> int:
	var root := index
	while parent[root] != root:
		root = parent[root]
	while parent[index] != root:
		var next := parent[index]
		parent[index] = root
		index = next
	return root


func _union(parent: Array[int], a: int, b: int) -> void:
	var root_a := _find(parent, a)
	var root_b := _find(parent, b)
	if root_a != root_b:
		parent[root_b] = root_a


func _by_longest_desc(a: Dictionary, b: Dictionary) -> bool:
	var sa: Vector3 = a["size"]
	var sb: Vector3 = b["size"]
	return maxf(sa.x, maxf(sa.y, sa.z)) > maxf(sb.x, maxf(sb.y, sb.z))


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


func _sanitize(raw: String) -> String:
	var out := ""
	var last_separator := false
	for index in raw.length():
		var glyph := raw[index]
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
	return "Part" if out.is_empty() else out


func _make_dir(path: String) -> void:
	var dir := DirAccess.open("res://")
	if dir == null:
		print("[Pack] cannot open res:// to create %s" % path)
		return
	dir.make_dir_recursive(path.trim_prefix("res://"))
