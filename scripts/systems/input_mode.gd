class_name InputMode
extends RefCounted

## Which control scheme the crew is playing with: DESKTOP (WASD + captured
## mouse), TOUCH (floating joysticks, minimal HUD) or VR (OpenXR rig).
##
## Static like the rest of the systems layer, so any script can read the mode
## without autoload wiring. Detection runs once, from the hardware: a headset
## that is actually initialized beats a touchscreen, which beats the desktop.
##
## THE OVERRIDE EXISTS FOR TESTING. A chip on the launch screen and a row in the
## dev menu can force any mode on any machine - most usefully TOUCH on a desktop
## - and the station controller consumes the change and re-wires the rig, the
## input layers and the HUD. The override lives only for the session: a fresh
## launch detects the hardware again rather than remembering yesterday's test.
##
## Mode changes do not broadcast a signal - the project keeps its systems static
## and dependency-free, so the station controller polls consume_dirty() once per
## frame and everything else reads `mode` directly. One poller, no wiring.

enum Mode { DESKTOP, TOUCH, VR }

static var mode: int = Mode.DESKTOP
static var _detected: bool = false
static var _dirty: bool = false


## The mode the hardware itself implies. Called once, lazily, so a headless or
## tool run never initializes an XR interface just by importing the script.
static func ensure_detected() -> void:
	if _detected:
		return
	_detected = true
	mode = _detect()


static func _detect() -> int:
	if bool(ProjectSettings.get_setting("xr/openxr/enabled", false)):
		var interface: XRInterface = XRServer.find_interface("OpenXR")
		if interface != null and interface.is_initialized():
			return Mode.VR
	if DisplayServer.is_touchscreen_available():
		return Mode.TOUCH
	return Mode.DESKTOP


## Force a mode. Returns false when the mode is VR and no OpenXR runtime is
## reachable - the caller decides what to tell the player and stays where it
## was, because silently eating the request would leave the chips pointing at a
## mode the ship is not in.
static func set_mode(value: int) -> bool:
	ensure_detected()
	if value == mode:
		return true
	if value == Mode.VR:
		var interface: XRInterface = XRServer.find_interface("OpenXR")
		if interface == null or not interface.is_initialized():
			if interface == null or not interface.initialize():
				return false
	mode = value
	_dirty = true
	return true


## True once, after a mode change. The station controller polls this per frame;
## nothing else needs to.
static func consume_dirty() -> bool:
	if not _dirty:
		return false
	_dirty = false
	return true


static func is_touch() -> bool:
	ensure_detected()
	return mode == Mode.TOUCH


static func is_vr() -> bool:
	ensure_detected()
	return mode == Mode.VR


static func label(value: int) -> String:
	match value:
		Mode.DESKTOP:
			return "DESKTOP"
		Mode.TOUCH:
			return "MOBILE"
		Mode.VR:
			return "VR"
	return "?"


static func icon(value: int) -> String:
	match value:
		Mode.DESKTOP:
			return "keyboard"
		Mode.TOUCH:
			return "phone"
		Mode.VR:
			return "headset"
	return "question"
