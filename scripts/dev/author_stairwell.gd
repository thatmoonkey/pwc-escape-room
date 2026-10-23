extends DeckBuilder

## One-off authoring tool for the vertical link: the SWITCHBACK stairwell that
## joins deck 1 to deck 2, and the deck 2 landing its lower flight arrives on.
##
##   run scenes/dev/author_stairwell.tscn once -> writes res://scenes/world/stairwell.tscn
##
## The game never calls this. Deck 1's own aft bulkhead is deliberately absent (see
## author_deck1.gd), so THIS scene is what closes deck 1 aft, and the landing it
## builds is the first piece of deck 2.
##
## WHY A SWITCHBACK RATHER THAN ONE STRAIGHT FLIGHT
##
## The first version ran one 27 riser flight straight aft down the whole bay and
## put the crew's feet on deck 2's floor at Z -38.5, facing the aft bulkhead. A
## straight flight can only meet a floor at its FOOT, and its foot was the last
## thing in the bay: the deck it served began in front of the stair, with the
## stair's own mass filling the corridor between the two. There was no way past
## it, in any direction, on either side - the lower deck was unreachable.
##
## Turning the flight around on a half landing fixes that without moving a single
## wall: the crew come down the PORT flight, cross the landing at the aft end, and
## come down the STARBOARD flight to deck 2's floor at the void's FORWARD edge -
## which is exactly where the deck 2 spine begins. They step off facing forward
## into the deck, with the stair behind them. The same void that the straight
## flight needed now carries both flights, because one sits over the other.
##
## THE GEOMETRY, AND WHY EACH NUMBER IS WHAT IT IS
##
## Deck 1's floor is y = 0 and its ceiling y = 4.06. The decks are separated by a
## 0.80 m slab, so deck 2's ceiling is y = -0.80 and its floor - one full deck
## below that ceiling - is y = -4.86. The stair therefore drops 4.86 m, in two
## halves of 2.43 m.
##
## The bay sits aft of the deck 1 spine, on the pack's 3.50 m grid: a one-tile
## lobby at Z -28.0..-31.5, then a two-tile void at Z -31.5..-38.5. The void's
## forward tile carries both flights, and its aft tile is the half landing. Each
## flight is 14 risers over 14 treads of 3.50/14 = 0.25 m, which uses the tile
## exactly at both ends: 14 risers of 2.43/14 = 0.1736 m put the turn on
## y = -2.43, and the same again puts the lower flight's foot exactly on deck 2's
## floor. The 34.77 degree slope is the same as the old straight flight's, and sits
## comfortably inside the controller's 45 degree floor angle.
##
## The 14th riser of each flight is not drawn: it is the step down onto the landing
## or onto the deck, and the landing and the deck are already there.
##
## Nothing here is stretched. The walls are the pack's own 3.50 x 4.06 panels, and
## the pieces the pack cannot supply - the void's two side walls, which run the
## full 4.86 m from deck 2's floor up to deck 1's and so are taller than any panel,
## the two short bands closing the void's forward and aft faces, the half landing,
## the flight divider and the guard at the head - are built as maroon boxes in the
## colour the ember shader maps the panels onto.
##
## THE BAY'S CLEAR WIDTH IS 3.205 m, between the inner faces of the two side wall
## panels. Two 1.455 m flights and a 0.295 m divider on the centre line fill it
## exactly, and each flight's outer edge IS its wall's inner face, so there is no
## slot at either side to fall into.
##
## HOW THE VOID IS SEALED. Deck 1's floor stops dead at the void's forward edge and
## deck 2's ceiling stops at its aft edge, so the void runs from deck 1's floor
## right down to deck 2's. The side walls are single 4.86 m boxes spanning all of
## it, which closes the 0.80 m slab band as well - a 4.06 m panel could not. The
## FORWARD face is closed only in that same slab band, and deliberately so: deck
## 2's spine runs on forward from that plane, and the lower flight lands right
## there, so a full-height head wall would seal the lower deck off from the very
## stair that serves it. The band's top face IS deck 1's floor, so nothing can see
## into the slab band from either side.
##
## WHY THE STEPS CARRY NO COLLISION. The player controller walks with move_and_slide
## and has no step-up logic, so 14 separate riser faces of 0.1736 m would stop the
## crew dead at the foot of each flight. The steps are therefore drawn only, and
## one invisible ramp per flight carries the collision: a single 34.77 degree
## surface meeting deck 1's floor flush at the head of the upper flight, the
## landing flush at the turn, and deck 2's floor flush at the foot of the lower
## one. Each ramp runs through its step nosings, so the visible treads sit within
## half a riser of the surface being walked on.

const OUT := "res://scenes/world/stairwell.tscn"
const TAG := "Stair"

## X wall centre line, shared with the deck 1 spine so the two sets of walls meet
## on one plane instead of standing beside each other.
const SPINE_X := 1.75

## The pack's wall panel thickness, carried here rather than taken from the base
## class so that every constant below derives from constants of this file alone.
## _check reads the base class's own value back and fails if the two disagree.
const PANEL_THICK := 0.295

## Z landmarks, each a whole number of the pack's 3.50 m module from the next.
const BAY_FWD := -28.0      ## where the deck 1 spine as authored stops
const HEAD := -31.5         ## the void's forward edge: the head of the upper flight
const TURN := -35.0         ## the half landing, and the turn itself
const AFT := -38.5          ## the void's aft face, and deck 1's aft bulkhead
const LAND_AFT := -42.0     ## the deck 2 landing's aft end

## Deck heights. Deck 1's floor is y = 0 by definition of the whole interior.
const SLAB := 0.8           ## the structure and services between the two decks
const D1_FLOOR := 0.0
const D2_CEIL := -0.8       ## = D1_FLOOR - SLAB
const D2_FLOOR := -4.86     ## = D2_CEIL - 4.06, one full deck below its ceiling
const DROP := D1_FLOOR - D2_FLOOR
const HALF_DROP := DROP * 0.5   ## each flight drops this much
const TURN_Y := D1_FLOOR - HALF_DROP

## One flight: 14 risers over the void's forward tile, so both the 2.43 m it drops
## and the 3.50 m it runs use the tile exactly and neither end is left in mid air.
const RISERS := 14
const RISER := HALF_DROP / float(RISERS)
const RUN := HEAD - TURN
const TREAD := RUN / float(RISERS)
const LOW_STEPS := RISERS - 1   ## drawn boxes per flight; the last riser is the floor

## How thick the walkable ramp is. It is never seen: it only has to be deep enough
## that nothing walks through it.
const RAMP_T := 0.5

## The half landing, and the distance the lower flight's own stringer is kept clear
## above it, so the two flights read as two flights rather than as one solid block.
const PLAT_T := 0.6
const CLEAR_DROP := 0.30
const STRINGER := HALF_DROP - CLEAR_DROP

## The divider on the centre line, and the guard across the head of the lower
## flight only. Both stop at the same height: a handrail's, not a wall's, so the
## lobby still reads into the void from deck 1.
const GUARD_H := 1.05
const GUARD_T := 0.15

## The divider stands ON the half landing and reaches past deck 1's floor, so the
## slot between the two flights is closed over their whole run rather than only
## where a handrail would reach. It runs the whole way to the void's forward
## plane, which is where the head band's aft face now is - the band sits forward
## of that plane rather than across it, so there is nothing left for the divider
## to poke a fin through and nothing left of the slot either.
const DIV_H := GUARD_H + HALF_DROP
const DIV_LEN := HEAD - TURN
const DIV_CY := (TURN_Y + D1_FLOOR + GUARD_H) * 0.5
const DIV_CZ := (TURN + HEAD) * 0.5

## The bay's clear width and how it is divided. See the header: two flights and the
## divider fill 2 x CLEAR_HALF exactly, with nothing left over at either side.
const CLEAR_HALF := SPINE_X - PANEL_THICK * 0.5
const FLIGHT_W := CLEAR_HALF - PANEL_THICK * 0.5
const FLIGHT_CX := (CLEAR_HALF + PANEL_THICK * 0.5) * 0.5


func _ready() -> void:
	_begin("Stairwell", OUT, TAG)
	_build()
	_finish(_span_under(["Walls"]) + _check())


func _build() -> void:
	var shell := _node("Shell", _root)
	var deck1 := _node("Deck1Bay", shell)
	var deck2 := _node("Deck2Landing", shell)
	var shaft := _node("Shaft", shell)
	var stair := _node("Stair", _root)
	var lights := _node("Lights", _root)

	## DECK 1: the lobby floor forward of the void, the ceiling over the whole bay,
	## the spine's side walls carried aft, and the bulkhead that closes the deck.
	## There is deliberately NO floor over the void - that opening is the stairwell,
	## and it is what the crew walk down.
	var d1_floor := _node("Floor", deck1)
	var d1_ceil := _node("Ceiling", deck1)
	var d1_wall := _node("Walls", deck1)
	_floor_slab(d1_floor, -SPINE_X, SPINE_X, HEAD, BAY_FWD, D1_FLOOR, "lobby")
	_ceiling_slab(d1_ceil, -SPINE_X, SPINE_X, AFT, BAY_FWD, H, "bay")
	_wall_run_z(d1_wall, SPINE_X, D1_FLOOR, AFT, BAY_FWD, [], "PX")
	_wall_run_z(d1_wall, -SPINE_X, D1_FLOOR, AFT, BAY_FWD, [], "NX")
	_wall_run_x(d1_wall, AFT, D1_FLOOR, -SPINE_X, SPINE_X, [], "AFT")

	## DECK 2: the landing the lower flight arrives on, floored from the void's aft
	## face forward to the head of the stair - the lower flight stands on that
	## floor - with its ceiling over the landing only. There must be none over the
	## void, or it would cap the stair half way down.
	var d2_floor := _node("Floor", deck2)
	var d2_ceil := _node("Ceiling", deck2)
	var d2_wall := _node("Walls", deck2)
	_floor_slab(d2_floor, -SPINE_X, SPINE_X, LAND_AFT, HEAD, D2_FLOOR, "land")
	_ceiling_slab(d2_ceil, -SPINE_X, SPINE_X, LAND_AFT, AFT, D2_CEIL, "land")
	_wall_run_z(d2_wall, SPINE_X, D2_FLOOR, LAND_AFT, AFT, [], "PX")
	_wall_run_z(d2_wall, -SPINE_X, D2_FLOOR, LAND_AFT, AFT, [], "NX")
	_wall_run_x(d2_wall, LAND_AFT, D2_FLOOR, -SPINE_X, SPINE_X, [], "D2AFT")

	## The void's walls: 4.86 m tall, from deck 2's floor to deck 1's, because that
	## is the height of the void they close. They run the full length of the bay,
	## so the two side walls also close the 0.80 m slab band below deck 1's floor,
	## which a 4.06 m panel cannot reach. Their inner faces are the flights' outer
	## edges.
	var shaft_len := BAY_FWD - AFT
	var shaft_mid_z := (BAY_FWD + AFT) * 0.5
	var shaft_mid_y := D2_FLOOR + DROP * 0.5
	_block(shaft, "PortWall", Vector3(PANEL_THICK, DROP, shaft_len),
		Vector3(-SPINE_X, shaft_mid_y, shaft_mid_z), M_WALL)
	_block(shaft, "StarboardWall", Vector3(PANEL_THICK, DROP, shaft_len),
		Vector3(SPINE_X, shaft_mid_y, shaft_mid_z), M_WALL)
	## Only the slab band, not the full void: see the header. Deck 2's spine runs on
	## forward from this plane and the lower flight lands on it, so the void has to
	## open onto the deck here at the deck's own level.
	## THE BAND SITS ENTIRELY FORWARD OF THE PLANE, and that is the whole reason
	## the stairs could be walked down but not up. Its top is deck 1's floor and
	## the upper flight's ramp arrives at that same height on this exact plane, so
	## a band centred ON the plane reached 0.1475 m aft of it, where the ramp's
	## surface is already 0.10 m lower - and stood there as a 10 cm step across the
	## full 3.5 m width of the bay. Measured, not guessed: a capsule the crew's own
	## size climbing the upper flight stopped at z -31.98, y -0.26, against this
	## band, 0.48 m short of the top. The descent never met it, because going down
	## leaves the floor before the band is reached; going up had to climb it, and
	## with no step-up logic in the controller it could not.
	_block(shaft, "HeadBand", Vector3(M, SLAB, PANEL_THICK),
		Vector3(0.0, D2_CEIL + SLAB * 0.5, HEAD + PANEL_THICK * 0.5), M_WALL)
	_block(shaft, "AftBand", Vector3(M, SLAB, PANEL_THICK),
		Vector3(0.0, D2_CEIL + SLAB * 0.5, AFT), M_WALL)
	## AND THE REST OF THE AFT FACE, one whole deck of it, from deck 2's floor up
	## to deck 2's ceiling. Deck 2's own landing bay runs aft from this plane to
	## Z -42.0, and the slab band above only closes y -0.80..0.00 - so everything
	## from deck 2's ceiling down to its floor was an opening the crew looked
	## straight into from the upper flight, over the half landing's head. It read
	## as the stairwell's back wall having been left out. Deck 1's own AFT wall
	## closes the deck above this and the band closes the slab, so with this piece
	## the face is solid from deck 2's floor right up to deck 1's ceiling.
	## The landing and this wall overlap by 0.1475 m, which is deliberate: both are
	## solid, and butting them would leave the seam the wall is here to remove.
	_block(shaft, "AftFace", Vector3(CLEAR_HALF * 2.0, H, PANEL_THICK),
		Vector3(0.0, (D2_FLOOR + D2_CEIL) * 0.5, AFT), M_WALL)

	## THE HALF LANDING. One bay deep, filling the void between the two side walls
	## at y = -2.43. It is a built piece rather than pack tiles because the pack's
	## tiles are 3.50 m squares and this has to sit INSIDE the bay's clear width,
	## between the wall panels rather than running under them.
	_block(deck2, "TurnPlatform", Vector3(CLEAR_HALF * 2.0, PLAT_T, TURN - AFT),
		Vector3(0.0, TURN_Y - PLAT_T * 0.5, (TURN + AFT) * 0.5), M_WALL)

	## THE DIVIDER on the centre line. Without it the two flights would be one
	## 2.91 m wide switchback with a 2.43 m drop in the middle of it and nothing to
	## stop a fall into; with it they are two 1.455 m service flights.
	_block(stair, "Divider", Vector3(PANEL_THICK, DIV_H, DIV_LEN),
		Vector3(0.0, DIV_CY, DIV_CZ), M_STEP)

	## AND A GUARD ACROSS THE HEAD OF THE LOWER FLIGHT'S SIDE ONLY. The upper
	## flight's side is where the crew step off deck 1's floor and there must be
	## nothing across it; the other side is open to the lobby with a 2.43 m drop
	## behind it over both flights' run.
	_block(stair, "HeadGuard", Vector3(FLIGHT_W, GUARD_H, GUARD_T),
		Vector3(FLIGHT_CX, D1_FLOOR + GUARD_H * 0.5, HEAD), M_STEP)

	## The two flights, drawn as solid step boxes. Each carries its own stringer
	## down to where the flight below it begins, so a flight reads as a built stair
	## rather than as a run of slabs floating in the void. The upper flight's boxes
	## stop 0.30 m above the lower flight's treads; the lower flight's reach deck
	## 2's own floor, which is what it stands on.
	## THE TWO FLIGHTS RUN OPPOSITE WAYS IN Z, so each flight's steps march along
	## its own direction: the upper one descends AFT, its steps running away from
	## the head at Z -31.5 toward the turn, and the lower one descends FORWARD from
	## the turn onto deck 2's floor. Both used to be placed at the lower flight's
	## Z, which put every step of the upper flight a whole run out of step with the
	## ramp under it - the collision was right and the stair you could see was not.
	var upper := _node("TreadsUpper", stair)
	for i in range(1, RISERS + 1):
		_step(upper, i, -FLIGHT_CX, D1_FLOOR - RISER * float(i),
			HEAD - TREAD * (float(i) - 0.5), STRINGER)
	var lower := _node("TreadsLower", stair)
	for i in range(1, RISERS):
		_step(lower, i, FLIGHT_CX, TURN_Y - RISER * float(i),
			TURN + TREAD * (float(i) - 0.5), HALF_DROP)

	## The two surfaces the crew actually walk on, one per flight. Each head and
	## foot is on the line the flight's own nosings follow, so both ends of both
	## flights meet a floor flush with no step to climb onto or off.
	var upper_head := Vector3(0.0, D1_FLOOR, HEAD)
	var upper_foot := Vector3(0.0, TURN_Y, TURN)
	var lower_head := Vector3(0.0, TURN_Y, TURN)
	var lower_foot := Vector3(0.0, D2_FLOOR, HEAD)
	_ramp(stair, "RampUpper", -FLIGHT_CX, upper_head, upper_foot)
	_ramp(stair, "RampLower", FLIGHT_CX, lower_head, lower_foot)

	_light(lights, "ShaftHead", Vector3(0.0, H - 0.45, HEAD - 0.5))
	_light(lights, "Arrival", Vector3(0.0, D2_CEIL - 0.45, HEAD - 0.7))
	_light(lights, "Turn", Vector3(0.0, D2_CEIL - 0.45, TURN - 0.5))
	_light(lights, "Landing", Vector3(0.0, D2_CEIL - 0.45, LAND_AFT + M * 0.5))


## One drawn step of a flight: its tread on top, its stringer below, running the
## full depth given. No collision - the ramp beside it carries that. See the header.
func _step(parent: Node3D, index: int, x: float, top: float, z: float,
		depth: float) -> void:
	_deco(parent, "Step_%02d" % index, Vector3(FLIGHT_W, depth, TREAD),
		Vector3(x, top - depth * 0.5, z), M_STEP)


## The one collidable surface of a flight: a slab whose top face runs from head to
## foot, so it lands ON the line the nosings follow rather than through it.
##
## Its basis is built from the flight's own direction rather than from a rotation
## about one axis, because the two flights run OPPOSITE ways in Z: the upper one
## descends aft, the lower one descends forward. Deriving the up-normal from the
## direction keeps both the same three lines of code and, unlike a rotation about
## Vector3.RIGHT, cannot quietly land one of them upside down.
func _ramp(parent: Node3D, node_name: String, x: float, head: Vector3,
		foot: Vector3) -> void:
	var along := (head - foot).normalized()
	var up := Vector3(0.0, absf(along.z), -along.y * signf(along.z)).normalized()
	_collider(parent, node_name, Vector3(FLIGHT_W, RAMP_T, (head - foot).length()),
		Basis(up.cross(along), up, along),
		Vector3(x, 0.0, 0.0) + (head + foot) * 0.5 - up * (RAMP_T * 0.5))


## The numbers that would differ if the link were wrong. A riser count that does
## not add up to the drop leaves a step in mid air; a tread count that does not
## reach the turn leaves a gap in the middle of the stair; a deck 2 floor that is
## not exactly one deck plus the slab below deck 1 puts a lip at the foot; a turn
## that is not exactly half the drop makes the two flights unequal; a slope past the
## controller's 45 degree floor angle turns a flight into a wall the crew cannot
## climb; and a bay whose parts do not add up to its own length is a stair with a
## hole in it. None of those shows up in a node count.
func _check() -> String:
	var covered := RISER * float(RISERS) * 2.0
	var reach := TREAD * float(RISERS)
	var slope := rad_to_deg(atan2(HALF_DROP, RUN))
	var bad: Array[String] = []
	if absf(covered - DROP) > 0.001:
		bad.append("risers x riser (%.4f) != the drop (%.4f)" % [covered, DROP])
	if absf(reach - RUN) > 0.001:
		bad.append("treads x tread (%.4f) != one flight's run (%.4f)" % [reach, RUN])
	if absf((HEAD - AFT) - (RUN + (TURN - AFT))) > 0.001:
		bad.append("run + turn platform (%.4f) != the bay (%.4f)" % [
			RUN + (TURN - AFT), HEAD - AFT])
	if absf(D2_FLOOR - (D1_FLOOR - H - SLAB)) > 0.001:
		bad.append("deck 2's floor (%.3f) is not one deck plus the slab below deck 1" % D2_FLOOR)
	if absf(TURN_Y - (D1_FLOOR - HALF_DROP)) > 0.001:
		bad.append("the turn (%.3f) is not half the drop" % TURN_Y)
	if absf(CLEAR_HALF * 2.0 - FLIGHT_W * 2.0 - PANEL_THICK) > 0.001:
		bad.append("two flights and the divider do not fill the bay's clear width")
	if absf(PANEL_THICK - WALL_T) > 0.001:
		bad.append("PANEL_THICK (%.3f) != the pack's wall thickness (%.3f)" % [
			PANEL_THICK, WALL_T])
	if absf(DIV_CZ + DIV_LEN * 0.5 - HEAD) > 0.001:
		bad.append("the divider does not reach the void's forward plane")
	if absf((DIV_CY - DIV_H * 0.5) - TURN_Y) > 0.001:
		bad.append("the divider does not stand on the half landing")
	if absf(DIV_CY + DIV_H * 0.5 - (D1_FLOOR + GUARD_H)) > 0.001:
		bad.append("the divider and the head guard do not stop at the same height")
	if slope >= 45.0:
		bad.append("slope (%.2f) is past the controller's 45 degree floor angle" % slope)
	for problem in bad:
		_problems.append("stair check: " + problem)
	return " | flights=2 steps=%d+%d riser=%.4f tread=%.4f drop=%.3f/%.3f run=%.3f/%.3f | turn y=%.2f platform z=%.1f..%.1f | arrival y=%.2f z=%.1f | slope=%.2fdeg" % [
		RISERS, LOW_STEPS, RISER, TREAD, covered, DROP, reach, RUN,
		TURN_Y, TURN, AFT, D2_FLOOR, HEAD, slope]
