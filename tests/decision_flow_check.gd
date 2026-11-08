extends SceneTree

## Headless check: a decision stays on screen, completes the bay, and reads
## back as a standing record on reopen.
##
## The commit handlers must NOT close the console: place() emits the
## "DECISION RECORDED" read-back, the crew reads it, and "Done" (return)
## releases the console through solve() -> solved -> the completion flow.
## Reopening a placed bay shows the record, not the spectrum again.
##
## Run: godot --headless --path . -s res://tests/decision_flow_check.gd

var _terminal: Node = null
var _puzzle: Puzzle = null
var _last_state: ScreenState = null
var _stage := 0
var _ticks := 0
var _failures: Array[String] = []


func _initialize() -> void:
	_terminal = (load("res://scenes/ui/terminal_ui.tscn") as PackedScene).instantiate()
	_puzzle = (load("res://scripts/puzzles/nav_puzzle.gd") as GDScript).new()
	_puzzle.puzzle_id = "navigation"
	_puzzle.state_changed.connect(func(state: ScreenState) -> void: _last_state = state)
	## The game wires this in game.gd: a solved bay releases the console (and
	## shows the reflection card). The check mimics that contract.
	_puzzle.solved.connect(func(_id: String) -> void:
		if _terminal.is_open():
			_terminal.close())


func _check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		_failures.append(what)


func _process(_d: float) -> bool:
	_ticks += 1
	match _stage:
		0:
			if _ticks > 30:
				_stage = 1
				root.add_child(_terminal)
				root.add_child(_puzzle)
				OperatingModel.declare("home_intact", "cautious")
		1:
			# Open the bay: an unplaced decision shows its spectrum.
			if _ticks > 60:
				_stage = 2
				_terminal.open(_puzzle)
				_check(_terminal.is_open(), "console opens for an unplaced bay")
				_check(_last_state != null and _last_state.has_spectrum(),
					"unplaced bay offers the decision (spectrum present)")
		2:
			# Commit: the read-back must STAY on screen and the placement recorded.
			if _ticks > 90:
				_stage = 3
				_terminal._on_mobile_placement("automated")
				_check(_terminal.is_open(), "console stays open after the commit (results visible)")
				_check(_last_state != null and _last_state.title.contains("DECISION RECORDED"),
					"the read-back (DECISION RECORDED) is on screen after the commit")
				_check(GameState.has_placement("navigation"), "the placement is on the record")
		3:
			# Done: releases the console through the completion flow.
			if _ticks > 120:
				_stage = 4
				_terminal._on_option_pressed("return")
				_check(not _terminal.is_open(), "\"Done\" releases the console")
				_check(GameState.is_restored("navigation"), "the bay completed (marked restored)")
		4:
			# Reopen: the standing record, not a second ask.
			if _ticks > 150:
				_stage = 5
				_terminal.open(_puzzle)
				_check(_last_state != null and _last_state.status == "DECISION MADE",
					"reopen shows the standing record (DECISION MADE), not the spectrum")
		5:
			# Revise from the record returns to the decision surface.
			if _ticks > 180:
				_stage = 6
				_terminal._on_option_pressed("revise")
				_check(_last_state != null and _last_state.has_spectrum(),
					"\"Change the decision\" returns to the decision surface")
				_terminal.close()
				var fatal := _failures.size() > 0
				print("decision_flow_check: %d failure(s)" % _failures.size())
				quit(1 if fatal else 0)
				return true
	return false
