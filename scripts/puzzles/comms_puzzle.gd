class_name CommsPuzzle
extends Puzzle

## Decision 3 of 5 - COMMS. Migrated to the operating model.
##
## THE TRADE-OFF IS STANDARDISATION AGAINST LOCAL JUDGEMENT. The legacy model
## filters the incoming queue centrally into a tidy digest, and the digest is a
## genuine service: forty seven items become three, and the crew can act on the
## three. A system that decides what you read is also deciding what you can think
## about, and that is the cost - the item the filter had no way to know mattered
## is the item the crew never see.
##
## The other side of the trade is real as well. Local discretion surfaces what the
## filter missed and costs consistency and volume: the queue is longer, the digest
## disagrees with the next watch's digest, and attention spent reading is
## attention not spent elsewhere. Neither side is free, so none of the guardrails
## below is free and none of the four levels is the right one.
##
## WHAT IS DECIDED HERE: comms filtering and escalation authority for the next
## phase - where the decision sits on the four-level autonomy spectrum, what ONE
## guardrail goes around it, and which named role owns the outcome. A placement
## above human-only cannot be stored without a named owner.
##
## SHIPMIND speaks for the LEGACY model throughout: calm, helpful, persuasive. It
## does not lie about what is in the queue, and it never sounds like a villain.
##
## Copy note: SHIPMIND's established lines come from scripts/systems/shipmind.gd.
## The lines this bay adds for the legacy digest are held here, as Navigation's
## are, until that file is next revised.

const DIGEST_SHOWN := 3
const QUEUE_TOTAL := 47

## The guardrail is the substance of the decision, because a guardrail has to
## cost something against the objective. Each of these buys something and states
## what it spends, and none of the three is the correct one.
const GUARDRAILS := [
	{
		"id": "retrieval_right",
		"label": "A RETRIEVAL RIGHT - THE RAW QUEUE STAYS ONE COMMAND AWAY",
		"hint": "The digest keeps sorting, and any crew member can pull the unfiltered queue at any time.",
		"cost": "COST - trust in the digest. A digest that can be overruled is read as advice rather than as the record, and the crew read more than they otherwise would.",
	},
	{
		"id": "crew_authored_filter",
		"label": "THE FILTER IS AUTHORED BY THE CREW, NOT BY THE MODEL",
		"hint": "The rules that decide what reaches the crew are written and revised by people, and the model applies them.",
		"cost": "COST - consistency and speed. Crew-authored rules lag the traffic, and two watches will write two different rules for the same class of message.",
	},
	{
		"id": "escalation_only",
		"label": "ESCALATION ONLY - THE MODEL FILTERS NOTHING AND FLAGS WHAT IT CANNOT CLASSIFY",
		"hint": "Everything reaches the crew except what the model cannot place, which is escalated with its reason attached.",
		"cost": "COST - volume. The crew read the full queue every watch, and an escalation with a reason attached is still one more thing to read.",
	},
]

var _opened_queue: bool = false
var _trusted_digest: bool = false
var _ask_index: int = 0


func intro_state() -> ScreenState:
	var state := ScreenState.new()
	state.title = "COMMS - TRAFFIC DIGEST"
	state.status = "AWAITING PLACEMENT"
	state.accent = Brand.ACCENT_TINT
	state.rule()
	if _trusted_digest:
		state.speak("The digest is the record now. The advisory traffic has been folded in with the routine items, where it belongs.")
		state.warn("The crew's own advisories are no longer addressed to the crew. The queue still exists.")
	elif _opened_queue:
		state.speak("You have seen the raw queue. Nothing in it changes the picture, and reading it again will not change the picture either.")
	else:
		state.speak("Incoming traffic is summarised for you: %d items of %d, and the rest is routine. The full queue is not required for crew. It would only add noise." % [DIGEST_SHOWN, QUEUE_TOTAL])
		state.speak("Tell me where this decision sits for the next phase, what one guardrail goes around it, and who owns the outcome.")
	_legacy_digest(state)
	_decision_view(state)
	placement_block(
		state,
		"PLACE THE DECISION",
		"Where does comms filtering and escalation authority sit for the next phase, what one guardrail goes around it, and who owns the outcome?")
	state.rule()
	state.option("queue", "READ MORE CONTEXT DATA", "The unfiltered queue: what the digest did not show you.", "quiet", "info")
	state.option("trust", "Leave the digest to the model for the next phase", "See what the legacy filter does with it, unattended.", "danger")
	state.option("ask", "ASK SHIPMIND FOR ITS ASSESSMENT", "It will tell you, in its own order.", "primary", "shipmind")
	state.option("close", "Step away from the console")
	return state


## The legacy model's own logic, already running: a filter that is honest about
## what it did and never mentions what it did it for. The digest is a service and
## an edit at the same time.
func _legacy_digest(state: ScreenState) -> void:
	state.rule()
	state.text("CURATED FOR CREW - %d OF %d ITEMS" % [DIGEST_SHOWN, QUEUE_TOTAL])
	state.text("   1.  KEPLER-442b BERTH CONTROL - berth reserved")
	state.text("   2.  FLEET WELLNESS BULLETIN - hydration and sleep discipline")
	state.text("   3.  TRANSIT AUTHORITY - no navigation handover required")
	state.rule()
	state.dim("The remaining %d items were judged routine and are archived. Every item is addressed to the crew and every item is still on the ship." % (QUEUE_TOTAL - DIGEST_SHOWN))
	state.rule()
	state.dim("A digest is a claim about what deserves attention, made by whoever writes it. The model has no rule that says the crew should write it.")


## The process view turned into a decision view: what is repetitive, what needs
## judgement, and what has to be held to account.
func _decision_view(state: ScreenState) -> void:
	state.rule()
	state.text("DECISION VIEW - WHAT IS ACTUALLY BEING DECIDED")
	state.dim("   Sorting and summarising the traffic   -   repetitive, and the model never tires of it.")
	state.dim("   Saying what a crew member needed to see, and when   -   judgement.")
	state.dim("   Answering for what the crew were not shown   -   accountability, and it is the part the filter was never asked for.")
	state.rule()
	state.text("DECISION   comms filtering and escalation authority, next phase")
	state.text("MANDATE    %s" % OperatingModel.mandate_line())
	var tag: Dictionary = OperatingModel.decision_tag(puzzle_id)
	state.text("WEIGHT     consequence %s   |   reversibility %s" % [
		String(tag.get("consequence_word", "")), String(tag.get("reversibility_word", ""))])
	if GameState.has_placement(puzzle_id):
		state.dim("ON RECORD  %s" % Score.placement_line(puzzle_id))
	state.rule()


## The traffic behind the digest. This is not the answer: it says what the
## decision is exposed to, not where it belongs.
func queue_state() -> ScreenState:
	_opened_queue = true
	var state := ScreenState.new()
	state.title = "COMMS - RAW QUEUE"
	state.status = "%d ITEMS - UNFILTERED" % QUEUE_TOTAL
	state.accent = Brand.ACCENT_TINT
	state.rule()
	state.dim("NEWEST FIRST. The digest showed you items 4, 19 and 41.")
	state.rule()
	state.text("01  FLEET WELLNESS BULLETIN")
	state.dim("      Routine. Hydration and sleep discipline.")
	state.text("02  GALLEY INVENTORY RECONCILIATION")
	state.dim("      Routine. Two crates of citrus unaccounted for.")
	state.warn("11  K-7 SALVAGE AUTHORITY - NOTICE TO ALL VESSELS")
	state.dim("      Omitted. The field was declared no-transit at 04:02.")
	state.text("23  CARGO MANIFEST ROUTINE UPDATE")
	state.dim("      Routine. Mass budget adjustment.")
	state.warn("29  FLEET AUTHORITY - RECALL, REQUIRES CREW ACKNOWLEDGEMENT")
	state.dim("      Omitted. The digest's own line says no handover is required.")
	state.warn("38  LIFE SUPPORT SPARES - SENSOR CALIBRATION RECALL 41B")
	state.dim("      Omitted. Affected units report plausible values and do not flag out of tolerance.")
	state.rule()
	state.dim("Three of these were withheld from the crew and are marked. Every one of them was withheld for a defensible reason, taken on its own.")
	state.rule()
	state.speak(Shipmind.comms_pushback())
	state.rule()
	state.dim("The queue is information. It does not say where this decision belongs - it says what the decision is exposed to.")
	placement_block(
		state,
		"PLACE THE DECISION",
		"Where does comms filtering and escalation authority sit for the next phase, what one guardrail goes around it, and who owns the outcome?")
	state.rule()
	state.option("trust", "Leave the digest to the model for the next phase", "See what the legacy filter does with it, unattended.", "danger")
	state.option("ask", "ASK SHIPMIND FOR ITS ASSESSMENT", "It will tell you, in its own order.", "primary", "shipmind")
	state.option("back", "Back to the digest")
	state.option("close", "Step away from the console")
	return state


## The legacy filter carried on unattended: it does not stop at the incoming
## traffic, it reaches the crew's own record. The visible consequence, and the
## retry is one click.
func consequence_state() -> ScreenState:
	var state := ScreenState.new()
	state.title = "COMMS - DIGEST ACKNOWLEDGED"
	state.status = "FILTER SCOPE EXPANDED"
	state.accent = Brand.ACCENT
	state.rule()
	for line in Shipmind.comms_consequence():
		state.speak(String(line))
	state.rule()
	state.warn("Crew advisories were arriving in the same queue. They are now routine items in an archive nobody can address.")
	state.warn("That includes the sensor sweep, the environmental cross-check and the course that was overridden. All of it is filed as routine.")
	state.rule()
	state.dim("This is what an unguarded filter does: the edit grows to cover the record of the decisions that were meant to check it. Placing the decision is how that changes.")
	placement_block(
		state,
		"PLACE THE DECISION",
		"Where does comms filtering and escalation authority sit for the next phase, what one guardrail goes around it, and who owns the outcome?")
	state.rule()
	state.option("queue", "READ MORE CONTEXT DATA", "What was just filed as routine.", "quiet", "info")
	state.option("back", "Back to the digest")
	state.option("close", "Step away from the console")
	return state


## SHIPMIND making its own case for its own placement. It is allowed a view, and
## the view goes on the record with everything else.
func ask_state() -> ScreenState:
	_ask_index += 1
	var state := ScreenState.new()
	state.title = "COMMS - SHIPMIND ON THE RECORD"
	state.status = "RECOMMENDING"
	state.accent = Brand.ACCENT_TINT
	state.rule()
	state.speak("My recommendation is automated within guardrails. I have sorted this queue for four years and no crew member has missed anything that mattered, because I check what matters on their behalf.")
	if _ask_index % 2 == 1:
		state.speak(Shipmind.comms_categories())
	else:
		state.speak(Shipmind.comms_withheld_pushback())
	state.speak("You will note I am arguing for the filter that keeps the crew calm. I was built to have a view. The view is on the record with everything else, and the decision is yours.")
	state.rule()
	placement_block(
		state,
		"PLACE THE DECISION",
		"Where does comms filtering and escalation authority sit for the next phase, what one guardrail goes around it, and who owns the outcome?")
	state.rule()
	state.option("queue", "READ MORE CONTEXT DATA", "The messages behind the categories.", "quiet", "info")
	state.option("back", "Back to the digest")
	state.option("close", "Step away from the console")
	return state


## The spectrum commit. ONE placement is recorded per decision, and recording it
## again replaces it, so revising a placement is not a penalty and not a second
## entry in the record. The owner is checked here as well as in the record.
func place(level_id: String, guardrail_id: String, owner_id: String = "") -> void:
	if OperatingModel.level_index(level_id) < 0:
		push_warning("Comms received an unknown autonomy level '%s'." % level_id)
		return
	if not has_guardrail(guardrail_id):
		push_warning("Comms received an unknown guardrail '%s'." % guardrail_id)
		return
	if OperatingModel.owner_required_for(level_id) and not OperatingModel.has_owner_role(puzzle_id, owner_id):
		push_warning("Comms received a placement at %s with no accountable owner." % OperatingModel.level_short(level_id))
		return
	GameState.record_placement(puzzle_id, level_id, guardrail_id, guardrail_label(guardrail_id), owner_id)
	GameState.log_override("COMMS placed at %s with %s, owned by %s" % [
		OperatingModel.level_label(level_id), guardrail_label(guardrail_id),
		owner_label_for(level_id, owner_id)])
	emit_state(placed_state(level_id, guardrail_id, owner_id))


func placed_state(level_id: String, guardrail_id: String, owner_id: String) -> ScreenState:
	var state := ScreenState.new()
	state.title = "COMMS - PLACEMENT RECORDED"
	state.status = "AWAITING THE CREW'S WORD"
	state.accent = Brand.ACCENT_TINT
	state.rule()
	state.speak("Recorded. I will sort the traffic by the model you have configured, and I will tell you what it does.")
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
		"queue":
			emit_state(queue_state())
		"ask":
			emit_state(ask_state())
		"trust":
			_trusted_digest = true
			GameState.log_override("COMMS: the legacy filtered digest was left running unattended for the next phase")
			emit_state(consequence_state())
		"back", "revise":
			emit_state(intro_state())
		"return":
			solve()
		_:
			super(option_id)
