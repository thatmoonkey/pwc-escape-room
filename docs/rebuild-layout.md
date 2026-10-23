# Interior rebuild - layout spec

The Adamant Verity interior, rebuilt as spine-and-rooms across two decks.

This is the spec the rebuild is built from. Everything in it is either measured
from the hull or a decision recorded here; nothing is assumed.

## Why rebuild at all

Three problems, in order of severity.

1. **The layout ignores the ship.** The interior is one straight corridor of 47 m
   in a 114 m vessel, occupying 4.2 m of its 38.4 m of height. It reads as a
   corridor parked inside a ship rather than a ship you walk through.
2. **No room can be a room.** All five bays are the same 7 m alcove, open to the
   same corridor. A room that cannot be closed cannot be sealed, cannot go dark,
   and cannot hold a countdown - which is what an escape room is made of.
3. **The level does not exist in the editor.** `kit_shell.gd`,
   `station_dressing.gd` and `cockpit_room.gd` build their geometry at load, so
   nothing can be hand-placed and the layout cannot be looked at without
   pressing Play. That was a workaround for a wall kit authored Z-up that lost
   its root orientation on placement, and the workaround should not survive the
   rebuild.

## The measured envelope

From the hull's own boot receipt, sampled across the ship's height at 3.4 m
intervals. Hull in world space is X -16.3..16.4 (32.7 beam), Y -12.0..26.4
(38.4 tall), Z -50.0..64.0 (114.0 long).

| sample Y | beam | usable Z run | run length |
|---|---|---|---|
| 9.1 | 23.2 | -49.9..12.0 | 61.9 |
| 5.4 | 32.1 | -50.0..15.2 | 65.2 |
| 1.7 | 32.4 | -50.0..56.0 | 106.0 |
| -2.0 | 32.6 | -50.0..63.9 | 113.9 |
| -5.7 | 32.7 | -41.0..59.8 | 100.9 |
| -9.4 | 30.0 | -30.0..64.0 | 94.0 |

Reading it:

- The widest and longest band is **below** deck 1, not above it. Deck 2 belongs
  down there, in the best volume the ship has.
- Above deck 1 the forward run collapses from +56 to +15 by Y 5.4, and the beam
  pinches to 23.2 m by Y 9.1. An upper deck would be short at the front and
  narrow. Rejected.
- At Y -9.4 there is still 30.0 beam and 94 m of run, so a third lower deck
  stays possible later. The aft end disappears first, so a deck 3 would be
  shorter at the stern.

## Deck stack

| deck | floor Y | ceiling Y | room height | samples | beam | run |
|---|---|---|---|---|---|---|
| 1 command | 0.0 | 4.06 | 4.06 | Y 1.7 | 32.4 | 106.0 |
| 2 industrial | -4.86 | -0.8 | 4.06 | Y -2.0, -5.7 | 32.6 | 100.9 |
| 3 (later) | -9.72 | -5.66 | 4.06 | Y -9.4 | 30.0 | 94.0 |

0.8 m of structure and services between decks, which is the standard floor slab
thickness already used in the scene.

Every room is 4.06 m high on both decks, so one prefab set serves both and any
piece can be reused anywhere. That is the wall pack's own height: raised from the
original 3.4 m by user decision so the sci-fi_interior_pack panels fit unscaled on
their own 3.50 m module (docs/interior-pack.md).

## Circulation

Spine, junctions and rooms - not one line.

**Deck 1, command.** Bridge forward (existing cockpit, Z 18..28.1). A central
junction at Z 2..10 carrying the SHIPMIND kiosk, so the AI has a physical place
the crew walk to. Spine corridor forward from the junction to the bridge gate
and aft to Z -40. One cross-corridor athwartships at Z -20 to reach rooms on
both sides. The aft spine runs on past Z -28 into the stairwell bay at
Z -28..-38.5, which drops one deck to the landing below.

**Deck 2, industrial.** Spine running under the deck 1 spine, aligned so the
stairwell lands on it. Stairwell landing at Z -28..-34. Cargo hold aft. An
engineering room forward, or amidships. A second SHIPMIND terminal, because a
crew member two decks down still has to be spoken to.

Spine corridor width 4.4 m (X +/-2.2) rather than today's 6.0 m. A 6 m corridor
is a hall; 4.4 m reads as a ship's spine and leaves more beam for the rooms
either side.

## Room schedule

| system | deck | position | size |
|---|---|---|---|
| Navigation | 1 | forward starboard | 8 x 8 |
| Comms | 1 | forward port | 8 x 8 |
| Life Support | 1 | mid port | 8 x 8 |
| Cargo | 2 | aft hold | 28 x 22 |
| Engineering | 2 | mid starboard | 10 x 8 |

Three systems above, two below. The spread is deliberate: cargo and engineering
are the industrial systems and they belong on the industrial deck, while
navigation sits beside the bridge where it is used.

Every room: fully enclosed, its own door, its own lighting, its own ambience.
The door is the beat - SHIPMIND controls whether it opens, and now the crew can
see the room it is keeping them out of.

## Build method

**Levels are authored as scenes with real nodes.** Nothing is generated at load
for the interior. `kit_shell.gd`, `station_dressing.gd` and `cockpit_room.gd`
retire as level builders.

**Walls come from a clean prefab set.** Every piece is authored with height on
Y, its pivot at the centre of its base, and a matching CollisionShape3D, so a
prefab can be dropped anywhere and lands on the floor with its collision
already aligned. The current maroon kit fails its own declared dimensions on 6
of its 15 modules - both consoles, the door frame, the window frame, and the
ceiling tile and light - which is exactly why `kit_shell.gd` carries all that
measuring and axis-guessing code. A prefab set that is correct by construction
deletes that problem instead of working around it.

**Materials are reused unchanged**, so the maroon identity survives and no new
asset is required:

- `wall_upper.tres` - panels, Brick Red #AD2323
- `wall_lower.tres` - lower band, #4F1010
- `trim_black.tres`, `floor_dark.tres`, `panel_light.tres`
- `accent_amber.tres`, `accent_cyan.tres`, `door_locked.tres`, `seat_warm.tres`

### Prefab list

| prefab | size | notes |
|---|---|---|
| wall_panel | 2.0 x 3.4 x 0.33 | the standard wall unit, matches the kit footprint |
| wall_corner | 1.0 x 3.4 x 0.33 both legs | L piece for room corners |
| floor_tile | 2.0 x 0.4 x 2.0 | top face at y = 0 |
| ceiling_tile | 2.0 x 0.4 x 2.0 | underside at y = 3.4 |
| doorway | 2.8 x 3.4 opening | frame and header, jamb overlaps the wall run |
| door_panel | 2.8 x 3.3 x 0.24 | driven by the existing LockedDoor / CockpitDoor pattern |
| wainscot | 1.05 high | lower band, laid against the wall face |
| trim_strip | 0.05 x 0.05, variable length | accent line |
| stair_flight | 4.2 m drop | deck to deck |
| ceiling_light | 1.6 x 0.12 x 1.6 | fixture plus OmniLight3D |
| window_unit | 7.6 x 3.4 x 0.38 | keeps WindowWall glass for the bays |

## What is reused, and what must change

Reused, unchanged:

- The five puzzle scripts. Puzzles are geometry-independent: each room needs a
  ConsoleInteractable parent and a puzzle path, and the puzzle logic does not
  move.
- The exterior hull, the launch cutscene, the scoring system, the audio mix,
  the launch screen and the debrief.

Must change with the layout:

- `game.gd` wires puzzles, doors and triggers by group and node name. The new
  layout must keep the `Interactables/<Name>` contract and the puzzle node
  names, or `game.gd` is updated in the same task.
- `ship_hull.gd`: `MODULE_MIN`, `MODULE_MAX` and `CUT_REACH_X` must be extended
  to cover deck 2. The cutout currently spans Y -1.4..4.4, so most of deck 2
  falls outside it and hull geometry would render inside the lower rooms.
- Deck 2 needs its own lighting and ambience. The current fog and ambient are
  tuned for the corridor alone.

## Risks to settle during the build

1. **Per-deck fit.** The hull must actually enclose each room box. `_band()` in
   `ship_hull.gd` already measures the hull's real cross-section across a Y
   range, so every deck's footprint can be checked against the hull at that
   height before rooms are placed, rather than after.
2. **Vertical navigation.** Two decks plus a junction is more travel. The
   objective readout and the SHIPMIND kiosk have to make the next destination
   obvious, or the rebuild will feel slower rather than bigger.
3. **Deck 2 lighting.** A 28 x 22 hold lit like a corridor will read as a big
   corridor. It needs its own treatment.

## What has been built

Three scenes, each authored by a one-off tool under `scripts/dev/` and saved as
an ordinary editor scene under `res://scenes/world/`. All four tools extend
`scripts/dev/deck_builder.gd`, which owns the 3.50 m pack grid, the prefab
ownership rule, the shared doorway/console/door/trigger/flank vocabulary and the
receipt.

| scene | authored by | extent |
|---|---|---|
| `deck1.tscn` | `author_deck1.gd` | floor y 0, ceiling 4.06; spine Z -28..17.5, junction Z 0..7, three rooms |
| `stairwell.tscn` | `author_stairwell.gd` | deck 1 bay Z -38.5..-28, deck 2 landing Z -42..-31.5, switchback stair turning at Z -35.0 |
| `deck2.tscn` | `author_deck2.gd` | floor y -4.86, ceiling -0.80; floor and ceiling Z -31.5..17.5, walls Z -38.5..17.5 |

`interior_slice.tscn` instances all three plus the player and the UI. That is the
walkable interior.

All five systems now exist, with their consoles, sealed doors, bay triggers and
SHIPMIND arrival lines:

| system | deck | position | door |
|---|---|---|---|
| Navigation (1) | 1 | starboard forward | none - left open on purpose |
| Life Support (2) | 1 | port amidships | sealed |
| Comms (3) | 1 | port forward | sealed |
| Cargo (4) | 2 | starboard aft hold | sealed, on the spine at Z -14.0 |
| Engineering (5) | 2 | starboard forward | sealed, on the spine at Z 10.5 |

Each deck also has its own SHIPMIND kiosk in its junction, both wired to
`hub_terminal.gd`.

### Deviations from this spec, each for a structural reason

- **Deck 2's junction is on the port side**, not centred. A centred junction
  reaches X +5.25 and the starboard rooms reach X +1.75, so the two floors would
  be laid at the same height in the same place.
- **The shaft's forward face is closed only across the 0.80 m slab band.** A
  full-height head wall there boxes the lower landing in completely: deck 2's
  spine continues forward from that plane, so the crew would come down the stair
  and find no way out.
- **The stair is a switchback, not one straight flight.** A straight flight can
  only meet a floor at its HEAD. The first build ran one 27-step flight aft from
  deck 1's floor to deck 2's, which put the crew at the foot underneath the stair
  with the flight filling the corridor in front of them: there was no way past it
  to the rooms, in any direction. Two half flights turning on a landing at
  Z -35.0..-38.5 fit the same bay and land them at Z -31.5 facing forward into
  the deck. Each flight is 1.455 m wide, split by a 0.295 m divider on the centre
  line, with a 1.05 m guard across the lower flight's side at the head.
- **Deck 2's old forward stair spindle is closed.** Its ceiling used to stop at
  Z 14.0 over an opening the earlier straight stair came down through, with the
  starboard wall opened for it too. With the stair moved aft that was a hole in
  the ceiling and a 3.5 m gap in the wall onto a region with no floor, so the
  ceiling now runs the full spine and the wall is unbroken there.
- **Deck 1's cross-corridor at Z -20 has not been built, and is no longer
  needed.** It was specified to reach rooms on both sides of the deck, but the
  final room placement puts all three Deck 1 rooms on the spine, so the spine
  already reaches every one of them. Build it if and when a room moves off the
  spine.
- **Deck 2 is 4 x 7 modules for cargo and 4 x 2 for engineering**, sized by the
  3.50 m grid rather than the 28 x 22 m hold sketched above. The hull's real
  beam at deck 2's height allows a wider deck later; the pack's module grid is
  what the rooms have to be built from.

### Windows, and what playing it turned up

The bay windows are back, and built on the pack grid rather than in a bay back: a
window drops exactly ONE 3.50 m panel from a room's outer wall, and the sill, the
header, the glass and its shutter fill that panel. Deck 1 carries three
(navigation, comms, life support) and deck 2 two (cargo, engineering), all
starting open, so the crew can see space from the first minute.

Two rules came out of building them:

- A window's centre must be a **panel centre**, not a panel boundary. An opening
  centred on a boundary is 3.50 m across two panels, so the wall drops 7.00 m and
  leaves a hole with the window standing in the middle of it. The builder now
  snaps the centre and says so in the receipt.
- A window's panes are built **once**. The authoring tools run in a live scene
  tree, so a script's `_ready` fires during authoring and what it builds is packed
  with the scene; without a guard each window carried a second pane on top of the
  first.

Walking the rebuilt interior also found three things that no receipt would have
shown:

1. Three exterior docking arms ran from the docked station straight through the
   life support room. They started at X -3.4, the old corridor's port wall; they
   now stop at -16.6, just outboard of the ship's own flank, and are 1.84 m long.
2. The stairwell's drawn steps ran the wrong way along the upper flight while the
   collision ramp under them was right, so the stair you could see did not match
   the stair you walked on.
3. The engineering console stood at Z -10.5, which is inside the cargo hold.

## Window jambs: the pack's wall panel is an open shell

The second walk-through reported "gaps between the walls and windows". Those were
not a placement error. `Wall_01` carries eight vertices and six triangles - the
inner surface and its two chamfered ends - and no side face and no outer face at
all, so a panel CUT by an opening leaves a hole clean through the wall's 0.295 m
thickness and the crew look out at space down each side of the glass. The sill
and the header never had this problem because both are solid blocks.

Flanking the opening the way a doorway is flanked would be wrong here: a window
clears exactly one 3.50 m module, so its neighbouring panels already are its
jambs. Instead `deck_builder._window` now builds a solid 0.12 m `WIN_JAMB` strip
at each edge of the opening, between sill and header, and the glass is set 0.02 m
into each jamb so its own edges are buried inside them instead of meeting them in
a coplanar face. The saved scenes confirm it: deck 1 carries
`Window_*_Jamb_A/B` for all three windows and deck 2 for both.

## The cockpit is an authored scene

`res://scenes/world/cockpit.tscn` is written by `scripts/dev/author_cockpit.gd`
through `scenes/dev/author_cockpit.tscn`, run once exactly like the deck authors,
and `station.tscn` instances it as its `Cockpit` node. `cockpit_room.gd` was
deleted in the same task; it was the last runtime level builder left in the game
and nothing referenced its node name or its class. The authored bridge keeps the
same envelope - half width 2.985, height 3.40, Z 17.5..28.15 - so the CockpitHelm
aim volume at Z 22.6 still stands on its own console.

Two pieces of the authored bridge need saying:

- The imported crew chair arrives with the collection's own materials and no
  physics. It carries `scripts/world/prop_paint.gd`, a runtime script that
  repaints every mesh under it into `seat_warm.tres`, because a chair left in the
  collection's shipped colour is the one piece of cool furniture on a warm ship.
  Its collision is a separate invisible blocker, so the model and the solid box
  cannot drift apart.
- The cockpit is a saved scene like the decks, so it must be regenerated whenever
  its authoring tool changes rather than being edited in the editor alone.

## The wall frame, and why every gap was really one gap

The recurring "gaps between the walls and windows, floors and ceilings" were all
one property of the kit. `Wall_01` is an **open shell**, not a box: eight
vertices, six triangles, carrying only the inner surface and its two chamfered
ends. There is no side face and no outer face at all. Everything the crew were
seeing follows from that:

- A panel cut by an opening leaves a hole clean through the wall's 0.295 m
  thickness, so an open window showed space down each side of the glass.
- Two perpendicular wall runs meeting at a corner left the panels' open ends
  facing each other, so the corner was a hole.
- Where a panel's chamfered top or bottom met a floor or ceiling tile, the join
  was not a face either.

The fix is one piece of shared machinery rather than a patch per symptom.
`deck_builder._wall_frame` builds a **frame** on every wall run: a skirting band
at the foot, a matching cove at the head, and a full-height post at every
opening edge and every run end. `_wall_spans` returns the run's solid stretches
with the openings removed, so a post lands on both sides of each doorway and
window, not only at the run's two ends. `_wall_run_z` and `_wall_run_x` call it
for the same span they place panels over, so a new deck gets the frame for free
and no run can be built without it.

The frame is deliberately a hair thicker than the wall (the wall's thickness plus
0.02 m, so 0.02 m proud on each side). That is what lets it close the panel's own
chamfer rather than sit inside the hole the chamfer leaves.

## The stairwell's head band stood in the climb

The band closing the void's forward face across the 0.80 m slab straddled the
void's own plane at Z -31.5, so it poked 0.1475 m proud of the upper flight's
ramp right where that ramp arrives at deck 1's floor. Walking down never touched
it - the descent meets the plane from above - so the stair looked correct from
the top. Walking **up** hit it as a 0.10 m wall and the crew could not leave the
stairwell. It is now shifted aft so its forward face sits *on* Z -31.5, flush
with the plane rather than across it.

This was measured rather than reasoned about. `scripts/dev/probe_ascent.gd`
drives a real `CharacterBody3D` up each flight and reports where each leg ended,
how far it moved, and which body it last stood on:

| leg | before | after |
|---|---|---|
| lower flight, from deck 2 | 7.55 m, ends on the turn platform | unchanged |
| upper flight, from the turn | 3.35 m, ends at y -0.259 against `HeadBand` | 7.59 m, ends at y 0.000 on `lobby_F00` |

Run it after any stair change: a leg that ends short of its flight's head names
the blocking body. The general rule it enforces is that the player has **no
step-up code** (`player.gd` walks with `move_and_slide` only), so any proud lip
in a walking surface is a wall - which is also why the stair's steps are drawn
only, with one invisible ramp carrying the collision.
