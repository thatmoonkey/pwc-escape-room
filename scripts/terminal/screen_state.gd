class_name ScreenState
extends RefCounted

## One frame of a diegetic ship terminal screen.
##
## Every terminal in the game - SHIPMIND's monologue, the navigation console,
## the read-only log stations, the mission debrief - is rendered from one of
## these. Puzzles describe the screen; they never touch a Control node.
##
## Line tones: "shipmind" (the AI speaking), "data" (ship readout), "ok",
## "warn", "dim", "rule" (a divider).
## Option tones: "normal", "primary", "danger", "quiet".
##
## LINES, OPTIONS AND ONE TYPED BLOCK. Most screens are lines and a button list,
## and they still are. A screen that asks the player to PLACE something needs a
## real control rather than a flat row of text, so it also carries one typed
## block: the autonomy spectrum. The block is data like everything else here -
## ScreenState describes it, TerminalUI draws it, and the puzzle never touches a
## Control node. A screen carries at most one block.

var title: String = ""
var status: String = "STANDBY"
var lines: Array[Dictionary] = []
var options: Array[Dictionary] = []
var accent: Color = Color(0.93, 0.86, 0.76)

## The one typed block, empty when the screen is a plain readout. Keys:
##   title            what the block is asking for
##   note             one line of context under the title
##   levels           [{id, label, hint, requires_owner}] in spectrum order,
##                    lowest index first; requires_owner is false for human-only
##   guardrail_title  the heading over the guardrail list
##   guardrails       [{id, label, hint, cost}] - cost is required, because a
##                    guardrail that costs nothing is not a decision
##   consequence      the decision's consequence word, shown as a tag
##   reversibility    the decision's reversibility word, shown as a tag
##   tag_note         why the decision carries that tag
##   owner_title      the heading over the accountable-owner list
##   owner_note       what that decision's owner is answering for
##   owners           [{id, label, hint}] - the roles that can own the outcome
##   submit_label     the label on the commit button
var spectrum: Dictionary = {}


func text(value: String) -> ScreenState:
	lines.append({"text": value, "tone": "data"})
	return self


func speak(value: String) -> ScreenState:
	lines.append({"text": value, "tone": "shipmind"})
	return self


func ok(value: String) -> ScreenState:
	lines.append({"text": value, "tone": "ok"})
	return self


func warn(value: String) -> ScreenState:
	lines.append({"text": value, "tone": "warn"})
	return self


func dim(value: String) -> ScreenState:
	lines.append({"text": value, "tone": "dim"})
	return self


func rule() -> ScreenState:
	lines.append({"text": "", "tone": "rule"})
	return self


func option(id: String, label: String, hint: String = "", tone: String = "normal", icon: String = "") -> ScreenState:
	options.append({"id": id, "label": label, "hint": hint, "tone": tone, "icon": icon})
	return self


# --- The autonomy spectrum block ----------------------------------------------


## Starts the spectrum block. Called first, then the levels, then the tag, then
## the guardrails: the block reads in the order it is written, so the screen
## writer cannot accidentally present a guardrail before the levels it guards.
func spectrum_block(title: String, note: String = "") -> ScreenState:
	spectrum = {
		"title": title,
		"note": note,
		"levels": [],
		"guardrail_title": "ONE GUARDRAIL",
		"guardrails": [],
		"consequence": "",
		"reversibility": "",
		"tag_note": "",
		"owner_title": "ACCOUNTABLE OWNER",
		"owner_note": "",
		"owners": [],
		"submit_label": "COMMIT THE PLACEMENT",
	}
	return self


## One rung of the spectrum. The order these are added in IS the order they are
## shown, and the level's own index in the model is what a placement records -
## so a decision never reorders the spectrum to suit itself. label is the full
## name read in the detail block; short_label is the one word under the slider's
## icon, kept short so four stops scan as four pictures rather than four
## paragraphs.
func spectrum_level(id: String, label: String, hint: String = "", requires_owner: bool = true, short_label: String = "") -> ScreenState:
	if spectrum.is_empty():
		spectrum_block("PLACE THE DECISION")
	var levels: Array = spectrum["levels"]
	levels.append({"id": id, "label": label, "hint": hint, "requires_owner": requires_owner, "short": short_label})
	return self


## The decision's own weight, shown with it. This is not decoration: the tag is
## the input to a defensible placement, so it has to be readable before the
## placement is made rather than after it is judged.
func spectrum_tag(consequence: String, reversibility: String, note: String = "") -> ScreenState:
	if spectrum.is_empty():
		spectrum_block("PLACE THE DECISION")
	spectrum["consequence"] = consequence
	spectrum["reversibility"] = reversibility
	spectrum["tag_note"] = note
	return self


func spectrum_guardrail_title(title: String) -> ScreenState:
	if spectrum.is_empty():
		spectrum_block("PLACE THE DECISION")
	spectrum["guardrail_title"] = title
	return self


## One guardrail. The cost line is not optional in the design even though it is
## optional in the signature: a guardrail that costs nothing against the
## objective is not a decision, and the console copy has to say what it spends.
func spectrum_guardrail(id: String, label: String, hint: String = "", cost: String = "") -> ScreenState:
	if spectrum.is_empty():
		spectrum_block("PLACE THE DECISION")
	var guardrails: Array = spectrum["guardrails"]
	guardrails.append({"id": id, "label": label, "hint": hint, "cost": cost})
	return self


## The accountability step, written after the guardrails and before the commit.
## A placement above human-only has to name the role that answers for the
## outcome, so the block carries the candidate roles and what they are answering
## for. Human-only carries no roles: the operator owns it by definition, and the
## console says so instead of asking a question with only one answer.
func spectrum_owner_title(title: String) -> ScreenState:
	if spectrum.is_empty():
		spectrum_block("PLACE THE DECISION")
	spectrum["owner_title"] = title
	return self


func spectrum_owner_note(note: String) -> ScreenState:
	if spectrum.is_empty():
		spectrum_block("PLACE THE DECISION")
	spectrum["owner_note"] = note
	return self


func spectrum_owner(id: String, label: String, hint: String = "") -> ScreenState:
	if spectrum.is_empty():
		spectrum_block("PLACE THE DECISION")
	var owners: Array = spectrum["owners"]
	owners.append({"id": id, "label": label, "hint": hint})
	return self


func spectrum_submit(label: String) -> ScreenState:
	if spectrum.is_empty():
		spectrum_block("PLACE THE DECISION")
	spectrum["submit_label"] = label
	return self


func has_spectrum() -> bool:
	return not spectrum.is_empty()
