extends Node3D

## Dev tool: writes res://openxr_action_map.tres, the action map the project
## settings point at (xr/openxr/default_action_map).
##
## WHY IT EXISTS: the setting names that file but the file was never in the
## project, and Godot's OpenXR interface loads it during initialize() and
## returns false if it cannot. So OpenXR could never start, game.gd fell back to
## the desktop player on every launch, and the XR rig was unreachable - the rig
## and its wiring were both already correct.
##
## WHY IT IS GENERATED AND NOT HAND-WRITTEN: the action NAMES are the engine's
## own contract. XRController3D.get_vector2("primary") and button_pressed(
## "trigger") only resolve against the actions the engine's own default set
## registers, so the map is asked for from the engine rather than transcribed
## from a demo project's file, which may drift.
##
## Run once through scenes/dev/make_openxr_action_map.tscn. The game never
## calls it.

const OUT_PATH := "res://openxr_action_map.tres"


func _ready() -> void:
	var map := OpenXRActionMap.new()
	map.create_default_action_sets()

	var err: int = ResourceSaver.save(map, OUT_PATH)
	if err != OK:
		printerr("[OpenXRActionMap] save FAILED err=%d" % err)
		get_tree().quit(1)
		return

	var set_count: int = map.get_action_set_count()
	var profile_count: int = map.get_interaction_profile_count()
	var set_names: Array[String] = []
	for i in set_count:
		var action_set: OpenXRActionSet = map.get_action_set(i)
		if action_set != null:
			set_names.append(String(action_set.resource_name))
	print("[OpenXRActionMap] wrote %s | sets=%d %s | profiles=%d" % [
		OUT_PATH, set_count, str(set_names), profile_count])
	get_tree().quit()
