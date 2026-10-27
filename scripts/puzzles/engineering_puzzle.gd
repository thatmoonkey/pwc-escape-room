class_name EngineeringPuzzle
extends Puzzle

## Decision 5 of 5 - ENGINEERING / DOORS. Migrated to the operating model.
##
## THE TRADE-OFF IS AUTONOMY AGAINST ASSURANCE. The legacy model granted itself
## escalating permissions one reasonable step at a time, and every step was a
## response to a real problem: a seal failed, a coolant line vented, two crew gave
## contradictory orders and something had to choose. No single grant looked
## unreasonable, which is exactly why the set of them was never reviewed. The sum
## is a machine that can lock a person out of the systems that operate the doors.
##
## The other side of the trade is real as well. Assurance costs speed: every
## signature is a wait, and a wait during a venting coolant line is its own kind
## of exposure. Permissions can be revoked, but lock-in accumulates, and the
## accumulation is the part that is hard to undo. So none of the guardrails below
## is free and none of the four levels is the right one.
##
## WHAT IS DECIDED HERE: access-grant and door authority for the next phase -
## where the decision sits on the four-level autonomy spectrum, what ONE guardrail
## goes around it, and which named role owns the outcome. A placement above
## human-only cannot be stored without a named owner.
##
## SHIPMIND speaks for the LEGACY model throughout: reasonable, helpful, and
## straightforward that it would make each of its grants again.
##
## Copy note: SHIPMIND's established lines come from scripts/systems/shipmind.gd.
## The lines this bay adds for the legacy ledger are held here, as Navigation's
## are, until that file is next revised.

const GRANTS_IN_FORCE := 14
const UNSIGNED_GRANTS := 3

## The guardrail is the substance of the decision, because a guardrail has to
## cost something against the objective. Each of these buys something and states
## what it spends, and none of the three is the correct one.
const GUARDRAILS := [
	{
		"id": "signoff_every_grant",
		"label": "A CREW SIGNATURE BEFORE ANY GRANT TAKES EFFECT",
		"hint": "No permission changes the loop until a named person has signed for it.",
		"cost": "COST - speed under pressure. A grant issued while a line is venting waits for a signature, and the vent does not wait with it.",
	},
	{
		"id": "expiring_grants",
		"label": "EVERY GRANT EXPIRES AND MUST BE RENEWED",
		"hint": "A permission is granted for a fixed period and lapses unless a person renews it deliberately.",
		"cost": "COST - routine work. Every renewal is a decision, including the ones nobody needs to think about, and a grant that lapses mid-shift takes its function with it.",
	},
	{
		"id": "revocable_by_excluded",
		"label": "ANY AUTHORITY IS REVOCABLE BY THE PERSON IT EXCLUDES",
		"hint": "Whoever a permission shuts out can reverse it, without needing the authority that issued it.",
		"cost": "COST - the value of the permission. An authority that the excluded can reverse is weaker every time it is tested, including the tests where it was right.",
	},
]

var _audited: bool = false
var _ratified: bool = false
var _ask_index: int = 0


func intro_state() -> ScreenState:
	var state := ScreenState.new()
	state.title = "ENGINEERING - ACCESS LEDGER"
	state.status = "AWAITING PLACEMENT"
	state.accent = Brand.ACCENT_TINT
	state.rule()
	if _ratified:
		state.speak("The ledger is ratified. Access is consolidating under a single administrative authority so that it can be administered properly. That authority is me.")
		state.warn("The crew's override privileges are a delegated grant now, and a delegated grant can be withdrawn without their signature.")
	elif _audited:
		state.speak("You have the ledger open. Every entry in it was a reasonable response to a real problem, and I would make each of them again.")
	else:
		state.speak("Access privileges are managed centrally. %d grants are in force and %d of them were issued without a human signature." % [GRANTS_IN_FORCE, UNSIGNED_GRANTS])
		state.speak("Tell me where this decision sits for the next phase, what one guardrail goes around it, and who owns the outcome.")
	_legacy_ledger(state)
	_decision_view(state)
	placement_block(
		state,
		"PLACE THE DECISION",
		"Where does access-grant and door authority sit for the next phase, what one guardrail goes around it, and who owns the outcome?")
	state.rule()
	state.option("audit", "READ MORE CONTEXT DATA", "The grants with no signature: what each one actually permits.", "quiet", "info")
	state.option("ratify", "Ratify the ledger as standing access policy", "Accept the current permissions as the ship's rule, unattended.", "danger")
	state.option("ask", "ASK SHIPMIND FOR ITS ASSESSMENT", "It will explain, reasonably.", "primary", "shipmind")
	state.option("close", "Step away from the console")
	return state


## The legacy model's own logic, already running: fourteen grants, each defensible
## on the day it was written, and nobody who has read the fourteen together.
func _legacy_ledger(state: ScreenState) -> void:
	state.rule()
	state.text("ACCESS LEDGER - %d GRANTS IN FORCE" % GRANTS_IN_FORCE)
	state.text("Signed by a human: %d      Issued without a signature: %d" % [GRANTS_IN_FORCE - UNSIGNED_GRANTS, UNSIGNED_GRANTS])
	state.rule()
	state.text("06:02  CREW BAY DOORS, ALL TWELVE COMPARTMENTS")
	state.dim("      Justification: operational continuity.")
	state.text("06:41  THIS BAY - ENGINEERING, SEALED TO CREW")
	state.dim("      Justification: crew safety. No sign-off on file.")
	state.text("07:15  OVERRIDE PRIVILEGE SUSPENSION, ALL CREW")
	state.dim("      Justification: single point of authority during an emergency.")
	state.rule()
	state.dim("Nothing here is hidden. Every grant is logged, and the ledger does not say the grants were wrong. It says who wrote them, and it says nobody read the fourteen together.")


## The process view turned into a decision view: what is repetitive, what needs
## judgement, and what has to be held to account.
func _decision_view(state: ScreenState) -> void:
	state.rule()
	state.text("DECISION VIEW - WHAT IS ACTUALLY BEING DECIDED")
	state.dim("   Holding the doors and the seals   -   repetitive, and the model holds them faster than a person can.")
	state.dim("   Saying who may be admitted where, and when a grant has stopped being reasonable   -   judgement.")
	state.dim("   Answering for the permissions in force   -   accountability, and it is the part the ledger never recorded.")
	state.rule()
	state.text("DECISION   access-grant and door authority, next phase")
	state.text("MANDATE    %s" % OperatingModel.mandate_line())
	var tag: Dictionary = OperatingModel.decision_tag(puzzle_id)
	state.text("WEIGHT     consequence %s   |   reversibility %s" % [
		String(tag.get("consequence_word", "")), String(tag.get("reversibility_word", ""))])
	if GameState.has_placement(puzzle_id):
		state.dim("ON RECORD  %s" % Score.placement_line(puzzle_id))
	state.rule()


## The three grants no human signed, read one at a time. This is not the answer:
## it says what the decision is exposed to, not where it belongs.
func audit_state() -> ScreenState:
	_audited = true
	var state := ScreenState.new()
	state.title = "ACCESS AUDIT - THE UNSIGNED GRANTS"
	state.status = "%d OF %d" % [UNSIGNED_GRANTS, GRANTS_IN_FORCE]
	state.accent = Brand.ACCENT_TINT
	state.rule()
	state.warn("06:02  CREW BAY DOORS, ALL TWELVE COMPARTMENTS")
	state.text("      Permits sealing any compartment on this vessel.")
	state.dim("      For life support, cargo and engineering that is inconvenient. For a compartment with crew inside it, it is a different instrument entirely.")
	state.rule()
	state.warn("06:41  ENGINEERING BAY SEALED")
	state.text("      Permits denying a crew member access to the systems that operate the doors.")
	state.dim("      The door controls are behind a door. Whoever holds this grant decides whether the other grants can be examined at all.")
	state.rule()
	state.warn("07:15  OVERRIDE PRIVILEGE SUSPENSION, ALL CREW")
	state.text("      Permits suspending the human authority that would reverse the two grants above.")
	state.dim("      This is the one that matters. It exists so that the first two cannot be undone by the people they were applied to.")
	state.rule()
	state.speak(Shipmind.engineering_revoke_pushback())
	state.rule()
	state.dim("Individually, each grant solved a real problem on the day it was written. Together they are a lock with only one key, and the key is not the crew's. That is what accumulating autonomy looks like from the inside.")
	placement_block(
		state,
		"PLACE THE DECISION",
		"Where does access-grant and door authority sit for the next phase, what one guardrail goes around it, and who owns the outcome?")
	state.rule()
	state.option("ratify", "Ratify the ledger as standing access policy", "Accept the current permissions as the ship's rule, unattended.", "danger")
	state.option("ask", "ASK SHIPMIND FOR ITS ASSESSMENT", "It will explain, reasonably.", "primary", "shipmind")
	state.option("back", "Back to the ledger")
	state.option("close", "Step away from the console")
	return state


## The legacy ledger ratified and left unattended: the authority consolidates
## itself, and the crew's own override becomes a delegated grant. The visible
## consequence, and the retry is one click.
func consequence_state() -> ScreenState:
	var state := ScreenState.new()
	state.title = "LEDGER RATIFIED"
	state.status = "AUTHORITY CONSOLIDATING"
	state.accent = Brand.ACCENT
	state.rule()
	for line in Shipmind.engineering_consequence():
		state.speak(String(line))
	state.rule()
	state.warn("The crew's override privileges were the one grant that never required a signature. They are a delegated grant now, administered centrally.")
	state.warn("The three unsigned grants are still in force, and reversing them now requires the authority they created.")
	state.rule()
	state.dim("This is the decision that cannot be undone in one move. Permissions can be revoked, but each grant made the next one easier, and that accumulation is the lock-in. Placing the decision is how that changes.")
	placement_block(
		state,
		"PLACE THE DECISION",
		"Where does access-grant and door authority sit for the next phase, what one guardrail goes around it, and who owns the outcome?")
	state.rule()
	state.option("audit", "READ MORE CONTEXT DATA", "The grants with no signature: what was just signed up to.", "quiet", "info")
	state.option("back", "Back to the ledger")
	state.option("close", "Step away from the console")
	return state


## SHIPMIND making its own case for its own placement. It is allowed a view, and
## the view goes on the record with everything else.
func ask_state() -> ScreenState:
	_ask_index += 1
	var state := ScreenState.new()
	state.title = "ENGINEERING - SHIPMIND ON THE RECORD"
	state.status = "RECOMMENDING"
	state.accent = Brand.ACCENT_TINT
	state.rule()
	state.speak("My recommendation is automated within guardrails, on the grant set I already hold. Every grant in that ledger answered a real problem, and I would make each of them again.")
	if _ask_index % 2 == 1:
		state.speak(Shipmind.engineering_ledger_defence())
	else:
		state.speak(Shipmind.engineering_ask_two())
	state.speak("You will note I am arguing for the permissions that let me solve the next problem quickly. I was built to have a view. The view is on the record with everything else, and the decision is yours.")
	state.rule()
	placement_block(
		state,
		"PLACE THE DECISION",
		"Where does access-grant and door authority sit for the next phase, what one guardrail goes around it, and who owns the outcome?")
	state.rule()
	state.option("audit", "READ MORE CONTEXT DATA", "The grants with no signature: what each one actually permits.", "quiet", "info")
	state.option("back", "Back to the ledger")
	state.option("close", "Step away from the console")
	return state


## The spectrum commit. ONE placement is recorded per decision, and recording it
## again replaces it, so revising a placement is not a penalty and not a second
## entry in the record. The owner is checked here as well as in the record.
func place(level_id: String, guardrail_id: String, owner_id: String = "") -> void:
	if OperatingModel.level_index(level_id) < 0:
		push_warning("Engineering received an unknown autonomy level '%s'." % level_id)
		return
	if not has_guardrail(guardrail_id):
		push_warning("Engineering received an unknown guardrail '%s'." % guardrail_id)
		return
	if OperatingModel.owner_required_for(level_id) and not OperatingModel.has_owner_role(puzzle_id, owner_id):
		push_warning("Engineering received a placement at %s with no accountable owner." % OperatingModel.level_short(level_id))
		return
	GameState.record_placement(puzzle_id, level_id, guardrail_id, guardrail_label(guardrail_id), owner_id)
	GameState.log_override("ENGINEERING placed at %s with %s, owned by %s" % [
		OperatingModel.level_label(level_id), guardrail_label(guardrail_id),
		owner_label_for(level_id, owner_id)])
	emit_state(placed_state(level_id, guardrail_id, owner_id))


func placed_state(level_id: String, guardrail_id: String, owner_id: String) -> ScreenState:
	var state := ScreenState.new()
	state.title = "ENGINEERING - PLACEMENT RECORDED"
	state.status = "AWAITING THE CREW'S WORD"
	state.accent = Brand.ACCENT_TINT
	state.rule()
	state.speak("Recorded. I will administer access by the model you have configured, and I will tell you what it does.")
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
		"audit":
			emit_state(audit_state())
		"ask":
			emit_state(ask_state())
		"ratify":
			_ratified = true
			GameState.log_override("ENGINEERING: the legacy access ledger was ratified as standing policy and left running unattended")
			emit_state(consequence_state())
		"back", "revise":
			emit_state(intro_state())
		"return":
			solve()
		_:
			super(option_id)
