class_name CockpitDoor
extends LockedDoor

## The helm doorway at the aft end of the corridor.
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
