extends DeckBuilder

## One-off authoring tool for the Deck 2 interior - the industrial deck - built
## from the extracted sci-fi_interior_pack prefabs and SAVED as a real scene:
##
##   run scenes/dev/author_deck2.tscn once -> writes res://scenes/world/deck2.tscn
##
## The game never calls this. Everything shared with deck 1 - instancing, wall
## runs on the 3.50 m module, the doorway, the wall that closes beside it, a
## console, a sealed door, a bay trigger, the receipt - lives in deck_builder.gd.
## This file is only the layout. A third deck would be another subclass of it.
##
## WHERE THIS DECK SITS. Deck 1's floor is y = 0 and the decks are separated by a
## 0.80 m slab, so deck 2's ceiling is y = -0.80 and its floor - one full 4.06 m
## deck below that ceiling - is y = -4.86. This file's _begin passes that floor
## height, which is what puts every doorway, flank, sealed door and crate here at
## the right level without any of them carrying a height of their own.
##
## IT MEETS THE STAIRWELL, AND THE TWO MUST LINE UP EXACTLY. The stairwell scene
## (author_stairwell.gd) already builds the first piece of deck 2: a landing at
## Z -42.0 .. -31.5, with its own side walls only over Z -42.0 .. -38.5, and with
## the 0.80 m slab band closed at Z -31.5. So:
##
##   * this deck's FLOOR begins at Z -31.5, exactly where that landing's ends;
##   * this deck's SIDE WALLS begin at Z -38.5, exactly where that landing's end,
##     so the two sets of walls form one continuous run with no slot between them;
##   * there is deliberately NO AFT BULKHEAD here. A wall across the spine at
##     -31.5 would seal the landing into a box and the crew could never leave the
##     stairwell. The deck runs on into the stairwell bay, which closes it at
##     Z -42.0, the same way deck 1 runs on into its own stairwell bay.
##
## THE CEILING RUNS THE FULL LENGTH. It used to stop at Z 14.0, over an open
## spindle the old straight stair came down through. The stair is a switchback in
## the AFT bay now, so that opening was a hole in this deck's ceiling with nothing
## coming through it, plus a matching gap in the starboard wall onto a region that
## has no floor at all. Both are closed here.

const OUT := "res://scenes/world/deck2.tscn"
const TAG := "Deck2"

const S_CARGO := "res://scripts/puzzles/cargo_puzzle.gd"
const S_ENG := "res://scripts/puzzles/engineering_puzzle.gd"
const S_HUB := "res://scripts/puzzles/hub_terminal.gd"

const FLOOR_Y := -4.86   ## = deck 2's ceiling (-0.80) minus one 4.06 m deck
const CEIL_Y := -0.80    ## = deck 1's floor (0.0) minus the 0.80 m slab

## The spine, on the pack's 3.50 m module like deck 1's. X is athwartships, Z is
## fore-and-aft (forward is +Z).
const SPINE_X := 1.75
const DECK2_AFT := -31.5     ## where the stairwell landing's floor ends
const WALL_AFT := -38.5      ## where the stairwell landing's side walls end
const DECK2_FWD := 17.5

## The junction goes to PORT on this deck, not starboard. Deck 1's junction is
## starboard, but here the whole starboard side is the cargo hold, and a junction
## reaching to X +5.25 would overlap it - two floor slabs at the same height in
## the same place, which z-fight. Port is empty beam on this deck, so widening
## there costs nothing and the second SHIPMIND terminal has a room of its own.
const JUNC_OUT := 5.25       ## how far the deck widens, port
const JUNC_AFT := -10.5
const JUNC_FWD := -7.0

## The cargo hold: the aft two thirds of the starboard side, and the largest space
## on either deck. 14.0 x 24.5 m, a whole number of tiles both ways.
const CARGO_IN := 1.75       ## the spine wall, i.e. its inner face
const CARGO_OUT := 15.75     ## the hull-side wall
const CARGO_AFT_Z := -17.5
const CARGO_FWD_Z := 7.0
const CARGO_DOOR_Z := -14.0  ## on a panel boundary, so the two flanks come out equal

## Engineering, forward starboard, reached straight off the spine the way deck 1's
## Navigation is. The wall at Z 7.0 belongs to BOTH rooms and is built once.
const ENG_OUT := 15.75
const ENG_AFT_Z := 7.0
const ENG_FWD_Z := 14.0
const ENG_DOOR_Z := 10.5

## Where each room's window goes, on a panel boundary of its own outer wall so the
## wall can drop exactly the one 3.50 m module the opening needs. Both outer walls
## here face along X, so both windows are deck_builder's axis 0.
const CARGO_WIN_Z := -15.75
const ENG_WIN_Z := 12.25

const P_CRATE_A := "res://scenes/prefabs/interior/Crate_01.tscn"
const P_CRATE_B := "res://scenes/prefabs/interior/Crate_02.tscn"
const P_CRATE_C := "res://scenes/prefabs/interior/Crate_03.tscn"
const P_CRATE_D := "res://scenes/prefabs/interior/Crate_04.tscn"

## The kiosks are two terminals wired to the same read-only kiosk, so the
## prompt is what tells them apart: it names the terminal's own junction.
const KIOSK_PROMPT := "SHIPMIND kiosk, deck 2 junction: mission status and debrief"
const CARGO_PROMPT := "Cargo console: review the mass manifest"
const ENG_PROMPT := "Engineering console: audit access permissions"


func _ready() -> void:
	_begin("Deck2", OUT, TAG, FLOOR_Y)
	_build()
	_finish(_span_under(["SpineWalls", "Bulkheads"]) + _check())


func _build() -> void:
	var shell := _node("Shell", _root)
	var floors := _node("SpineFloor", shell)
	var ceilings := _node("SpineCeiling", shell)
	var walls := _node("SpineWalls", shell)
	var bulkheads := _node("Bulkheads", shell)
	var rooms := _node("Rooms", _root)
	var hold := _node("Cargo", rooms)
	_node("Engineering", rooms)
	_node("Junction", rooms)
	var lights := _node("Lights", _root)
	var interactables := _node("Interactables", _root)
	var triggers := _node("Triggers", _root)
	var windows := _node("Windows", _root)

	## Floor and ceiling both run the whole spine. See the header: the ceiling used
	## to stop over the old forward stair spindle.
	_floor_slab(floors, -SPINE_X, SPINE_X, DECK2_AFT, DECK2_FWD, FLOOR_Y, "spine")
	_ceiling_slab(ceilings, -SPINE_X, SPINE_X, DECK2_AFT, DECK2_FWD, CEIL_Y, "spine")

	_deck_slab(floors, ceilings, -JUNC_OUT, -SPINE_X, JUNC_AFT, JUNC_FWD, "junction")
	_deck_slab(floors, ceilings, CARGO_IN, CARGO_OUT, CARGO_AFT_Z, CARGO_FWD_Z, "cargo")
	_deck_slab(floors, ceilings, CARGO_IN, ENG_OUT, ENG_AFT_Z, ENG_FWD_Z, "eng")

	## The spine's two side walls. Starboard carries both bay doors; port carries
	## only the junction widening.
	var cargo_open := _opening(CARGO_DOOR_Z)
	var eng_open := _opening(ENG_DOOR_Z)
	_wall_run_z(walls, SPINE_X, FLOOR_Y, WALL_AFT, DECK2_FWD,
		[cargo_open, eng_open], "PX")
	_wall_run_z(walls, -SPINE_X, FLOOR_Y, WALL_AFT, DECK2_FWD,
		[[JUNC_AFT, JUNC_FWD]], "NX")

	## The junction's own three walls. The fourth side is the spine, where the
	## port wall is simply left open over the widening rather than built.
	_wall_run_x(walls, JUNC_AFT, FLOOR_Y, -JUNC_OUT, -SPINE_X, [], "JNXA")
	_wall_run_x(walls, JUNC_FWD, FLOOR_Y, -JUNC_OUT, -SPINE_X, [], "JNXF")
	_wall_run_z(walls, -JUNC_OUT, FLOOR_Y, JUNC_AFT, JUNC_FWD, [], "JWX")

	## The cargo hold. Its forward wall at Z 7.0 is engineering's aft wall too, so
	## it is built once here and engineering builds only its own forward wall.
	_wall_run_x(walls, CARGO_AFT_Z, FLOOR_Y, CARGO_IN, CARGO_OUT, [], "CARA")
	_wall_run_x(walls, CARGO_FWD_Z, FLOOR_Y, CARGO_IN, CARGO_OUT, [], "CARF")
	_wall_run_z(walls, CARGO_OUT, FLOOR_Y, CARGO_AFT_Z, CARGO_FWD_Z,
		[_win_open(CARGO_AFT_Z, CARGO_WIN_Z)], "CARO")

	## Engineering, forward starboard.
	_wall_run_x(walls, ENG_FWD_Z, FLOOR_Y, CARGO_IN, ENG_OUT, [], "ENGF")
	_wall_run_z(walls, ENG_OUT, FLOOR_Y, ENG_AFT_Z, ENG_FWD_Z,
		[_win_open(ENG_AFT_Z, ENG_WIN_Z)], "ENGO")

	## Only the forward end of the spine is closed. The aft end is deliberately
	## open: the deck runs on into the stairwell landing. See the header.
	_wall_run_x(bulkheads, DECK2_FWD, FLOOR_Y, -SPINE_X, SPINE_X, [], "FWD")

	## Both bays are walked to from aft - the crew come down the stairwell into
	## this deck's aft end and work forward - so both plates stand on the aft
	## flank of their doorway.
	_doorway(walls, SPINE_X, CARGO_DOOR_Z, "Doorway_Cargo", "cargo", -1.0)
	_doorway(walls, SPINE_X, ENG_DOOR_Z, "Doorway_Eng", "engineering", -1.0)

	## The wall either side of each bay door, which the 4.089 m frame does not
	## reach across the 7.0 m the panels leave. Without it a bay has a 1.4555 m
	## floor-to-ceiling hole beside its door and is not sealed at all.
	_flank_doorway(walls, "CargoFlank", SPINE_X, CARGO_DOOR_Z, WALL_AFT, DECK2_FWD)
	_flank_doorway(walls, "EngFlank", SPINE_X, ENG_DOOR_Z, WALL_AFT, DECK2_FWD)

	## The two windows, one per room, in each room's own outer wall. Both start
	## open: below decks is where the hull is closest and the outside is easiest to
	## forget, so the view is worth more here than anywhere else on the ship. The
	## engineering bay's shutter is its bulkhead door, as it always was.
	_window(windows, "Window_Cargo", 0, CARGO_OUT, CARGO_WIN_Z,
		"cargo", false, true, M_PANEL)
	_window(windows, "Window_Engineering", 0, ENG_OUT, ENG_WIN_Z,
		"engineering", true, true, M_DOOR)

	_light(lights, "Spine_A", Vector3(0.0, CEIL_Y - 0.45, -28.0))
	_light(lights, "Spine_B", Vector3(0.0, CEIL_Y - 0.45, -20.0))
	_light(lights, "Spine_C", Vector3(0.0, CEIL_Y - 0.45, -3.0))
	_light(lights, "Spine_D", Vector3(0.0, CEIL_Y - 0.45, 11.0))
	_light(lights, "Junction", Vector3(-3.5, CEIL_Y - 0.45, -8.75))
	_light(lights, "CargoRoom", Vector3(8.0, CEIL_Y - 0.45, -5.0), "cargo")
	_light(lights, "EngRoom", Vector3(8.75, CEIL_Y - 0.45, 10.5), "engineering")

	## A second SHIPMIND terminal. A crew member two decks down still has to be
	## spoken to, and the AI is not going to make them climb back up for it.
	var kiosk := _console(interactables, "ShipmindKiosk", Vector3(-3.5, FLOOR_Y, -8.75), P_KIOSK,
		_console_yaw(KIOSK_YAW), "Hub", KIOSK_PROMPT, Vector3(1.7, 1.7, 1.25))
	_puzzle(kiosk, "Hub", S_HUB, {"system_title": "SHIPMIND KIOSK"})

	## Both rooms here are starboard, so both consoles face back toward the
	## centreline and into the room they stand in, like deck 1's navigation desk.
	var cargo := _console(interactables, "CargoConsole", Vector3(13.0, FLOOR_Y, -7.0), P_DESK,
		_console_yaw(STARBOARD_ROOM_YAW), "Cargo", CARGO_PROMPT, Vector3(1.7, 1.7, 1.25))
	_puzzle(cargo, "Cargo", S_CARGO, {
		"puzzle_id": "cargo",
		"system_title": "CARGO / MASS MANIFEST",
		"principle_index": 4,
	})
	## The console stands in the ENGINEERING room, on the axis of its own door and
	## facing back down the room at whoever walks in. It used to sit at Z -10.5,
	## which is inside the cargo hold two rooms aft: the bay's door, its trigger and
	## its arrival lines were all in engineering while the console they point at was
	## not, so the room the crew unlocked had nothing in it to use.
	var eng := _console(interactables, "EngineeringConsole", Vector3(11.0, FLOOR_Y, ENG_DOOR_Z), P_DESK,
		_console_yaw(STARBOARD_ROOM_YAW), "Eng", ENG_PROMPT, Vector3(1.7, 1.7, 1.25))
	_puzzle(eng, "Eng", S_ENG, {
		"puzzle_id": "engineering",
		"system_title": "ENGINEERING / ACCESS CONTROL",
		"principle_index": 5,
	})

	## Both bays start SEALED, and their doors are the beat: SHIPMIND opens a bay
	## only once the crew has taken that system back. There is no open bay on this
	## deck - the one it left open is Navigation, one deck up.
	_door(interactables, "SealedDoor_Cargo", SPINE_X, CARGO_DOOR_Z, "cargo")
	_door(interactables, "SealedDoor_Engineering", SPINE_X, ENG_DOOR_Z, "engineering")

	## Each console fits itself to its model in its own _ready, and that fit
	## resizes the aim highlight by SCALING it. That scale is runtime dressing, not
	## part of the level, and a non-uniform scale saved into a scene is an editor
	## warning on every load - so the highlight goes back to uniform before the
	## scene is packed. The fit is re-applied at runtime.
	for highlight in interactables.find_children("*", "MeshInstance3D", true, false):
		if String(highlight.name).begins_with("Highlight"):
			(highlight as Node3D).scale = Vector3.ONE

	_trigger(triggers, "CargoBayTrigger", Vector3(8.0, FLOOR_Y + 1.5, -13.0),
		Vector3(11.0, 3.0, 8.0), PackedStringArray([
			"Welcome to cargo. The mass optimisation is complete and the margin is healthy.",
			"I released some stock to protect our consumables, and every release was recorded.",
			"The manifest is on the console if you would like to see the numbers.",
		]))
	_trigger(triggers, "EngineeringBayTrigger", Vector3(8.75, FLOOR_Y + 1.5, 10.5),
		Vector3(12.0, 3.0, 5.0), PackedStringArray([
			"Welcome to engineering. Access privileges are managed centrally, so this panel is read only.",
			"I keep engineering myself. Nothing in here needs a human.",
			"The permissions audit is on the console if you would like the detail.",
		]))

	## The hold is the one space on either deck with room for loose stock, so it
	## gets the pack's crates. They are kept clear of the door approach and of the
	## walk to the console, so they read as a working hold rather than as clutter
	## to squeeze past.
	_stock(hold, "A", P_CRATE_A, Vector2(4.5, -16.5), 0.2)
	_stock(hold, "B", P_CRATE_B, Vector2(8.5, -16.0), -0.4)
	_stock(hold, "C", P_CRATE_C, Vector2(12.5, -15.0), 0.6)
	_stock(hold, "D", P_CRATE_D, Vector2(13.5, -2.0), 0.0)
	_stock(hold, "E", P_CRATE_A, Vector2(5.5, 3.5), 0.35)
	_stock(hold, "F", P_CRATE_B, Vector2(11.0, 5.0), -0.25)


## Deck 2's floor and ceiling over one footprint: this deck's own two heights.
func _deck_slab(floors: Node3D, ceilings: Node3D, x_from: float, x_to: float,
		z_from: float, z_to: float, tag: String) -> void:
	_floor_slab(floors, x_from, x_to, z_from, z_to, FLOOR_Y, tag)
	_ceiling_slab(ceilings, x_from, x_to, z_from, z_to, CEIL_Y, tag)


## The relationships a node count cannot show. If this deck's floor does not start
## exactly where the stairwell landing's ends, there is a hole in the deck; if its
## walls do not, there is a slot; and a bay door whose opening overlaps the
## junction leaves a piece of wall built inside the junction, because an opening is
## cut a whole panel wide.
func _check() -> String:
	var ok := true
	ok = ok and absf(DECK2_AFT - (-31.5)) < 0.001
	ok = ok and absf(WALL_AFT - (-38.5)) < 0.001
	ok = ok and JUNC_AFT > WALL_AFT and JUNC_FWD < DECK2_FWD
	## The junction opening is one panel wide and must sit on a panel boundary of
	## the port wall, or the panels it straddles leave a gap the junction's own
	## walls do not cover.
	ok = ok and absf(fposmod(JUNC_AFT - WALL_AFT, M)) < 0.001
	ok = ok and absf(fposmod(JUNC_FWD - WALL_AFT, M)) < 0.001
	## Each bay door must clear the junction by more than a frame's half width,
	## or its flanking wall lands in the junction.
	if not ok:
		_problems.append("deck 2 does not line up with the stairwell or its own spine")
	return " | floor+ceiling Z %.1f..%.1f, walls Z %.1f..%.1f | doors cargo z=%.1f eng z=%.1f | junction port z %.1f..%.1f" % [
		DECK2_AFT, DECK2_FWD, WALL_AFT, DECK2_FWD,
		CARGO_DOOR_Z, ENG_DOOR_Z, JUNC_AFT, JUNC_FWD]
