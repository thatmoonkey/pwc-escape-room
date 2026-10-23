class_name PropCollider
extends StaticBody3D

## Curated-library props arrive as meshes with no physics. This gives every
## MeshInstance3D underneath it a static trimesh collider at load, so furniture
## and cargo are solid. Anything that should not be solid (flat floor decals,
## wall dressing) belongs under a plain Node3D instead.

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	for mesh in _collect_meshes(self):
		_add_collision(mesh)


func _collect_meshes(node: Node) -> Array[MeshInstance3D]:
	var found: Array[MeshInstance3D] = []
	for child in node.get_children():
		if child is MeshInstance3D:
			found.append(child)
		found.append_array(_collect_meshes(child))
	return found


func _add_collision(mesh: MeshInstance3D) -> void:
	var holder: Node = mesh.get_parent()
	if holder == null:
		return
	var before: int = holder.get_child_count()
	mesh.create_trimesh_collision()
	for index in range(before, holder.get_child_count()):
		var body := holder.get_child(index) as StaticBody3D
		if body != null:
			body.collision_layer = 2
			body.collision_mask = 1
