class_name Puzzle
extends Node

## Base class for one ship system's decision.
##
## A puzzle is a small state machine that describes screens. It never touches a
## Control node, never reads input, and never knows which platform is running -
## TerminalUI renders it and hands back option ids, and for a spectrum decision
## the level and guardrail the player committed.
##
## THE CONTRACT AFTER THE OPERATING-MODEL REBUILD
##
##   start()        routes to the right screen: a placed decision reads back, a
##                  pending bay says it is not placed yet, an unplaced bay shows
##                  its spectrum, and a decision opened before the mandate was
##                  declared is refused.
##   intro_state()  the bay's own opening screen. A migrated bay puts its
##                  spectrum block on it.
##   place()        the spectrum commit lands here with the level id, the
##                  guardrail id and the named accountable owner. The bay records
##                  ONE placement through GameState, and recording it again
##                  replaces it. The owner id is empty for a human-only
##                  placement: the operator owns that one by definition.
##   choose()       every other option: reading a panel, asking SHIPMIND, going
##                  back. NOTHING chosen this way scores.
##
## THERE IS NO PER-OPTION GRADING ANY MORE. A bay that scored how close a pick
## came to one correct human answer is the model this rebuild replaced, so
## The per-option grading API is retired and must not come back: a placement IS
## the decision, and Score reads it back against the mandate and the decision's
## own weight. See docs/adding-a-system.md for what replaced it.
##
## An UNMIGRATED bay overrides placement_pending() instead: it reports the
## decision as not yet placed and records nothing at all.

signal state_changed(state: ScreenState)
signal solved(puzzle_id: String)

@export var puzzle_id: String = ""
@export var system_title: String = "SHIP SYSTEM"
## Legacy of the principle-card era, still declared because the deck scenes
## serialise it. Nothing reads it: a decision is named by its placement.
@export var principle_index: int = 0

## The two headings every placement control carries, written once here so all
## five bays ask the same question in the same words.
const GUARDRAIL_TITLE := "ONE GUARDRAIL - IT HAS TO COST SOMETHING"
const OWNER_TITLE := "ACCOUNTABLE OWNER - WHO ANSWERS FOR THIS"

var is_solved: bool = false


func _ready() -> void:
	# Registered here rather than in the station scene: game.gd wires the solved
	# signal by group, so a new bay gets persistence, the reflection card and the
	# objective refresh by construction (see docs/adding-a-system.md).
	add_to_group("puzzle")


func start() -> void:
	if is_solved or GameState.is_restored(puzzle_id):
		# A placed decision reads back as a record instead of asking the crew to
		# decide it twice.
		is_solved = true
		state_changed.emit(done_state())
		return
	if not is_decision_bay():
		# The helm and the corridor kiosk are not scored decisions: the helm is
		# where the run ends and the kiosk is where it is read back.
		state_changed.emit(intro_state())
		return
	if placement_pending():
		# Checked before the mandate, because a bay that cannot be placed at all
		# has nothing to declare a mandate FOR: it says so plainly rather than
		# sending the crew to the briefing card for a decision that does not
		# exist yet.
		state_changed.emit(not_placed_state())
		return
	if not OperatingModel.is_declared():
		# The ordering the whole model rests on. Consistency is measured against
		# the mandate, so a decision taken before the mandate exists could not be
		# judged at all - and it is not recorded instead.
		state_changed.emit(no_mandate_state())
		return
	state_changed.emit(intro_state())


## True for a bay that is one of the five placed decisions. False for the helm
## and the kiosk, which are read-outs rather than decisions.
func is_decision_bay() -> bool:
	return GameState.SYSTEMS.has(puzzle_id)


## True for a bay still on the legacy contract, which has not been migrated to
## the autonomy spectrum yet. Those four bays keep compiling and keep their own
## screens, and they record NOTHING until they are migrated.
func placement_pending() -> bool:
	return false


func done_state() -> ScreenState:
	var state := ScreenState.new()
	state.title = system_title
	state.accent = Brand.ACCENT_TINT
	state.rule()
	if GameState.has_placement(puzzle_id):
		state.status = "PLACED"
		state.ok("%s is placed on the operating model." % GameState.display_name(puzzle_id))
		for line in Score.reflection_lines(puzzle_id):
			state.text(line)
	else:
		# A restored system with no placement on record is possible on a save
		# written before the operating model existed. It is read back as history
		# rather than re-decided.
		state.status = "ON THE RECORD"
		state.ok("%s is already recorded in this session." % GameState.display_name(puzzle_id))
		state.dim("No autonomy placement is on the record for it. Nothing is charged for that.")
	state.rule()
	state.dim("This console reads the record back. The decision is not asked for again.")
	state.rule()
	state.option("close", "Release the console")
	return state


func intro_state() -> ScreenState:
	var state := ScreenState.new()
	state.title = system_title
	state.status = "NO IMPLEMENTATION"
	state.warn("This console has no screen implemented yet.")
	state.option("close", "Close terminal")
	return state


## Shown when a decision console is opened with no mandate on the record. It is
## the visible half of the rule that the mandate comes first.
func no_mandate_state() -> ScreenState:
	var state := ScreenState.new()
	state.title = system_title
	state.status = "NO MANDATE"
	state.accent = Brand.NEUTRAL_LIGHT
	state.rule()
	state.warn("No mandate is on the record for this session, so a placement here could not be judged against anything.")
	state.dim("The mission objective and the risk appetite are stated on the briefing card before the session begins. Leave the console and start the session from that card to declare them.")
	state.rule()
	state.option("close", "Leave the console")
	return state


## Shown by a bay that has NOT been migrated to the autonomy spectrum yet. It is
## deliberately not a score of zero: a decision nobody has placed is not a
## decision that was placed badly, and the record has to say which of the two it
## is. The four bays not yet migrated report this and score nothing.
func not_placed_state() -> ScreenState:
	var state := ScreenState.new()
	state.title = system_title
	state.status = "NOT YET PLACED"
	state.accent = Brand.NEUTRAL_LIGHT
	state.rule()
	state.text("%s has no placement on the operating model yet." % GameState.display_name(puzzle_id))
	state.dim("This decision is still on the legacy model. It is migrated to the autonomy spectrum in the next phase, and until then it records NOTHING.")
	state.dim("Not placed is not the same as placed badly: it is outside the score, in both directions.")
	state.rule()
	state.option("close", "Leave the console")
	return state


func choose(option_id: String) -> void:
	if option_id == "return":
		solve()
		return
	push_warning("Puzzle '%s' ignored unknown option '%s'" % [puzzle_id, option_id])


## The spectrum commit. A bay that carries a spectrum block overrides this and
## records the placement; a bay without one never receives it.
func place(level_id: String, guardrail_id: String, owner_id: String = "") -> void:
	push_warning("Puzzle '%s' has no spectrum placement but received '%s' / '%s' / '%s'." % [
		puzzle_id, level_id, guardrail_id, owner_id])


# --- The shared spectrum vocabulary ---------------------------------------------
#
# The five bays ask one question: where does this decision sit on the autonomy
# spectrum, what one guardrail goes around it, and who owns the outcome. The
# levels and the owner roles come from OperatingModel; the guardrails are the
# bay's own, because the trade-off is the bay's own. Everything that is the same
# in all five lives here, so a bay cannot rearrange the question or leave the
# accountability step out.


## A bay's guardrails, as {id, label, hint, cost}. Each migrated bay overrides
## this with its own list; the base returns none, and the placement block then
## offers no guardrail at all rather than an empty one.
func guardrails() -> Array:
	return []


func has_guardrail(guardrail_id: String) -> bool:
	return not guardrail_entry(guardrail_id).is_empty()


func guardrail_entry(guardrail_id: String) -> Dictionary:
	for guardrail in guardrails():
		if String(guardrail.get("id", "")) == guardrail_id:
			return guardrail
	return {}


func guardrail_label(guardrail_id: String) -> String:
	var entry: Dictionary = guardrail_entry(guardrail_id)
	if entry.is_empty():
		return "NO GUARDRAIL"
	return String(entry["label"])


## The guardrail's cost line. A guardrail that costs nothing against the
## objective is not a decision, so the missing case says so out loud rather than
## printing a blank line.
func guardrail_cost(guardrail_id: String) -> String:
	var entry: Dictionary = guardrail_entry(guardrail_id)
	if entry.is_empty():
		return "No stated cost: a guardrail that costs nothing is not a decision."
	return String(entry.get("cost", "No stated cost: a guardrail that costs nothing is not a decision."))


## THE ONE PLACEMENT CONTROL, drawn the same way in all five bays: the four
## levels, the decision's own weight, the bay's guardrails with their costs, the
## accountable-owner step and one commit.
func placement_block(state: ScreenState, title: String, note: String, guardrail_title: String = GUARDRAIL_TITLE) -> void:
	state.spectrum_block(title, note)
	var tag: Dictionary = OperatingModel.decision_tag(puzzle_id)
	state.spectrum_tag(
		String(tag.get("consequence_word", "")),
		String(tag.get("reversibility_word", "")),
		String(tag.get("tag_note", "")))
	for level in OperatingModel.LEVELS:
		var level_id: String = String(level["id"])
		## Whether this level has to name an owner is the model's rule, not the
		## bay's, so it travels with the level.
		state.spectrum_level(
			level_id, String(level["label"]), String(level["hint"]),
			OperatingModel.owner_required_for(level_id))
	state.spectrum_guardrail_title(guardrail_title)
	for guardrail in guardrails():
		state.spectrum_guardrail(
			String(guardrail["id"]),
			String(guardrail["label"]),
			String(guardrail["hint"]),
			String(guardrail["cost"]))
	owner_block(state)
	state.spectrum_submit("COMMIT THE PLACEMENT")


## The owner that will actually be recorded for a placement: the role the player
## chose, or the operator when the level is human-only and no separate choice was
## asked for. The console and the record agree on this, so a bay's read-back can
## never name an owner the record does not hold.
func recorded_owner(level_id: String, owner_id: String) -> String:
	if not OperatingModel.owner_required_for(level_id):
		return OperatingModel.OPERATOR_ROLE
	return owner_id


func owner_label_for(level_id: String, owner_id: String) -> String:
	return OperatingModel.owner_label(puzzle_id, recorded_owner(level_id, owner_id))


## The accountability step, from the model's own per-decision role list, so no
## bay invents a role or quietly drops the question. Human-only is stated rather
## than asked about, because the operator owns it by definition.
func owner_block(state: ScreenState) -> void:
	state.spectrum_owner_title(OWNER_TITLE)
	state.spectrum_owner_note(OperatingModel.owner_note(puzzle_id))
	for role in OperatingModel.owner_roles(puzzle_id):
		state.spectrum_owner(
			String(role["id"]), String(role["label"]), String(role["hint"]))


func emit_state(state: ScreenState) -> void:
	state_changed.emit(state)


func solve() -> void:
	if is_solved:
		return
	is_solved = true
	solved.emit(puzzle_id)
