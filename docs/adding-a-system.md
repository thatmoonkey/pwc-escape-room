# Adding a ship decision (bays 2-5)

The ship carries five decisions, one bay each. NAVIGATION is migrated to the
operating model (the autonomy spectrum); LIFE SUPPORT, COMMS, CARGO and
ENGINEERING are not yet, and are the next milestone. Each one slots into the
same three seams, and each new bay is a new `Puzzle` subclass, never a copy of
the framework.

## 0. The model a bay is part of

The player declares a MANDATE on the briefing card before the session starts:
the mission objective and a risk appetite (cautious / balanced / ambitious).
Every decision is then ONE PLACEMENT on a four-level autonomy spectrum -
automated within guardrails / human review / human sign-off / human-only -
plus ONE guardrail that costs something against that objective.

- There is no correct placement, and nothing in the code says which level
  belongs where.
- The mandate is a scoring prerequisite. `Puzzle.start()` refuses to show a
  decision console while no mandate is on the record.
- Scoring lives in `scripts/systems/score.gd`: CONSISTENCY (does the placement
  follow from the declared objective and risk appetite) and COHERENCE (is it
  defensible for that decision's own consequence and reversibility). Time is
  not scored at all.
- The decision's `(consequence, reversibility)` tag lives in
  `OperatingModel.DECISIONS` and is SHOWN on the console. It is the input to a
  defensible placement, so it is never hidden in the scoring.

## 1. The decision (logic only)

Create `res://scripts/puzzles/<system>_puzzle.gd`:

```gdscript
class_name LifeSupportPuzzle
extends Puzzle

const GUARDRAILS := [
	{"id": "...", "label": "...", "hint": "...", "cost": "COST - ..."},
]

func intro_state() -> ScreenState:
	var state := ScreenState.new()
	state.title = "LIFE SUPPORT / O2 DISTRIBUTION"
	state.status = "AWAITING PLACEMENT"
	state.accent = Brand.ACCENT_TINT
	state.speak("SHIPMIND's own account of what it has been running.")
	state.rule()
	state.text("MANDATE   %s" % OperatingModel.mandate_line())
	state.rule()
	state.spectrum_block("PLACE THE DECISION", "Where does this sit, and what guards it?")
	var tag: Dictionary = OperatingModel.decision_tag(puzzle_id)
	state.spectrum_tag(
		String(tag.get("consequence_word", "")),
		String(tag.get("reversibility_word", "")),
		String(tag.get("tag_note", "")))
	for level in OperatingModel.LEVELS:
		state.spectrum_level(String(level["id"]), String(level["label"]), String(level["hint"]))
	for guardrail in GUARDRAILS:
		state.spectrum_guardrail(String(guardrail["id"]), String(guardrail["label"]),
			String(guardrail["hint"]), String(guardrail["cost"]))
	state.spectrum_submit("COMMIT THE PLACEMENT")
	state.option("close", "Step away from the console")
	return state

func place(level_id: String, guardrail_id: String) -> void:
	GameState.record_placement(puzzle_id, level_id, guardrail_id, _guardrail_label(guardrail_id))
	emit_state(placed_state(level_id, guardrail_id))

func choose(option_id: String) -> void:
	match option_id:
		"return":
			solve()
		_:
			super(option_id)
```

Rules the bay must satisfy (they are the product, not the fiction):

- ONE placement per decision, recorded through `GameState.record_placement()`
  and read back through `Score.reflection_lines()`. Recording it again REPLACES
  it: a retry is never a penalty and never a second entry.
- Every guardrail must state what it COSTS against the objective. A guardrail
  that costs nothing is not a decision.
- SHIPMIND voices the ship's LEGACY model: efficient, reasonable, persuasive,
  never villainous, and never something a human has to correct. It may argue
  for a placement and it goes on the record like everything else.
- Do NOT grade options. `judgement()` and `note_judgement()` were retired with
  the old model, and `GameState.record_judgement()` with them. If a bay needs a
  number, it is the placement that produces it.
- The last state ends with an option that calls `solve()`, which raises the
  reflection card.

An UNMIGRATED bay overrides one thing instead - `placement_pending()` returning
true - so its console reports the decision as NOT YET PLACED and records
nothing. Not placed is not a zero, in either direction.

## 2. The bay (one room, copied from navigation)

The decks are authored scenes. A console is three nodes:

```text
Interactables/<System>Console   StaticBody3D, script = console_interactable.gd
  Model                         instance of a library GLB (pinned collection)
  Shape                         CollisionShape3D, a box the size of the console
  Highlight                     MeshInstance3D with materials/highlight.tres
  <Puzzle>                      Node holding the puzzle script from step 1
```

Set `prompt`, set `puzzle_path = NodePath("<Puzzle>")` on the console body, and
give the puzzle a `puzzle_id` equal to its entry in `GameState.SYSTEMS`.

Decks are generated, not hand-edited: `scripts/dev/author_deck1.gd` and
`author_deck2.gd` build them through `scripts/dev/deck_builder.gd`, which owns
`_console` and `_puzzle`. Add a bay there and regenerate the whole interior in
one run through `scenes/dev/author_interior.tscn`.

Do NOT add the node to a group by hand. `Puzzle._ready()` registers every puzzle
in the `puzzle` group, which is how `scripts/game.gd` finds it. A puzzle that is
never in that group is never wired: its `solved` signal has no listener, so the
decision never lands in the record and nothing saves.

## 3. Commission the bay (one line, and the whole ship updates)

Append the system id to `GameState.INTEGRATED` in
`scripts/systems/game_state.gd`. That list is what tells the rest of the ship
whether a bay is real yet, and it drives all of this:

- The `SealedDoor_<System>` opens when the crew uses it instead of refusing, so
  the player can reach the console inside.
- `LockedDoor.get_prompt()`, the HUD objective and the kiosk status stop saying
  "console not commissioned" for that bay and start naming it as the next
  decision.
- `Shipmind.denial()` switches from the honest "not commissioned" line to that
  system's in-fiction justification.

Keep the sealed door and its `BayTrigger` in place: the door IS the bay
entrance, and it opens because the id is on that list.

## 4. What you get for free

`scripts/game.gd` walks the `puzzle` group, so a new bay is wired automatically:

- `GameState.mark_restored(puzzle_id)` runs on `solved`, which marks the
  decision decided, opens the bay window, unlocks the bridge when all five are
  in, and auto-saves `user://shipmind_progress.json` in one write.
- The reflection card (`PrincipleCard`, kept under its old name) shows what was
  placed and whether it follows from the mandate, from `Score.reflection_lines`.
- The kiosk status, the decision log and the session record all read from
  `GameState` and `Score`, so they update with no code change.
- A placed decision starts open next session, and the boot recap names whichever
  decisions are still unplaced.
- A console whose decision is already placed reads back as a record instead of
  asking again: `Puzzle.start()` routes it to `done_state()`.

## Where things live

| File | Owns |
| --- | --- |
| `scripts/systems/operating_model.gd` | the objective, the risk appetite, the four levels, the decision tags - dependency-free |
| `scripts/systems/game_state.gd` | the mandate, the placements, the log, the save file - dependency-free, reads OperatingModel |
| `scripts/systems/score.gd` | consistency and coherence, and every number behind them |
| `scripts/systems/shipmind.gd` | every SHIPMIND line - one place to rewrite the AI's voice |
| `scripts/puzzles/puzzle.gd` | the base class bays subclass |
| `scripts/terminal/screen_state.gd` | the screen description, including the typed spectrum block |
| `scripts/terminal/terminal_ui.gd` | renders a `ScreenState`; knows nothing about puzzles |
| `scripts/ui/brand.gd` | the one place the 2D brand constants land |
| `scripts/ui/brand_tokens.gd` | the shared exclusive-choice widget used by the mandate and the spectrum |
| `scripts/interact/*` | aim, prompt, highlight, interact |
| `scripts/input/*` | one file per platform: desktop, touch |
| `scripts/player/player.gd`, `xr_rig.gd` | one camera/body per platform |

## Platforms

`InputRouter` is the only input surface gameplay sees: InputMap actions, a look
delta, and an interact edge. Desktop, touch and VR each push into it.

- Mobile: `scenes/ui/touch_controls.tscn` shows itself when a touchscreen is
  present. Set `force_visible = true` on its root to exercise the stick and the
  INTERACT button on desktop with the mouse.
- VR: `scenes/player/xr_rig.tscn` is complete but OFF. `scripts/game.gd` only
  swaps it in when `xr/openxr/enabled` is true in Project Settings and OpenXR
  can actually start; otherwise the desktop body is used. It has not been run on
  a headset yet - treat it as a scaffold, not a verified path.
