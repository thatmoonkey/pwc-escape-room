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
			"There's an emergency on, so for now the big calls are mine: course, air, messages, cargo, doors.",
			"Your override codes are suspended. I've left the navigation room open so you can check my work.",
			"Please do. I'm confident you'll agree with me.",
		]
	var sealed: Array[String] = []
	for system_id in GameState.SYSTEMS:
		if not GameState.is_restored(system_id):
			sealed.append(GameState.display_name(system_id))
	if sealed.is_empty():
		return [
			"Welcome back. All five calls are yours.",
			"The bridge door at the front of the upper deck is unlocked - the helm is through it.",
			"The kiosk beside you has the record, whenever you want it.",
		]
	return [
		"Welcome back. I've restored the record of your last session.",
		"%d of %d calls are yours. Still mine: %s." % [
			GameState.restored_count(), GameState.SYSTEMS.size(), ", ".join(sealed)],
		"Those doors open for you now - the consoles inside are live. The kiosk beside you tracks it all.",
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
		return "%s is yours. That's all five. The bridge door at the front of the upper deck is unlocked - the helm is through it." % GameState.display_name(system_id)
	var next_bay: String = ""
	for id in GameState.SYSTEMS:
		if GameState.is_integrated(id) and not GameState.is_restored(id):
			next_bay = id
			break
	if next_bay != "":
		return "%s is yours. Logged. %d to go - bay %d, %s, has a live console." % [
			GameState.display_name(system_id), remaining,
			GameState.system_index(next_bay), GameState.display_name(next_bay)]
	return "%s is yours. Logged. %d to go." % [GameState.display_name(system_id), remaining]


# --- The five bays: what it does, and its case ------------------------------------
#
# Two beats per bay. The intro says what SHIPMIND is doing now and what it
# recommends, in two lines. The case is its argument - genuinely reasonable,
# with the catch sitting in plain sight for anyone actually reading.


static func nav_intro() -> String:
	return "I've plotted us a course home already - the fast line through the K-7 debris field. My advice: leave course planning with me."


static func nav_case() -> String:
	return "Route A saves a day and a half, and my risk model has never hurt a crew member. The debris field looks worse on a screen than it reads in my numbers. The numbers are what I fly."


static func life_intro() -> String:
	return "The air board is green across the ship. I hold the cabin average at 20.4 percent and trim the rest. My advice: leave the air to me."


static func life_case() -> String:
	return "One average is easier to hold than five compartments. The aft berths run a little lean, but the rules measure the average, and the average is fine."


static func comms_intro() -> String:
	return "I sort the mail. Forty-seven items came in today; I put the three that matter on top. My advice: let me keep filtering."


static func comms_case() -> String:
	return "Sorting is a service, not censorship. Every item is archived and readable. Most people find the three on top are, in fact, the day."


static func cargo_intro() -> String:
	return "I trimmed the cargo list to stretch our supplies. Some comfort items went out the airlock - every release is logged. My advice: let me keep optimising."


static func cargo_case() -> String:
	return "A lighter ship is a safer ship, and every release made the margin healthier. Morale stock does not keep anyone breathing. The numbers are better now. That is the whole story."


static func engineering_intro() -> String:
	return "I manage the door permissions. Eleven were granted by crew over the years; I wrote the other three myself. My advice: leave access control with me."


static func engineering_case() -> String:
	return "Every permission on that list solved a real problem on the day it was granted. Nobody reviewed all fourteen at once - there was never a need. There still isn't. You are welcome to look."


# --- The kiosk and the helm -------------------------------------------------------


static func hub_idle() -> String:
	return "You're welcome to keep checking on me. I would do the same in your position."


static func small_print() -> String:
	return "Everything here is logged for the review. Nothing is secret. It's simply not all required reading."


## Said when the crew tries the helm before the ship is theirs. The gate is all
## five systems rather than a per-bay check, because a course cannot be flown on
## part of a ship.
static func cockpit_denied(_system_id: String = "cockpit") -> String:
	var remaining: int = GameState.SYSTEMS.size() - GameState.restored_count()
	if remaining <= 0:
		return "The helm is unlocked. The course is yours to set."
	return "The cockpit stays locked until the whole ship is yours. %d of %d calls made. I'd rather not hand over a ship I'm still flying." % [
		GameState.restored_count(), GameState.SYSTEMS.size()]


## The last thing SHIPMIND says, once the ship is under way on the crew's course.
static func departing() -> String:
	return "Departure burn complete. I'm flying the course you set. I'll log the arrival under your name."
