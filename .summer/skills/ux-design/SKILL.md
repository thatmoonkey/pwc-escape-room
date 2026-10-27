---
name: ux-design
description: >
  UX design for the Adamant Verity escape room. Use when adding or changing
  any screen, overlay, HUD element, copy, or input flow in this game. Carries
  the design principles, the changes made from the original and why, and the
  rules for keeping new work consistent with them.
---

# UX design - Adamant Verity

## The principles this game follows

1. **The first screen is the first goal, not a manual.** The original launch
   screen opened with a briefing wall of text - the first thing a player read
   was an instruction manual. The restructure replaced it with the journey
   itself as the anchor: the three things the crew must do, as three icon
   tiles, with progress on each. If a screen's job is to tell the player what
   to do next, show the doing, not the describing.
2. **Progressive disclosure in two layers.** Primary layer: minimal, short
   statements, one line each. Secondary layer: curiosity-friendly buttons
   ("WHY YOU'RE HERE", "HOW IT'S JUDGED", "CONTROLS") that open a sheet in a
   slightly smaller type (13px vs 15px) where longer paragraphs are welcome.
   Detail is available, never compulsory.
3. **Icons anchor list items.** Every list item a player must remember - the
   three goals, the mandate objectives, the risk appetites, the five systems -
   carries a glyph next to its text, so the concept is anchored to a picture
   and the player does not re-read the words to recall the meaning. The icon
   must match the concept: the "map the planet" objective is a globe with
   meridian arcs, not a generic dot.
4. **Verdict first.** The decision-reflection card leads with the system's
   icon and the verdict word ("WELL JUDGED" / "DEFENSIBLE" / "HARD TO
   DEFEND"); the written reasoning sits beneath in a quieter size, read by
   players who want the reasoning rather than the headline.
5. **The interface is the same world.** Warm palette tokens only (see
   `docs/art-direction.md`), no green/blue status, no cool accent.

## Changes made from the original, and why

### Anchor screen (launch screen)
- **Original:** briefing wall of text; the first read felt like an
  instruction manual.
- **Now:** "THE SHIP IS YOURS - Five decisions. One ship. Your call." with
  three icon tiles in the centre: THE MANDATE (scroll) / FIVE DECISIONS
  (sliders) / FLY HOME (rocket). Each tile carries its own progress: gold
  check badge when done, "0/5 PLACED" counter, "LOCKED" on the flight tile
  until the five are placed, and a soft pulse marks the one tile to touch
  next. Callsign + BEGIN is the only other primary element.
- **Why:** the objective is three steps, so the screen is those three steps.
  A player who lands can act immediately; nothing requires reading to start.

### Mandate picker as a popup
- **Original:** the mandate picker was a form squeezed between the three goal
  tiles and the BEGIN row, which overcrowded the anchor screen - the one
  screen whose whole job is to stay minimal.
- **Now:** the anchor screen keeps its three tiles + callsign/BEGIN; tapping
  the mandate tile opens the picker as a modal popup in the same visual family
  as the other popups (dim layer, tangerine border, centred panel). The first
  goal is still the first interaction - the tile is the door, the popup is the
  room.
- **Progressive disclosure in the picker's typography.** Each option button
  carries only its NAME, bold and larger; the one-line definition underneath is
  hidden until that option is the chosen one. Five definitions always visible
  read as documentation; one definition under the chosen option reads as the
  decision just made. A chosen option grows to make room - the definition's
  space exists only while the definition is on screen.
- **The declared mandate is stated, not assembled from buttons.** Above the
  choice buttons sits a "THE MANDATE YOU ARE DECLARING" box that builds up as
  picks land: pick "HOME ON SCHEDULE" + "BALANCED" and it writes "Mandate:
  Keep the filed schedule. The charter holders are waiting. / Risk appetite:
  Take the openings that are worth it, and carry the cost of the rest." The
  buttons only choose; the box says what was chosen, in the sentence every
  decision will later be judged against. The picker's micro-copy states the
  mandate's role once: "Every decision you make is judged against this."
- **Sealing:** picking both halves closes the popup after a beat, long enough
  to read the mandate just written - a form that stays open after it is done
  reads as unfinished.

### Copy at the right stage of the journey
- **"FINISH THE SURVEY" became "MAP THE PLANET".** The original label made
  the player parse an undefined "the survey" on the very first screen - it
  could have been lore, or a corporate questionnaire, and nothing had
  established it yet. The label now states the action in the same words the
  situation sheet uses, so the mandate is self-explanatory with zero
  prerequisite reading.
- **Rule:** a term that is not yet established in the journey must not appear
  as a bare reference in a goal list. Either name the action plainly, or put
  the term behind a curiosity button where it is defined.
- **Where the lore is anchored:** the situation sheet (secondary layer) says
  the ship's job is to map the planet, then bring its data home to
  Kepler-442b. Kepler-442b is HOME - the ship flies home to it at the end;
  it is not "bound for" it during the session. Do not re-introduce the
  "bound for" mistake.
- **Internal ids are legacy-stable:** `finish_the_survey` is the save-file
  id and stays; only the user-facing label and statement changed. Renaming
  ids would break saves and glyph mappings.
- **Same class of fix elsewhere:** "the survey" as an unexplained activity
  was replaced with "mapping" wording in the nav puzzle's guardrail costs
  ("narrow mapping grid", "running the mapping sweep"). The mandate tile
  hint changed from "Declare it before you walk." to "Set what the mission
  is for." - vague "it" and in-world jargon do not belong on the anchor
  screen. The kicker "ADAMANT VERITY - SURVEY SHIP" stays: it is the ship's
  class, not an undefined activity, and the sheet defines the mission.

### Icon library (scripts/ui/glyph.gd)
- ~27 vector-drawn flat line icons, drawn with draw_arc/draw_polyline
  primitives in a 24x24 box - no font or texture dependencies, so the UI
  never breaks on a missing asset. `Glyph.icon_for_objective()` /
  `icon_for_appetite()` / `icon_for_system()` map ids to icons. `Glyph.make()`
  builds one; a Control, so it can be anchored inside buttons and labels.
- Used in: goal tiles, chooser buttons, HUD chips, sheets, principle card,
  the pause menu's music toggle, the HUD menu button.

### HUD (scripts/ui/hud.gd)
- **Original:** five text lines readout.
- **Now:** five system icon chips (compass/heart/signal/crate/gear) - gold
  when placed, hollow while the bay is open, dimmed while SHIPMIND holds it -
  plus a mandate chip and two slim score bars. The full written record is one
  layer down: Tab or the chevron reveals it. The mandate chip refreshes on
  the score signature so it corrects itself after BEGIN, not just on the
  next placement.
- A corner MENU button is visible in every mode including mobile - a player
  who wants to leave must never have to remember a shortcut to find the door.

### Input modes (scripts/systems/input_mode.gd)
- DESKTOP / MOBILE / VR chips on the launch screen corner and in the F8 dev
  menu; flip live during testing. MOBILE activates the floating-joystick
  layer (left thumb walk, right thumb look, tap/button interact) with the
  HUD's compact variant (chips + subtitles only, no bars/callsign). DESKTOP
  is WASD + mouse/trackpad. VR attempts a live rig swap and refuses cleanly
  with a SYSTEM message when no OpenXR runtime is reachable - a mode switch
  must never fail silently.
- A forced mode is honoured over hardware detection; the mode layer owns the
  answer and the input layer group decides whether the cursor may be
  captured (a touch or XR mode declines on its own).

### Pause menu, mute, cursor
- Music defaults to MUTED and is toggled from the launch screen's corner and
  the pause menu; muting is a volume change, not a stop, so unmuting resumes
  the track exactly where it was.
- The pause menu (Esc, or the HUD MENU button) is RESUME primary, music
  switch, input mode chips, MAIN MENU. The run clock stops while it is open;
  MAIN MENU returns to the title card with the record shown and the clock
  held until BEGIN.
- The open launch screen enforces cursor visibility every frame - anything
  that grabs the mouse later must not leave the crew staring at a menu they
  cannot click.
- Opening is refused while another overlay owns the screen: two modals never
  stack.

### Layout fit
- The launch screen fits itself to the viewport by scaling the content to
  the height it needs, and centres on the SCALED CONTENT, not the scaled
  viewport - centring on the viewport clipped the callsign row off the
  bottom on taller-than-16:9 screens. Fixed-size overlays (pause menu,
  principle card, terminal) are responsive; any new overlay must be too.
- **A modal whose content can outgrow the screen must cap the panel and
  scroll the list.** The mandate popup's five option rows - two of which grow
  when chosen - can be taller than the viewport, and a centred panel that
  overflows clips at BOTH edges. The fix: the panel keeps a fixed,
  screen-sized height (a ScrollContainer with a set minimum size) and the
  option list scrolls inside it, vertical only. The panel never moves; the
  list moves instead. Any popup with a variable-length list needs this.

## Rules for new work

- New screen: what is the one thing the player does next? Lead with that.
  Put the reasoning behind a curiosity button.
- New list item: give it an icon that matches the concept, and a statement
  short enough to scan without re-reading.
- New term: either define it where it first appears, or don't use it there.
  Check the journey stage before shipping copy.
- New overlay: responsive at any canvas width; modal stacking handled;
  input mode aware (compact HUD on mobile, no captured cursor over menus);
  content that can outgrow the screen scrolls INSIDE the panel - the panel
  never moves.
- A chooser belongs in a popup, not inline on the anchor screen: the anchor
  stays three tiles, the door opens the room.
- Save-file ids are stable; user-facing copy is free to change.
