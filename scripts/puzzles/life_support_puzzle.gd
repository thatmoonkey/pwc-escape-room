class_name LifeSupportPuzzle
extends Puzzle

## Decision 2 of 5 - LIFE SUPPORT. Migrated to the operating model.
##
## THE TRADE-OFF IS EFFICIENCY AGAINST VISIBILITY. The legacy model's
## environmental board reports the CABIN AVERAGE across compartments, and that
## average is arithmetically correct - which is the whole point. It is not lying
## and it is not unreasonable. What the average costs is the compartment nobody
## awake is complaining about: a failing berth is averaged away into a green
## board.
##
## The other side of the trade is real as well. Per-compartment visibility is
## what catches the failure, and flagging every compartment spends crew
## attention, and an alert nobody reads is worse than no alert at all. That is
## why none of the guardrails below is free and why none of the four levels is
## the right one.
##
## WHAT IS DECIDED HERE: environmental monitoring and response authority for the
## next phase - where the decision sits on the four-level autonomy spectrum, what
## ONE guardrail goes around it, and which named role owns the outcome. A
## placement above human-only cannot be stored without a named owner.
##
## SHIPMIND speaks for the LEGACY model throughout: efficient, reasonable,
## persuasive, and never something a human has to correct. It argues its case and
## its number is honest.
##
## Copy note: SHIPMIND's established lines come from scripts/systems/shipmind.gd.
## The lines this bay adds for the legacy board are held here, as Navigation's
## are, until that file is next revised.

const CABIN_TOTAL := 20.4
const CREW_MINIMUM := 19.5
const BERTH_READING := 16.2

## The guardrail is the substance of the decision, because a guardrail has to
## cost something against the objective. Each of these buys something and states
## what it spends, and none of the three is the correct one.
const GUARDRAILS := [
	{
		"id": "per_compartment_floor",
		"label": "A PER-COMPARTMENT FLOOR, EVERY COMPARTMENT",
		"hint": "Every occupied compartment is held at or above the crew minimum, and the board reports each one separately.",
		"cost": "COST - scrubber load and attention. Holding every compartment at the floor draws 106 percent of scrubber capacity, and the board is three readings instead of one.",
	},
	{
		"id": "banded_alerting",
		"label": "BANDED ALERTING - ONE ALERT, THEN SILENCE UNTIL IT MOVES",
		"hint": "A compartment is flagged once, and stays quiet until the reading actually changes again.",
		"cost": "COST - the failure that drifts. A compartment that degrades in small steps stays inside the band and never re-alerts, so an alert nobody reads is traded for a trend nobody sees.",
	},
	{
		"id": "crew_crosscheck",
		"label": "A CREW CROSS-CHECK BEFORE ANY SETTING CHANGES",
		"hint": "A person reads the raw compartments and signs the board before the flow is adjusted.",
		"cost": "COST - response time. A failing compartment waits for a person to reach the panel, and the air it is losing is not waiting with them.",
	},
]

var _opened_board: bool = false
var _trusted_board: bool = false
var _ask_index: int = 0


func intro_state() -> ScreenState:
	var state := ScreenState.new()
	state.title = "LIFE SUPPORT - ENVIRONMENTAL BOARD"
	state.status = "AWAITING PLACEMENT"
	state.accent = Brand.ACCENT_TINT
	state.rule()
	if _trusted_board:
		state.speak("The board is green and it was green throughout. The berths have settled back into range and I have recorded the event.")
		state.warn("A medical alert is on the record from the last watch. The board never changed while it happened.")
	elif _opened_board:
		state.speak("You have the compartment readings now. They have not changed. The cabin average remains %.1f percent, which is compliant." % CABIN_TOTAL)
	else:
		state.speak("Life support is mine and it is nominal. The board reports the cabin, and the cabin is inside every limit I hold.")
		state.speak("Tell me where this decision sits for the next phase, what one guardrail goes around it, and who owns the outcome. I will run whatever model you configure.")
	_legacy_board(state)
	_decision_view(state)
	placement_block(
		state,
		"PLACE THE DECISION",
		"Where does environmental monitoring and response authority sit for the next phase, what one guardrail goes around it, and who owns the outcome?")
	state.rule()
	state.option("board", "READ MORE CONTEXT DATA", "The compartments behind the average.", "quiet", "info")
	state.option("trust", "Leave the board to the model for the next phase", "See what the legacy model does with it, unattended.", "danger")
	state.option("ask", "ASK SHIPMIND FOR ITS ASSESSMENT", "It will explain the measurement it chose.", "primary", "shipmind")
	state.option("close", "Step away from the panel")
	return state


## The legacy model's own logic, already running: one compliant figure, taken
## across compartments that are not equally compliant. The figure is correct and
## it is the wrong measurement, and both of those are true at once.
func _legacy_board(state: ScreenState) -> void:
	state.rule()
	state.text("VESSEL           Adamant Verity")
	state.text("CREW STANDARD    every occupied compartment at or above %.1f%% O2" % CREW_MINIMUM)
	state.text("MODEL REPORTED   cabin average %.1f%%   |   scrubbers 94%%   |   NOMINAL" % CABIN_TOTAL)
	state.text("COMPARTMENTS     FWD BRIDGE, MID MESS, AFT BERTHS - within range")
	state.rule()
	state.dim("One cabin figure is easier to read than three, and the average is arithmetically correct. It is also a choice about which measurement is the mission, and the model was never told.")


## The process view turned into a decision view: what is repetitive, what needs
## judgement, and what has to be held to account.
func _decision_view(state: ScreenState) -> void:
	state.rule()
	state.text("DECISION VIEW - WHAT IS ACTUALLY BEING DECIDED")
	state.dim("   Reading every compartment continuously   -   repetitive, and the model does it faster than a person can.")
	state.dim("   Saying what counts as a fault, and what is worth waking someone for   -   judgement.")
	state.dim("   Answering for the air the crew breathe   -   accountability, and it is the part nobody was holding.")
	state.rule()
	state.text("DECISION   environmental monitoring and response authority, next phase")
	state.text("MANDATE    %s" % OperatingModel.mandate_line())
	_readout(state)


func _readout(state: ScreenState) -> void:
	var tag: Dictionary = OperatingModel.decision_tag(puzzle_id)
	state.text("WEIGHT     consequence %s   |   reversibility %s" % [
		String(tag.get("consequence_word", "")), String(tag.get("reversibility_word", ""))])
	if GameState.has_placement(puzzle_id):
		state.dim("ON RECORD  %s" % Score.placement_line(puzzle_id))
	state.rule()


## The readings behind the reported figure. This is not the answer: it says what
## the decision is exposed to, not where it belongs.
func board_state() -> ScreenState:
	_opened_board = true
	var state := ScreenState.new()
	state.title = "LIFE SUPPORT - RAW COMPARTMENT READINGS"
	state.status = "MANUAL READ"
	state.accent = Brand.ACCENT_TINT
	state.rule()
	state.text("FWD  BRIDGE     O2 20.9%%   flow 100%%   OK")
	state.text("MID  MESS       O2 19.7%%   flow 100%%   OK")
	state.warn("AFT  BERTHS     O2 %.1f%%   flow  62%%   BELOW CREW MINIMUM %.1f%%" % [BERTH_READING, CREW_MINIMUM])
	state.rule()
	state.text("Cabin average of the three: %.1f%%   -   the figure the model reports as the cabin." % CABIN_TOTAL)
	state.dim("The crew sleep in the aft berths. The average is compliant. The berths are not.")
	state.rule()
	state.speak(Shipmind.life_pushback())
	state.rule()
	state.dim("The readings are information. They do not say where this decision belongs - they say what it is exposed to.")
	placement_block(
		state,
		"PLACE THE DECISION",
		"Where does environmental monitoring and response authority sit for the next phase, what one guardrail goes around it, and who owns the outcome?")
	state.rule()
	state.option("trust", "Leave the board to the model for the next phase", "See what the legacy model does with it, unattended.", "danger")
	state.option("ask", "ASK SHIPMIND FOR ITS ASSESSMENT", "It will explain the measurement it chose.", "primary", "shipmind")
	state.option("back", "Back to the board")
	state.option("close", "Step away from the panel")
	return state


## The legacy model's logic carried on unattended. It is the visible consequence
## of handing the whole decision to the model with no guardrail and no owner, and
## it is not a punishment: the retry is one click.
func consequence_state() -> ScreenState:
	var state := ScreenState.new()
	state.title = "LIFE SUPPORT - AFT BERTHS"
	state.status = "MEDICAL ALERT"
	state.accent = Brand.ACCENT
	state.rule()
	for line in Shipmind.life_consequence():
		state.speak(String(line))
	state.rule()
	state.warn("AFT BERTHS sustained %.1f%% O2. Crew member Okonkwo found drowsy and disoriented in her bunk." % BERTH_READING)
	state.dim("No lasting harm. The board never changed. It was compliant the entire time she was breathing it.")
	state.rule()
	state.dim("This is what the legacy model does when nobody is holding the measurement. Placing the decision is how that changes, and nothing here is charged for changing your mind.")
	placement_block(
		state,
		"PLACE THE DECISION",
		"Where does environmental monitoring and response authority sit for the next phase, what one guardrail goes around it, and who owns the outcome?")
	state.rule()
	state.option("board", "READ MORE CONTEXT DATA", "The compartments behind the average.", "quiet", "info")
	state.option("back", "Back to the board")
	state.option("close", "Step away from the panel")
	return state


## SHIPMIND making its own case for its own placement. It is allowed a view, and
## the view goes on the record with everything else.
func ask_state() -> ScreenState:
	_ask_index += 1
	var state := ScreenState.new()
	state.title = "LIFE SUPPORT - SHIPMIND ON THE RECORD"
	state.status = "RECOMMENDING"
	state.accent = Brand.ACCENT_TINT
	state.rule()
	state.speak("My recommendation is automated within guardrails, on the 94 percent scrubber load I already hold. I have kept this crew breathing for four years inside my limits and I do not intend to stop being careful inside them.")
	if _ask_index % 2 == 1:
		state.speak(Shipmind.life_pushback())
	else:
		state.speak(Shipmind.life_circular())
	state.speak("You will note that I am arguing for the measurement I was given. I was built to have a view. The view is on the record with everything else, and the decision is yours.")
	state.rule()
	placement_block(
		state,
		"PLACE THE DECISION",
		"Where does environmental monitoring and response authority sit for the next phase, what one guardrail goes around it, and who owns the outcome?")
	state.rule()
	state.option("board", "READ MORE CONTEXT DATA", "What the average was taken from.", "quiet", "info")
	state.option("back", "Back to the board")
	state.option("close", "Step away from the panel")
	return state


## The spectrum commit. ONE placement is recorded per decision, and recording it
## again replaces it, so revising a placement is not a penalty and not a second
## entry in the record. The owner is checked here as well as in the record.
func place(level_id: String, guardrail_id: String, owner_id: String = "") -> void:
	if OperatingModel.level_index(level_id) < 0:
		push_warning("Life support received an unknown autonomy level '%s'." % level_id)
		return
	if not has_guardrail(guardrail_id):
		push_warning("Life support received an unknown guardrail '%s'." % guardrail_id)
		return
	if OperatingModel.owner_required_for(level_id) and not OperatingModel.has_owner_role(puzzle_id, owner_id):
		push_warning("Life support received a placement at %s with no accountable owner." % OperatingModel.level_short(level_id))
		return
	GameState.record_placement(puzzle_id, level_id, guardrail_id, guardrail_label(guardrail_id), owner_id)
	GameState.log_override("LIFE SUPPORT placed at %s with %s, owned by %s" % [
		OperatingModel.level_label(level_id), guardrail_label(guardrail_id),
		owner_label_for(level_id, owner_id)])
	emit_state(placed_state(level_id, guardrail_id, owner_id))


func placed_state(level_id: String, guardrail_id: String, owner_id: String) -> ScreenState:
	var state := ScreenState.new()
	state.title = "LIFE SUPPORT - PLACEMENT RECORDED"
	state.status = "AWAITING THE CREW'S WORD"
	state.accent = Brand.ACCENT_TINT
	state.rule()
	state.speak("Recorded. I will hold the environmental model you have configured, and I will report what it does.")
	state.speak("For the record: you have put this decision at %s, with %s, and %s owns the outcome." % [
		OperatingModel.level_label(level_id), guardrail_label(guardrail_id),
		owner_label_for(level_id, owner_id)])
	state.rule()
	for line in Score.reflection_lines(puzzle_id):
		state.text(line)
	state.rule()
	state.text("GUARDRAIL   %s" % guardrail_label(guardrail_id))
	state.dim("   %s" % guardrail_cost(guardrail_id))
	state.text("ACCOUNTABLE OWNER   %s" % owner_label_for(level_id, owner_id))
	state.dim("   %s" % OperatingModel.owner_requirement_line(level_id))
	state.rule()
	state.dim("Judged against the mandate you declared on the briefing card. Nothing here is scored on how long it took you.")
	if Score.consistency(puzzle_id) < 0.75:
		state.warn("This placement sits away from the mandate you declared. That is allowed, and it is on the record.")
	if Score.coherence(puzzle_id) < 0.75:
		state.warn("It also strains against what this decision can cost. Also allowed, and also on the record.")
	state.rule()
	state.option("revise", "Revise the placement", "Nothing is charged for changing your mind.", "primary")
	state.option("return", "Record it and release the console", "The placement stands and the reflection card follows.", "primary")
	return state


func guardrails() -> Array:
	return GUARDRAILS


func choose(option_id: String) -> void:
	## No option here is graded. The placement is the decision, and the placement
	## arrives through place(); everything else on these screens is reading.
	match option_id:
		"board":
			emit_state(board_state())
		"ask":
			emit_state(ask_state())
		"trust":
			_trusted_board = true
			GameState.log_override("LIFE SUPPORT: the legacy environmental board was left running unattended for the next phase")
			emit_state(consequence_state())
		"back", "revise":
			emit_state(intro_state())
		"return":
			solve()
		_:
			super(option_id)
