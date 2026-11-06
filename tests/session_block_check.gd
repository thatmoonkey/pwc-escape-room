extends SceneTree

## Headless check for the run-start handover: the intro holds InputRouter's
## ui_block, and _on_intro_finished must give it back — the pause menu lives
## or dies by it. Run:
##   godot --headless --path . -s res://tests/session_block_check.gd

var _game: Node = null
var _stage := 0
var _ticks := 0


func _initialize() -> void:
	_game = (load("res://scenes/main.tscn") as PackedScene).instantiate()


func _process(_delta: float) -> bool:
	_ticks += 1
	match _stage:
		0:
			if _ticks > 30:
				_stage = 1
				root.add_child(_game)
		1:
			if _ticks > 240:
				_stage = 2
				var intro: Node = _game.get_node_or_null("UI/IntroScreen")
				print("CHECK: intro up=%s ui_blocking=%s (intro should hold it)"
					% [intro != null and intro.visible, InputRouter.ui_blocking])
				_game._on_intro_finished()
		2:
			if _ticks > 300:
				_stage = 3
				if InputRouter.ui_blocking:
					print("CHECK: FAIL — ui_block never released after the intro")
					quit(1)
					return true
				var pause: Node = _game.get_node_or_null("UI/PauseMenu")
				if pause == null:
					print("CHECK: FAIL — no pause menu node")
					quit(1)
					return true
				pause.open()
				print("CHECK: pause open=%s clock stopped=%s"
					% [pause.is_open(), GameState.run_running == false])
				pause.close()
				print("CHECK: pause closed, clock back=%s"
					% [GameState.run_running == GameState.run_started])
				print("CHECK: PASS")
				quit(0)
	return false
