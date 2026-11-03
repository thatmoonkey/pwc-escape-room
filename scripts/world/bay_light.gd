class_name BayLight
extends OmniLight3D

## A bay's own room light, reporting the state of that bay's decision.
##
## Every room was lit exactly the same flood from the moment it was built to the
## moment the session ended, so a room the crew had finished was
## indistinguishable from one they had not. The light now reads as a room
## status lamp: amber while the decision still sits with SHIPMIND, green once
## the crew have set the console. The change tweens over about a second, so
## placing a decision visibly turns the room over to the crew.

const PENDING_COLOR := Color(1.0, 0.76, 0.12)  ## waiting on the console: amber
const PLACED_COLOR := Color(0.26, 1.0, 0.38)   ## console set: green
## A lift over whatever base the scene saved, so placed reads brighter at any
## palette tuning: a ratio, not an absolute, because the light-ship pass took
## the base from 2.2 to 1.25 and an absolute would have doubled the room.
const PLACED_ENERGY_SCALE := 1.4
const TWEEN_TIME := 0.9

@export var system_id: String = ""

var _base_energy := 2.2
var _tween: Tween = null


func _ready() -> void:
	add_to_group("bay_light")
	if system_id == "":
		push_warning("Bay light '%s' names no system, so it can never report a placed decision." % name)
	## Only the energy is taken from the scene: the two states are the lamp's
	## own colours, so a room can never be left on neither one nor the other.
	_base_energy = light_energy
	refresh_from_state()


## Re-applies saved progress. Scene children run _ready before the station
## controller has loaded the save, so a bay whose decision is already placed
## has to be told so once the save is actually in memory - the same shape as
## the bay doors and the windows.
func refresh_from_state() -> void:
	_apply(GameState.is_restored(system_id), false)


## The station controller calls this the moment a decision is placed, so the
## room turns over while the reflection card is still up.
func set_placed(value: bool, animate: bool = true) -> void:
	_apply(value, animate)


func _apply(value: bool, animate: bool) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	var target_color := PLACED_COLOR if value else PENDING_COLOR
	var target_energy := _base_energy * PLACED_ENERGY_SCALE if value else _base_energy
	if not animate:
		light_color = target_color
		light_energy = target_energy
		return
	_tween = create_tween().set_parallel()
	_tween.tween_property(self, "light_color", target_color, TWEEN_TIME)
	_tween.tween_property(self, "light_energy", target_energy, TWEEN_TIME)
