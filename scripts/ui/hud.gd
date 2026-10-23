class_name HUD
extends CanvasLayer

## Minimal diegetic-free HUD: crosshair, aim prompt, the mandate and the
## decisions placed so far, the crew callsign, the run's two score axes, and the
## SHIPMIND subtitle line that carries its ambient barks.
##
## The run clock is still advanced here, and nowhere else, because a HUD is
## already processing every frame and GameState owns the elapsed value. WHAT THE
## HUD DOES NOT DO IS SCORE IT: speed is out of scope in the operating model, so
## the elapsed line is a readout for a host and nothing multiplies it by
## anything.
##
## Nothing is cached: every value drawn is read back from GameState, Score and
## OperatingModel at the moment it is drawn, so the HUD cannot show a stale
## total. The labels are only REBUILT when the numbers behind them actually
## change, because this runs every frame and reformatting five strings per frame
## is pure waste.

@onready var root: Control = $Root
@onready var crosshair: Control = $Root/Crosshair
@onready var prompt_label: Label = $Root/Prompt
@onready var objective_label: Label = $Root/Objective
@onready var callsign_label: Label = $Root/Callsign
@onready var score_label: Label = $Root/Score
@onready var subtitle: PanelContainer = $Root/Subtitle
@onready var subtitle_text: Label = $Root/Subtitle/Margin/VBox/Text
@onready var subtitle_speaker: Label = $Root/Subtitle/Margin/VBox/Speaker

var _say_token: int = 0
## The last score block drawn, as a cheap signature. Never a legitimate empty
## string, so the first refresh always draws.
var _score_signature: String = ""


func _ready() -> void:
	clear_prompt()
	subtitle.visible = false
	## This runs before the station controller loads the save - a child's _ready
	## fires before its parent's - so the first read here shows defaults. That is
	## why the clock and the score are refreshed every frame instead of once:
	## the readout corrects itself on the next frame rather than needing to be
	## told when the save arrived.
	refresh_objective()
	_refresh_callsign()
	_refresh_score()


func _process(delta: float) -> void:
	if GameState.run_running:
		GameState.tick(delta)
	_refresh_callsign()
	_refresh_score()


func clear_prompt() -> void:
	prompt_label.text = ""


func set_prompt(text: String) -> void:
	prompt_label.text = text


## What the crew have placed so far, and at which level. A decision that has not
## been placed reads as an open bay rather than as a deficit, because that is
## what it is: the record distinguishes "not yet placed" from "placed badly" and
## so does this.
func refresh_objective() -> void:
	var lines: Array[String] = []
	lines.append("DECISIONS PLACED   %d / %d" % [Score.placed_count(), GameState.SYSTEMS.size()])
	for system_id in GameState.SYSTEMS:
		var label: String = GameState.display_name(system_id)
		if GameState.has_placement(system_id):
			var level: String = String(GameState.placement(system_id).get("level", ""))
			lines.append("[x] %s  -  %s" % [label, OperatingModel.level_short(level)])
		elif GameState.is_restored(system_id):
			lines.append("[x] %s  -  on the record, no placement" % label)
		elif GameState.is_integrated(system_id):
			lines.append("[ ] %s  -  bay open, not placed" % label)
		else:
			lines.append("[ ] %s  -  console not commissioned" % label)
	objective_label.text = "\n".join(lines)


## The callsign sits on its own line above the score, so it reads as the identity
## the run is filed under rather than as another number in the block.
func _refresh_callsign() -> void:
	if callsign_label == null:
		return
	callsign_label.text = "CREW  %s" % GameState.callsign_or_default()


## One axis of the score, as a percentage and a word. "--" before anything is
## placed, which is the sentinel Score returns for an axis with nothing to
## measure: a run that has placed nothing has not been consistent or
## inconsistent, and must not be shown as either.
func _axis_text(value: float) -> String:
	if value < 0.0:
		return "--"
	return "%d%%  %s" % [Score.percent(value), Score.grade_label(value)]


func _refresh_score() -> void:
	if score_label == null:
		return
	var signature: String = "%d|%d|%d|%d|%s" % [
		Score.total(), int(GameState.elapsed), Score.placed_count(), GameState.restored_count(),
		OperatingModel.mandate_line()]
	if signature == _score_signature:
		return
	_score_signature = signature
	if not GameState.has_mandate():
		score_label.text = "MANDATE      --\nPLACED       --\nCONSISTENCY  --\nCOHERENCE    --"
		return
	var lines: Array[String] = []
	lines.append("MANDATE      %s / %s" % [OperatingModel.objective_label(), OperatingModel.appetite_label()])
	lines.append("PLACED       %d of %d decisions   (%d points)" % [
		Score.placed_count(), GameState.SYSTEMS.size(), Score.total()])
	lines.append("CONSISTENCY  %s" % _axis_text(Score.mean_consistency()))
	lines.append("COHERENCE    %s" % _axis_text(Score.mean_coherence()))
	## Shown for a host's interest. NOT part of the score, and nothing here
	## multiplies it by anything.
	lines.append("ELAPSED      %s   (not scored)" % GameState.elapsed_text())
	score_label.text = "\n".join(lines)


func say_shipmind(text: String, seconds: float = 6.5) -> void:
	_say_token += 1
	var token: int = _say_token
	subtitle_speaker.text = Shipmind.NAME
	subtitle_text.text = text
	subtitle.visible = true
	await get_tree().create_timer(seconds).timeout
	if token == _say_token and is_inside_tree():
		subtitle.visible = false


func say_shipmind_lines(lines: Array, hold: float = 4.5) -> void:
	for line in lines:
		say_shipmind(String(line), hold)
		await get_tree().create_timer(hold).timeout
