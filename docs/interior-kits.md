# Interior kits - measured assessment and rebuild plan

This assesses the three kits now in res://assets/kit/ and sets out how the
approved interior rebuild (spine, junctions, enclosed rooms, two decks) uses
them. The exterior hull, the five puzzles, scoring, audio, the launch screen and
the debrief are all untouched.

## How these numbers were obtained

Each GLB was measured twice, with the engine's importer kept honest by the
file's own inventory:

1. The GLB container was read directly. A GLB is a header plus a JSON chunk that
   lists every node, mesh, material and image in the file, so the file's own
   contents can be counted without trusting any importer.
2. The imported PackedScene was instantiated and every part measured - its
   bounding box, its triangle count, its pivot and its position - with sizes
   taken relative to the kit root, so any scale on the import wrapper is
   already included. These are the sizes a part has once placed.

Everything below is measured, except where it is marked as a recommendation.

## The single most important finding

All three files are Sketchfab **display arrangements**, not drop-in scenes. Each
kit's parts sit at their own offsets in a showroom grid: the floor kit alone
spans 6900 x 5300 units. Dropping a GLB into the level therefore gives you a
scattered grid of parts floating in mid-air, not a room.

The workflow is fixed by that: **import the kit, extract one part into its own
scene, re-origin it, give it collision, save it as a prefab.** The GLB is a
quarry, not a prefab.

The second consequence is that each kit needs its own uniform scale correction,
and they are wildly different - x0.01, x0.1 and x7.7 (below). No single world
scale works, so the factor belongs on the extracted prefab, written down, and
never guessed again at placement time.

## Scale table

| kit | file size | parts | tris | own units | correction | result |
|---|---|---|---|---|---|---|
| modular_sci-fi_floor | 7.7 MB | 21 | 35,687 | 800-1000 across | **x0.01** | deck plates 8-10 m, 0.64 m thick |
| sci-fi_modular_terminal_toolkit | 4.4 MB | 16 | 2,024 | 7.5-29 across | **x0.1** | consoles 0.75-1.0 m, ceiling screens to 2.9 m |
| spaceship_interior | 35.8 MB | 183 | 13,351 | whole kit 1.98 long | **x7.7** | corridor 15.3 x 3.2 x 3.4 m |

The x7.7 for the corridor kit is not arbitrary: the kit's own interior height is
0.44 units, and 3.4 / 0.44 = 7.7 puts its ceiling exactly on our deck height. At
that factor it is 3.2 m wide, which is a corridor, and 15.3 m long, which is a
good spine segment.

## Kit 1 - modular_sci-fi_floor.glb - floors: USE IT

- 7,689,824 bytes, generator Sketchfab-14.49.0
- Container: 45 nodes, 21 with a mesh, 21 meshes, 1 material, 4 images, 0 animations
- Imported: 21 parts, 21 meshes, 35,687 tris
- Textures: 2048x2048 on all 21 surfaces
- Parts: 800-1000 x 64.4 x 800-1000 units, all thin slabs (thickness 6-8 percent
  of length). Largest is exactly 1000.00 x 64.41 x 1000.00.
- Pivot: part origins sit at y=0 with the box starting at y=-0.95, i.e. base
  pivot - a plate can be placed by writing a floor position.
- Part names are opaque: Cube.000 to Cube.020.

At x0.01 this is a set of **8-10 m square deck plates, 0.64 m thick**. That is
exactly what a 28 x 22 m cargo hold, a spine and a junction floor want: three
plates cover a 28 m hold, one covers an 8 x 8 m room. It is not a fine tiling
system - 8 m is the smallest plate here - so rooms below about 8 m square want
the plate trimmed or the maroon floor_dark material instead.

The 0.64 m thickness matters: place the plate so its **top** face lands on the
deck floor, not its origin, or every floor sits 0.64 m too high.

## Kit 2 - sci-fi_modular_terminal_toolkit.glb - consoles and screens: USE IT

- 4,395,616 bytes, generator Sketchfab-15.44.0
- Container: 60 nodes, 42 with a mesh, 42 meshes, 16 materials, 17 images, 0 animations
- Imported: 16 parts, 42 meshes, 2,024 tris
- Textures: 512x512 on 14 surfaces
- Shape mix: 5 flat plates, 1 thin slab, 10 solid volumes - i.e. consoles and screens
- Parts: 7.45-29.23 units. Largest 29.23 x 13.16 x 9.51.
- Parts are named in German, and the names are meaningful, which makes part
  selection easy:
  - **Modulare Konsole** 45, 45 aussen, 90, 90 aussen, Grade, Grade mit Fuss, Screen
  - **Decken Screen** (ceiling screen) 2x45, 45, 90, big, small
  - **Holoscreen** Einfach and Komplex, each as Bild (image) and Rahmen (frame)

At x0.1 this is the console, terminal, wall-screen and ceiling-screen set the
five system rooms need. The names map straight onto the game: a Modulare
Konsole for each system console, a Holoscreen for SHIPMIND's kiosk faces, a
Decken Screen for lit ceiling panels in the junction and the cockpit.

Two honest caveats. It is very cheap geometry (2,024 triangles for all 16
parts) and only 512x512 textures, so the model is a **frame** - the readouts the
player actually reads are drawn by our own terminal UI, which is the right split
anyway. And at x1.0 these parts would be 7-29 m, i.e. room-sized; x0.1 is the
factor that makes them furniture, and it should be confirmed by eye once
extracted.

## Kit 3 - spaceship_interior.glb - corridors: USE IT, AS A CORRIDOR

- 35,825,176 bytes, generator Sketchfab-15.26.0
- Container: 368 nodes, 183 with a mesh, 183 meshes, 16 materials, 56 images, 0 animations
- Imported: 183 parts, 183 meshes, 13,351 tris
- Textures: 2048x2048 across all 183 surfaces
- Shape mix: 17 flat plates, 68 thin slabs, 98 solid volumes
- Sizes are tiny as imported: 35 parts under 1 cm, 104 under 10 cm, 44 under
  50 cm. The largest single part is 0.34 x 0.06 x 0.40 - four triangles, so a
  flat quad.
- The whole kit occupies 0.42 x 0.44 x 1.98 units: elongated 4.5 to 1, which is
  corridor proportions.
- Part names are useless: defaultMaterial and g102, g110, g111 and so on.

This is the kit the numbers alone could not settle, so it was rendered. Scaled
to x10 it reads as **an enclosed passage with side walls, a floor, a ceiling,
panelling and doorway openings**, built from modular segments joined linearly.
So the expectation that it holds hallways, doors and windows is right - but it
holds them as **one joined corridor arrangement of 183 small parts**, not as a
box of separate door and window modules you can assemble freely.

At x7.7 it is a 15.3 x 3.2 x 3.4 m corridor segment that matches our deck
height. Place two or three along the spine and the aft cross-corridor.

**Memory warning.** The file is 35.8 MB, almost all of it 56 textures, and one
loaded instance carries all of it. Do **not** instance the whole GLB five times
to make five corridors - that is five copies of the texture set. Extract the
parts for one corridor segment into a small prefab scene once, then instance
that lightweight scene repeatedly.

## What is reused, and what retires

- The maroon palette stays. `wall_upper` #AD2323, `wall_lower` #4F1010,
  `trim_black`, `floor_dark`, `panel_light`, `accent_amber`, `door_locked`,
  `seat_warm`. These are unchanged and still define the look.
- The rebuilt prefab set: `floor_plate_8` and `floor_plate_10` (kit 1),
  `corridor_segment` (kit 3), `console_45`, `console_90`, `ceiling_screen`,
  `holoscreen` (kit 2), plus the maroon wall, wainscot, trim, doorway and door
  panel authored as plain scenes.
- Every prefab gets its own CollisionShape3D on layer 2. **No kit supplies
  collision** - none of the three has any.
- `kit_shell.gd`, `station_dressing.gd` and `cockpit_room.gd` retire for the
  interior. The rebuilt level is authored as real nodes in real scenes, which is
  the whole point: today the corridor does not exist in the editor, so nothing
  can be hand-placed and the layout cannot be looked at without pressing Play.

## Rebuild plan

Keeping the approved scope (interior only) and layout (spine, junctions,
enclosed rooms, two decks), and the measured deck stack from
docs/rebuild-layout.md: deck 1 floor y=0.0 ceiling y=3.4; deck 2 ceiling y=-0.8
floor y=-4.2; every room 3.4 m high so one prefab set serves both.

1. **Prefabs.** Extract from the three kits at the factors above into
   res://scenes/prefabs/, each with collision, each with its factor written into
   the prefab name or a comment so it is never guessed again. Author the maroon
   wall, wainscot, trim, doorway and door panel alongside them.
2. **Deck 1 slice.** Junction at Z 2..10 with the SHIPMIND kiosk (Modulare
   Konsole plus Holoscreen), spine forward to the bridge gate and aft to Z -40,
   and the Navigation room at 8 x 8 forward starboard. Walkable, with the Nav
   console wired through the existing ConsoleInteractable, and the existing
   puzzle scripts unchanged.
3. **Vertical.** Stairwell on the aft spine at Z -28..-34, deck 2 landing and
   spine, and extend `ship_hull.gd` MODULE_MIN/MAX and CUT_REACH_X so the cutout
   covers deck 2. Today the cutout spans Y -1.4..4.4, so most of deck 2 would
   have hull geometry rendering inside it.
4. **Rooms.** Comms and Life Support on deck 1, then the deck 2 cargo hold
   (28 x 22, kit 1 floor plates) and Engineering (10 x 8). Each room fully
   enclosed with its own door, lighting and ambience, and its console migrated
   onto the new geometry.
5. **Cockpit run.** Refit the cockpit to the new structure with the terminal
   kit's ceiling screens and console banks, re-fit the launch cutscene, and play
   the full five-system run through to the helm and the debrief.

## Risks to settle during the build

- **Palette.** The kits' own textures are dark and neutral where our interior is
  warm maroon. Project rules exclude cool blue and green interiors. The plan is
  to keep maroon for wall, trim and wainscot, use kit geometry with our own
  materials where the surface is large, and accept the kit's own textures only
  on floors and consoles. This needs a look check once the first prefabs are
  placed.
- **Texture softness** on the terminal kit (512x512) on screens the player walks
  up to.
- **Scale confirmation by eye.** The floor and corridor factors are well
  supported (a 1000-unit plate reading as 10 m, a 0.44-unit interior reading as
  our 3.4 m deck). The terminal x0.1 is the one worth a second look.
- **Travel time** grows with two decks, so the SHIPMIND kiosk and the objective
  readout must make the next destination obvious.

## Verification notes

- All three kits were measured from their own file inventory and from the
  imported scene, and the two agree on counts.
- The corridor kit was confirmed visually at x10 in an edit-time render. A
  staged render showing all three side by side was not usable: the first two
  attempts captured black frames because the geometry was built at runtime and
  was not ready when the frame was taken. Declaring the kit instances in the
  scene file instead produced a legible frame, which is how the corridor was
  confirmed.
- Nothing in this document has been playtested in the running game.
