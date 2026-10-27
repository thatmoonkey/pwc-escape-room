# Adamant Verity - art direction and palette

## The palette

Five tokens, warm-only. There is no cool accent anywhere on the ship: the crew
spend the whole game inside SHIPMIND's interior, and the palette is the warm
end of an alert scale, so every surface reads as something that is switched on.

| Token | Hex | Where it lives |
|---|---|---|
| Warm Platinum | `#B2ACA4` | Wall panels, ceilings, crate bodies - the ship's silver base |
| Spicy Paprika | `#DC5E27` | Kicker text, terminal rule bar, sill lighting, the papaya accent light |
| Brick Red | `#AD2323` | Sealed door bodies, deep alert fills |
| Burnt Tangerine | `#D04026` | Alert/danger text and borders, step numerals, button edges |
| Sunflower Gold | `#F0B839` | Attention text, HUD border, resolved state, primary button, glow strips |
| White | `#FFFFFF` | Headline text only |

The ship's base is a warm platinum silver - a silver with the red-brown taken
out of it, not a cool grey - and the strong reds ride ON it as accents: doors,
hazard strips, alert fills. The red is the exception, which is what makes it
read. A wall panel is platinum; a door is brick red; gold is the light that
runs along the join between them.

Grounds are a warm near-black rather than a neutral one: panels sit on
`Color(0.06, 0.032, 0.022)`, not on grey or blue-black.

## The semantic scale

The palette has no green and no cool blue, so status is expressed as three
steps up the warm family rather than as the usual red/amber/green:

- info / neutral - warm sand `Color(0.93, 0.86, 0.76)` (replaced the old cyan)
- attention - gold `Color(0.941, 0.722, 0.224)`
- resolved - bright gold `Color(1.0, 0.88, 0.55)` (replaced the old green)
- alert - tangerine `Color(0.816, 0.251, 0.149)`

Resolved and attention are deliberately close in hue and separated by value,
with the word RESTORED and the `[x]` marker carrying the same meaning in text.
If a future screen needs them further apart, change the values here and in
`scripts/terminal/terminal_ui.gd` rather than inventing a sixth colour.

## Where the colours are set

Materials are the main lever - every wall, floor, ceiling, trim, door and screen
reads from a `.tres` in `res://materials/`, so the ship's palette can be retuned
without touching a scene. The filenames are historical (`accent_cyan.tres`
holds gold, `panel_blue.tres` holds warm off-white); they are kept because
scenes and scripts reference them by path.

- `wall_upper.tres` - the wall panels themselves, Warm Platinum. This is the
  material painted onto every kit wall module, so it is the colour the whole
  corridor reads as
- `wall_lower.tres` - the base band laid against those panels: the same hue
  taken down to a near-black neutral, so the wall reads as platinum with a
  dark skirt
- `panel_light.tres` - ceiling slab, warm off-white platinum
- `panel_blue.tres` - secondary panel with a low warm emission
- `floor_dark.tres`, `trim_black.tres` - warm near-black ground and trim
- `door_locked.tres` - sealed door, brick red with a dull ember emission. The
  doors are the ship's main red accent against the silver walls
- `accent_amber.tres`, `accent_cyan.tres` - the two accent strips
- `screen_cyan.tres` - console screen fill, gold emission
- `highlight.tres` - the aim highlight on interactables
- `window_glass.tres` - glass, warm-tinted and still transparent

Lighting lives in `scenes/world/station.tscn` under `Lights`, on the warm flood
colour `Color(0.97, 0.87, 0.72)`, with the environment ambient warm. The
exterior hull, the docking arms and the debris are warm dark metal and rock
rather than cool grey.

## The kit modules are repainted in code

The corridor walls, doors and window frames are the modular kit in
`res://assets/kit/modules`, and that kit carries its own grey baked into each
GLB. Those modules do not exist in the saved scene - `scripts/world/kit_shell.gd`
builds them at runtime - so no material saved in a scene can ever reach them.
The palette is therefore applied at the one place a module is placed, from the
`PAINT` table in that script. Changing a wall colour means changing that table,
not the scene.

## The two-tone wall

The whole interior uses one wall treatment: maroon wall panels with a deeper
band running along the bottom, separated by the kit's dark frames and doors. The
kit's wall module is a single full-height panel, so the lower tone is a separate
thin slab laid flat against the panel's inner face, built by `_wainscot()` at
`WAINSCOT_H` = 1.05 m.

The two materials read as one wall treatment: platinum panels over a near-black
skirting band. The panel material is the one the room reads as, so it is the
one that carries the wall colour.

Which of the wall's two faces is the inner one is derived per run rather than
assumed, so the same rule is correct for walls whose inner faces point along
three different axes.

## Space, seen through the glass

Space is deliberately near-black and slightly cool, so that it reads as outside
the ship rather than as another lit room:

- `background_energy_multiplier` 0.18 - the starfield is a dim backdrop
- `fog_sky_affect` 0.0 - the fog must NOT tint the sky. At any other value it
  paints over the starfield and the planet, and every window reads as warm haze.
  This is what made space look red.
- `fog_light_color` `Color(0.05, 0.055, 0.085)` - a cool dark, not the warm
  interior tone
- `fog_density` 0.0015 - enough to seat the hull in air, far too little to tint
  the planet 190 m out

The ambient light source is a flat colour rather than the sky, so the interior
keeps its warm light no matter how dark space gets. Keep it that way.

## Rules

- ASCII punctuation only, in every file.
- No cool blue or green anywhere in the interior. If a new system needs a
  status colour, use the scale above.
- Red is an accent, not a base: walls and floors are the platinum and
  near-black ramp, and the brick/tangerine reds belong to doors, alert fills
  and hazard detail. If a surface the size of a wall panel is asking to be
  red, the palette is drifting.
- Every interactable has to be legible at a glance: accents are for state, and
  text carries the meaning even in a screenshot with the colour stripped out.
- A `.tres` carries no comment lines. A comment inside one is not skipped - the
  loader loses the property block with it, so the resource still loads, still
  looks fine in the editor, and hands out its DEFAULT values instead. The two
  wall materials were documented this way and both resolved to `#ffffff` at
  runtime, which is why the corridor stayed white through two recolours: the
  panels and the base band were being painted with a default white material.

## Verifying a palette change

A colour change is not done until the number confirms it, because the failure
above looked exactly like a colour change that had not been made yet. The shell
prints what each palette material actually resolved to, and how many meshes were
painted with it:

```
[KitShell] modules=92 wainscots=78 retired=19 | face=ad2323 base=4f1010 |
painted wall_upper n=78, trim_black n=10, door_locked n=4
```

`face=` is the wall panel colour and `base=` is the lower band. `face=ffffff`
means the wall material is not loading its properties, whatever the file says.
`painted wall_upper n=78` means all 78 wall modules took it.
