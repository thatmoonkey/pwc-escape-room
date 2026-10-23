class_name ConsoleInteractable
extends Interactable

## A terminal the player can use: opens the Puzzle node it points at in the
## shared TerminalUI. Every bay console and kiosk in the game is one of these,
## so a new system needs no new interaction code.
##
## It also fits the console to the room. Imported GLB props have pivots and
## footprints that do not match a hand-authored box, which is why consoles drift
## above the floor, sit inside walls, or leave the highlight floating where the
## asset is not. So at load each console measures its own model and then:
##
##   1. drops the model so its base rests on the floor,
##   2. centres it on the console body,
##   3. resizes the interaction box and the highlight to the model's real size.
##
## Step 3 is what keeps the aim volume, the highlight and the visible asset in
## line with each other - for every console, including ones added later.

signal puzzle_opened(puzzle_id: String)

@export var puzzle_path: NodePath
@export var fit_to_model: bool = true
## A short prop is still given a box this tall, so it stays comfortable to aim at.
@export var min_aim_height: float = 0.9

var _puzzle: Puzzle = null


func _ready() -> void:
	super()
	_puzzle = get_node_or_null(puzzle_path) as Puzzle
	if _puzzle == null:
		push_warning("Console '%s' has no Puzzle wired at '%s'" % [name, puzzle_path])
	if fit_to_model:
		_fit_to_model()


func get_prompt() -> String:
	if _puzzle != null and GameState.is_restored(_puzzle.puzzle_id):
		return "%s - already under crew control" % prompt
	return prompt


func interact(by: Node) -> void:
	super(by)
	flash()
	if _puzzle == null:
		return
	var terminal := get_tree().get_first_node_in_group("terminal_ui") as TerminalUI
	if terminal == null:
		push_warning("No TerminalUI in the scene tree.")
		return
	if terminal.is_open():
		return
	Sfx.play(Sfx.COMPUTER)
	puzzle_opened.emit(_puzzle.puzzle_id)
	terminal.open(_puzzle)


## Measures the model under this console, then aligns the model, the collision
## box and the highlight to one another. Runs once, at load.
func _fit_to_model() -> void:
	var model: Node3D = get_node_or_null("Model") as Node3D
	if model == null:
		return
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(model, meshes)
	if meshes.is_empty():
		return

	# Merge every mesh of the model into one box, expressed in this body's space.
	var to_local: Transform3D = global_transform.affine_inverse()
	var bounds := AABB()
	var first: bool = true
	for mesh in meshes:
		if not is_instance_valid(mesh):
			continue
		var box: AABB = (to_local * mesh.global_transform) * mesh.get_aabb()
		if first:
			bounds = box
			first = false
		else:
			bounds = bounds.merge(box)
	if first:
		return

	# 1 and 2: base on the floor, centred on the console body.
	var center: Vector3 = bounds.get_center()
	model.position += Vector3(-center.x, -bounds.position.y, -center.z)

	# 3: the aim volume and the highlight match the model, with a floor on the
	# height so a low prop is still easy to aim at.
	var width: float = maxf(bounds.size.x, 0.4)
	var height: float = maxf(bounds.size.y, min_aim_height)
	var depth: float = maxf(bounds.size.z, 0.4)

	var shape_node: CollisionShape3D = get_node_or_null("Shape") as CollisionShape3D
	if shape_node != null and shape_node.shape is BoxShape3D:
		# Duplicated first: the box shape is a sub-resource shared by consoles.
		var box_shape: BoxShape3D = (shape_node.shape as BoxShape3D).duplicate()
		box_shape.size = Vector3(width, height, depth)
		shape_node.shape = box_shape
		shape_node.position = Vector3(0.0, height * 0.5, 0.0)

	var highlight: MeshInstance3D = get_node_or_null("Highlight") as MeshInstance3D
	if highlight != null:
		highlight.scale = Vector3(width, height, depth) * 1.06
		highlight.position = Vector3(0.0, height * 0.5, 0.0)


func _collect_meshes(node: Node, found: Array[MeshInstance3D]) -> void:
	for child in node.get_children():
		if child is MeshInstance3D:
			found.append(child)
		_collect_meshes(child, found)
