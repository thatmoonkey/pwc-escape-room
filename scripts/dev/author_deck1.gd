extends DeckBuilder

## One-off authoring tool for the Deck 1 interior, built from the extracted
## sci-fi_interior_pack prefabs and SAVED as a real scene:
##
##   run scenes/dev/author_deck1.tscn once -> writes res://scenes/world/deck1.tscn
##
## The game never calls this. The shared machinery - how a prefab is instanced and
## owned, how a run of the pack's panels is laid on its 3.50 m module, the doorway,
## the wall that closes beside it, a console, a sealed door, a bay trigger and the
## receipt - lives in deck_builder.gd. This file is ONLY the layout: which tiles
## are floor, where the walls run, and which system sits in which room. A second
## deck is a second layout subclass beside this one (author_deck2.gd), never a
## second copy of that machinery.
##
## THE AFT END IS OPEN ON PURPOSE. See _build: the deck continues aft into the
## stairwell bay, which author_stairwell.gd owns and which closes the deck itself.

const OUT := "res://scenes/world/deck1.tscn"
const TAG := "Deck1"

const S_NAV := "res://scripts/puzzles/nav_puzzle.gd"
const S_LIFE := "res://scripts/puzzles/life_support_puzzle.gd"
const S_COMMS := "res://scripts/puzzles/comms_puzzle.gd"
const S_HUB := "res://scripts/puzzles/hub_terminal.gd"

## The plan, all of it on the pack's 3.50 m module. X is athwartships, Z is
## fore-and-aft (forward is +Z), Y is up with the deck floor at 0.
const SPINE_X := 1.75        ## spine half width, so the spine is one tile wide
const SPINE_AFT := -28.0     ## the aft end of the deck as authored here
const SPINE_FWD := 17.5      ## 3 tiles forward of the junction
const JUNC_X := 5.25         ## junction half width
const JUNC_AFT := 0.0
const JUNC_FWD := 7.0
const ROOM_IN := 1.75        ## room inner face, i.e. the spine wall
const ROOM_OUT := 8.75       ## room outer wall, two tiles out
const ROOM_AFT := 7.0
const ROOM_FWD := 14.0
const LIFE_AFT := -7.0

## Each door sits on a panel boundary of its wall run, which is what makes the two
## flanks the frame does not cover come out equal (see _flank_doorway).
const NAV_DOOR_Z := 10.5
const COMMS_DOOR_Z := 10.5
const LIFE_DOOR_Z := -3.5

## One window per room, in the room's own OUTER wall and directly across from its
## door. Each sits on a panel boundary like the doors, so the wall drops exactly
## the one 3.50 m module the opening needs. See deck_builder._window.
const WIN_NAV_Z := 12.25
const WIN_COMMS_Z := 12.25
const WIN_LIFE_Z := -1.75

const NAV_PROMPT := "Navigation console: plot a course"
const LIFE_PROMPT := "Life support console: verify the environmental board"
const COMMS_PROMPT := "Comms console: review the incoming queue"
## The kiosks are two terminals wired to the same read-only kiosk, so the
## prompt is what tells them apart: it names the terminal's own junction.
const KIOSK_PROMPT := "SHIPMIND kiosk, deck 1 junction: mission status and debrief"


func _ready() -> void:
	_begin("Deck1", OUT, TAG)
	_build()
	_finish(_span_under(["SpineWalls", "Bulkheads"]))


func _build() -> void:
	var shell := _node("Shell", _root)
	var floors := _node("SpineFloor", shell)
	var ceilings := _node("SpineCeiling", shell)
	var walls := _node("SpineWalls", shell)
	var bulkheads := _node("Bulkheads", shell)
	var rooms := _node("Rooms", _root)
	var lights := _node("Lights", _root)
	var interactables := _node("Interactables", _root)
	var triggers := _node("Triggers", _root)
	var windows := _node("Windows", _root)

	for group in ["Navigation", "Comms", "LifeSupport", "Junction"]:
		_node(group, rooms)

	## Floors and ceilings. One tile column is the whole spine, and each room is
	## a whole number of tiles in both directions.
	_deck_slab(floors, ceilings, -SPINE_X, SPINE_X, SPINE_AFT, SPINE_FWD, "spine")
	_deck_slab(floors, ceilings, -JUNC_X, JUNC_X, JUNC_AFT, JUNC_FWD, "junction")
	_deck_slab(floors, ceilings, ROOM_IN, ROOM_OUT, ROOM_AFT, ROOM_FWD, "nav")
	_deck_slab(floors, ceilings, -ROOM_OUT, -ROOM_IN, ROOM_AFT, ROOM_FWD, "comms")
	_deck_slab(floors, ceilings, -ROOM_OUT, -ROOM_IN, LIFE_AFT, JUNC_AFT, "life")

	## The spine's two side walls. The junction is an opening in both of them,
	## because the deck widens there; each doorway is an opening too, and the
	## frame fills it.
	var junction_open := [[JUNC_AFT, JUNC_FWD]]
	var starboard_open := [junction_open[0], _opening(NAV_DOOR_Z)]
	var port_open := [junction_open[0], _opening(COMMS_DOOR_Z), _opening(LIFE_DOOR_Z)]
	_wall_run_z(walls, SPINE_X, 0.0, SPINE_AFT, SPINE_FWD, starboard_open, "PX")
	_wall_run_z(walls, -SPINE_X, 0.0, SPINE_AFT, SPINE_FWD, port_open, "NX")

	## Junction cross walls, at the fore and aft ends of the widening. The gap in
	## the middle of each is where the spine runs on.
	_wall_run_x(walls, JUNC_FWD, 0.0, -JUNC_X, -SPINE_X, [], "JNXF")
	_wall_run_x(walls, JUNC_FWD, 0.0, SPINE_X, JUNC_X, [], "JPXF")
	_wall_run_x(walls, JUNC_AFT, 0.0, -JUNC_X, -SPINE_X, [], "JNXA")
	_wall_run_x(walls, JUNC_AFT, 0.0, SPINE_X, JUNC_X, [], "JPXA")
	_wall_run_z(walls, JUNC_X, 0.0, JUNC_AFT, JUNC_FWD, [], "JEX")
	_wall_run_z(walls, -JUNC_X, 0.0, JUNC_AFT, JUNC_FWD, [], "JWX")

	## Navigation, starboard forward. Each room's outer wall drops one module for
	## its window, and its other three walls are solid.
	_wall_run_x(walls, ROOM_AFT, 0.0, JUNC_X, ROOM_OUT, [], "NAVA")
	_wall_run_x(walls, ROOM_FWD, 0.0, ROOM_IN, ROOM_OUT, [], "NAVF")
	_wall_run_z(walls, ROOM_OUT, 0.0, ROOM_AFT, ROOM_FWD, [_win_open(ROOM_AFT, WIN_NAV_Z)], "NAVO")

	## Comms, port forward.
	_wall_run_x(walls, ROOM_AFT, 0.0, -ROOM_OUT, -JUNC_X, [], "COMA")
	_wall_run_x(walls, ROOM_FWD, 0.0, -ROOM_OUT, -ROOM_IN, [], "COMF")
	_wall_run_z(walls, -ROOM_OUT, 0.0, ROOM_AFT, ROOM_FWD, [_win_open(ROOM_AFT, WIN_COMMS_Z)], "COMO")

	## Life support, port amidships.
	_wall_run_x(walls, JUNC_AFT, 0.0, -ROOM_OUT, -JUNC_X, [], "LIFA")
	_wall_run_x(walls, LIFE_AFT, 0.0, -ROOM_OUT, -ROOM_IN, [], "LIFB")
	_wall_run_z(walls, -ROOM_OUT, 0.0, LIFE_AFT, JUNC_AFT, [_win_open(LIFE_AFT, WIN_LIFE_Z)], "LIFO")

	## BOTH ENDS OF THE SPINE ARE OPEN. Aft, the deck runs on into the stairwell
	## bay, which author_stairwell.gd builds and closes at Z -38.5; a bulkhead at
	## the old aft end (Z -28) would wall the stairwell off from the deck it
	## serves, and the deck could never be left.
	##
	## Forward, the spine now opens into the bridge approach. A wall across it
	## would wall the bridge off the same way, so the deck no longer builds one:
	## station.tscn closes the two sides of that opening and hangs the cockpit
	## gate in the middle of it. The `Bulkheads` group is kept as the place a
	## future deck's end wall would go.

	## Each doorway carries its bay plate on the approach side: navigation and
	## comms are walked to from the junction, which is aft of them, while life
	## support hangs off the junction's own aft wall, so its approach is from
	## forward. Navigation's plate is the only one its bay will ever have - it
	## was left open, with no door at all.
	_doorway(walls, SPINE_X, NAV_DOOR_Z, "Doorway_Nav", "navigation", -1.0)
	_doorway(walls, -SPINE_X, COMMS_DOOR_Z, "Doorway_Comms", "comms", -1.0)
	_doorway(walls, -SPINE_X, LIFE_DOOR_Z, "Doorway_Life", "life_support", 1.0)

	## The wall either side of each doorway, which the 4.089 m frame does not
	## reach across the 7.0 m the panels leave. Without this every bay has a
	## 1.4555 m floor-to-ceiling hole beside its door, and a bay the crew can walk
	## around the door into is not sealed at all.
	_flank_doorway(walls, "NavFlank", SPINE_X, NAV_DOOR_Z, SPINE_AFT, SPINE_FWD)
	_flank_doorway(walls, "CommsFlank", -SPINE_X, COMMS_DOOR_Z, SPINE_AFT, SPINE_FWD)
	_flank_doorway(walls, "LifeFlank", -SPINE_X, LIFE_DOOR_Z, SPINE_AFT, SPINE_FWD)

	## The three windows. Every one starts open, so the crew can see they are on a
	## ship from the moment they walk into a room; the shutter stays available and
	## is what SHIPMIND can drop over a bay. All three outer walls face along X, so
	## all three are axis 0.
	_window(windows, "Window_Navigation", 0, ROOM_OUT, WIN_NAV_Z,
		"navigation", false, true, M_PANEL)
	_window(windows, "Window_Comms", 0, -ROOM_OUT, WIN_COMMS_Z,
		"comms", false, true, M_PANEL)
	_window(windows, "Window_LifeSupport", 0, -ROOM_OUT, WIN_LIFE_Z,
		"life_support", false, true, M_PANEL)

	_light(lights, "Spine_A", Vector3(0.0, H - 0.45, 10.5))
	_light(lights, "Spine_B", Vector3(0.0, H - 0.45, -3.5))
	_light(lights, "Spine_C", Vector3(0.0, H - 0.45, -17.5))
	_light(lights, "Junction", Vector3(0.0, H - 0.45, JUNC_FWD * 0.5))
	_light(lights, "NavRoom", Vector3(5.25, H - 0.45, 10.5), "navigation")
	_light(lights, "CommsRoom", Vector3(-5.25, H - 0.45, 10.5), "comms")
	_light(lights, "LifeRoom", Vector3(-5.25, H - 0.45, LIFE_DOOR_Z), "life_support")

	## The SHIPMIND kiosk stands in the junction, off the spine so the crew walk
	## past it, and the navigation console sits in the navigation room.
	var kiosk := _console(interactables, "ShipmindKiosk", Vector3(-3.5, 0.0, 3.5), P_KIOSK,
		_console_yaw(KIOSK_YAW), "Hub", KIOSK_PROMPT, Vector3(1.7, 1.7, 1.25))
	_puzzle(kiosk, "Hub", S_HUB, {"system_title": "SHIPMIND KIOSK"})
	var nav := _console(interactables, "NavConsole", Vector3(5.25, 0.0, 11.5), P_DESK,
		_console_yaw(STARBOARD_ROOM_YAW), "Nav", NAV_PROMPT, Vector3(1.7, 1.7, 1.25))
	_puzzle(nav, "Nav", S_NAV, {
		"puzzle_id": "navigation",
		"system_title": "NAVIGATION / PRIMARY CONSOLE",
		"principle_index": 1,
	})

	## Both remaining Deck 1 consoles sit on the port side, so they take the port
	## yaw: the model turned to face into the room, not into the wall.
	var life := _console(interactables, "LifeSupportConsole", Vector3(-5.25, 0.0, -4.5), P_DESK,
		_console_yaw(PORT_ROOM_YAW), "Life", LIFE_PROMPT, Vector3(1.7, 1.7, 1.25))
	_puzzle(life, "Life", S_LIFE, {
		"puzzle_id": "life_support",
		"system_title": "LIFE SUPPORT / ENVIRONMENTAL BOARD",
		"principle_index": 2,
	})
	var comms := _console(interactables, "CommsConsole", Vector3(-5.25, 0.0, 11.5), P_DESK,
		_console_yaw(PORT_ROOM_YAW), "Comms", COMMS_PROMPT, Vector3(1.7, 1.7, 1.25))
	_puzzle(comms, "Comms", S_COMMS, {
		"puzzle_id": "comms",
		"system_title": "COMMS / INCOMING QUEUE",
		"principle_index": 3,
	})

	## Comms and life support start SEALED, and their doors are the beat: SHIPMIND
	## opens a bay only once the crew has taken that system back. Navigation is the
	## single bay it deliberately left open - the doorway, and no door.
	_door(interactables, "SealedDoor_LifeSupport", -SPINE_X, LIFE_DOOR_Z, "life_support")
	_door(interactables, "SealedDoor_Comms", -SPINE_X, COMMS_DOOR_Z, "comms")

	## Each console fits itself to its model in its own _ready, and that fit
	## resizes the aim highlight by SCALING it. That scale is runtime dressing, not
	## part of the level, and a non-uniform scale saved into a scene is an editor
	## warning on every load - so the highlight goes back to uniform before the
	## scene is packed. The fit is re-applied at runtime.
	for highlight in interactables.find_children("*", "MeshInstance3D", true, false):
		if String(highlight.name).begins_with("Highlight"):
			(highlight as Node3D).scale = Vector3.ONE

	_trigger(triggers, "NavigationBayTrigger", Vector3(5.25, 1.5, 10.5),
		Vector3(5.0, 3.0, 6.0), PackedStringArray([
			"Navigation. My tidiest room.",
			"Our course home is already plotted - you are welcome to look at it.",
			"Looking over my work is a reasonable thing to want to do.",
		]))
	_trigger(triggers, "CommsBayTrigger", Vector3(-5.25, 1.5, 10.5),
		Vector3(5.0, 3.0, 6.0), PackedStringArray([
			"Comms. Today's digest is already on the console.",
			"Forty-seven items came in; the three that matter are on top.",
			"The full queue is there too, if you would like the noise.",
		]))
	_trigger(triggers, "LifeSupportBayTrigger", Vector3(-5.25, 1.5, -3.5),
		Vector3(5.0, 3.0, 6.0), PackedStringArray([
			"Life support. The board is green across the ship.",
			"I keep this room myself - nothing in here needs a human.",
			"The detail is on the console if you would like it.",
		]))
