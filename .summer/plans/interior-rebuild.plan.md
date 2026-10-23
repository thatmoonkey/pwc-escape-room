---
name: interior-rebuild
overview: >-
  Rebuild the Adamant Verity interior as a spine-and-rooms layout across two
  decks, using the hull's own measured volume, with levels authored as editor
  scenes instead of generated at runtime.
createdAt: '2026-10-20T08:28:59.546Z'
todos:
  - id: layout-spec
    content: >-
      Write the measured layout spec: deck heights, room schedule, circulation,
      prefab list, and what retires.
    status: completed
  - id: prefabs
    content: >-
      Build the clean editor-authorable prefab set (wall, floor, ceiling,
      doorway, door panel, wainscot, trim, stair, light) with correct pivots and
      collision in the existing maroon palette.
    status: completed
  - id: deck1-slice
    content: >-
      Author the Deck 1 vertical slice: junction, spine and the Navigation room
      as a real scene, walkable, with the Nav console wired.
    status: completed
  - id: vertical
    content: >-
      Add the stairwell and Deck 2 spine landing, and extend the hull cutout box
      down to cover both decks.
    status: completed
  - id: rooms
    content: >-
      Build the remaining four system rooms and the cross-corridor, and migrate
      every console, door and trigger onto the new layout.
    status: completed
  - id: cockpit-run
    content: >-
      Rebuild the cockpit to the new structure, re-fit the launch cutscene, and
      play the full five-system run.
    status: completed
  - id: prefabs-authored
    content: >-
      Author the prefabs the three kits cannot supply - room wall panel, wall
      corner, doorway, door panel, wainscot, trim strip, ceiling tile, stair
      flight and ceiling light - as maroon box geometry with collision on layer
      2.
    status: cancelled
  - id: deck-swap
    content: >-
      Swap station.tscn onto the authored deck1 + stairwell scenes, retire
      kit_shell.gd / station_dressing.gd / cockpit_room.gd as level builders,
      and extend ship_hull.gd MODULE_MIN/MAX to cover both decks and the
      stairwell.
    status: completed
  - id: rooms-deck2
    content: >-
      Extend Deck 1 aft with the cross-corridor at Z -20, then author Deck 2:
      its spine, the aft cargo hold and the mid-starboard engineering room, with
      their consoles, doors, triggers and a second SHIPMIND terminal, authored
      by a new subclass of deck_builder.gd into res://scenes/world/deck2.tscn.
    status: completed
  - id: bay-windows
    content: >-
      Restore the bay reveal: cut a window opening in each system room's outer
      wall, flank it like a doorway, and re-add the WindowWall nodes so taking a
      system back opens that bay onto the exterior.
    status: completed
  - id: full-run-playtest
    content: >-
      Play the whole game end to end: the five system puzzles, each bay door,
      the cockpit gate, the helm launch and the debrief, and confirm the window
      views, the stair and the bridge all read correctly on screen.
    status: pending
---
# Interior rebuild - spine, junctions, rooms, two decks

Scope agreed: **interior only**. The exterior hull, the five puzzles, scoring,
audio, launch screen and debrief all stay. The interior geometry is replaced.

## The measured envelope (runtime receipt, this session)

Hull in world space: X -16.3..16.4 (32.7 beam), Y -12.0..26.4 (38.4 tall),
Z -50.0..64.0 (114.0 long). Sampled across the ship's height:

| sample Y | beam | usable Z run | run length |
|---|---|---|---|
| 9.1 | 23.2 | -49.9..12.0 | 61.9 |
| 5.4 | 32.1 | -50.0..15.2 | 65.2 |
| 1.7 | 32.4 | -50.0..56.0 | 106.0 | deck 1 today |
| -2.0 | 32.6 | -50.0..63.9 | 113.9 |
| -5.7 | 32.7 | -41.0..59.8 | 100.9 |
| -9.4 | 30.0 | -30.0..64.0 | 94.0 |

The widest, longest band is BELOW deck 1. Above it the forward run collapses
from +56 to +15 and the beam pinches to 23.2. So deck 2 goes down, and a third
deck is still possible lower still.

Today the interior occupies Z -18.6..28.4 only: 47 m of a 114 m ship, 4.2 m of
38.4 m of height, one straight line.

## Deck stack

- Deck 1 (command): floor y=0.0, ceiling y=4.06. Existing deck.
- Structure: 0.8 m slab and services between decks.
- Deck 2 (industrial): ceiling y=-0.8, floor y=-4.86. Samples Y -2.0 and -5.7,
  so it gets the ship's best space: 32.6-32.7 beam and 100+ m of run.
- Deck 3: optional later, floor y=-9.72, 30.0 beam, 94 m run.

Every deck is 4.06 m high, raised from 3.4 m by user decision so the
sci-fi_interior_pack wall panels (3.50 x 4.06 x 0.30) fit unscaled and the room
set lands on the pack's native 3.50 m grid. The hull has 38.4 m of height and two
decks use under 10 m, so it fits either way.

## Circulation

Spine, not one line. A central junction on each deck, a spine corridor forward
and aft of it, one cross-corridor athwartships on deck 1, and a stairwell on
the aft spine joining the decks.

- Deck 1: bridge (forward, existing Z 18..28.1) - junction Z 2..10 containing
  the SHIPMIND kiosk - spine forward to the bridge gate and aft to Z -40 -
  cross-corridor at Z -20 - stairwell down at Z -28..-34.
- Deck 2: spine under the deck 1 spine - stairwell landing - cargo hold aft
  (about 28 x 22) - engineering room forward - a second SHIPMIND terminal.

## Room schedule

- Deck 1: Navigation (forward starboard, 8 x 8), Comms (forward port, 8 x 8),
  Life Support (mid port, 8 x 8).
- Deck 2: Cargo (aft hold, 28 x 22), Engineering (mid starboard, 10 x 8).

Every room is fully enclosed with its own door, its own lighting and its own
ambience. That is the point of the rebuild: a sealed room can be locked, dark
or on a countdown, which a 7 m alcove open to a corridor never can.

## Build method

Levels are authored as scenes with real nodes, not generated in code at load.
`kit_shell.gd`, `station_dressing.gd` and `cockpit_room.gd` retire for the
interior. The reason is practical: today the corridor does not exist in the
editor, so nothing can be hand-placed and the layout cannot be looked at
without pressing Play.

Walls come from a clean prefab set with height on Y, pivot at base centre and a
matching CollisionShape3D. The current maroon kit fails its own declared
dimensions on 6 of 15 modules, including both consoles and every ceiling and
door part, which is why all that measuring and axis-guessing code exists.

Materials are reused as-is, so the maroon identity survives and no new asset is
needed: wall_upper #AD2323, wall_lower #4F1010, trim_black, floor_dark,
panel_light, accent_amber, accent_cyan, door_locked, seat_warm.

Prefabs: the wall kit now EXISTS at res://scenes/prefabs/interior - wall
(Wall_01-06, 3.50 x 4.06 x 0.30 m, plus a 1.65 x 1.48 x 0.83 corner piece),
doorway (Doorway_01-02), door panel (Door_01-02), floor tile (FloorTile_01-09),
ceiling (Ceiling_01), sliding window (SlidingWindow_01-02), crate (Crate_01-04)
- all extracted from sci-fi_interior_pack_lowpoly.glb and recoloured through
shaders/ember_recolour.gdshader. Still to author by hand: wainscot (1.05 h),
trim_strip,
stair_flight, ceiling_light, window_unit.

## What is reused and what must change

- Puzzles are geometry-independent. Each system room needs a
  ConsoleInteractable parent and a puzzle path; the puzzle scripts do not
  change.
- `game.gd` wires by group and node name, so the new layout must keep the
  `Interactables/<Name>` contract and the puzzle node names, or game.gd is
  updated with it.
- `ship_hull.gd`: MODULE_MIN/MAX and CUT_REACH_X must be extended to cover
  deck 2. Today the cutout spans Y -1.4..4.4, so most of deck 2 sits outside
  it and the hull would render inside the lower rooms.
- `launch_cutscene.gd` and the exterior are untouched.

## Risks to settle during the build

- Per-deck fit: the hull must actually enclose each room box. `_band()`
  already samples the hull across a Y range, so each deck's footprint can be
  checked against its real cross-section before rooms are placed.
- Deck 2 needs its own lighting and ambience; the current fog and ambient are
  tuned for the corridor only.
- Travel time grows with two decks, so the SHIPMIND kiosk and the objective
  readout have to make the next destination obvious.
