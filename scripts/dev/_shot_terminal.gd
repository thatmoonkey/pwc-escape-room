extends Node3D

## One-off layout harness for the stacked terminal. Not shipped behaviour:
## loads the station, opens a bay console (spectrum decision) and the helm
## (options only), and saves a screenshot of each so the layout can be read
## from the outside. Delete when the layout settles.

const SHOT_NAV := "/tmp/opencode/terminal_nav.png"
const SHOT_HELM := "/tmp/opencode/terminal_helm.png"


func _ready() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn") as PackedScene
	if packed == null:
		push_error("harness: no main scene")
		get_tree().quit()
		return
	await get_tree().process_frame
	print("[ShotTerminal] window=", DisplayServer.window_get_size(),
		" viewport_rect=", get_viewport().get_visible_rect().size,
		" content_scale=", get_tree().root.content_scale_factor)
	var main := packed.instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	## A clean record: any placement saved by an earlier run is erased, so the
	## nav console draws its spectrum decision instead of the "ON THE RECORD"
	## playback that a stored placement gives. The puzzles' own solved flags
	## were stamped by the save's restore (game.gd re-marks them from the save)
	## and are cleared here with the rest of it.
	GameState.reset()
	for node in get_tree().get_nodes_in_group("puzzle"):
		var puzzle := node as Puzzle
		if puzzle != null:
			puzzle.is_solved = false
	## In-memory only mandate, so the bay console draws its spectrum.
	OperatingModel.declare("home_intact", "balanced")
	## Get the boot UI out of the way: the terminal is what is under test.
	var launch := main.get_node_or_null("UI/LaunchScreen") as CanvasLayer
	if launch != null:
		launch.visible = false
	var intro := main.get_node_or_null("UI/IntroScreen") as CanvasLayer
	if intro != null:
		intro.visible = false
	var terminal := get_tree().get_first_node_in_group("terminal_ui") as TerminalUI
	if terminal == null:
		push_error("harness: no terminal")
		get_tree().quit()
		return
	await _shot(terminal, "navigation", SHOT_NAV)
	await _shot(terminal, "cockpit", SHOT_HELM)
	print("[ShotTerminal] done")
	get_tree().quit()


func _shot(terminal: TerminalUI, puzzle_id: String, path: String) -> void:
	var puzzle := _find(puzzle_id)
	if puzzle == null:
		push_error("harness: no puzzle %s" % puzzle_id)
		return
	terminal.open(puzzle)
	## Long enough for the typewriter to lay down the readout.
	for i in 90:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png(path)
	print("[ShotTerminal] saved %s" % path)
	terminal.close()
	await get_tree().process_frame


func _find(puzzle_id: String) -> Puzzle:
	for node in get_tree().get_nodes_in_group("puzzle"):
		var puzzle := node as Puzzle
		if puzzle != null and puzzle.puzzle_id == puzzle_id:
			return puzzle
	return null
