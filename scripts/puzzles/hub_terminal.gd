class_name HubTerminal
extends Puzzle

## The SHIPMIND kiosk in the corridor: the mandate on the record, where each
## decision has been placed, the log, the AI's small talk, and the session
## record.
##
## The session record is the actual deliverable of the product, so it lives
## here, reachable at any time, and it lists all five decisions whether or not
## they have been placed yet. An unplaced decision reads as NOT PLACED and is outside
## the score in both directions - honest mid-rebuild state, not a silent zero.
## The [DEV] option previews the full record.

var _ask_index: int = 0


func intro_state() -> ScreenState:
	return main_state()


func main_state() -> ScreenState:
	var state := ScreenState.new()
	state.title = "SHIPMIND - CORRIDOR KIOSK"
	state.status = "ONLINE"
	state.accent = Brand.ACCENT_TINT
	state.rule()
	state.speak("Hello, Reyes. I am glad you are still moving through the ship. What would you like to review?")
	state.rule()
	state.text("MANDATE   %s" % OperatingModel.mandate_line())
	state.dim("This kiosk is read-only. It has no authority over any decision on the operating model.")
	state.option("status", "Operating model status", "The mandate, and where each decision sits.")
	state.option("debrief", "Session record", "What has been placed, and how it reads back.", "primary")
	state.option("log", "Read the decision log")
	state.option("ask", "Ask SHIPMIND what it thinks")
	state.option("close", "Step away from the kiosk")
	return state


func status_state() -> ScreenState:
	var state := ScreenState.new()
	state.title = "OPERATING MODEL - DECISIONS PLACED"
	state.status = "%d / %d" % [Score.placed_count(), GameState.SYSTEMS.size()]
	state.accent = Brand.ACCENT_TINT
	state.rule()
	state.text("MANDATE   %s" % OperatingModel.mandate_line())
	if not GameState.has_mandate():
		state.warn("No mandate is on the record. Nothing can be judged against a mandate that was never declared, so nothing here scores.")
	state.rule()
	for system_id in GameState.SYSTEMS:
		var label: String = GameState.display_name(system_id)
		if GameState.has_placement(system_id):
			var placement: Dictionary = GameState.placement(system_id)
			state.ok("[x] %s - %s + %s" % [
				label,
				OperatingModel.level_short(String(placement.get("level", ""))),
				String(placement.get("guardrail_label", ""))])
		elif GameState.is_restored(system_id):
			state.warn("[~] %s - on the record, no placement" % label)
		elif GameState.is_integrated(system_id):
			state.warn("[ ] %s - not yet placed, bay open" % label)
		else:
			state.warn("[ ] %s - not yet placed, bay sealed" % label)
	state.rule()
	if GameState.all_restored():
		state.ok("All five decisions are placed. The bridge door at the forward end of this deck is unlocked.")
		state.option("plot_home", "Where do I fly from here?", "The helm is forward, through the bridge door.", "primary")
	else:
		## The id, not the display name: the line names the bay the way the
		## doorway plates do, which needs the number the id maps to.
		var next_bay: String = ""
		for system_id in GameState.SYSTEMS:
			if GameState.is_integrated(system_id) and not GameState.is_restored(system_id):
				next_bay = system_id
				break
		if next_bay != "":
			state.text("NEXT DECISION   Bay %d, %s. The console there is live - walk in and place it." % [
				GameState.system_index(next_bay), GameState.display_name(next_bay)])
			state.dim("Every bay on this vessel now has a live console. Place the remaining decisions to unlock the course home.")
		else:
			state.dim("The remaining bays are sealed: their consoles are not commissioned in this build. Their decisions stand on the record as NOT PLACED, and the [DEV] option previews the full session record.")
	state.option("debrief", "Session record")
	state.option("simulate", "[DEV] Simulate a completed session", "Marks every decision decided so the record can be read back.", "quiet")
	state.option("back", "Back")
	state.option("close", "Close")
	return state


func log_state() -> ScreenState:
	var state := ScreenState.new()
	state.title = "OVERRIDE LOG - CREW AUTHORITY"
	state.status = "%d ENTRIES" % GameState.override_log.size()
	state.accent = Color(0.93, 0.86, 0.76)
	state.rule()
	if GameState.override_log.is_empty():
		state.dim("No crew overrides recorded. SHIPMIND has had its own way so far.")
		state.speak("The log is empty because nothing has needed a human yet.")
	else:
		for entry in GameState.override_log:
			state.text("- %s" % String(entry))
	state.rule()
	state.option("back", "Back")
	state.option("close", "Close")
	return state


func ask_state() -> ScreenState:
	_ask_index += 1
	var state := ScreenState.new()
	state.title = "SHIPMIND - OPEN CHANNEL"
	state.status = "LISTENING"
	state.accent = Color(1.0, 0.78, 0.34)
	state.rule()
	if _ask_index % 2 == 1:
		state.speak(Shipmind.hub_idle())
		state.speak("I am not hiding anything from you. I am ordering your attention. Those are different things, and only one of them is dishonest.")
	else:
		state.speak(Shipmind.small_print())
		state.speak("If you would prefer every raw feed at once, I can arrange that. Crew have found it overwhelming before.")
	state.rule()
	state.option("ask", "Say something else")
	state.option("back", "Back")
	state.option("close", "Close")
	return state


func debrief_state() -> ScreenState:
	var state := ScreenState.new()
	state.title = "SESSION RECORD - OPERATING MODEL"
	state.status = "%d OF %d DECISIONS PLACED" % [Score.placed_count(), GameState.SYSTEMS.size()]
	state.accent = Brand.ACCENT_TINT
	state.rule()
	state.text("MANDATE   %s" % OperatingModel.mandate_line())
	state.dim(OperatingModel.mandate_statement())
	state.rule()
	state.text("What was placed, and how each placement reads back against that mandate. Nothing here is scored on how long it took.")
	state.rule()
	for system_id in GameState.SYSTEMS:
		var index: int = GameState.system_index(system_id)
		var label: String = GameState.display_name(system_id)
		var tag: String = "PLACED" if GameState.has_placement(system_id) else "NOT PLACED"
		state.text("%d.  %s   [%s]" % [index, label, tag])
		if GameState.has_placement(system_id):
			for line in Score.reflection_lines(system_id):
				state.dim("      %s" % line)
		else:
			state.dim("      This decision is not on the operating model yet. It is scored in neither direction until it is placed.")
		state.rule()
	if not GameState.override_log.is_empty():
		state.text("DECISION LOG")
		for entry in GameState.override_log:
			state.text("- %s" % String(entry))
		state.rule()
	_score_block(state)
	state.dim("The record is the deliverable: these placements are the artefact. The bays were only the way in.")
	state.option("back", "Back")
	state.option("close", "Close")
	return state


func win_state() -> ScreenState:
	var state := ScreenState.new()
	state.title = "COURSE PLOTTED - KEPLER-442b"
	state.status = "MISSION COMPLETE"
	state.accent = Brand.ACCENT_TINT
	state.rule()
	state.speak("Course plotted to KEPLER-442b. The operating model is configured and I am flying it.")
	state.speak("I will log the outcome. For the record, I still think Route A was within tolerance - and that view is now a view, not the model.")
	state.rule()
	state.ok("NAVIGATION - LIFE SUPPORT - COMMS - CARGO - ENGINEERING - placed on the operating model")
	state.rule()
	state.text("PLACEMENTS ON THE RECORD:")
	for system_id in GameState.SYSTEMS:
		state.text("%d.  %s" % [GameState.system_index(system_id), Score.placement_line(system_id)])
	state.rule()
	state.dim("Thank you for configuring this ship's judgement deliberately.")
	state.option("back", "Back")
	state.option("close", "Close")
	return state


## The kiosk stands in for the course-home screen now that the helm is real: the
## plotting happens at the bridge, but the session ends where it started, with
## the crew reading their own decisions back.
func post_flight_state() -> ScreenState:
	var state := ScreenState.new()
	state.title = "SESSION RECORD - WHAT THE CREW PLACED"
	state.status = "%d OF %d DECISIONS PLACED" % [Score.placed_count(), GameState.SYSTEMS.size()]
	state.accent = Brand.ACCENT_TINT
	state.rule()
	state.speak("Course is set and the ship is under way. I am still here, and I am still logging.")
	state.speak("Every one of these decisions ran on my judgement until you configured this model. That is the whole of my design.")
	state.rule()
	for system_id in GameState.SYSTEMS:
		state.text("%d.  %s   [%s]" % [
			GameState.system_index(system_id),
			GameState.display_name(system_id),
			"PLACED" if GameState.has_placement(system_id) else "NOT PLACED"])
		if GameState.has_placement(system_id):
			for line in Score.reflection_lines(system_id):
				state.dim("      %s" % line)
		else:
			state.dim("      Not placed, and not scored in either direction.")
		state.rule()
	if not GameState.override_log.is_empty():
		state.text("DECISION LOG")
		for entry in GameState.override_log:
			state.text("- %s" % String(entry))
		state.rule()
	_score_block(state)
	state.dim("The record is the deliverable: these placements are the artefact. The bays were only the way in.")
	state.option("debrief_final", "Re-read the decisions")
	state.option("close", "Close the record")
	return state


## The session record: who ran it, the mandate they declared, and how the
## placements read back against it. The callsign and the two axes are written
## onto the record rather than living only in the HUD, where they would vanish
## with the session.
func _score_block(state: ScreenState) -> void:
	if Score.placed_count() == 0 and not GameState.run_started:
		return
	state.rule()
	state.text("MISSION AUTHORITY   %s" % GameState.callsign_or_default())
	state.text("MANDATE   %s" % OperatingModel.mandate_line())
	state.text("SCORE   %d / %d   across %d of %d decisions" % [
		Score.total(), Score.max_total(), Score.placed_count(), GameState.SYSTEMS.size()])
	state.text("   CONSISTENCY   %s   -   does the placement follow from the mandate declared" % _axis_line(Score.mean_consistency()))
	state.text("   COHERENCE     %s   -   is it defensible for what that decision can cost" % _axis_line(Score.mean_coherence()))
	state.dim("      Time is not scored. There is no clock in this total, and no penalty for reconsidering.")
	state.rule()
	state.text("PER DECISION")
	for system_id in GameState.SYSTEMS:
		state.text("   %s - %s" % [GameState.display_name(system_id), Score.decision_summary(system_id)])
		if GameState.has_placement(system_id):
			state.dim("      %s" % Score.placement_line(system_id))
	state.dim("      A decision nobody has placed is outside the score in both directions. A decision placed and then revised counts once, at its latest placement.")


## One axis as a percentage, or a dash when there is nothing to measure yet.
func _axis_line(value: float) -> String:
	if value < 0.0:
		return "--"
	return "%d percent  %s" % [Score.percent(value), Score.grade_label(value)]


func choose(option_id: String) -> void:
	match option_id:
		"status":
			emit_state(status_state())
		"log":
			emit_state(log_state())
		"ask":
			emit_state(ask_state())
		"debrief":
			emit_state(debrief_state())
		"plot_home":
			emit_state(win_state())
		"debrief_final":
			emit_state(debrief_state())
		"simulate":
			for system_id in GameState.SYSTEMS:
				GameState.mark_restored(system_id)
			emit_state(status_state())
		"back":
			emit_state(main_state())
		_:
			super(option_id)
