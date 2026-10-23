# sci-fi_interior_pack_lowpoly.glb - review and extraction

The walls-and-doors pack. Reviewed, extracted and verified in this session.

## What the file is

`res://assets/kit/sci-fi_interior_pack_lowpoly.glb`, 6,497,396 bytes, 8 textures
(up to 3.4 MB each). Seven named parts, 2,559 triangles total, 7 meshes.

Unlike the three earlier kits it is NOT a nameless showroom grid. Its parts are
named for what they are:

| part | islands | what each island is |
|---|---|---|
| `Walls_6` | 7 | six wall panels 3.50 x 4.06 x 0.30 m, plus one 1.65 x 1.48 x 0.83 corner piece |
| `FloorCeilings_9` | 9 | nine floor/ceiling quads 3.50 x 3.50 m, zero thickness |
| `Ceiling_Straight` | 1 | one more 3.50 x 3.50 ceiling quad |
| `Doorways` | 2 | two door frames 4.06 m high, 4.09 m wide, 0.31 and 0.78 m deep |
| `Doors` | 2 | two door panels 3.87 m high, 3.69 m wide, 0.25 and 0.28 m thick |
| `SlidingDoor_Window` | 2 | two window quads 1.18 x 1.72 m, zero thickness |
| `Crates` | 4 | four crates, 1.55 - 1.74 m on a side, 336 - 687 tris |

The parts are merged: `Walls_6` is ONE mesh of 128 triangles holding six panels
side by side in a display row. Instancing it would drop six walls into a room at
once, so each part is split into its connected islands before use.

## Scale

**Native x1.0. This pack is already authored in real metres.** The wall panel is
3.50 m wide and 4.06 m tall, floor tiles are 3.50 x 3.50, door panels are 3.87 m
tall inside a 4.06 m wall, and the crates are about 1.6 m cubes. No correction
factor is needed, unlike the other three kits (x0.01, x0.1, x7.7).

The 3.50 m module and 4.06 m wall height are the pack's own grid, and the door
frame at 4.09 m wide matches the wall height exactly. The kit is internally
consistent at this scale.

## The 27 extracted prefabs

`res://scenes/prefabs/interior/` - all 27 verified: every one loads, every one
carries a MeshInstance3D and a CollisionShape3D on layer 2, and every one has
its pivot at the base centre of its own bounding box, so a placement writes a
floor position and the object sits on it.

- `Wall_01` - `Wall_06`: 3.50 x 4.06 x 0.30 m
- `Wall_07`: 1.65 x 1.48 x 0.83 m (corner / trim piece)
- `FloorTile_01` - `FloorTile_09`, `Ceiling_01`: 3.50 x 3.50 m flat quads
- `Doorway_01`, `Doorway_02`: 4.09 m wide frames
- `Door_01`, `Door_02`: 3.87 m tall panels
- `SlidingWindow_01`, `SlidingWindow_02`: 1.18 x 1.72 m panes
- `Crate_01` - `Crate_04`: about 1.6 m cubes

### Flat quads and collision

The floor tiles, ceiling tiles and windows are zero-thickness quads. A box with
no height has no surface to stand on, so the extractor gives every collision box
a 0.05 m minimum thickness and aligns the TOP face of the collision with the top
of the geometry. A floor tile placed at a deck's floor level therefore has its
walking surface exactly there, while the visible mesh stays flat.

### Doorway frames carry one solid box, so a doorway is authored differently

`Doorway_01`'s own `CollisionShape3D` is ONE box spanning the whole frame,
4.089 m wide - a wall, not an opening. It cannot simply be switched off from an
authoring script: a property override on a child of an instanced scene is written
only by the editor's "editable children" flow, and `PackedScene.pack()` either
drops such a child or (when the child is re-owned by the scene root) writes it as
a second, local node that leaves the prefab's own active box underneath it. Both
routes leave the room sealed, which was measured on this build: the override line
is accepted without complaint and the shape still loads with `disabled = false`.

So a doorway in a level is built as the prefab's frame MESH in a body of its own,
with one collision box per upright and the opening clear between them. The mesh is
copied into the level by value, so a re-extract of the pack means re-authoring the
level that uses it.

## Two conflicts with the project rules - RESOLVED

Both were put to the user and decided. The options below are kept as the record
of what was weighed.

### 1. Wall height 4.06 m against the 3.4 m deck rule - DECIDED: raise the deck

`.summerrules` fixes every room at 3.4 m high on both decks (deck 1 floor y=0
ceiling y=3.4; deck 2 ceiling y=-0.8 floor y=-4.2). This pack's wall panel is
4.06 m, and its doorway and door are sized to that.

- Fit the pack to the rule: uniform x0.8374, wall 2.93 x 3.4 x 0.25 m. The
  module becomes 2.93 m, so an 8 m room is 2.73 modules - an awkward grid.
- Fit the rule to the pack: raise the deck to 4.06 m. Deck 2 floor moves to
  y=-4.86. The hull has 38.4 m of height and the two decks use under 10 m, and
  the measured profile at y=-5.7 still gives 32.7 m beam and 100.9 m of run, so
  the hull fits either way. This keeps the pack's own clean 3.50 m grid, its
  door proportions, and needs no scaling at all.

### 2. The pack's palette is cool teal and blue - DECIDED: recolour, keep detail

Rendered, the pack's own textures are teal walls, blue floor plates and blue
window panes, against `.summerrules`: "No cool blue or green in the interior."

DONE. Every prefab now carries a ShaderMaterial using
`res://shaders/ember_recolour.gdshader`. It reads each albedo as pure luminance
and maps that onto a warm ramp per part family - walls #4F1010 low to #AD2323
high, doors #5A1408 to #D04026, windows amber, floors and ceilings near-black
warm - and re-tints the kit's own emission map amber. Panel seams, rivets and
shading survive; the pack's hue does not.

Confirmed by a runtime readback of the rendered frame rather than by eye: mean
RGB 0.462 / 0.240 / 0.234 over 490 lit pixels, 453 warm against 0 cool.

Note for later: an edit-time staged render draws these prefabs flat white,
because the staged previewer does not compile a custom shader. That is a
previewer limitation, not a material fault - check a recoloured surface in the
running game.

- Recolour: override with the maroon palette (wall_upper #AD2323, wall_lower
  #4F1010). A flat override loses the panel detail that lives in the albedo and
  normal maps; a small shader that reads the albedo as luminance and multiplies
  by a warm colour keeps the panel seams and the normal detail while landing on
  the ember palette.
- Keep the pack's look: contradicts the stated art direction.

## What the pack closes and what is still missing

Closed: wall panels, doorway, door panels, floor tiles, ceiling tiles, windows,
crates. This is exactly the gap the three earlier kits left.

Still missing, and still needing authoring in the maroon palette: wainscot /
lower wall band, trim strip, stair flight, and ceiling light. `Wall_07` and the
`DeckPlate` set from the floor kit can serve the spine floor.

## Re-extracting

`scripts/dev/extract_interior_pack.gd`, run through
`scenes/dev/extract_interior_pack.tscn`. Set `DRY_RUN = true` to re-measure
without writing, `SCALE` to re-extract at a different factor. It writes only
into `res://scenes/prefabs/interior` and the game never calls it.

`scripts/dev/verify_prefabs.gd` through `scenes/dev/verify_prefabs.tscn` loads
every prefab in a folder and reports any that fail to load, carry no mesh, carry
no collision, or have a pivot that is not at the base.
