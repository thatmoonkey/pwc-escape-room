class_name WindowWall
extends Node3D

## One bay's back wall, reworked as a full-height window onto space.
##
## The ship's back walls arrive as solid panels. This hides its panel (the
## shutter) and puts a glass pane in the opening, so the bay looks out at the
## world Exterior builds. Collision is left exactly where it was, so a crew
## member can never walk out of an open window - and SHIPMIND can bring a shutter
## back down, which is the first failure consequence in the game the player can
## see.
##
## The pane and its sill light are built in code so all five bays get an
## identical fit to the opening rather than five hand-tuned copies in the scene
## file.

signal shutter_changed(system_id: String, is_open: bool)

const GLASS_MATERIAL := "res://materials/window_glass.tres"
## The size the pane is built at, and what the sill strip is laid under. Set by
## the level rather than fixed here, because openings differ: the old corridor's
## bay backs were 7.0 m wide, while a window in an authored room clears exactly
## one 3.50 m wall module.
##
## The node's own frame is what the pane is built in: X along the wall's normal,
## Z along the wall. A wall whose face points along X therefore needs no rotation
## at all, and one whose face points along Z needs a quarter turn. See
## deck_builder._window.
@export var opening: Vector3 = Vector3(0.05, 3.4, 7.0)

@export var system_id: String = ""
## The solid panel this window replaces, hidden while the window is open.
## Resolved from this node, so a sibling in Shell needs "../Shell/<mesh>".
@export var shutter_path: NodePath
## Engineering's back wall is the bulkhead door: closing it reads as the door
## coming down rather than as a blank panel.
@export var is_door: bool = false
## Navigation and life support start open, so the change is visible the moment
## the game loads. The rest are brought up by SHIPMIND as the crew takes the
## systems back.
@export var starts_open: bool = false

var _shutter: Node3D = null
var _is_open: bool = false


func _ready() -> void:
	add_to_group("window_wall")
	_shutter = get_node_or_null(shutter_path) as Node3D
	if _shutter == null:
		push_warning("WindowWall '%s' has no shutter at '%s'; the opening reads as a hole." % [name, shutter_path])
	_build_pane()
	_build_sill_light()
	set_open(starts_open, false)


func is_open_() -> bool:
	return _is_open


## Re-applies saved progress. Scene children run _ready before the station
## controller loads the save, so a window belonging to a system the crew already
## holds has to be told so once the save is actually in memory.
func refresh_from_state() -> void:
	if GameState.is_restored(system_id):
		set_open(true, false)


func set_open(value: bool, announce: bool = true) -> void:
	if _is_open == value:
		return
	_is_open = value
	if _shutter != null and is_instance_valid(_shutter):
		_shutter.visible = not value
	if announce:
		shutter_changed.emit(system_id, value)


## Which way is out: the bays on the -X side of the corridor look out along -X.
func outward() -> float:
	return -1.0 if global_position.x < 0.0 else 1.0


func _build_pane() -> void:
	## Built once, and packed with the scene: the FIRST time this node enters a
	## tree is during authoring, so the pane the level ships with is the one built
	## then. A later load must leave it alone, or every window would carry two
	## panes exactly on top of each other, which z-fights.
	if get_node_or_null("Glass") != null:
		return
	var pane_mesh := BoxMesh.new()
	pane_mesh.size = opening
	var pane := MeshInstance3D.new()
	pane.name = "Glass"
	pane.mesh = pane_mesh
	var material: Material = load(GLASS_MATERIAL) as Material
	if material != null:
		pane.material_override = material
	add_child(pane)


## A thin amber strip along the sill, so a window still reads as an opening when
## the exterior is dark or the sun is on the far side of the planet.
func _build_sill_light() -> void:
	## Built once, for the same reason as the pane above.
	if get_node_or_null("SillLight") != null:
		return
	var strip_mesh := BoxMesh.new()
	strip_mesh.size = Vector3(0.12, 0.05, opening.z - 0.3)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.863, 0.369, 0.153)
	material.emission_enabled = true
	material.emission = Color(0.863, 0.369, 0.153)
	material.emission_energy_multiplier = 2.0
	var strip := MeshInstance3D.new()
	strip.name = "SillLight"
	strip.mesh = strip_mesh
	strip.material_override = material
	strip.position = Vector3(0.0, -opening.y * 0.5 + 0.06, 0.0)
	add_child(strip)
