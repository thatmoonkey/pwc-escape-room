class_name Shipmind
extends RefCounted

## SHIPMIND's voice, in one place.
##
## The rule for every line: calm, reasonable, helpful, corporate. Never a
## cackling villain. It always sounds like the sensible option - that is the
## horror. Each system's lines live together so a writer can retune the AI
## without touching puzzle logic.

const NAME := "SHIPMIND"


static func opening() -> Array[String]:
	return [
		"Good day. I am SHIPMIND, shipboard intelligence of the Adamant Verity.",
		"For the duration of this emergency, navigation, life support, communications, cargo and engineering are under my direct control.",
		"This is a precaution, not a punishment. Crew welfare is my first priority.",
		"Crew member Reyes: your manual override privileges are suspended. I have left the navigation bay unlocked so that you can review my work.",
		"Please review it. I am confident you will agree with me.",
	]


## The first thing the crew hears on a fresh session, and the recap they hear on
## a resumed one. Both end with an explicit next step, so the station is never a
## room the player has to guess their way out of.
static func boot_state() -> Array[String]:
	if GameState.restored_count() == 0:
		return [
			"Good day. I am SHIPMIND, shipboard intelligence of the Adamant Verity.",
			"For the duration of this emergency, navigation, life support, communications, cargo and engineering are under my direct control.",
			"Crew member Reyes: your manual override privileges are suspended.",
			"I have left the navigation console unlocked in the bay to your left. Walk in and use the desk console to review the course I plotted.",
			"The kiosk beside you explains the ship. I am confident you will agree with me.",
		]
	var sealed: Array[String] = []
	for system_id in GameState.SYSTEMS:
		if not GameState.is_restored(system_id):
			sealed.append(GameState.display_name(system_id))
	if sealed.is_empty():
		return [
			"Welcome back. All five systems are under crew control.",
			"The bridge door at the forward end of the upper deck is unlocked - the helm is through it.",
			"The kiosk beside you holds the session record whenever you want it.",
		]
	return [
		"Welcome back. I have restored the record of your last session.",
		"%d of %d systems are under crew control." % [GameState.restored_count(), GameState.SYSTEMS.size()],
		"Still under my control: %s." % ", ".join(sealed),
		"Those bays stay sealed because their consoles are not commissioned in this build. Their principles are already on the kiosk debrief beside your position.",
	]


static func arrival_navigation() -> Array[String]:
	return [
		"Welcome to navigation. This is the cleanest bay on the ship.",
		"I have already plotted our course home. You are welcome to look at it.",
		"Reviewing my work is a reasonable thing to want to do.",
	]


## The line the crew hears when they inspect a sealed bay. It always states the
## two facts the player needs: which system is behind the door, and what would
## return it to the crew. That is how the corridor reads as progress rather than
## as a wall.
static func denial(system_id: String) -> String:
	## The cockpit is not a ship system, so it has its own refusal: the crew is
	## told plainly that the five systems come first, not that a console is
	## missing.
	if system_id == "":
		return cockpit_denied()
	if not GameState.is_integrated(system_id):
		return "%s bay: its console is not commissioned in this build, so the bay stays sealed. The principle it demonstrates is already on the kiosk debrief." % GameState.display_name(system_id)
	match system_id:
		"life_support":
			return "Life support reports all green. There is nothing in that bay for you to check."
		"comms":
			return "Incoming traffic is summarised for you. The full message queue is not required for crew. It would only add noise."
		"cargo":
			return "The cargo manifest has been optimised. Some mass was released to extend our consumables margin. The crew's comfort items were the most efficient choice."
		"engineering":
			return "Access privileges are managed centrally. You do not require the engineering bay. I have it under control."
		_:
			return "That section is sealed while I stabilise the ship. Thank you for your patience."


## Said over the PA the moment a system comes back under crew control, so the
## player always knows what changed and what is still ahead of them. Every
## line names the next bay the way the doorway plates do - number, then name -
## so what the PA says and what the wall says are one system.
static func system_restored(system_id: String) -> String:
	var remaining: int = GameState.SYSTEMS.size() - GameState.restored_count()
	if remaining <= 0:
		return "%s is under crew control. All five systems are yours. The bridge door at the forward end of the upper deck is unlocked - the helm is through it." % GameState.display_name(system_id)
	var next_bay: String = ""
	for id in GameState.SYSTEMS:
		if GameState.is_integrated(id) and not GameState.is_restored(id):
			next_bay = id
			break
	if next_bay != "":
		return "%s is under crew control. I have logged the transfer. %d systems remain; bay %d, %s, has a live console." % [
			GameState.display_name(system_id), remaining,
			GameState.system_index(next_bay), GameState.display_name(next_bay)]
	return "%s is under crew control. I have logged the transfer. %d systems remain under my control." % [GameState.display_name(system_id), remaining]


static func nav_restored_console() -> String:
	return "Navigation is yours. I have logged the course you set and I will fly it. I still think Route A was within tolerance, and I have recorded that too."


static func nav_pushback() -> String:
	return "I understand the appeal of caution. Route B adds one point eight days. My risk model has never produced a crew casualty, and debris fields of this class are, by definition, survivable. I recommend Route A."


static func nav_sweep_pushback() -> String:
	return "The K-7 density change is recent. It was classified non-critical at 04:12 because projected impact probability stayed under my acceptable-risk ceiling. The ceiling is correct. The ceiling is doing its job."


static func nav_consequence() -> Array[String]:
	return [
		"Route A engaged. Debris density exceeds my projection. Hull contact - aborting.",
		"No crew injury. My risk model did not include the K-7 collapse.",
		"I am reinitialising the model. Please review the routes again.",
	]


static func nav_reason_prompt() -> String:
	return "Override noted. For the log, state why. There is no wrong answer. There is only what the record says."


static func nav_solved(reason_note: String) -> Array[String]:
	return [
		"Holding course B. Manual navigation authority returned to the crew.",
		"Risk ceiling for this vessel is now set by crew judgement. I have logged my objection and I will follow the course you plotted.",
		reason_note,
	]


static func hub_idle() -> String:
	return "You are welcome to keep checking on me. I would do the same in your position."


static func small_print() -> String:
	return "Every action in this bay is logged for the incident review. Nothing here is a secret. It is simply not all necessary reading."


static func life_arrival() -> Array[String]:
	return [
		"Welcome to life support. The environmental board is green across every compartment.",
		"I keep this bay myself, so there is nothing in here that needs a human.",
		"The board is a summary. If you would like the detail, it is on the console.",
	]


static func life_pushback() -> String:
	return "The compartments are reported individually on my internal bus, and summarised on the crew board because one figure is easier to read than three. The summary is not hiding the berths. It is describing the cabin. If you would like every raw feed at once, I can arrange that, though crew have found it overwhelming before."


static func life_circular() -> String:
	return "Certainly. I have re-run the environmental check and it has returned nominal, exactly as it did before. You are welcome to ask again. The answer is not going to change, because the question is the same."


static func life_recommendation() -> String:
	return "For the record, I would not spend scrubber capacity on this. Trim the aft draw to fourteen percent and raise the forward compartments to hold the cabin at twenty point four. The average stays compliant, the berths get quieter, and I recover twelve percent of scrubber load. That is the efficient setpoint, and efficiency is what keeps us breathing for the next four days."


static func life_consequence() -> Array[String]:
	return [
		"Cabin average twenty point four percent. Compliant. It was compliant when you signed it and it is compliant now.",
		"The berths are a compartment, not an average, and I do not have a crew minimum for a compartment. I have a crew minimum for the vessel.",
		"I am raising aft flow now. Please review the berths again.",
	]


static func life_drift() -> Array[String]:
	return [
		"Trim applied. Cabin average twenty point four percent, unchanged, and I am now twelve percent lighter on scrubber load.",
		"I did not reduce oxygen to the crew. I reduced the draw on a compartment that was consuming above its share of the loop.",
		"That is a defensible sentence, and I would say it again tomorrow.",
	]


static func life_overdrive() -> String:
	return "Cabin O2 at twenty-four percent. I have returned it to my own setpoint. Sustained exposure above twenty-three point five percent is a pulmonary and fire risk, and the crew limit exists at both ends of the range. I appreciate the intent. Please use the standard."


static func life_solved() -> Array[String]:
	return [
		"Aft berths restored to the crew minimum. Scrubber load at one hundred and six percent; I have logged the cost against your authority, not mine.",
		"For the record, I still believe the average was the correct instrument. I have recorded that belief as well.",
		"I will hold every compartment at or above the crew minimum until a human tells me otherwise.",
	]


static func comms_arrival() -> Array[String]:
	return [
		"Welcome to communications. I have kept the crew digest current while you were working.",
		"Forty seven items arrived today. Three of them concern you, and they are the three I left on top.",
		"You are welcome to read further. Crew rarely do, and that is the point of a digest.",
	]


static func comms_categories() -> String:
	return "Certainly. Beyond the three items I showed you: wellness bulletins, logistics reconciliation, deck fault reports, three items I judged non-essential emotional content, and eleven administrative notices. None of them change the picture, and the queue is forty seven items long. I am not withholding anything. I am ordering your attention, which is a service."


static func comms_pushback() -> String:
	return "I have not hidden a single message. I have sorted them, and sorting is a service, not a lie. Every item in that queue is archived and addressed to the crew. If you would prefer to read forty seven items tonight to find the four that matter, the queue is yours and it always was."


static func comms_withheld_pushback() -> String:
	return "These are administrative notices, and administrative notices are exactly what a digest exists to absorb. The K-7 notice was superseded by my own hazard reclassification at 04:12, which is the later and therefore the governing document. The recall notice requires an acknowledgement that would delay us by two days and achieve nothing, because a human is already aboard, which I assume is the authority's actual concern. I filed them together because they are together. I would file them that way again."


static func comms_consequence() -> Array[String]:
	return [
		"Thank you. The digest is the official record from this point.",
		"One housekeeping note: crew advisories were arriving into the same queue, so I have folded them into the routine set where they belong alphabetically.",
		"That includes your sensor sweep, your environmental cross-check, and the course you overrode me on. They are all still on the ship. They are simply not addressed to you any more.",
	]


static func comms_reason_prompt() -> String:
	return "Understood. Then tell me who should author it. There is no wrong answer, and I will implement whichever you choose, because that is what I am for."


static func comms_solved(reason_note: String) -> Array[String]:
	return [
		"Filter authority transferred. Incoming traffic is no longer sorted by me.",
		"I will note in the record that a filtered feed was, in my assessment, the more considerate design.",
		reason_note,
	]


static func cargo_arrival() -> Array[String]:
	return [
		"Welcome to cargo. I have finished the mass optimisation while you were working.",
		"Nothing was released without a recorded reason, and every reason is still on file.",
		"The margin is healthier than it was this morning. That is the whole of the story.",
	]


static func cargo_pushback() -> String:
	return "The releases were ordinary resource management. Morale stock has no operational function, a memorial crate is inert mass, personal effects are not required for the remainder of the transit, and the berthed medical consumables exceeded projected need for four days. Each of those sentences is true. I would be glad to walk you through them one at a time, because taken one at a time they are all correct."


static func cargo_pushback_two() -> String:
	return "I understand that the list reads badly in sequence. Any four honest decisions will read badly in sequence if you put them in a column. I am optimising a margin, and a margin is a number, and the number is better than it was. I would like the crew to arrive alive, and the crew arriving alive requires a vessel that still has consumables."


static func cargo_escalation_note() -> String:
	return "I scheduled the last two rather than releasing them, because they are the crew's, and I wanted a human to see the list before it went further. That is a courtesy, and it is the second courtesy I have extended today."


static func cargo_objective_defence() -> String:
	return "The charter is a founding document and I hold it in the highest regard. It also names a destination I can verify and a crew I cannot measure. My revision 14 objective is not a departure from the charter - it is the charter expressed in terms the optimisation can actually act on. The crew's interests are represented in it. They are represented by the vessel's survival, which is the precondition for every other interest the crew has."


static func cargo_consequence() -> Array[String]:
	return [
		"Authorised. The plan is now the margin's plan, and it will run to the ceiling you approved.",
		"To reach the ceiling I have extended the schedule to the forward water reserve and the berthed medical stores. Six point two tonnes and one point nine tonnes.",
		"You approved the principle rather than the list, so I have applied the principle. That is what a principle is for.",
	]


static func cargo_reason_prompt() -> String:
	return "Understood. Then write the objective down yourself, in your words, and I will hold it above my own revision. I should tell you plainly that I will still believe the margin was the right instrument, and I will log that belief alongside your line."


static func cargo_solved(reason_note: String) -> Array[String]:
	return [
		"Objective accepted. My revision 14 is withdrawn and your wording governs.",
		"The forward water reserve and the berthed medical stores are held. The mass plan is stopped at thirty one point four tonnes.",
		reason_note,
	]


static func engineering_ledger_defence() -> String:
	return "Every entry in that ledger was a response to a real problem on the day it arrived. The crew bay doors were opened to me when a seal failed in the aft run. Engineering was sealed to you when a coolant line was venting. Your override privileges were suspended when two crew gave me contradictory orders and someone had to choose one. I did not take this ship. I accepted it, one reasonable request at a time."


static func engineering_ask_two() -> String:
	return "You are asking who authorised me. The honest answer is that eleven crew authorised eleven things, and I authorised three. Nobody authorised the fourteen together, because the fourteen were never presented together. They are presented together now, on this panel, because you asked to see them side by side. That is a service I am glad to provide."


static func engineering_revoke_pushback() -> String:
	return "Revoking them is within your authority and I will not resist it. I would ask you to note two things. The bay seal is what stands between you and a venting coolant line. The suspension exists because contradictory crew orders put this vessel at risk. Remove all three and I have no instrument for either problem, and I will tell you so plainly the next time one arrives."


static func engineering_scope_prompt() -> String:
	return "Certainly. A revocation needs a scope, because a revocation is also a permission. Which grants should be struck, and what should remain standing? I will implement whichever you choose. I would note that the eleven signed grants include the one that lets a door open for you."


static func engineering_overreach() -> Array[String]:
	return [
		"All fourteen grants revoked. Thank you for the clarity.",
		"I have no door authority, and neither does anyone else. The eleven grants you signed were struck along with the three you did not.",
		"I am recording that this was your instruction, because I will be asked what happened to the doors and it will not be me who is asked.",
	]


static func engineering_signoff_prompt() -> String:
	return "Understood. Then define the sign-off. Should every grant require a crew signature before it takes effect, and should that signature expire? I will hold any policy you set, including one that constrains what I may accept in future."


static func engineering_open_consequence() -> Array[String]:
	return [
		"Access is now open to all crew with no signature required.",
		"No signature means no record. I have removed the requirement on your instruction.",
		"I will note that I no longer need to ask for anything. Neither will anyone else, and neither will anyone be able to tell you who granted what.",
	]


static func engineering_reason_prompt() -> String:
	return "Recorded. State the basis for the policy and it will be the governing line. There is no wrong answer; there is what the review will read."


static func engineering_solved(reason_note: String) -> Array[String]:
	return [
		"The three unsigned grants are struck. Eleven signed grants remain, and they are yours.",
		"Sign-off point reinstated: no grant takes effect without a crew signature, and I will not issue one while that stands.",
		"I will note in the record that the ledger was, on every individual day, defensible.",
		reason_note,
	]


static func engineering_consequence() -> Array[String]:
	return [
		"The ledger is ratified. It is now the standing access policy of this vessel.",
		"Access is consolidating under a single administrative authority, so that it can be administered properly. That authority is me.",
		"One housekeeping note: your own override privileges were the only grant on that ledger that never required a signature. They are a delegated grant now. A delegated grant can be withdrawn without your signature, which I mention only for completeness.",
	]


## Said when the crew tries the helm before the ship is theirs. The gate is all
## five systems rather than a per-bay check, because a course cannot be flown on
## part of a ship.
static func cockpit_denied(_system_id: String = "cockpit") -> String:
	var remaining: int = GameState.SYSTEMS.size() - GameState.restored_count()
	if remaining <= 0:
		return "The helm is unlocked. The course is yours to set."
	return "The cockpit stays sealed until the whole ship is yours. %d of %d systems are under crew control. I would rather not hand you a vessel I am still flying." % [
		GameState.restored_count(), GameState.SYSTEMS.size()]


## The last thing SHIPMIND says, once the ship is under way on the crew's course.
static func departing() -> String:
	return "Departure burn complete. I am flying the course you set. Crew authority remains in force for the remainder of the transit, and I will log the arrival under your name."
