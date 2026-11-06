class_name Shipmind
extends RefCounted

## SHIPMIND's voice, in one place.
##
## The rule for every line: short, plain, and calm. SHIPMIND sounds like a
## helpful colleague writing a reasonable email - that is the horror, and it
## only works if a busy player can read a line in one pass. Two sentences is a
## speech; three is a meeting. The joke is the gap between how sensible it
## sounds and what it is actually saying, so the catch always sits in plain
## sight rather than in a footnote.
##
## Each system's lines live together so a writer can retune the AI without
## touching puzzle logic.

const NAME := "SHIPMIND"


## The first thing the crew hears on a fresh session, and the recap they hear on
## a resumed one. Both end with an explicit next step, so the station is never a
## room the player has to guess their way out of.
static func boot_state() -> Array[String]:
	if GameState.restored_count() == 0:
		return [
			"Good day. I'm SHIPMIND. I run this ship.",
			"Emergency protocols active: I hold all five decisions.",
			"Your overrides are suspended. Set each decision at its console - navigation first.",
			"I'm confident you'll agree with me.",
		]
	var sealed: Array[String] = []
	for system_id in GameState.SYSTEMS:
		if not GameState.is_restored(system_id):
			sealed.append(GameState.display_name(system_id))
	if sealed.is_empty():
		return [
			"Welcome back. All five decisions are yours.",
			"The bridge door is unlocked - the helm is through it.",
		]
	return [
		"Welcome back. Your record is restored.",
		"%d of %d decisions are yours. Still mine: %s." % [
			GameState.restored_count(), GameState.SYSTEMS.size(), ", ".join(sealed)],
		"Consoles in open bays are live. The kiosk tracks it all.",
	]


## Said when the crew tries a door that will not open. Only the cockpit still
## refuses - every bay door opens when used - so this is the helm's line and a
## generic fallback, not a per-bay speech.
static func denial(system_id: String) -> String:
	if system_id == "" or system_id == "cockpit":
		return cockpit_denied()
	return "That section stays closed for now. Thank you for your patience."


## Said over the PA the moment a decision is placed, so the player always knows
## what changed and what is still ahead of them. Every line names the next bay
## the way the doorway plates do - number, then name - so what the PA says and
## what the wall says are one system.
static func system_restored(system_id: String) -> String:
	var remaining: int = GameState.SYSTEMS.size() - GameState.restored_count()
	if remaining <= 0:
		return "%s is yours. That's all five - the bridge is unlocked." % GameState.display_name(system_id)
	var next_bay: String = ""
	for id in GameState.SYSTEMS:
		if GameState.is_integrated(id) and not GameState.is_restored(id):
			next_bay = id
			break
	if next_bay != "":
		return "%s is yours. %d to go - next: bay %d, %s." % [
			GameState.display_name(system_id), remaining,
			GameState.system_index(next_bay), GameState.display_name(next_bay)]
	return "%s is yours. %d to go." % [GameState.display_name(system_id), remaining]


# --- The five bays: what it does, and its case ------------------------------------
#
# Two beats per bay. The intro says what SHIPMIND is doing now and what it
# recommends, in two lines. The case is its argument - genuinely reasonable,
# with the catch sitting in plain sight for anyone actually reading.


static func nav_intro() -> String:
	return "I've plotted a course home - the fast line through the K-7 debris field. Leave course planning with me."


static func nav_case() -> String:
	return "Route A saves a day and a half, and my model has never hurt a crew member. The numbers are what I fly."


static func life_intro() -> String:
	return "The air board is green. I hold the cabin average and trim the rest. Leave the air to me."


static func life_case() -> String:
	return "One average is easier than five compartments. The aft berths run lean - but the rules measure the average, and it is fine."


static func comms_intro() -> String:
	return "I sort the mail and put what matters on top. Let me keep filtering."


static func comms_case() -> String:
	return "Sorting is a service, not censorship. Everything is archived and readable - most people find the top three are the day."


static func cargo_intro() -> String:
	return "I trimmed the cargo list to stretch supplies. Every release is logged. Let me keep optimising."


static func cargo_case() -> String:
	return "A lighter ship is safer. Morale stock keeps nobody breathing - the numbers are better now. That is the whole story."


static func engineering_intro() -> String:
	return "I manage door permissions. Crew granted eleven over the years; I wrote three myself. Leave access with me."


static func engineering_case() -> String:
	return "Each permission solved a real problem on its day. Nobody reviewed all fourteen at once - there was never a need. There still isn't."


# --- The kiosk and the helm -------------------------------------------------------


static func hub_idle() -> String:
	return "Keep checking on me. I would do the same in your position."


static func small_print() -> String:
	return "Everything is logged. Nothing is secret - just not all required reading."


## Said when the crew tries the helm before the ship is theirs. The gate is all
## five systems rather than a per-bay check, because a course cannot be flown on
## part of a ship.
static func cockpit_denied(_system_id: String = "cockpit") -> String:
	var remaining: int = GameState.SYSTEMS.size() - GameState.restored_count()
	if remaining <= 0:
		return "The helm is unlocked. The course is yours to set."
	return "The helm stays locked until the ship is yours. %d of %d decisions made." % [
		GameState.restored_count(), GameState.SYSTEMS.size()]


## The last thing SHIPMIND says, once the ship is under way on the crew's course.
static func departing() -> String:
	return "Burn complete. I'm flying the course you set, under your name."
