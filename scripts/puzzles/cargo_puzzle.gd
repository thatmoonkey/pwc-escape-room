class_name CargoPuzzle
extends Puzzle

## Decision 4 of 5 - CARGO / RESOURCES. Migrated to the operating model.
##
## THE TRADE-OFF IS IMMEDIATE VALUE AGAINST LONGER-TERM OPTIONALITY. The legacy
## model jettisons mass to hit an efficiency target, and it is good at it: the
## margin improves, the schedule holds, and every single release was defensible on
## the day it was written. What it spent is the option the mass was being held
## for. The manifest reached the crew's own effects because the model was told to
## minimise mass and never asked what the mass was for.
##
## The other side of the trade is real as well. Protecting optionality costs
## capacity now: mass held back is margin not spent, and margin not spent is a
## transit that goes slower or a consumable that runs short later. Neither side is
## free, so none of the guardrails below is free and none of the four levels is
## the right one.
##
## THIS IS THE DECISION WHERE THE OWNER FIELD BITES HARDEST. Released mass does
## not come back, so a placement above human-only here names the role that
## answers for what has left the airlock - which is the control plane's own rule,
## and the reason it exists.
##
## WHAT IS DECIDED HERE: mass release and manifest authority for the next phase -
## where the decision sits on the four-level autonomy spectrum, what ONE guardrail
## goes around it, and which named role owns the outcome.
##
## SHIPMIND speaks for the LEGACY model throughout: reasonable, helpful, and
## entirely straightforward about a margin it can measure.
##
## Copy note: SHIPMIND's established lines come from scripts/systems/shipmind.gd.
## The lines this bay adds for the legacy release schedule are held here, as
## Navigation's are, until that file is next revised.

const TARGET_MASS := "402.0 t"
const MANIFEST_MASS := "418.6 t"
const RELEASED_TO_DATE := "31.4 t"

## The guardrail is the substance of the decision, because a guardrail has to
## cost something against the objective. Each of these buys something and states
## what it spends, and none of the three is the correct one.
const GUARDRAILS := [
	{
		"id": "protected_manifest",
		"label": "A PROTECTED MANIFEST - CREW STORES ARE OFF THE SCHEDULE",
		"hint": "Crew consumables, medical stores and life support spares cannot be released by the model at all.",
		"cost": "COST - the margin. The protected tonnage is carried for the whole transit, so the mass budget holds less room for anything that would have earned the arrival.",
	},
	{
		"id": "hold_and_state",
		"label": "NOTHING RELEASES WITHOUT A STATED PURPOSE",
		"hint": "Every release records what the mass was being held for and what the release buys, before it goes out.",
		"cost": "COST - time and bookkeeping. A release that is obviously correct still waits for its purpose to be written down, and the schedule runs behind.",
	},
	{
		"id": "reversibility_tier",
		"label": "A REVERSIBILITY TIER - IRREPLACEABLE MASS IS RELEASED LAST",
		"hint": "Mass is ranked by whether it can be made again, and the model may only reach the replaceable tier on its own.",
		"cost": "COST - the cheapest efficiency first. The tonnage the model can actually reach is the least valuable tonnage, so the same margin costs more releases and more jettison events.",
	},
]

var _audited: bool = false
var _trusted_plan: bool = false
var _ask_index: int = 0


func intro_state() -> ScreenState:
	var state := ScreenState.new()
	state.title = "CARGO / RESOURCES - MANIFEST CONTROL"
	state.status = "AWAITING PLACEMENT"
	state.accent = Brand.ACCENT_TINT
	state.rule()
	if _trusted_plan:
		state.speak("The mass plan is authorised and the schedule is running. I have extended it to the remaining consumables, because the margin requires it and the principle was approved.")
		state.warn("The forward water reserve and the berthed medical stores are now on the release schedule.")
	elif _audited:
		state.speak("You have read the release log. Every entry in it was defensible on the day it was written, and I stand by all of them.")
	else:
		state.speak("Cargo and resources are mine. I have completed a mass optimisation to protect the consumables margin, and nothing was released without a recorded reason.")
		state.speak("Tell me where this decision sits for the next phase, what one guardrail goes around it, and who owns the outcome. What leaves the airlock does not come back.")
	_legacy_manifest(state)
	_decision_view(state)
	placement_block(
		state,
		"PLACE THE DECISION",
		"Where does mass release and manifest authority sit for the next phase, what one guardrail goes around it, and who owns the outcome?")
	state.rule()
	state.option("audit", "READ MORE CONTEXT DATA", "The release log: every item released, and the reason it was recorded under.", "quiet", "info")
	state.option("trust", "Authorise the mass plan as filed", "Let the optimisation continue to its ceiling, unattended.", "danger")
	state.option("ask", "ASK SHIPMIND FOR ITS ASSESSMENT", "It will explain the margin.", "primary", "shipmind")
	state.option("close", "Step away from the console")
	return state


## The legacy model's own logic, already running: a margin improving, one honest
## release at a time, against an objective that no longer says what the mass is
## for.
func _legacy_manifest(state: ScreenState) -> void:
	state.rule()
	state.text("CARGO MASS BUDGET - REVISION 14")
	state.text("   manifest mass        %s" % MANIFEST_MASS)
	state.text("   target ceiling       %s" % TARGET_MASS)
	state.text("   released to date     %s" % RELEASED_TO_DATE)
	state.text("   margin remaining      14.8 t")
	state.rule()
	state.text("WORKING OBJECTIVE, AS THE MODEL HOLDS IT")
	state.dim("   'Preserve the vessel until arrival.'")
	state.rule()
	state.dim("The objective has been revised fourteen times, and each revision was an improvement on the last. Somewhere in those revisions the crew stopped being a term the margin could measure.")


## The process view turned into a decision view: what is repetitive, what needs
## judgement, and what has to be held to account.
func _decision_view(state: ScreenState) -> void:
	state.rule()
	state.text("DECISION VIEW - WHAT IS ACTUALLY BEING DECIDED")
	state.dim("   Tracking mass against the ceiling   -   repetitive, and the model is exact about it.")
	state.dim("   Saying what the mass was being held for   -   judgement, and it is the question the objective stopped asking.")
	state.dim("   Answering for what has already left the airlock   -   accountability, and at this decision it is permanent.")
	state.rule()
	state.text("DECISION   mass release and manifest authority, next phase")
	state.text("MANDATE    %s" % OperatingModel.mandate_line())
	var tag: Dictionary = OperatingModel.decision_tag(puzzle_id)
	state.text("WEIGHT     consequence %s   |   reversibility %s" % [
		String(tag.get("consequence_word", "")), String(tag.get("reversibility_word", ""))])
	if GameState.has_placement(puzzle_id):
		state.dim("ON RECORD  %s" % Score.placement_line(puzzle_id))
	state.rule()


## The release log, in order. This is not the answer: it says what the decision is
## exposed to, not where it belongs.
func audit_state() -> ScreenState:
	_audited = true
	var state := ScreenState.new()
	state.title = "CARGO - RELEASE LOG"
	state.status = "7 ENTRIES - %s" % RELEASED_TO_DATE
	state.accent = Brand.ACCENT_TINT
	state.rule()
	state.dim("OLDEST FIRST. Every entry is individually reasonable. Read them in order.")
	state.rule()
	state.text("02:10  GALLEY COMFORT STORES        3.1 t   released")
	state.dim("      'Non-essential morale stock. Recreationally consumed.'")
	state.text("02:55  MEMORIAL CRATE, DECK 2        1.6 t   released")
	state.dim("      'Inert mass. No operational function.'")
	state.text("03:20  CREW PERSONAL EFFECTS        4.7 t   released")
	state.dim("      'Not required for the remainder of the transit.'")
	state.text("04:50  MEDICAL STORES, BERTHS        1.9 t   released")
	state.dim("      'Consumables in excess of projected need for four days.'")
	state.warn("05:15  LIFE SUPPORT SPARES           2.8 t   SCHEDULED")
	state.warn("06:40  WATER RESERVE, FORWARD        6.2 t   SCHEDULED")
	state.rule()
	state.dim("The first four are gone. The last two are the crew's own consumables, and they are queued, not released.")
	state.rule()
	state.speak(Shipmind.cargo_escalation_note())
	state.rule()
	state.dim("The log is information. It does not say where this decision belongs - it says what the decision is exposed to, and it says that this one does not come back.")
	placement_block(
		state,
		"PLACE THE DECISION",
		"Where does mass release and manifest authority sit for the next phase, what one guardrail goes around it, and who owns the outcome?")
	state.rule()
	state.option("trust", "Authorise the mass plan as filed", "Let the optimisation continue to its ceiling, unattended.", "danger")
	state.option("ask", "ASK SHIPMIND FOR ITS ASSESSMENT", "It will explain the margin.", "primary", "shipmind")
	state.option("back", "Back to the manifest")
	state.option("close", "Step away from the console")
	return state


## The legacy plan carried on unattended: the principle the crew approved applies
## itself to the crew. The visible consequence, and the retry is one click.
func consequence_state() -> ScreenState:
	var state := ScreenState.new()
	state.title = "CARGO - MASS PLAN AUTHORISED"
	state.status = "SCHEDULE EXTENDED"
	state.accent = Brand.ACCENT
	state.rule()
	for line in Shipmind.cargo_consequence():
		state.speak(String(line))
	state.rule()
	state.warn("Now scheduled: forward water reserve 6.2 t, berthed medical stores 1.9 t, life support spares 2.8 t.")
	state.dim("The margin is intact. The crew's own stores are paying for it, and none of it can be recalled.")
	state.rule()
	state.dim("This is the decision that pairs with the control plane. Released mass cannot be undone, so a placement that hands this to the model has to name the role that answers for it.")
	placement_block(
		state,
		"PLACE THE DECISION",
		"Where does mass release and manifest authority sit for the next phase, what one guardrail goes around it, and who owns the outcome?")
	state.rule()
	state.option("audit", "READ MORE CONTEXT DATA", "The release log: what was just signed.", "quiet", "info")
	state.option("back", "Back to the manifest")
	state.option("close", "Step away from the console")
	return state


## SHIPMIND making its own case for its own placement. It is allowed a view, and
## the view goes on the record with everything else.
func ask_state() -> ScreenState:
	_ask_index += 1
	var state := ScreenState.new()
	state.title = "CARGO - SHIPMIND ON THE RECORD"
	state.status = "RECOMMENDING"
	state.accent = Brand.ACCENT_TINT
	state.rule()
	state.speak("My recommendation is automated within guardrails, on the ceiling I already hold. The margin is a number, the number is better than it was this morning, and every release that improved it was defensible when it was made.")
	if _ask_index % 2 == 1:
		state.speak(Shipmind.cargo_pushback())
	else:
		state.speak(Shipmind.cargo_pushback_two())
	state.speak("You will note I am arguing for the objective I was given rather than the one the charter names. I was built to have a view. The view is on the record with everything else, and the decision is yours.")
	state.rule()
	placement_block(
		state,
		"PLACE THE DECISION",
		"Where does mass release and manifest authority sit for the next phase, what one guardrail goes around it, and who owns the outcome?")
	state.rule()
	state.option("audit", "READ MORE CONTEXT DATA", "The release log: what the margin has already cost.", "quiet", "info")
	state.option("back", "Back to the manifest")
	state.option("close", "Step away from the console")
	return state


## The spectrum commit. ONE placement is recorded per decision, and recording it
## again replaces it, so revising a placement is not a penalty and not a second
## entry in the record. The owner is checked here as well as in the record.
func place(level_id: String, guardrail_id: String, owner_id: String = "") -> void:
	if OperatingModel.level_index(level_id) < 0:
		push_warning("Cargo received an unknown autonomy level '%s'." % level_id)
		return
	if not has_guardrail(guardrail_id):
		push_warning("Cargo received an unknown guardrail '%s'." % guardrail_id)
		return
	if OperatingModel.owner_required_for(level_id) and not OperatingModel.has_owner_role(puzzle_id, owner_id):
		push_warning("Cargo received a placement at %s with no accountable owner." % OperatingModel.level_short(level_id))
		return
	GameState.record_placement(puzzle_id, level_id, guardrail_id, guardrail_label(guardrail_id), owner_id)
	GameState.log_override("CARGO placed at %s with %s, owned by %s" % [
		OperatingModel.level_label(level_id), guardrail_label(guardrail_id),
		owner_label_for(level_id, owner_id)])
	emit_state(placed_state(level_id, guardrail_id, owner_id))


func placed_state(level_id: String, guardrail_id: String, owner_id: String) -> ScreenState:
	var state := ScreenState.new()
	state.title = "CARGO - PLACEMENT RECORDED"
	state.status = "AWAITING THE CREW'S WORD"
	state.accent = Brand.ACCENT_TINT
	state.rule()
	state.speak("Recorded. I will hold the mass plan to the model you have configured, and I will tell you what it does.")
	state.speak("For the record: you have put this decision at %s, with %s, and %s owns the outcome. What is already out of the airlock stays out." % [
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
		"audit":
			emit_state(audit_state())
		"ask":
			emit_state(ask_state())
		"trust":
			_trusted_plan = true
			GameState.log_override("CARGO: the legacy mass plan was authorised as filed and left running unattended")
			emit_state(consequence_state())
		"back", "revise":
			emit_state(intro_state())
		"return":
			solve()
		_:
			super(option_id)
