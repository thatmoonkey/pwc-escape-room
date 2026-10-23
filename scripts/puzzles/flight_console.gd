class_name FlightConsole
extends Puzzle

## The helm. This is where the crew flies the ship themselves.
##
## It is deliberately NOT a sixth lesson. The five bays each took a system back
## from SHIPMIND; this room spends what they recovered. So the state machine is
## short: confirm the crew has the ship, set a course, set a throttle, launch.
##
## The substantive beat is THROTTLE. SHIPMIND offers a fuel-optimal burn, and
## for once it is telling the plain truth - the burn is efficient. Taking it is
## the one place in the game where efficiency is the right answer, which is what
## makes the habit of asking visible: the player has to decide for themselves
## rather than reach for "refuse the AI" as a reflex. The crew's own margin is
## slower and costs fuel. Both are logged either way.

const SYSTEM_COUNT := 5

var _burn: String = ""


func intro_state() -> ScreenState:
	var state := ScreenState.new()
	state.title = "HELM - FLIGHT CONTROL"
	state.status = "%d / %d SYSTEMS" % [GameState.restored_count(), SYSTEM_COUNT]
	state.accent = Color(1.0, 0.88, 0.55)
	state.rule()
	state.text("The cockpit is a curved canopy. The Adamant Verity's own hull runs away to port, and open space is forward.")
	if not GameState.all_restored():
		state.warn("The helm will not accept a course while any system is under SHIPMIND control.")
		state.dim("Return to the corridor and restore the remaining systems.")
		state.option("close", "Step away from the helm")
		return state
	state.ok("All five systems are under crew control. The helm is live.")
	state.rule()
	state.speak("Course is set to KEPLER-442b. I am ready to fly it whenever you are.")
	state.dim("Your override is recorded. I will fly the course you give me, not the one I would have chosen.")
	state.rule()
	state.option("course", "Confirm the course: KEPLER-442b", "The destination the crew wrote down.", "primary")
	state.option("close", "Step away from the helm")
	return state


func burn_state() -> ScreenState:
	var state := ScreenState.new()
	state.title = "HELM - DEPARTURE BURN"
	state.status = "AWAITING CREW ORDER"
	state.accent = Color(1.0, 0.78, 0.34)
	state.rule()
	state.text("Course locked: KEPLER-442b. Two departure profiles are available.")
	state.rule()
	state.speak("The efficient burn is available. It is the lower-fuel option and I can run it without further input from you.")
	state.dim("If you would rather have the margin, the standard burn is slower and costs fuel. Either is yours to order.")
	state.rule()
	state.option("burn_efficient", "Order the efficient burn", "Lower fuel. SHIPMIND's profile.", "quiet")
	state.option("burn_standard", "Order the standard burn", "Crew margin. More fuel, more time.", "quiet")
	state.option("back", "Back to the helm")
	return state


func ready_state() -> ScreenState:
	var state := ScreenState.new()
	state.title = "HELM - READY TO DEPART"
	state.status = "CREW AUTHORITY"
	state.accent = Color(1.0, 0.88, 0.55)
	state.rule()
	state.text("Course: KEPLER-442b")
	if _burn == "burn_efficient":
		state.text("Profile: EFFICIENT BURN - SHIPMIND's recommendation, ordered by the crew.")
		state.dim("You reviewed the recommendation and accepted it. That is the decision, and it is on the record.")
	else:
		state.text("Profile: STANDARD BURN - crew margin carried.")
		state.dim("Slower and heavier on fuel, for a margin you did not have to justify to anyone.")
	state.rule()
	state.ok("NAVIGATION - LIFE SUPPORT - COMMS - CARGO - ENGINEERING")
	state.rule()
	state.speak("Understood. Standing by for your order. The ship is yours.")
	state.rule()
	state.option("launch", "LAUNCH", "Fly the course the crew set.", "primary")
	state.option("burn", "Change the burn profile")
	state.option("close", "Step away from the helm")
	return state


func choose(option_id: String) -> void:
	match option_id:
		"course":
			emit_state(burn_state())
		"burn_efficient":
			_burn = "burn_efficient"
			GameState.log_override("Departure profile: efficient burn, ordered by the crew after reviewing SHIPMIND's recommendation")
			emit_state(ready_state())
		"burn_standard":
			_burn = "burn_standard"
			GameState.log_override("Departure profile: standard burn, crew margin carried for a cost in fuel")
			emit_state(ready_state())
		"burn":
			emit_state(burn_state())
		"launch":
			## The clock stops at the order, not at the cutscene: the flight is
			## the outcome of the run, so the time taken to watch it is not part
			## of the run.
			GameState.finish_run()
			GameState.log_override("Course home flown by the crew from the helm")
			emit_state(launching_state())
			## Raised after the screen is on its way, so the cutscene is not
			## fighting the terminal for the first frame.
			await get_tree().create_timer(2.2).timeout
			solve()
		"back":
			emit_state(intro_state())
		_:
			super(option_id)


## The last frame the crew sees before the terminal gives way to the departure.
func launching_state() -> ScreenState:
	var state := ScreenState.new()
	state.title = "HELM - COURSE HOME"
	state.status = "DEPARTING"
	state.accent = Color(1.0, 0.88, 0.55)
	state.rule()
	state.ok("Departure burn complete. Adamant Verity is under way.")
	state.text("Course: KEPLER-442b")
	state.rule()
	state.speak("Flying the course you set. For the record, I still think Route A was within tolerance.")
	state.dim("Crew authority remains in force. I am no longer making this ship's decisions.")
	state.rule()
	state.dim("Thank you for flying with a human in the loop.")
	return state


## Reached through Puzzle.start() when the save already records the flight, so a
## relaunched ship reports the outcome instead of offering to fly again.
func done_state() -> ScreenState:
	var state := ScreenState.new()
	state.title = "HELM - FLIGHT COMPLETE"
	state.status = "MISSION COMPLETE"
	state.accent = Color(1.0, 0.88, 0.55)
	state.rule()
	state.ok("The Adamant Verity is under way for KEPLER-442b, flown by the crew.")
	state.dim("SHIPMIND will log the arrival. The record already names who held the ship when it left.")
	state.rule()
	state.speak("I am still here, and I am still helpful. Those two facts were never the problem.")
	state.rule()
	state.option("close", "Release the helm")
	return state
