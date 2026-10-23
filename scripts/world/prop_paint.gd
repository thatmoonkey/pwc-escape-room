class_name PropPaint
extends Node3D

## Repaints every mesh under an imported prop with one of the ship's materials.
##
## The curated props arrive with the materials they shipped with, and this
## interior keeps to a palette: the crew chairs ship green, and no green belongs
## anywhere on this ship. The repaint deliberately does NOT live in the authored
## scene: a property override on a child of an INSTANCED prefab does not survive
## PackedScene.pack() - the child is either dropped or saved as a second local
## copy that leaves the prefab's own mesh underneath it. So it is applied at
## load, which is dressing rather than level geometry: the prop, its placement
## and its collision are all still real nodes in the scene file.
##
## Put it on a holder node with the prop instanced under it, and name the
## material to use.

## Which of the ship's materials the prop is repainted with.
@export var material_path: String = ""


func _ready() -> void:
	if material_path == "":
		return
	var material: Material = load(material_path) as Material
	if material == null:
		push_warning("PropPaint '%s': material did not load: %s" % [name, material_path])
		return
	for node in find_children("*", "MeshInstance3D", true, false):
		(node as MeshInstance3D).material_override = material
