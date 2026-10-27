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
## Opening is purely presentation: the panel hides and its collision disables.

signal denied(system_id: String)
signal opened(system_id: String)

@export var system_id: String = ""

var _open: bool = false
var _panel: Node3D = null
var _shape: CollisionShape3D = null


func _ready() -> void:
	super()
	_panel = get_node_or_null("Panel") as Node3D
	_shape = get_node_or_null("Shape") as CollisionShape3D
	refresh_from_state()


## A system already under crew control starts with its bay standing open, so a
## restored ship looks restored. Called a second time from the station controller
## once the save file is in memory, because scene children run _ready before it
## has been loaded.
func refresh_from_state() -> void:
	if GameState.is_restored(system_id):
		_set_open(true, false)


## Every prompt carries the bay number the doorway plates show, so the number
## a crew member reads on the wall is the same number the kiosk and the PA
## use for that bay.
func get_prompt() -> String:
	var label: String = GameState.display_name(system_id)
	if GameState.is_restored(system_id):
		return "Bay %d, %s - open" % [GameState.system_index(system_id), label]
	if not GameState.is_integrated(system_id):
		return "Bay %d, %s - sealed, console not commissioned" % [
			GameState.system_index(system_id), label]
	return "Bay %d, %s - sealed, review the console" % [
		GameState.system_index(system_id), label]


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


func _set_open(value: bool, animate: bool) -> void:
	_open = value
	if _panel != null and is_instance_valid(_panel):
		_panel.visible = not value
	if _shape != null and is_instance_valid(_shape):
		_shape.set_deferred("disabled", value)
	if value and animate:
		# Only on a crew-triggered open: a door restored from the save file
		# should not bang open at boot.
		Sfx.play(Sfx.DOOR)
		var tween := create_tween()
		tween.tween_property(self, "scale:x", 0.6, 0.25)
		tween.tween_callback(func() -> void: scale.x = 1.0)
