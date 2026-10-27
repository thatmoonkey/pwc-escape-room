class_name LockedDoor
extends Interactable

## A bay doorway. The prompt and the AI's line are both state-aware, because the
## corridor is where the player reads their own progress:
##
##   restored        -> the door is open, the system is yours
##   integrated      -> using it opens the bay so you can review the AI's work
##                      (this is how systems 2-5 let the crew in)
##   not integrated  -> the bay stays sealed, and SHIPMIND says plainly that the
##                      console does not exist in this build instead of silently
##                      refusing to open
##
## Opening is a two-leaf slide: the panel hides and two half-leaves part
## sideways into the jamb wall, the way a ship's door has always moved.

signal denied(system_id: String)
signal opened(system_id: String)

@export var system_id: String = ""

## How long the leaves take to part, and how long after the first one starts
## the second one follows. Staggered, so the door reads as two moving pieces
## rather than one shape scaling.
const SLIDE_TIME := 0.55
const SLIDE_STAGGER := 0.09

var _open: bool = false
var _panel: Node3D = null
var _shape: CollisionShape3D = null
var _leaves: Array[MeshInstance3D] = []


func _ready() -> void:
	super()
	_panel = get_node_or_null("Panel") as Node3D
	_shape = get_node_or_null("Shape") as CollisionShape3D
	_make_leaves()
	refresh_from_state()


## A system already under crew control starts with its bay standing open, so a
## restored ship looks restored. Called a second time from the station controller
## once the save file is in memory, because scene children run _ready before it
## has been loaded.
func refresh_from_state() -> void:
	if GameState.is_restored(system_id):
		_set_open(true, false)


func get_prompt() -> String:
	var label: String = GameState.display_name(system_id)
	if GameState.is_restored(system_id):
		return "%s bay - open" % label
	if not GameState.is_integrated(system_id):
		return "%s bay - sealed, console not commissioned" % label
	return "%s bay - sealed, review the console" % label


func can_interact(_by: Node) -> bool:
	return true


func interact(by: Node) -> void:
	super(by)
	flash()
	if GameState.is_integrated(system_id) and not _open:
		_set_open(true, true)
		opened.emit(system_id)
		return
	denied.emit(system_id)


func is_open() -> bool:
	return _open


## The leaf geometry. Every panel in the ship is a box, so the split is exact:
## cut the panel's mesh in half across its wide axis and rebuild it as two
## leaves that share the door's centre line. The jamb wall the doorway sits in
## is solid for the full width each leaf retracts, so a parked leaf is behind
## wall, never floating in a room. The original slab panel stays in the scene,
## retired - saved scenes and their materials keep working untouched.
func _make_leaves() -> void:
	if _panel == null or not _panel is MeshInstance3D:
		return
	var panel := _panel as MeshInstance3D
	var box := panel.mesh as BoxMesh
	if box == null:
		return
	var size := box.size
	for i in 2:
		var side: float = -1.0 if i == 0 else 1.0
		var leaf := MeshInstance3D.new()
		leaf.name = "Leaf_Port" if side < 0.0 else "Leaf_Star"
		var half := BoxMesh.new()
		half.size = size
		half.size[axis_of(size)] = size[axis_of(size)] * 0.5
		leaf.mesh = half
		leaf.material_override = panel.material_override
		leaf.position = _leaf_pos(size, side * size[axis_of(size)] * 0.25)
		add_child(leaf)
		_leaves.append(leaf)
	panel.visible = false


## The door's width axis: the box's thin side is its thickness, its widest
## horizontal side is the direction the leaves part along.
func axis_of(size: Vector3) -> int:
	return 0 if size.x >= size.z else 2


func _leaf_pos(size: Vector3, slide: float) -> Vector3:
	var at: Vector3 = _panel.position
	at[axis_of(size)] = at[axis_of(size)] + slide
	return at


func _set_open(value: bool, animate: bool) -> void:
	_open = value
	if _panel != null and is_instance_valid(_panel):
		_panel.visible = false
	if _shape != null and is_instance_valid(_shape):
		_shape.set_deferred("disabled", value)
	if _leaves.is_empty():
		return
	var size: Vector3 = (_panel as MeshInstance3D).mesh.size
	var slide_axis := axis_of(size)
	if not value:
		for i in _leaves.size():
			_leaves[i].visible = true
			_leaves[i].position = _leaf_pos(size, _side(i) * size[slide_axis] * 0.25)
		return
	# A leaf parked fully behind the frame's upright: half the panel's width to
	# clear the opening, plus a tuck so no leaf edge peeks at the jambs.
	var travel: float = size[slide_axis] * 0.5 + 0.1
	if not animate:
		for i in _leaves.size():
			_leaves[i].visible = false
			_leaves[i].position = _leaf_pos(size,
				_side(i) * (size[slide_axis] * 0.75 + 0.1))
		return
	# Only on a crew-triggered open: a door restored from the save file
	# should not slide open at boot.
	Sfx.play(Sfx.DOOR)
	for i in _leaves.size():
		var leaf := _leaves[i]
		leaf.visible = true
		leaf.position = _leaf_pos(size, _side(i) * size[slide_axis] * 0.25)
		var tween := create_tween()
		tween.tween_interval(SLIDE_STAGGER * float(i))
		tween.tween_property(leaf, "position",
			_leaf_pos(size, _side(i) * (size[slide_axis] * 0.75 + 0.1)),
			SLIDE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.tween_callback(func() -> void: leaf.visible = false)


func _side(index: int) -> float:
	return -1.0 if index == 0 else 1.0
