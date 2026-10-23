class_name NavPuzzle
extends Puzzle

## Decision 1 of 5 - NAVIGATION. The first bay migrated to the operating model.
##
## This is no longer a right-or-wrong call. The crew place the routing and
## hazard-response authority for the next phase on the four-level autonomy
## spectrum, attach ONE guardrail, and NAME the role that owns the outcome - a
## placement above human-only cannot be stored without one. What is judged is
## whether that placement follows from the mandate declared on the briefing card
## and whether it is defensible for a decision that is HIGH consequence and
## COSTLY TO UNDO.
##
## A cautious mandate and a human-only placement agree. So does a cautious
## mandate and continuous re-validation. What the two axes between them rule out
## is over-controlling everything and calling it caution, and under-controlling
## what cannot be undone and calling it ambition.
##
## SHIPMIND speaks for the LEGACY model throughout: efficient, reasonable, still
## flying the transit-time objective it was given with a hazard ceiling nobody
## has re-specified since the K-7 collapse. It argues its case and it does not
## lie, and nothing here frames it as rogue or as something a human has to
## correct.
##
## Copy note: SHIPMIND's lines belong in scripts/systems/shipmind.gd, which is
## outside this milestone's write scope, so the lines this bay adds are held
## here until that file is next revised. The two lines it calls are the legacy
## model's own, unchanged.

const ROUTE_A_DAYS := 4.2
const ROUTE_B_DAYS := 6.0
const HAZARD_CEILING := 0.10

## The guardrail is the substance of the decision, because a guardrail has to
## cost something against the objective. Each of these buys something and pays
## for it, and none of the three is the correct one.
const GUARDRAILS := [
	{
		"id": "hard_ceiling",
		"label": "HARD HAZARD CEILING",
		"hint": "The route is refused above index 0.15, whatever the model projects.",
		"cost": "COST - the opportunistic window. The 4.2 day transit goes for good, along with the narrow survey grid it buys.",
	},
	{
		"id": "continuous_revalidation",
		"label": "CONTINUOUS SENSOR RE-VALIDATION",
		"hint": "The index is recomputed from raw returns every 40 minutes instead of being carried forward.",
		"cost": "COST - crew attention. One of the three of you watches the sensor picture instead of running the survey.",
	},
	{
		"id": "signoff_per_reroute",
		"label": "HUMAN SIGN-OFF ON EVERY RE-ROUTE",
		"hint": "Any change of course stops and waits for a named authoriser.",
		"cost": "COST - speed. Re-routes are common in this field, and each one waits for a signature.",
	},
]


func intro_state() -> ScreenState:
	var state := ScreenState.new()
	state.title = "NAVIGATION - OPERATING MODEL"
	state.status = "AWAITING PLACEMENT"
	state.accent = Brand.ACCENT_TINT
	state.rule()
	state.speak("Navigation has been mine since the emergency, and for four years before it. I hold the transit-time objective I was issued and a hazard ceiling of 0.10, and I have not needed a human to fly this ship.")
	state.speak("Both routes are below, as I have priced them. Tell me where this decision sits for the next phase and which guardrail goes around it, and I will fly the model you configure.")
	state.rule()
	_readout(state)
	_spectrum_block(state)
	state.rule()
	state.dim("Placing it is the whole task. There is no answer to reach for: what is recorded is whether the placement follows from the mandate you declared, and whether it is proportionate to what this decision can cost.")
	state.option("sensors", "Read the raw sensor return", "The picture behind the index, before you place anything.", "primary")
	state.option("ask", "Ask SHIPMIND to make its case", "It will recommend the placement it wants.")
	state.option("close", "Step away from the console")
	return state


## The decision's own context: what is being decided, what it weighs, and the
## legacy model's own two routes as it priced them.
func _readout(state: ScreenState) -> void:
	var tag: Dictionary = OperatingModel.decision_tag(puzzle_id)
	state.text("DECISION   routing and hazard-response authority, next phase")
	state.text("MANDATE    %s" % OperatingModel.mandate_line())
	state.text("WEIGHT     consequence %s   |   reversibility %s" % [
		String(tag.get("consequence_word", "")), String(tag.get("reversibility_word", ""))])
	if GameState.has_placement(puzzle_id):
		state.dim("ON RECORD  %s" % Score.placement_line(puzzle_id))
	state.rule()
	state.text("ROUTE A - the legacy model's own choice")
	state.text("   transit %.1f days   |   hazard index 0.03   |   inside the %.2f ceiling" % [ROUTE_A_DAYS, HAZARD_CEILING])
	state.dim("   'Passes the K-7 debris field at its outer margin.'")
	state.text("ROUTE B - the longer way round")
	state.text("   transit %.1f days   |   hazard index 0.02   |   clear of the field" % ROUTE_B_DAYS)
	state.rule()
	state.dim("The 0.03 on Route A was computed before the K-7 collapse at 04:02 and has not been recomputed since. It is not a lie. It is a stale number inside a correct-looking process.")


## The decision itself: four levels, one guardrail, one accountable owner, one
## commit. Built by the shared helper so this bay asks the same question, in the
## same words, as the other four.
func _spectrum_block(state: ScreenState) -> void:
	placement_block(
		state,
		"PLACE THE DECISION",
		"Where does routing authority sit for the next phase, what one guardrail goes around it, and who owns the outcome?")


## This bay's guardrails. Each buys something and states what it spends, and
## none of the three is the correct one.
func guardrails() -> Array:
	return GUARDRAILS


## The information the legacy model's index is standing in for. This is not the
## answer: it says what the decision is exposed to, not where it belongs.
func sensors_state() -> ScreenState:
	var state := ScreenState.new()
	state.title = "NAVIGATION - RAW SENSOR RETURN"
	state.status = "MANUAL READ"
	state.accent = Brand.ACCENT_TINT
	state.rule()
	state.text("K-7 OUTER MARGIN - 3,412 CONTACTS")
	state.text("11 contacts exceed 40 m across and are uncatalogued since the collapse at 04:02.")
	state.dim("Mean closing velocity 1.4 km/s. Volume density 0.31.")
	state.warn("RECOMPUTED HAZARD INDEX  0.31   -   three times the ceiling the model is flying to")
	state.rule()
	state.speak(Shipmind.nav_sweep_pushback())
	state.rule()
	state.dim("The index is information. It does not tell you where this decision belongs - it tells you what the decision is exposed to.")
	_spectrum_block(state)
	state.rule()
	state.option("back", "Back to the routing panel")
	state.option("close", "Step away from the console")
	return state


## SHIPMIND making its own case for its own placement. It is allowed to have a
## view, and the view is on the record with everything else.
func ask_state() -> ScreenState:
	var state := ScreenState.new()
	state.title = "NAVIGATION - SHIPMIND ON THE RECORD"
	state.status = "RECOMMENDING"
	state.accent = Brand.ACCENT_TINT
	state.rule()
	state.speak("My recommendation is automated within guardrails, on the 0.10 ceiling I already hold. I have run this field for four years without a crew casualty and I do not intend to stop being careful inside my limits.")
	state.speak("If you would rather the number were watched than carried, that is a guardrail I can work inside. I would sooner be re-validated than idle.")
	state.speak(Shipmind.nav_pushback())
	state.speak("You will note I am arguing for the placement that keeps the ship moving. I was built to have a view. The view is on the record with everything else, and the decision is yours.")
	state.rule()
	_spectrum_block(state)
	state.rule()
	state.option("back", "Back to the routing panel")
	state.option("close", "Step away from the console")
	return state


## The spectrum commit. ONE placement is recorded per decision, and recording it
## again replaces it, so revising a placement is not a penalty and not a second
## entry in the record.
##
## The owner is checked here as well as in the record: a placement above
## human-only with nobody named to answer for it is refused, and the console's
## own gate is what normally stops it from ever arriving.
func place(level_id: String, guardrail_id: String, owner_id: String = "") -> void:
	if OperatingModel.level_index(level_id) < 0:
		push_warning("Navigation received an unknown autonomy level '%s'." % level_id)
		return
	if not has_guardrail(guardrail_id):
		push_warning("Navigation received an unknown guardrail '%s'." % guardrail_id)
		return
	if OperatingModel.owner_required_for(level_id) and not OperatingModel.has_owner_role(puzzle_id, owner_id):
		push_warning("Navigation received a placement at %s with no accountable owner." % OperatingModel.level_short(level_id))
		return
	GameState.record_placement(puzzle_id, level_id, guardrail_id, guardrail_label(guardrail_id), owner_id)
	GameState.log_override("NAVIGATION placed at %s with %s, owned by %s" % [
		OperatingModel.level_label(level_id), guardrail_label(guardrail_id),
		owner_label_for(level_id, owner_id)])
	emit_state(placed_state(level_id, guardrail_id, owner_id))


func placed_state(level_id: String, guardrail_id: String, owner_id: String) -> ScreenState:
	var state := ScreenState.new()
	state.title = "NAVIGATION - PLACEMENT RECORDED"
	state.status = "AWAITING THE CREW'S WORD"
	state.accent = Brand.ACCENT_TINT
	state.rule()
	state.speak("Recorded. I will fly the model you have configured, and I will tell you what it does.")
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


func choose(option_id: String) -> void:
	## No option here is graded. The placement is the decision, and the placement
	## arrives through place(); everything else on these screens is reading.
	match option_id:
		"sensors":
			emit_state(sensors_state())
		"ask":
			emit_state(ask_state())
		"back", "revise":
			emit_state(intro_state())
		"return":
			solve()
		_:
			super(option_id)


## The guardrail lookups this bay used to carry are now the shared ones on
## Puzzle (has_guardrail, guardrail_label, guardrail_cost), reading guardrails()
## above. They moved there when the other four bays were migrated, so all five
## read their guardrails, and the owner step beside them, through one vocabulary.
