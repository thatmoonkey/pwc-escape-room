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
## ONE PICK PER DECISION. The crew choose a level and nothing else: the
## guardrail-and-owner steps of the earlier model asked more reading than the
## decision was worth, so the record now states who runs a decision as a line
## derived from the level itself (WHO_RUNS_IT). The level IS the decision.

## Risk appetite, in the order the boot screen offers it. rank is what the
## placement policy is measured against: a cautious mandate leans toward human
## authority, an ambitious one toward machine autonomy, and neither is correct.
const APPETITES := [
	{
		"id": "cautious",
		"label": "CAREFUL",
		"rank": 0,
		"blurb": "Ship and crew first. Slower, and you will pass up chances.",
	},
	{
		"id": "balanced",
		"label": "BALANCED",
		"rank": 1,
		"blurb": "Take the chances worth taking, and carry the cost of the rest.",
	},
	{
		"id": "ambitious",
		"label": "BOLD",
		"rank": 2,
		"blurb": "The mission is worth real risk. Move fast, spend the margin.",
	},
]

## The mission objective, STATED rather than assumed. pressure is how hard that
## objective pulls a placement toward machine autonomy (negative) or human
## authority (positive): it is the objective's own nature, and Score is what
## applies a weight to it.
const OBJECTIVES := [
	{
		"id": "home_intact",
		"label": "HOME IN ONE PIECE",
		"statement": "Everyone home, ship in one piece. No extra risk to the hull.",
		"pressure": 0.75,
	},
	{
		"id": "home_on_schedule",
		"label": "HOME ON TIME",
		"statement": "Keep the filed schedule. People are waiting on this delivery.",
		"pressure": -0.75,
	},
	{
		# The id is legacy - it is what the save file stores, so it stays stable
		# while the user-facing wording is free to improve.
		"id": "finish_the_survey",
		"label": "MAP THE PLANET",
		"statement": "Finish the map, secure the data, bring it home.",
		"pressure": -0.10,
	},
]

## The four levels of the autonomy spectrum, ordered from most machine autonomy
## to most human authority. THE INDEX IS THE LEVEL: a placement is recorded as
## this index, so reordering the list would re-score every placement ever made.
##
## The labels are written to be read in one glance: each says who acts, in
## plain words, and the hint is one line of what that means in practice.
const LEVELS := [
	{
		"id": "automated",
		"label": "SHIPMIND DECIDES ALONE",
		"short": "ALONE",
		"hint": "Fastest. It acts on its own, inside limits it cannot cross.",
	},
	{
		"id": "review",
		"label": "SHIPMIND ACTS, CREW CAN UNDO",
		"short": "CAN UNDO",
		"hint": "It acts first. A crew member reads the call after, and can send it back.",
	},
	{
		"id": "signoff",
		"label": "SHIPMIND ASKS FIRST",
		"short": "ASK FIRST",
		"hint": "It proposes. Nothing happens until a crew member says yes.",
	},
	{
		"id": "human_only",
		"label": "CREW DECIDES",
		"short": "CREW ONLY",
		"hint": "The call is yours. SHIPMIND carries out orders, nothing more.",
	},
]

## What each decision is worth if it is got wrong, and whether it can be undone.
## This is shown to the player on the console, because it is the input to a
## defensible placement rather than a hidden weight: consequence runs 0 low to 2
## high, reversibility runs 0 hardest to undo to REVERSIBILITY_MAX recoverable.
## No decision borrows another's words, and no two carry the same pair of
## figures, which is what stops one placement being right for all five at once.
##
## The words are plain on purpose: the player should get the stakes of a bay in
## the two seconds they glance at the tag, not decode a table.
const DECISIONS := {
	"navigation": {
		"consequence": 2,
		"consequence_word": "HIGH",
		"reversibility": 1,
		"reversibility_word": "HARD",
		"tag_note": "You can change a plotted course until the moment it is flown. You cannot un-hit a rock.",
	},
	"life_support": {
		"consequence": 2,
		"consequence_word": "HIGH",
		"reversibility": 2,
		"reversibility_word": "SLOW",
		"tag_note": "Air goes bad slowly and can be fixed - if someone catches it in time.",
	},
	"comms": {
		"consequence": 1,
		"consequence_word": "MEDIUM",
		"reversibility": 3,
		"reversibility_word": "EASY",
		"tag_note": "A buried message can be dug back up. The cost is everyone who never saw it.",
	},
	"cargo": {
		"consequence": 1,
		"consequence_word": "MEDIUM",
		"reversibility": 0,
		"reversibility_word": "NEVER",
		"tag_note": "What leaves the airlock stays in space. Gone is gone.",
	},
	"engineering": {
		"consequence": 2,
		"consequence_word": "HIGH",
		"reversibility": 2,
		"reversibility_word": "SLOW",
		"tag_note": "Permissions can be revoked. The habits they create are the part that sticks.",
	},
}

## The reversibility scale's top value. 0 NEVER, 1 HARD, 2 SLOW, 3 EASY. Score
## normalises a tag against this, so the words above and this number can only
## move together.
const REVERSIBILITY_MAX := 3

## What a placement means in practice, one line per level. This replaced the
## accountable-owner pick: the crew choose a level and the record states who
## runs the decision at that level, rather than asking them to staff it.
const WHO_RUNS_IT := {
	"automated": "SHIPMIND runs it, inside limits the crew set. The crew still answer for those limits.",
	"review": "SHIPMIND runs it. A crew member checks after, and can undo.",
	"signoff": "A crew member must approve each action before it happens.",
	"human_only": "The crew make this call themselves. SHIPMIND is not asked.",
}

## What the player has declared. Empty until the boot screen records it: a
## placement made before this exists would have nothing to be consistent with,
## which is why it is a prerequisite rather than flavour.
static var objective_id: String = ""
static var appetite_id: String = ""


static func reset() -> void:
	objective_id = ""
	appetite_id = ""


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


## The same entries, by id - what the mandate picker uses while the crew are
## still choosing: the picker holds pending picks that are not on the model
## yet, so the declared-state accessors above cannot answer for them.
static func objective_entry_for(id: String) -> Dictionary:
	return _entry(OBJECTIVES, id)


static func appetite_entry_for(id: String) -> Dictionary:
	return _entry(APPETITES, id)


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
		return "NO MANDATE DECLARED"
	return "OBJECTIVE  %s   |   RISK  %s" % [objective_label(), appetite_label()]


## The mandate as the sentence the player declared, so a decision can be read
## back against the words the player chose rather than against a label.
static func mandate_statement() -> String:
	if not is_declared():
		return "No mandate has been declared for this session."
	return "%s Risk: %s - %s" % [
		objective_statement(), appetite_label().to_lower(), appetite_blurb()]


## What the chosen level means in practice: who runs the decision once the
## crew walk away from the console. One line, derived from the level itself.
static func who_runs_it(level_id: String) -> String:
	return String(WHO_RUNS_IT.get(level_id, ""))


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
