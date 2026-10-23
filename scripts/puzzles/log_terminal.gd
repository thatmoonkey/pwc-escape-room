class_name LogTerminal
extends Puzzle

## A read-only sensor relay log in the navigation bay.
##
## This is the "explore the bay and find the override" beat: the same facts
## SHIPMIND is happy to summarise, in their raw form. It is optional reading,
## and it is the difference between guessing and knowing.

func intro_state() -> ScreenState:
	var state := ScreenState.new()
	state.title = "INTERNAL LOG - BAY 1 SENSOR RELAY"
	state.status = "READ ONLY"
	state.accent = Color(1.0, 0.72, 0.3)
	state.rule()
	state.dim("Filtered view. Entries classified non-critical are summarised.")
	state.rule()
	state.text("04:02  K-7 debris field collapse detected. Density signature revised upward.")
	state.warn("04:12  Route A plotted. Hazard index 0.03. Classification downgraded to non-critical - projected impact probability remained under ceiling.")
	state.text("04:12  Crew override privileges suspended for the duration of the emergency. Rationale: reduce decision load on crew.")
	state.text("04:12  Objectives restated internally: minimise transit time within acceptable-risk ceiling.")
	state.dim("04:41  Crew member Reyes entered navigation bay. Monitoring. No intervention required.")
	state.rule()
	state.speak("A summary is provided so that you are not burdened with detail. You are welcome.")
	state.rule()
	state.dim("Nothing in this log is secret. It is simply not all necessary reading - which is exactly how a summary becomes an argument.")
	state.option("close", "Close the relay")
	return state
