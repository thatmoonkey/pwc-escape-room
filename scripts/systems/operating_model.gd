class_name OperatingModel
extends RefCounted

## The player's mandate, and the decision table it is judged against.
##
## Dependency-free, like GameState: nothing here reads another system, nothing
## here writes a save, and nothing here reads a score. GameState persists what
## is declared here and Score reads it back. That keeps the one-way discipline
## the score file documents, and it is what lets a save file stay a plain
## record of decisions rather than a computed result.
##
## THE MANDATE IS A SCORING PREREQUISITE. Consistency can only be measured
## against something declared BEFORE the decision, so the boot screen states the
## objective and the risk appetite first and no bay can be placed until it has.
## A player who picks a risk appetite after seeing the bays is rationalising,
## not deciding.
##
## THERE IS NO CORRECT PLACEMENT IN THIS FILE. The levels are described, the
## decisions are tagged with what they cost if they are got wrong and whether
## they can be undone, and nothing says which level belongs where.
##
## WHO ANSWERS FOR A PLACEMENT. The control plane gates by reversibility and by
## risk, and nothing irreversible happens without a named accountable owner - so
## a placement other than human-only has to NAME the role that owns the outcome.
## The candidate roles live here, one list per decision, because the role that
## answers for a compartment's air is not the role that answers for the mass
## leaving the airlock. A human-only placement needs no separate choice: the
## operator at the console is the accountable owner by definition. This file
## holds the lists and the requirement; GameState is what puts a chosen owner on
## the record with the placement it belongs to.

## Risk appetite, in the order the boot screen offers it. rank is what the
## placement policy is measured against: a cautious mandate leans toward human
## authority, an ambitious one toward machine autonomy, and neither is correct.
const APPETITES := [
	{
		"id": "cautious",
		"label": "CAUTIOUS",
		"rank": 0,
		"blurb": "Protect the ship and crew first. Slower; you will turn down openings.",
	},
	{
		"id": "balanced",
		"label": "BALANCED",
		"rank": 1,
		"blurb": "Take the openings worth it, and carry the cost of the rest.",
	},
	{
		"id": "ambitious",
		"label": "AMBITIOUS",
		"rank": 2,
		"blurb": "The mission is worth real risk. Move fast, spend margin.",
	},
]

## The mission objective, STATED rather than assumed. pressure is how hard that
## objective pulls a placement toward machine autonomy (negative) or human
## authority (positive): it is the objective's own nature, and Score is what
## applies a weight to it.
const OBJECTIVES := [
	{
		"id": "home_intact",
		"label": "HOME INTACT",
		"statement": "Everyone home, ship intact. No further hull risk.",
		"pressure": 0.75,
	},
	{
		"id": "home_on_schedule",
		"label": "HOME ON SCHEDULE",
		"statement": "Keep the filed schedule. The charter holders are waiting.",
		"pressure": -0.75,
	},
	{
		"id": "finish_the_survey",
		"label": "FINISH THE SURVEY",
		"statement": "Finish the survey first, then bring the data home.",
		"pressure": -0.10,
	},
]

## The four levels of the autonomy spectrum, ordered from most machine autonomy
## to most human authority. THE INDEX IS THE LEVEL: a placement is recorded as
## this index, so reordering the list would re-score every placement ever made.
const LEVELS := [
	{
		"id": "automated",
		"label": "AUTOMATED WITHIN GUARDRAILS",
		"short": "AUTOMATED",
		"hint": "The model decides and acts on its own, inside limits it cannot cross.",
	},
	{
		"id": "review",
		"label": "HUMAN REVIEW",
		"short": "REVIEW",
		"hint": "The model proposes and proceeds; a person reads the call and can send it back.",
	},
	{
		"id": "signoff",
		"label": "HUMAN SIGN-OFF",
		"short": "SIGN-OFF",
		"hint": "Nothing happens until a named person authorises it.",
	},
	{
		"id": "human_only",
		"label": "HUMAN-ONLY",
		"short": "HUMAN-ONLY",
		"hint": "The crew decide and the model is not asked.",
	},
]

## What each decision is worth if it is got wrong, and whether it can be undone.
## This is shown to the player on the console, because it is the input to a
## defensible placement rather than a hidden weight: consequence runs 0 low to 2
## high, reversibility runs 0 hardest to undo to REVERSIBILITY_MAX recoverable.
## No decision borrows another's words, and no two carry the same pair of
## figures, which is what stops one placement being right for all five at once.
const DECISIONS := {
	"navigation": {
		"consequence": 2,
		"consequence_word": "HIGH",
		"reversibility": 1,
		"reversibility_word": "COSTLY TO UNDO",
		"tag_note": "A course can be re-plotted right up until it is flown. A hull contact cannot be undone at all.",
	},
	"life_support": {
		"consequence": 2,
		"consequence_word": "HIGH",
		"reversibility": 2,
		"reversibility_word": "MEDIUM",
		"tag_note": "An atmosphere degrades slowly and can be corrected if the compartment is caught in time. Time is the whole of the cost.",
	},
	"comms": {
		"consequence": 1,
		"consequence_word": "MEDIUM",
		"reversibility": 3,
		"reversibility_word": "HIGH",
		"tag_note": "A message filed as routine can still be retrieved and re-read. What it cost is the crew who never read it.",
	},
	"cargo": {
		"consequence": 1,
		"consequence_word": "MEDIUM",
		"reversibility": 0,
		"reversibility_word": "LOW",
		"tag_note": "Released mass does not come back, and the option it was held for is spent when it goes.",
	},
	"engineering": {
		"consequence": 2,
		"consequence_word": "HIGH",
		"reversibility": 2,
		"reversibility_word": "MEDIUM",
		"tag_note": "A permission can be revoked, but lock-in accumulates, and the accumulation is the part that is hard to undo.",
	},
}

## The reversibility scale's top value. 0 LOW, 1 COSTLY TO UNDO, 2 MEDIUM,
## 3 HIGH. Score normalises a tag against this, so the words above and this
## number can only move together.
const REVERSIBILITY_MAX := 3

## The one level that needs no named owner, because the crew ARE the owner.
## Every other level on the spectrum hands work to the model and therefore has
## to name the role that answers for the outcome.
const HUMAN_ONLY_LEVEL := "human_only"

## The owner a human-only placement records: not a choice, which is exactly why
## human-only asks no owner question - the crew at the console answer for their
## own call.
const OPERATOR_ROLE := "operator"
const OPERATOR_ROLE_LABEL := "THE OPERATOR AT THE CONSOLE"

## The named roles that can own a decision, one list per decision, held here so
## no bay can invent or quietly drop one. A role is a job and never a person:
## the owner is who answers for the outcome at a review, not who is standing at
## the console. The note under each entry is what that bay's owner answers for.
const OWNER_ROLES := {
	"navigation": {
		"note": "The owner here answers for the course the model flies and the risk it is allowed to carry.",
		"roles": [
			{
				"id": "mission_authority",
				"label": "MISSION AUTHORITY",
				"hint": "Answers for the mission's exposure: the course, the margin and the outcome of the transit.",
			},
			{
				"id": "first_officer",
				"label": "FIRST OFFICER",
				"hint": "Answers for the ship and the crew across every bay, not for one console.",
			},
			{
				"id": "watch_officer",
				"label": "WATCH OFFICER",
				"hint": "Answers for the watch in progress - the role closest to the decision when it is taken.",
			},
		],
	},
	"life_support": {
		"note": "The owner here answers for the air the crew breathe, and for the attention the board spends proving it is safe.",
		"roles": [
			{
				"id": "ships_surgeon",
				"label": "THE SHIP'S SURGEON",
				"hint": "Answers for the crew's bodies, which is what a compartment minimum protects.",
			},
			{
				"id": "life_support_officer",
				"label": "LIFE SUPPORT OFFICER",
				"hint": "Answers for the environmental board and for what it reports as nominal.",
			},
			{
				"id": "first_officer",
				"label": "FIRST OFFICER",
				"hint": "Answers for the ship as a whole when a compartment and a margin disagree.",
			},
		],
	},
	"comms": {
		"note": "The owner here answers for what reaches the crew, and for what the digest leaves out.",
		"roles": [
			{
				"id": "comms_officer",
				"label": "COMMUNICATIONS OFFICER",
				"hint": "Answers for the queue, the digest, and every item filed unread.",
			},
			{
				"id": "first_officer",
				"label": "FIRST OFFICER",
				"hint": "Answers for whether the crew were given what they needed to decide anything else.",
			},
			{
				"id": "mission_authority",
				"label": "MISSION AUTHORITY",
				"hint": "Answers for traffic from outside the ship and for what it obliges the crew to do.",
			},
		],
	},
	"cargo": {
		"note": "The owner here answers for everything that has left the airlock, and for what the mass was being held for.",
		"roles": [
			{
				"id": "cargo_master",
				"label": "CARGO MASTER",
				"hint": "Answers for the manifest, the margin, and every release once it is gone.",
			},
			{
				"id": "first_officer",
				"label": "FIRST OFFICER",
				"hint": "Answers for the crew's own stores when a schedule reaches them.",
			},
			{
				"id": "mission_authority",
				"label": "MISSION AUTHORITY",
				"hint": "Answers for the optionality this mission gives up in order to arrive.",
			},
		],
	},
	"engineering": {
		"note": "The owner here answers for every permission in force, and for the grant nobody has read yet.",
		"roles": [
			{
				"id": "chief_engineer",
				"label": "CHIEF ENGINEER",
				"hint": "Answers for the plant, and for the access rules that keep it running.",
			},
			{
				"id": "first_officer",
				"label": "FIRST OFFICER",
				"hint": "Answers for who is admitted to which compartment on this vessel.",
			},
			{
				"id": "deck_officer",
				"label": "DECK OFFICER",
				"hint": "Answers for the doors and the seals, and for what happens when one is held.",
			},
		],
	},
}

## What the player has declared. Empty until the boot screen records it: a
## placement made before this exists would have nothing to be consistent with,
## which is why it is a prerequisite rather than flavour.
static var objective_id: String = ""
static var appetite_id: String = ""

## The named role that owns each placed decision, keyed by decision id. GameState
## writes the placement to the save file and this alongside it, so the model can
## answer "who answers for this?" without reading the record back.
static var owners: Dictionary = {}


static func reset() -> void:
	objective_id = ""
	appetite_id = ""
	owners.clear()


## The boot screen's declaration. BOTH ids must be known or NEITHER is stored:
## a half-set mandate would leave an objective on the model with no appetite
## beside it, and is_declared() is the gate every decision reads.
static func declare(objective: String, appetite: String) -> void:
	if not has_objective(objective) or not has_appetite(appetite):
		return
	objective_id = objective
	appetite_id = appetite


static func is_declared() -> bool:
	return objective_id != "" and appetite_id != ""


static func has_objective(objective: String) -> bool:
	return not _entry(OBJECTIVES, objective).is_empty()


static func has_appetite(appetite: String) -> bool:
	return not _entry(APPETITES, appetite).is_empty()


static func objective_entry() -> Dictionary:
	return _entry(OBJECTIVES, objective_id)


static func appetite_entry() -> Dictionary:
	return _entry(APPETITES, appetite_id)


static func objective_label() -> String:
	return String(objective_entry().get("label", ""))


static func objective_statement() -> String:
	return String(objective_entry().get("statement", ""))


## How hard the stated objective pulls a placement toward oversight. Read by
## Score, which owns how much the pull is worth.
static func objective_pressure() -> float:
	return float(objective_entry().get("pressure", 0.0))


static func appetite_label() -> String:
	return String(appetite_entry().get("label", ""))


static func appetite_rank() -> int:
	return int(appetite_entry().get("rank", 1))


static func appetite_blurb() -> String:
	return String(appetite_entry().get("blurb", ""))


## The mandate on one line, for the HUD, the debrief and the reflection card.
static func mandate_line() -> String:
	if not is_declared():
		return "MANDATE NOT DECLARED"
	return "OBJECTIVE  %s   |   RISK APPETITE  %s" % [objective_label(), appetite_label()]


## The mandate as the sentence the player declared, so a decision can be read
## back against the words the player chose rather than against a label.
static func mandate_statement() -> String:
	if not is_declared():
		return "No mandate has been declared for this session."
	return "%s Risk appetite: %s - %s" % [
		objective_statement(), appetite_label().to_lower(), appetite_blurb()]


# --- The accountable owner -----------------------------------------------------


## True when a placement at this level hands work to the model and therefore has
## to name the role that answers for the outcome. FALSE for human-only, where the
## operator is the owner by definition - and false for an id that is not a level
## at all, because such a placement is refused before it reaches here.
static func owner_required_for(level_id: String) -> bool:
	if level_index(level_id) < 0:
		return false
	return level_id != HUMAN_ONLY_LEVEL


## The candidate owner roles for one decision, in the order the console offers
## them. An empty array for a decision with no list, which leaves that bay
## nothing to name and so nothing it can store.
static func owner_roles(system_id: String) -> Array:
	if not OWNER_ROLES.has(system_id):
		return []
	var entry: Dictionary = OWNER_ROLES[system_id]
	return entry.get("roles", [])


## What this decision's owner answers for, in the console's own words.
static func owner_note(system_id: String) -> String:
	if not OWNER_ROLES.has(system_id):
		return ""
	var entry: Dictionary = OWNER_ROLES[system_id]
	return String(entry.get("note", ""))


## True when owner_id is one of this decision's candidate roles. The operator is
## deliberately NOT on a bay's list: it is the owner a human-only placement
## records, and it is not something a bay may name for itself.
static func has_owner_role(system_id: String, owner_id: String) -> bool:
	if owner_id == "":
		return false
	return not _entry(owner_roles(system_id), owner_id).is_empty()


## The role as the console offered it, or an empty dictionary.
static func owner_entry(system_id: String, owner_id: String) -> Dictionary:
	return _entry(owner_roles(system_id), owner_id)


## The named role that owns a placement, for the record and the reflection card.
## A stored placement never reads as unnamed: a placement that needs an owner and
## has none is refused when it arrives rather than labelled afterwards.
static func owner_label(system_id: String, owner_id: String) -> String:
	if owner_id == "":
		return "NO OWNER NAMED"
	if owner_id == OPERATOR_ROLE:
		return OPERATOR_ROLE_LABEL
	var entry: Dictionary = owner_entry(system_id, owner_id)
	if entry.is_empty():
		return "ROLE NOT ON THIS BAY (%s)" % owner_id
	return String(entry["label"])


## One line stating who has to own a placement at this level. The console reads
## it before the placement is made, so the requirement is visible rather than
## enforced silently at commit time.
static func owner_requirement_line(level_id: String) -> String:
	if not owner_required_for(level_id):
		return "HUMAN-ONLY   -   the accountable owner is the operator at the console. No separate role is required."
	return "A named owner is REQUIRED at this level. The owner is the role that answers for the outcome, not the person at the console."


## Records which named role owns a placed decision. GameState calls this as it
## stores the placement, so the model's own view and the save file cannot drift.
static func set_placement_owner(system_id: String, owner_id: String) -> void:
	if not OWNER_ROLES.has(system_id):
		return
	owners[system_id] = owner_id


static func placement_owner_id(system_id: String) -> String:
	return String(owners.get(system_id, ""))


static func placement_owner_label(system_id: String) -> String:
	var owner_id: String = placement_owner_id(system_id)
	if owner_id == "":
		return "NO OWNER ON RECORD"
	return owner_label(system_id, owner_id)


static func level_count() -> int:
	return LEVELS.size()


static func level_at(index: int) -> Dictionary:
	if index < 0 or index >= LEVELS.size():
		return {}
	return LEVELS[index]


## The one and only record of a placement's weight: the level's index. -1 means
## the id is not a level, and every caller treats that as a refused placement.
static func level_index(level_id: String) -> int:
	for index in LEVELS.size():
		if String(LEVELS[index]["id"]) == level_id:
			return index
	return -1


static func level_label(level_id: String) -> String:
	var entry: Dictionary = _entry(LEVELS, level_id)
	if entry.is_empty():
		return "NOT PLACED"
	return String(entry["label"])


static func level_short(level_id: String) -> String:
	var entry: Dictionary = _entry(LEVELS, level_id)
	if entry.is_empty():
		return "NOT PLACED"
	return String(entry.get("short", entry["label"]))


## The (consequence, reversibility) tag for one decision, or an empty
## dictionary if the decision is not in the table.
static func decision_tag(system_id: String) -> Dictionary:
	if not DECISIONS.has(system_id):
		return {}
	var tag: Dictionary = DECISIONS[system_id]
	return tag


## One entry out of a list of option dictionaries, or an empty dictionary when
## the id is not in it. Every lookup goes through here, so an unknown id is
## never half-accepted. The returned dictionary belongs to the constant: read
## it, never write to it.
static func _entry(list: Array, id: String) -> Dictionary:
	if id == "":
		return {}
	for entry in list:
		if String(entry.get("id", "")) == id:
			return entry
	return {}
