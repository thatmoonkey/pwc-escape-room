class_name Platform
extends RefCounted

## WHICH BUILD IS RUNNING, IN ONE PLACE.
##
## The game ships to three places: a PWA in a browser, an Android APK, and a
## headset. They share one scene tree and one 2D layer, so the differences
## between them have to live somewhere small and readable rather than as
## `OS.has_feature` calls scattered through the screens.
##
## What actually differs, and therefore what this file answers:
##
##   - the pointer. A phone has a thumb, a desktop has a cursor, a headset has a
##     ray and no cursor at all.
##   - the keyboard. A headset has none, a phone has a virtual one that a browser
##     or Android only raises for a focused field, and the web export needs the
##     experimental virtual keyboard switched on (it is, in the export preset).
##   - the size of a touch target. A thumb needs a bigger control than a cursor.
##   - the way out. Android's back gesture must not quit the game out of a menu.
##
## Nothing here caches hardware state beyond one detection, and nothing here
## changes the input mode: InputMode owns DESKTOP/TOUCH/VR and the launch
## screen's chips can override it. This file reports the BUILD, which the mode
## layer cannot change by design.

enum Kind { DESKTOP, WEB, ANDROID, VR }

static var _kind: int = -1


static func kind() -> int:
	if _kind < 0:
		_kind = _detect()
	return _kind


static func _detect() -> int:
	if InputMode.is_vr():
		return Kind.VR
	if OS.has_feature("web"):
		return Kind.WEB
	if OS.has_feature("android") or OS.has_feature("ios"):
		return Kind.ANDROID
	return Kind.DESKTOP


static func label() -> String:
	match kind():
		Kind.VR:
			return "VR"
		Kind.WEB:
			return "WEB"
		Kind.ANDROID:
			return "ANDROID"
	return "DESKTOP"


static func is_web() -> bool:
	return kind() == Kind.WEB


static func is_android() -> bool:
	return kind() == Kind.ANDROID


static func is_vr() -> bool:
	return kind() == Kind.VR


## True when the only pointer is a finger - a phone in a browser, an Android
## phone or tablet. A laptop with a touchscreen keeps its cursor, which is why
## the input MODE is consulted as well as the hardware.
static func touch_ui() -> bool:
	return InputMode.is_touch()


## Type sizes for a screen that will be read at arm's length. One multiplier,
## applied by every overlay, so no screen has its own private idea of "big".
static func ui_scale() -> float:
	if kind() == Kind.VR:
		return 1.4
	if touch_ui():
		## The phone tier used to add a fifth to every overlay on top of base
		## sizes already drawn for a tablet: boxes and modals came out too big.
		return 1.0
	return 1.0


## A control a thumb can hit. The pointer targets on the 2D layer are floored at
## this height on a touch device and stay compact everywhere else.
static func touch_target(base: float) -> float:
	return maxf(base, 46.0) if touch_ui() else base


## Whether text can be typed at all. A headset has no keyboard, so a screen that
## asks for an email address has to offer a way past it there rather than
## trapping the player in a field they cannot fill.
static func can_type() -> bool:
	return kind() != Kind.VR
