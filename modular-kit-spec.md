# Modular kit spec - corridor, doors, walls, ceiling, windows

This is the exact geometry the station uses today, so a kit built to these
numbers drops straight in as a swap with no layout change. Build it to this
and I will replace the placeholder shell without touching the puzzles,
consoles, triggers or doors' behaviour.

## 1. Conventions (please follow these exactly)

- Format: .glb, Y up, units in METRES at 1 unit = 1 m.
- Pivot: at the BASE CENTRE of each piece. Base sits at y = 0 in the file.
  Every problem we have had with props floating or sinking came from stray
  pivots, so this one rule matters more than any other.
- Orientation: author each wall run lying along +X, height along +Y, thickness
  along +Z. I rotate and place them. Do not pre-rotate anything.
- Scale: 1.0 on import. Do not bake a scale into the piece.
- Name each mesh node clearly (Wall_Run, Door_Frame, Window_Glazing...). I
  match by name, and a wrongly named node is worse than a missing one.
- Detail budget: the asset you gave me was 2.9 MB for one module, which is a
  good ceiling. Keep each component under roughly 20k triangles.

## 2. The layout being filled

Corridor interior: 6.3 m wide (x -3.15..+3.15), 3.4 m tall (y 0..3.4),
36 m long (z -18..+18). Floor top surface at y = 0. Ceiling underside at
y = 3.4.

Five bay openings, each 2.8 m wide x 3.4 m tall (full wall height):

| Bay         | Wall plane | Opening centre (z) | Opening spans (z) |
|-------------|-----------|--------------------|-------------------|
| NAVIGATION  | x = -3.15 | 13                 | 11.6 .. 14.4      |
| COMMS       | x = -3.15 | 1                  | -0.4 .. 2.4       |
| ENGINEERING | x = -3.15 | -12                | -13.4 .. -10.6    |
| LIFE SUPPORT| x = +3.15 | 7                  | 5.6 .. 8.4        |
| CARGO       | x = +3.15 | -5                 | -6.4 .. -3.6      |

Blind wall runs between and beside those openings (what I need panels for):

| Wall plane | Runs (z start -> z end), length |
|-----------|----------------------------------|
| x = -3.15 | 14.4 -> 18.0 (3.6), 2.4 -> 11.6 (9.2), -10.6 -> -0.4 (10.2), -18.0 -> -13.4 (4.6) |
| x = +3.15 | 8.4 -> 18.0 (9.6), -3.6 -> 5.6 (9.2), -18.0 -> -6.4 (11.6) |

Wall thickness: 0.3 m. Two end caps close the corridor at z = -18 and z = +18,
each 6.3 m wide x 3.4 m tall x 0.3 m thick.

Each bay is 8.0 m deep, 7.0 m wide, 3.4 m tall, sitting behind its opening:

| Bay         | Back wall plane | Bay spans (z) | Side walls |
|-------------|----------------|---------------|-----------|
| NAVIGATION  | x = -11.15     | 9.5 .. 16.5   | 2         |
| COMMS       | x = -11.15     | -2.5 .. 4.5   | 2         |
| ENGINEERING | x = -11.15     | -15.5 .. -8.5 | 2         |
| LIFE SUPPORT| x = +11.15     | 3.5 .. 10.5   | 2         |
| CARGO       | x = +11.15     | -8.5 .. -1.5  | 2         |

The floor and ceiling slabs each cover the whole footprint: 22.3 m (x) by
36.3 m (z). That is corridor plus both bay rows; there are no gaps to fill.

## 3. Components to supply

### A. Wall panel module (the workhorse)
- Size: 2.0 m long x 3.4 m tall x 0.3 m thick.
- Pivot: base centre.
- Desired: repeatable, with a panel seam/trim so a run reads as tiles rather
  than one slab. Include a subtle cyan emissive accent line and a black trim
  edge, matching the hallway asset you sent.
- Also useful: a half module 1.0 m and a quarter 0.5 m so I can close the odd
  lengths (3.6, 4.6, 9.2 runs are not multiples of 2).
- I will tile these along the runs in section 2.

### B. Door frame module
- Fits a 2.8 m wide x 3.4 m tall opening in a 0.3 m thick wall.
- Supplies the reveal/jamb so the opening is not a raw hole, plus a header.
- Same panel finish as A.

### C. Door panel (x4: life support, comms, cargo, engineering)
- Size: 3.0 m wide x 3.3 m tall x 0.2 m thick.
  Slightly wider than the 2.8 opening on purpose, so the ends bury inside the
  wall and no coplanar face can z-fight.
- Pivot: base centre, so it slides/hides cleanly when the bay opens.
- Desired: a two-leaf or ribbed sliding door reads best for a sealed bulkhead.
  It should look locked when shut - this is the object the AI is keeping from
  the player. Amber alert stripe optional.

### D. Window frame + glazing (x5, one per bay back wall)
- Opening: 7.0 m wide x 3.4 m tall, in a 0.3 m thick wall.
- Supply: a frame with a mullion pattern, using a transparent or
  very-low-roughness glass material. Keep the glass a SEPARATE material or
  mesh named glass - I hide the shutter behind it and the exterior is visible
  through it, so the alpha must be genuinely transparent.
- Note the engineering bay's back wall is the bulkhead door above, not a
  window; the other four are windows. Supply 5 window units and I will use 4
  of them plus the door.

### E. Floor module
- Size: 2.0 m x 2.0 m x 0.2 m, top surface at y = 0.
- Desired: dark deck plating with a vent/grille panel variant, matching the
  kit's Floor_and_vent look.
- I will tile these over the 22.3 x 36.3 footprint.

### F. Ceiling module
- Size: 2.0 m x 2.0 m x 0.2 m, underside at y = 3.4.
- Desired: white panel with an inset light strip - ideally one variant with an
  emissive panel so the corridor is lit by the ceiling rather than by the
  OmniLights I am using now.

### G. Trim kit (small, I will scale these)
- A cyan accent strip profile to run along wall mid-heights.
- A black skirting profile for wall bases.
- An amber bar for the lintel over each bay opening (currently 3.0 m long).
- Keep these as simple extruded profiles; I place and scale them.

### H. Consoles (optional, if you want them to match)
The four bay consoles plus the kiosk and the sensor relay currently use the
pinned shooter-scifi library props. My console script measures whatever model
it is given and fits the interaction box to it, so any size works. If you want
matching hardware:
- Standing console for a bay: about 1.6 m wide x 1.4 m tall x 1.0 m deep,
  pivot base centre, with a readable screen face angled toward the crew.
- A shorter kiosk variant, about 1.2 m x 1.4 m x 0.8 m.

## 4. What must not change

- The five opening positions and sizes in section 2. The puzzles, door
  triggers and bay areas are built around them.
- Floor at y = 0 and ceiling at y = 3.4. The player capsule and every console
  are placed against those heights.
- Wall thickness 0.3 m, so the openings stay aligned with the collision I keep.

If you would rather design a different layout than match this one, that is a
legitimate choice - but it means moving consoles, triggers, spawn and the
exterior windows with it, so tell me before you build and I will re-issue the
grid to your new dimensions instead.

## 5. Alternative, if a kit is too much work

Send ONE corridor .glb whose layout already contains the five openings at the
positions in section 2, with its own floor and ceiling. I will treat it as the
level and rebuild collision against it, the same way I would for a library
ready-scene. That is less flexible but far less work for you.

## 6. What I will do when it lands

1. Import, verify scale and pivots against this spec.
2. Replace the Shell box meshes with the kit pieces, keeping the collision
   layer and the five openings.
3. Re-attach the door panels, window shutters and the five window nodes to the
   new geometry and update every shutter_path.
4. Reload, boot, and check nothing is orphaned - then hand it to you to look at,
   because I cannot see the result myself.
