extends Node3D

## Read-only diagnostic for a reported crash: pressing a console killed the game.
##
##   run scenes/dev/probe_terminal.tscn once and read the receipt
##
## It drives the REAL path a press takes - ConsoleInteractable.interact calls
## TerminalUI.open, which calls Puzzle.start, which renders the screen - so a
## fault inside the terminal reproduces here instead of needing a human at a
## keyboard. It writes nothing: no placement is recorded and no save is touched.
##
## TWO consoles are opened, because they take different branches of
## Puzzle.start: a bay console, which renders the autonomy spectrum, and the
## cockpit helm, which renders the flight screen. The crash this was written for
## happened on the first printed line of both, so opening either one is enough
## to catch it.
##
## The game never calls this.

const SCENE := "res://scenes/main.tscn"
const BAY_PUZZLE := "navigation"
const HELM_PUZZLE := "cockpit"


func _ready() -> void:
	var packed: PackedScene = load(SCENE) as PackedScene
	if packed == null:
		print("[ProbeTerminal] could not load %s" % SCENE)
		return
	add_child(packed.instantiate())
	## Two frames, so every _ready in the station has run and the terminal has
	## something to render into.
	await get_tree().process_frame
	await get_tree().process_frame
	## A mandate held IN MEMORY ONLY, so a bay console draws its spectrum rather
	## than the no-mandate screen. GameState.set_mandate would write the save
	## file; OperatingModel.declare does not.
	OperatingModel.declare("home_intact", "balanced")
	var terminal := get_tree().get_first_node_in_group("terminal_ui") as TerminalUI
	if terminal == null:
		print("[ProbeTerminal] no TerminalUI in the tree")
		return
	await _open(terminal, BAY_PUZZLE)
	await _open(terminal, HELM_PUZZLE)
	print("[ProbeTerminal] done - no error above means both screens survived")


func _open(terminal: TerminalUI, puzzle_id: String) -> void:
	var puzzle := _find(puzzle_id)
	if puzzle == null:
		print("[ProbeTerminal] no puzzle '%s'" % puzzle_id)
		return
	terminal.open(puzzle)
	await get_tree().process_frame
	await get_tree().process_frame
	print("[ProbeTerminal] opened '%s' - open=%s" % [puzzle_id, str(terminal.is_open())])
	terminal.close()
	await get_tree().process_frame


func _find(puzzle_id: String) -> Puzzle:
	for node in get_tree().get_nodes_in_group("puzzle"):
		var puzzle := node as Puzzle
		if puzzle != null and puzzle.puzzle_id == puzzle_id:
			return puzzle
	return null
