class_name CockpitDoor
extends LockedDoor

## The helm doorway at the forward end of the corridor.
##
## It reuses LockedDoor's presentation - the panel hides, the collision disables,
## the door sound plays - but the gate is a different question. A bay door opens
## when its own system comes back. The cockpit opens when ALL five do, because a
## course cannot be flown on part of a ship.
##
## It deliberately does not call LockedDoor.interact(): that tests
## is_integrated(system_id) and would refuse, since "cockpit" is not one of the
## five ship systems. The base Interactable behaviour is reproduced here instead,
## and the denied/opened signals are still emitted, so the station controller's
## existing wiring narrates it without knowing this type exists.

const SYSTEM_ID := "cockpit"

## The bay doors' own panel material. The helm doorway used to be a solid slab of
## accent amber, which read as a lit wall rather than as a door; it is now the
## same grey metal panel as every other door in the ship.
const PANEL_MATERIAL := preload("res://materials/door_locked.tres")
## The glow the helm doorway keeps. It is no longer the door itself - it is the
## lit sill and lintel around it, so the bridge is still the lit end of the
## corridor without the door looking like a different species from the bays.
const GLOW_MATERIAL := preload("res://materials/accent_amber.tres")


func _ready() -> void:
	super()
	_dress_as_a_door()


## Re-skins the gate to match the bay doors and lights its opening.
##
## The leaves are built by LockedDoor before this runs and each copies the panel's
## material at that moment, so both the retired slab and the two leaves are
## re-assigned here rather than only the slab.
func _dress_as_a_door() -> void:
	var panel := get_node_or_null("Panel") as MeshInstance3D
	if panel == null:
		return
	panel.material_override = PANEL_MATERIAL
	for leaf in _leaves:
		leaf.material_override = PANEL_MATERIAL
	var box := panel.mesh as BoxMesh
	if box == null:
		return
	_glow_bar(Vector3(0.0, 0.06, 0.0), Vector3(box.size.x + 0.16, 0.1, box.size.z + 0.12))
	_glow_bar(Vector3(0.0, box.size.y - 0.06, 0.0),
		Vector3(box.size.x + 0.16, 0.1, box.size.z + 0.12))


## One emissive strip across the opening. They sit on the doorway, not on the
## leaves, so the light stays where the way through is as the panels part.
func _glow_bar(at: Vector3, size: Vector3) -> void:
	var bar := MeshInstance3D.new()
	bar.name = "GlowSill" if at.y < 0.5 else "GlowLintel"
	var mesh := BoxMesh.new()
	mesh.size = size
	bar.mesh = mesh
	bar.material_override = GLOW_MATERIAL
	bar.position = at
	bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(bar)


func get_prompt() -> String:
	if GameState.all_restored():
		return "Cockpit - unlocked. The helm is yours."
	return "Cockpit - sealed, %d of %d systems under crew control" % [
		GameState.restored_count(), GameState.SYSTEMS.size()]


func can_interact(_by: Node) -> bool:
	## Always true: the crew should be able to aim at the door and be told what
	## is missing, rather than find a door that silently does nothing.
	return true


func interact(by: Node) -> void:
	interacted.emit(by)
	if one_shot:
		active = false
	flash()
	if GameState.all_restored() and not _open:
		_set_open(true, true)
		opened.emit(SYSTEM_ID)
		return
	denied.emit(SYSTEM_ID)


## A ship whose five systems are all back has its cockpit standing open, so a
## restored save reloads with the helm reachable.
func refresh_from_state() -> void:
	if GameState.all_restored():
		_set_open(true, false)
