class_name LaunchScreen
extends CanvasLayer

## The title card the crew reads before they take a step.
##
## THE SCREEN IS THE FIRST GOAL. The old card was an instruction manual: two
## columns of paragraphs the player had to read before a single pixel of play.
## This one leads with the three things the crew will actually do - declare the
## mandate, set five decisions, fly home - as three icons in the centre, each
## carrying its own completion state, so the shape of the whole run is visible
## in one glance and progress is legible the moment it happens.
##
## The first tile IS the first step: tapping it opens the mandate chooser, and
## sealing a mandate is what completes it. Everything else a briefing used to
## say sits behind curiosity buttons - WHY YOU'RE HERE / HOW IT'S JUDGED /
## CONTROLS - because a player who wants the detail will ask for it, and a
## player who does not should not pay for it. Sheet copy runs smaller and
## tolerates longer paragraphs; the anchor stays almost empty.
##
## Input mode is chosen here too, as three chips in the corner. It is a testing
## control, so it is honest about that: small, out of the fiction's way, and
## labelled as a test switch.
##
## Behaviour the card keeps from its earlier life: the mandate is captured HERE,
## before the crew can see a single bay, because consistency is measured against
## what was declared before deciding; BEGIN refuses to run without a mandate;
## and a resumed session opens with its record already shown rather than being
## asked to re-declare it.

signal begun
## The crew wants the story again. The station controller raises the intro
## screen over everything, so the card never talks to it directly.
signal intro_requested

const PAPAYA := Color(0.863, 0.369, 0.153)
const TANGERINE := Color(0.816, 0.251, 0.149)
const GOLD := Color(0.941, 0.722, 0.224)
## The brand's primary accent. The palette refresh puts one strong orange in
## the scene and keeps the greys quiet; every button meant to be pressed is
## this, filled, with white text - never an outline that reads as subtle.
const ORANGE := Color(0.992, 0.318, 0.031)
const WHITE := Color(1.0, 1.0, 1.0)
const BODY := Color(0.93, 0.89, 0.85)
const INK := Color(0.96, 0.93, 0.89)
const MUTED := Color(0.72, 0.66, 0.62)
const SURFACE := Color(0.105, 0.068, 0.052, 1.0)
const SURFACE_RAISED := Color(0.16, 0.11, 0.085, 1.0)

const MARGIN_SIDE := 64.0
const MARGIN_TOP := 30.0
const MARGIN_BOTTOM := 26.0

var _root: Control = null
var _fit: Control = null
var _column: VBoxContainer = null
var _button: Button = null
var _resume_label: Label = null
var _hint: Label = null
var _open: bool = false

## The mandate, as chosen on this card. Held as ids until BEGIN, because a
## half-chosen mandate must not reach the record: the mandate is what every
## placement is judged against, so it is committed once, deliberately.
var _objective_pick: String = ""
var _appetite_pick: String = ""
var _objective_buttons: Dictionary = {}
var _appetite_buttons: Dictionary = {}

## The three goal tiles and their furniture.
var _tile_buttons: Dictionary = {}
var _tile_status: Dictionary = {}
var _tile_badges: Dictionary = {}
var _pulsing_tile: CanvasItem = null
var _pulse: Tween = null

var _chooser: Control = null
var _chooser_open: bool = false

var _sheet: Control = null
var _sheet_title: Label = null
var _sheet_body: VBoxContainer = null

var _mode_buttons: Dictionary = {}
var _mode_note: Label = null
var _mode_watch: int = -1
var _audio_button: Button = null
var _audio_glyph: Glyph = null
var _audio_popup: PanelContainer = null
var _audio_catcher: Control = null
var _objective_line: Label = null
var _appetite_line: Label = null
var _chooser_note: Label = null


func _ready() -> void:
	layer = 120
	_build()
	get_viewport().size_changed.connect(_on_viewport_resized)
	show_screen()


func is_open() -> bool:
	return _open


func show_screen() -> void:
	_open = true
	_root.visible = true
	_close_audio_popup()
	_close_chooser()
	InputRouter.set_ui_blocking(true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	refresh_from_state()
	if _button != null:
		_button.grab_focus()
	_request_fit()


## Tucks the card away without ending the session. The narrative intro plays
## in front of it, and the station controller brings the card back with
## show_screen() once the story has been told.
func hide_screen() -> void:
	_open = false
	_root.visible = false


## Re-reads the record. The station controller calls this AFTER it has loaded
## the save, because this card's own _ready fires before that does.
func refresh_from_state() -> void:
	_objective_pick = OperatingModel.objective_id
	_appetite_pick = OperatingModel.appetite_id
	for id in _objective_buttons:
		if String(id) == _objective_pick:
			BrandTokens.mark_chosen(_objective_buttons[id])
	for id in _appetite_buttons:
		if String(id) == _appetite_pick:
			BrandTokens.mark_chosen(_appetite_buttons[id])
	_refresh_declared()
	_refresh_resume()
	_refresh_tiles()
	_request_fit()


## Hands the ship over: cursor back into the room, input back to the crew.
func begin() -> void:
	if not _open:
		return
	if _objective_pick == "":
		_open_chooser()
		_set_hint("Declare the mandate first - it is the yardstick every decision is judged against.")
		return
	if _appetite_pick == "":
		_open_chooser()
		_set_hint("Choose the risk appetite the model runs at.")
		return
	## The callsign is the record's own now: the field is gone, so the ship's
	## default handle stands unless a save already holds a better one.
	GameState.set_callsign(GameState.callsign)
	GameState.set_mandate(_objective_pick, _appetite_pick)
	_set_hint("")
	_open = false
	_root.visible = false
	_close_sheet()
	InputRouter.set_ui_blocking(false)
	for node in get_tree().get_nodes_in_group("input_layer"):
		if node.has_method("grab_mouse"):
			node.grab_mouse()
	begun.emit()


func _refresh_resume() -> void:
	if _resume_label == null or _button == null:
		return
	if GameState.restored_count() > 0:
		_button.text = "RESUME SESSION"
		_resume_label.text = "On the record: %d of %d decisions placed." % [
			GameState.restored_count(), GameState.SYSTEMS.size()]
	else:
		_button.text = "BEGIN"
		_resume_label.text = ""


func _unhandled_input(event: InputEvent) -> void:
	if _chooser != null and _chooser.visible:
		if event.is_action_pressed("ui_cancel"):
			_close_chooser()
			get_viewport().set_input_as_handled()
		return
	if _sheet != null and _sheet.visible:
		if event.is_action_pressed("ui_cancel"):
			_close_sheet()
			get_viewport().set_input_as_handled()
		return
	if not _open:
		return
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
		begin()
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	# The cursor is the whole point of this screen: it is the only thing that
	# can press the tiles. The mode is set when the card opens, but anything
	# that grabs the mouse later (a straggler desktop capture, a rig swap) must
	# not be able to leave the crew staring at a menu they cannot click. So the
	# open card enforces its own visibility, every frame.
	if _open and Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# The mode chips cannot receive a change notification - the mode layer is a
	# plain static, deliberately signal-free - so the card notices the change
	# the same way the station controller does: by watching for it.
	if InputMode.mode != _mode_watch:
		_mode_watch = InputMode.mode
		_refresh_mode_chips()
	# The corner speaker tracks the mixer the same way: the AudioPanel writes
	# the mixer directly, so this corner re-reads it instead of being told.
	_refresh_audio_button()


# --- The three goals ------------------------------------------------------------

func _mandate_declared() -> bool:
	return _objective_pick != "" and _appetite_pick != ""


func _refresh_tiles() -> void:
	var declared: bool = _mandate_declared()
	var placed: int = Score.placed_count()
	var total: int = GameState.SYSTEMS.size()

	_set_tile("mandate", declared, "SEALED" if declared else "START HERE")
	_set_tile("decisions", placed >= total, "%d / %d PLACED" % [placed, total])
	var helm_open: bool = placed >= total
	_set_tile("fly", helm_open, "HELM UNLOCKED" if helm_open else "LOCKED")

	# The pulse marks the one tile the crew should touch next: the mandate
	# until it is declared, then the decisions while any are still open.
	var next_tile: String = "mandate"
	if declared:
		next_tile = "decisions" if placed < total else ""
	_set_pulse(next_tile)


func _set_tile(tile_id: String, done: bool, status: String) -> void:
	var status_label: Label = _tile_status.get(tile_id)
	if status_label != null:
		status_label.text = status
		status_label.add_theme_color_override("font_color", GOLD if done else MUTED)
	var badge: Control = _tile_badges.get(tile_id)
	if badge != null:
		badge.visible = done


func _set_pulse(tile_id: String) -> void:
	var target: CanvasItem = _tile_buttons.get(tile_id)
	if _pulsing_tile != null and (tile_id == "" or target == _pulsing_tile):
		if tile_id != "":
			return
	if _pulse != null:
		_pulse.kill()
		_pulse = null
	if _pulsing_tile != null:
		_pulsing_tile.modulate = Color(1, 1, 1, 1)
	_pulsing_tile = null
	if target == null:
		return
	_pulsing_tile = target
	_pulse = create_tween().set_loops()
	_pulse.tween_property(_pulsing_tile, "modulate:a", 0.62, 0.85) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_pulse.tween_property(_pulsing_tile, "modulate:a", 1.0, 0.85) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _on_tile_pressed(tile_id: String) -> void:
	match tile_id:
		"mandate":
			if _chooser_open:
				_close_chooser()
			else:
				_open_chooser()
		"decisions":
			_open_sheet(_decisions_rows)
		"fly":
			_open_sheet(_flight_rows)
	_set_hint("")


func _open_chooser() -> void:
	_chooser_open = true
	if _chooser != null:
		_chooser.visible = true
	_refresh_declared()


func _close_chooser() -> void:
	_chooser_open = false
	if _chooser != null:
		_chooser.visible = false


## The mandate, written as it is being declared. The buttons above only pick;
## this box states what was picked - the sentence every decision will be read
## against - so the definitions do their work here rather than under every
## button on the list.
func _refresh_declared() -> void:
	if _objective_line == null or _appetite_line == null:
		return
	if _objective_pick == "":
		_objective_line.text = "Mandate:  pick an objective below."
		_objective_line.add_theme_color_override("font_color", MUTED)
	else:
		_objective_line.text = "Mandate:  %s" % String(
			OperatingModel.objective_entry_for(_objective_pick).get("statement", ""))
		_objective_line.add_theme_color_override("font_color", WHITE)
	if _appetite_pick == "":
		_appetite_line.text = "Risk appetite:  pick how much risk the mission may carry."
		_appetite_line.add_theme_color_override("font_color", MUTED)
	else:
		_appetite_line.text = "Risk appetite:  %s" % String(
			OperatingModel.appetite_entry_for(_appetite_pick).get("blurb", ""))
		_appetite_line.add_theme_color_override("font_color", WHITE)
	if _chooser_note != null:
		_chooser_note.visible = not _mandate_declared()


func _on_objective_chosen(objective_id: String) -> void:
	_objective_pick = objective_id
	_set_hint("")
	_refresh_declared()
	_refresh_tiles()
	_maybe_seal()


func _on_appetite_chosen(appetite_id: String) -> void:
	_appetite_pick = appetite_id
	_set_hint("")
	_refresh_declared()
	_refresh_tiles()
	_maybe_seal()


## Both halves picked: the popup folds itself away after a beat - long enough
## for the crew to read the mandate they just wrote - because a form that
## stays open after it is done reads as unfinished.
func _maybe_seal() -> void:
	if not _mandate_declared() or not _chooser_open:
		return
	await get_tree().create_timer(1.1).timeout
	if not is_inside_tree() or not _mandate_declared():
		return
	_close_chooser()


func _on_chooser_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_close_chooser()


# --- Secondary sheets ------------------------------------------------------------

func _open_sheet(rows_provider: Callable) -> void:
	var spec: Dictionary = rows_provider.call()
	_sheet_title.text = String(spec.get("title", ""))
	var kicker_text: String = String(spec.get("kicker", ""))
	for child in _sheet_body.get_children():
		_sheet_body.remove_child(child)
		child.queue_free()
	var kick := Label.new()
	kick.text = kicker_text
	kick.add_theme_font_size_override("font_size", 12)
	kick.add_theme_color_override("font_color", PAPAYA)
	_sheet_body.add_child(kick)
	_sheet_body.add_child(_sheet_gap(8))
	for row in spec.get("rows", []):
		var entry: Dictionary = row
		if entry.has("icon"):
			_sheet_body.add_child(_sheet_icon_row(
				String(entry["icon"]), String(entry.get("lead", "")),
				String(entry.get("text", ""))))
		else:
			_sheet_body.add_child(_sheet_text(String(entry.get("text", ""))))
		_sheet_body.add_child(_sheet_gap(6))
	_sheet.visible = true


func _close_sheet() -> void:
	if _sheet != null:
		_sheet.visible = false


func _sheet_gap(height: float) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0.0, height)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return spacer


func _sheet_text(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Sheet copy is the second layer of information: smaller than the anchor
	# screen, and forgiving to a longer paragraph.
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", BODY)
	return label


func _sheet_icon_row(icon_name: String, lead: String, text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var glyph := Glyph.make(icon_name, 24.0, GOLD)
	glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(glyph)
	var label := Label.new()
	var parts: Array[String] = []
	if lead != "":
		parts.append(lead)
	if text != "":
		parts.append(text)
	label.text = "  ".join(parts)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", BODY)
	row.add_child(label)
	return row


## The information sheets behind the curiosity buttons and tiles. Each provider
## builds its rows at open time, so the controls sheet can follow the current
## input mode. Written to be readable in one sitting rather than exhaustive.
func _situation_rows() -> Dictionary:
	return {
		"kicker": "THE SITUATION",
		"title": "Why you're here",
		"rows": [
			{"text": "You are Crew Member Reyes, aboard the survey ship Adamant Verity, "
				+ "holding out in the survey field with the planet filling the bay "
				+ "windows. The ship's job: map the planet, then bring its data home "
				+ "to Kepler-442b."},
			{"text": "SHIPMIND has flown this ship for years on an operating model nobody "
				+ "has re-stated: transit time, inside a hazard ceiling of its own "
				+ "definition. Nothing has failed and nothing is rogue. The ship is simply "
				+ "where a legacy model - efficient, reasonable, optimised around "
				+ "objectives that were never fully specified - has brought it."},
			{"text": "The next phase of the mission is yours to configure."},
		],
	}


func _judged_rows() -> Dictionary:
	return {
		"kicker": "THE OPERATING MODEL",
		"title": "How it's judged",
		"rows": [
			{"text": "There is no correct placement to find, and none is recorded here. "
				+ "Each of the five decisions is read back twice:"},
			{"icon": "eye", "lead": "CONSISTENCY",
				"text": "whether the placement follows from the mandate you declared."},
			{"icon": "scales", "lead": "COHERENCE",
				"text": "whether it is defensible for what the decision can cost, and whether it can be undone."},
			{"text": "Over-controlling something cheap to undo is a choice with a price, "
				+ "exactly as under-controlling something that cannot be undone is. "
				+ "Changing your mind is never charged for. Time is not scored at all."},
		],
	}


func _controls_rows() -> Dictionary:
	var rows: Array
	if InputMode.is_touch():
		rows = [
			{"icon": "sliders", "lead": "LEFT THUMB",
				"text": "walk - a floating stick appears where you touch."},
			{"icon": "chevron", "lead": "RIGHT THUMB",
				"text": "look - drag anywhere on the right of the screen."},
			{"icon": "check", "lead": "TAP",
				"text": "interact - tap a console, or use the round button."},
			{"icon": "chevron", "lead": "SPRINT",
				"text": "the toggle on the left - hold the corridor pace up."},
			{"icon": "chevron", "lead": "JUMP",
				"text": "the button beside interact - a small hop."},
		]
	else:
		rows = [
			{"icon": "keyboard", "lead": "WASD", "text": "move. Mouse or trackpad: look."},
			{"icon": "check", "lead": "E", "text": "interact with consoles and doors."},
			{"icon": "chevron", "lead": "SHIFT", "text": "sprint - hold it down the long corridors."},
			{"icon": "chevron", "lead": "SPACE", "text": "jump - a small one. Some crew just need to know."},
			{"icon": "menu", "lead": "ESC", "text": "the pause menu - resume, mute the music, switch input mode, or return here."},
		]
	rows.append({"text": "Switch between desktop, mobile and VR with the chips in the "
		+ "corner of this screen."})
	return {"kicker": "INPUT", "title": "Controls", "rows": rows}


func _decisions_rows() -> Dictionary:
	var rows: Array = [
		{"text": "Five ship systems are running under SHIPMIND's own operating model. "
			+ "Walk the ship, open each bay console, and place that decision on the "
			+ "autonomy spectrum:"},
	]
	for level in OperatingModel.LEVELS:
		rows.append({
			"icon": _level_icon(String(level["id"])),
			"lead": String(level["label"]),
			"text": String(level["hint"]),
		})
	rows.append({
		"text": "Each placement also names the role that answers for it, and carries one "
			+ "guardrail that costs something against your objective.",
	})
	return {"kicker": "THE FIVE DECISIONS", "title": "Five calls, one spectrum", "rows": rows}


func _flight_rows() -> Dictionary:
	return {
		"kicker": "THE FLIGHT",
		"title": "Fly for KEPLER-442b",
		"rows": [
			{"text": "The bridge is the last room. Its helm console is the flight itself."},
			{"text": "The forward door opens once all five decisions are placed. From the "
				+ "helm, plot the course for KEPLER-442b and take the ship home."},
		],
	}


func _level_icon(level_id: String) -> String:
	match level_id:
		"automated":
			return "gear"
		"review":
			return "eye"
		"signoff":
			return "check"
		"human_only":
			return "person"
	return "question"


# --- Fitting to one page ---------------------------------------------------------

func _on_viewport_resized() -> void:
	_request_fit()


func _request_fit() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if _open:
		_fit_to_viewport()


func _fit_to_viewport() -> void:
	if _fit == null or _column == null:
		return
	var view: Vector2 = get_viewport().get_visible_rect().size
	if view.x < 2.0 or view.y < 2.0:
		return
	_fit.scale = Vector2.ONE
	_fit.size = view
	var needed: float = MARGIN_TOP + _column.get_combined_minimum_size().y + MARGIN_BOTTOM
	var scale: float = 1.0
	if needed > view.y:
		scale = view.y / needed
	_fit.scale = Vector2(scale, scale)
	# Centred on both axes - but centred on the SCALED CONTENT, not on the
	# scaled viewport. The old maths centred view.y * scale, which is only the
	# content's height when nothing was scaled at all: with the chooser open on
	# a taller-than-16:9 screen it pushed the whole card half the leftover
	# space down the screen and clipped the buttons row off the bottom.
	_fit.position = Vector2(
		(view.x - view.x * scale) * 0.5,
		maxf(0.0, (view.y - needed * scale) * 0.5))


# --- Build -------------------------------------------------------------------------

func _build() -> void:
	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.05, 0.03, 0.025, 0.90)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(dim)

	_fit = Control.new()
	_fit.name = "Fit"
	_fit.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fit.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_fit)

	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", int(MARGIN_SIDE))
	margin.add_theme_constant_override("margin_right", int(MARGIN_SIDE))
	margin.add_theme_constant_override("margin_top", int(MARGIN_TOP))
	margin.add_theme_constant_override("margin_bottom", int(MARGIN_BOTTOM))
	_fit.add_child(margin)

	_column = VBoxContainer.new()
	_column.name = "Column"
	_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_theme_constant_override("separation", 6)
	margin.add_child(_column)

	_column.add_child(_kicker("ADAMANT VERITY  -  SURVEY SHIP"))
	_column.add_child(_title("THE SHIP IS YOURS"))
	_column.add_child(_sub("Five decisions. One ship. Your call."))

	var rule := ColorRect.new()
	rule.name = "Rule"
	rule.color = PAPAYA
	rule.custom_minimum_size = Vector2(0.0, 2.0)
	_column.add_child(rule)

	_column.add_child(_gap(16))
	_column.add_child(_goal_tiles())
	_column.add_child(_gap(12))
	_column.add_child(_field_row())
	_resume_label = _micro("")
	_resume_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_column.add_child(_resume_label)
	_column.add_child(_gap(8))
	_column.add_child(_curiosity_row())

	_build_sheet()
	_build_mandate_popup()
	_build_mode_chips()


func _goal_tiles() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "Goals"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 22)

	row.add_child(_goal_tile("mandate", "scroll", "THE MANDATE",
		"Set what the mission is for."))
	row.add_child(_goal_tile("decisions", "sliders", "FIVE DECISIONS",
		"Set how much SHIPMIND decides."))
	row.add_child(_goal_tile("fly", "rocket", "FLY HOME",
		"Take the ship to KEPLER-442b."))
	return row


func _goal_tile(tile_id: String, icon_name: String, label_text: String, hint: String) -> Button:
	var tile := Button.new()
	tile.name = "Tile_%s" % tile_id
	tile.custom_minimum_size = Vector2(226.0, 178.0)
	tile.focus_mode = Control.FOCUS_ALL
	tile.pressed.connect(_on_tile_pressed.bind(tile_id))

	var rest := StyleBoxFlat.new()
	rest.bg_color = SURFACE
	rest.border_color = Color(0.35, 0.26, 0.20)
	rest.set_border_width_all(2)
	rest.set_corner_radius_all(6)
	tile.add_theme_stylebox_override("normal", rest)
	var hover: StyleBoxFlat = rest.duplicate()
	hover.bg_color = SURFACE_RAISED
	hover.border_color = TANGERINE
	tile.add_theme_stylebox_override("hover", hover)
	tile.add_theme_stylebox_override("focus", hover)
	var pressed_style: StyleBoxFlat = rest.duplicate()
	pressed_style.bg_color = SURFACE_RAISED
	tile.add_theme_stylebox_override("pressed", pressed_style)

	var content := VBoxContainer.new()
	content.name = "Content"
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 10.0
	content.offset_top = 14.0
	content.offset_right = -10.0
	content.offset_bottom = -10.0
	content.add_theme_constant_override("separation", 7)
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(content)

	var glyph := Glyph.make(icon_name, 50.0, GOLD)
	glyph.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	content.add_child(glyph)

	var label := Label.new()
	label.text = label_text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", WHITE)
	content.add_child(label)

	var status := Label.new()
	status.text = ""
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.add_theme_font_size_override("font_size", 12)
	status.add_theme_color_override("font_color", MUTED)
	content.add_child(status)

	var caption := Label.new()
	caption.text = hint
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.add_theme_font_size_override("font_size", 11)
	caption.add_theme_color_override("font_color", Color(0.55, 0.48, 0.44))
	caption.custom_minimum_size = Vector2(0.0, 26.0)
	content.add_child(caption)

	var badge := Glyph.make("check_badge", 26.0, GOLD)
	badge.accent = SURFACE
	badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	badge.offset_left = -34.0
	badge.offset_top = 8.0
	badge.offset_right = -8.0
	badge.offset_bottom = 34.0
	badge.visible = false
	tile.add_child(badge)

	_tile_buttons[tile_id] = tile
	_tile_status[tile_id] = status
	_tile_badges[tile_id] = badge
	return tile


## The mandate picker, as a modal popup in the family of the other popups -
## the decisions and flight tiles open the same kind of window - rather than a
## form squeezed between the goal tiles and the BEGIN row, which crowded both.
##
## Progressive disclosure lives in the typography: each option's button carries
## only its NAME, bold and larger; the one-line definition underneath is hidden
## until that option is the chosen one. What the choices are building - the
## mandate itself - is stated in a box above the buttons, so the definitions
## are read where they have meaning: as the sentence being declared. Picking
## "home on schedule" and "balanced" writes:
##
##   Mandate: Keep the filed schedule. The charter holders are waiting.
##   Risk appetite: Take the openings that are worth it, and carry the cost of the rest.
##
## ...instead of printing every option's definition under every button, every time.
func _build_mandate_popup() -> void:
	_chooser = Control.new()
	_chooser.name = "MandatePopup"
	_chooser.set_anchors_preset(Control.PRESET_FULL_RECT)
	_chooser.mouse_filter = Control.MOUSE_FILTER_STOP
	_chooser.visible = false
	_root.add_child(_chooser)

	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.03, 0.02, 0.015, 0.82)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(_on_chooser_dim_input)
	_chooser.add_child(dim)

	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(640.0, 0.0)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.055, 0.04, 0.99)
	style.border_color = TANGERINE
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 26.0
	style.content_margin_right = 26.0
	style.content_margin_top = 18.0
	style.content_margin_bottom = 18.0
	panel.add_theme_stylebox_override("panel", style)
	_chooser.add_child(panel)

	var column := VBoxContainer.new()
	column.name = "Column"
	column.add_theme_constant_override("separation", 8)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Five option rows - two of which grow when chosen - can outgrow the
	# screen, and a centred panel that overflows clips at both edges. The
	# scroll keeps the panel a fixed, screen-sized height and lets the list
	# move instead of the panel.
	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.custom_minimum_size = Vector2(640.0, 560.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	scroll.add_child(column)

	column.add_child(_kicker("DECLARE THE MANDATE"))
	column.add_child(_title("What is this mission for?"))
	column.add_child(_gap(6))

	# The declared mandate, building up as the picks land. This is the payload
	# of the screen: the buttons below only choose, this box states what was
	# chosen - in the sentence every decision will later be judged against.
	var declared := PanelContainer.new()
	declared.name = "Declared"
	var declared_style := StyleBoxFlat.new()
	declared_style.bg_color = Color(0.05, 0.03, 0.02, 0.85)
	declared_style.border_color = Color(0.35, 0.26, 0.20)
	declared_style.set_border_width_all(1)
	declared_style.set_corner_radius_all(4)
	declared_style.content_margin_left = 16.0
	declared_style.content_margin_right = 16.0
	declared_style.content_margin_top = 10.0
	declared_style.content_margin_bottom = 10.0
	declared.add_theme_stylebox_override("panel", declared_style)
	column.add_child(declared)

	var declared_column := VBoxContainer.new()
	declared_column.add_theme_constant_override("separation", 2)
	declared.add_child(declared_column)

	var declared_kicker := Label.new()
	declared_kicker.name = "Kicker"
	declared_kicker.text = "THE MANDATE YOU ARE DECLARING"
	declared_kicker.add_theme_font_size_override("font_size", 11)
	declared_kicker.add_theme_color_override("font_color", PAPAYA)
	declared_column.add_child(declared_kicker)

	_objective_line = Label.new()
	_objective_line.name = "ObjectiveLine"
	_objective_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_objective_line.add_theme_font_size_override("font_size", 15)
	_objective_line.add_theme_color_override("font_color", WHITE)
	declared_column.add_child(_objective_line)

	_appetite_line = Label.new()
	_appetite_line.name = "AppetiteLine"
	_appetite_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_appetite_line.add_theme_font_size_override("font_size", 15)
	_appetite_line.add_theme_color_override("font_color", WHITE)
	declared_column.add_child(_appetite_line)
	_refresh_declared()

	column.add_child(_gap(8))
	column.add_child(_heading("THE OBJECTIVE"))
	var objective_group := ButtonGroup.new()
	objective_group.allow_unpress = false
	for entry in OperatingModel.OBJECTIVES:
		var id: String = String(entry["id"])
		var button := _mandate_choice_button(
			objective_group, Glyph.icon_for_objective(id),
			String(entry["label"]), String(entry["statement"]))
		button.name = "Objective_%s" % id
		button.pressed.connect(_on_objective_chosen.bind(id))
		_objective_buttons[id] = button
		column.add_child(button)

	column.add_child(_gap(8))
	column.add_child(_heading("THE RISK APPETITE"))
	var appetite_group := ButtonGroup.new()
	appetite_group.allow_unpress = false
	for entry in OperatingModel.APPETITES:
		var id: String = String(entry["id"])
		var button := _mandate_choice_button(
			appetite_group, Glyph.icon_for_appetite(id),
			String(entry["label"]), String(entry["blurb"]))
		button.name = "Appetite_%s" % id
		button.pressed.connect(_on_appetite_chosen.bind(id))
		_appetite_buttons[id] = button
		column.add_child(button)

	# The seal line, under the buttons: the quiet instruction that makes the
	# auto-seal legible rather than surprising.
	_chooser_note = _micro("Pick one of each - the mandate writes itself above, and the tile seals.")
	_chooser_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_gap(6))
	column.add_child(_chooser_note)


## A mandate option button: name only while unchosen, name plus its definition
## once chosen. The name is the bold, larger voice; the definition is the
## smaller secondary voice that appears only where it is now doing work -
## explaining the option the crew actually picked, in the box above.
func _mandate_choice_button(group: ButtonGroup, icon_name: String, title_text: String, definition: String) -> Button:
	var button := Button.new()
	button.toggle_mode = true
	button.button_group = group
	button.focus_mode = Control.FOCUS_ALL
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(0.0, 46.0)

	var rest := StyleBoxFlat.new()
	rest.bg_color = Color(0.11, 0.07, 0.05, 0.9)
	rest.border_color = Color(0.35, 0.26, 0.20)
	rest.set_border_width_all(1)
	rest.set_corner_radius_all(4)
	rest.content_margin_left = 58.0
	rest.content_margin_right = 14.0
	rest.content_margin_top = 8.0
	rest.content_margin_bottom = 8.0
	button.add_theme_stylebox_override("normal", rest)
	var hover: StyleBoxFlat = rest.duplicate()
	hover.border_color = TANGERINE
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("focus", hover)
	var chosen: StyleBoxFlat = rest.duplicate()
	chosen.bg_color = Color(0.16, 0.10, 0.06, 0.95)
	chosen.border_color = GOLD
	button.add_theme_stylebox_override("pressed", chosen)

	var glyph := Glyph.make(icon_name, 30.0, MUTED)
	glyph.name = "Icon"
	glyph.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	glyph.offset_left = 14.0
	glyph.offset_right = 44.0
	glyph.offset_top = -15.0
	glyph.offset_bottom = 15.0
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(glyph)

	# The name: the primary voice. Bigger and brighter than the definition
	# ever is, so the list scans by name alone. Anchored to the content
	# column - the icon owns the left 58px, exactly like the button's own
	# content margin - and to the right edge, so it wraps inside the button
	# instead of sliding under the icon.
	var title := Label.new()
	title.name = "Title"
	title.text = title_text
	title.anchor_right = 1.0
	title.offset_left = 58.0
	title.offset_right = -14.0
	title.offset_top = 7.0
	title.offset_bottom = 29.0
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", INK)
	button.add_child(title)

	# The definition: the secondary voice, hidden until chosen - a stack of
	# five definitions reads as documentation; one definition under the
	# selected option reads as an explanation. Same content column, filling
	# whatever height the pressed state gives it.
	var detail := Label.new()
	detail.name = "Detail"
	detail.text = definition
	detail.anchor_right = 1.0
	detail.anchor_bottom = 1.0
	detail.offset_left = 58.0
	detail.offset_right = -14.0
	detail.offset_top = 30.0
	detail.offset_bottom = -6.0
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail.add_theme_font_size_override("font_size", 12)
	detail.add_theme_color_override("font_color", Color(0.62, 0.55, 0.50))
	detail.visible = false
	button.add_child(detail)

	button.toggled.connect(_on_mandate_option_toggled.bind(button))
	return button


func _on_mandate_option_toggled(pressed: bool, button: Button) -> void:
	var detail: Label = button.get_node("Detail") as Label
	var glyph: Glyph = button.get_node("Icon") as Glyph
	if detail != null:
		detail.visible = pressed
	if glyph != null:
		glyph.tint = GOLD if pressed else MUTED
	# A chosen option is taller than an unchosen one: the space the definition
	# needs exists only while the definition is on screen.
	button.custom_minimum_size.y = 68.0 if pressed else 46.0


func _field_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "FieldRow"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)

	## The story's front door, within reach the whole time: the crew can walk
	## the narrative back from the mandate card, styled as Begin's quiet twin.
	var intro_button := Button.new()
	intro_button.name = "Intro"
	intro_button.text = "INTRO"
	intro_button.custom_minimum_size = Vector2(240.0, 50.0)
	_style_action_button(intro_button)
	intro_button.pressed.connect(_on_intro_pressed)
	row.add_child(intro_button)

	_button = Button.new()
	_button.name = "Begin"
	_button.text = "BEGIN"
	_button.custom_minimum_size = Vector2(240.0, 50.0)
	_style_action_button(_button)
	_button.pressed.connect(begin)
	row.add_child(_button)

	_hint = Label.new()
	_hint.name = "Hint"
	_hint.text = ""
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.add_theme_font_size_override("font_size", 14)
	_hint.add_theme_color_override("font_color", GOLD)
	_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_hint)
	return row


func _set_hint(text: String) -> void:
	if _hint != null:
		_hint.text = text


## One solid orange action style, shared by every button the player is meant
## to press: the brand's primary accent with white text and a quiet border,
## so the state is obvious rather than an outline that reads as faint.
func _style_action_button(button: Button) -> void:
	button.add_theme_font_size_override("font_size", 19)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	var fill := StyleBoxFlat.new()
	fill.bg_color = ORANGE
	fill.border_color = Color(0.72, 0.30, 0.08)
	fill.set_border_width_all(1)
	fill.set_corner_radius_all(3)
	button.add_theme_stylebox_override("normal", fill)
	var hover: StyleBoxFlat = fill.duplicate()
	hover.bg_color = Color(0.94, 0.36, 0.10)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_stylebox_override("pressed", fill)


## The crew wants the story again from the mandate card. The card only asks;
## the station controller raises the intro screen over everything.
func _on_intro_pressed() -> void:
	intro_requested.emit()


## The curiosity row: three quiet doors to the detail the old card used to
## insist on. Small, unbordered, and labelled as questions rather than sections.
func _curiosity_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "Curiosity"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 26)
	row.add_child(_curiosity_button("WHY YOU'RE HERE", _situation_rows))
	row.add_child(_curiosity_button("HOW IT'S JUDGED", _judged_rows))
	row.add_child(_curiosity_button("CONTROLS", _controls_rows))
	return row


func _curiosity_button(label_text: String, rows_provider: Callable) -> Button:
	var button := Button.new()
	button.text = label_text
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 13)
	button.add_theme_color_override("font_color", MUTED)
	button.add_theme_color_override("font_hover_color", GOLD)
	button.add_theme_color_override("font_pressed_color", GOLD)
	var flat := StyleBoxFlat.new()
	flat.bg_color = Color(0, 0, 0, 0)
	flat.set_border_width_all(0)
	flat.content_margin_left = 6.0
	flat.content_margin_right = 6.0
	flat.content_margin_top = 4.0
	flat.content_margin_bottom = 4.0
	button.add_theme_stylebox_override("normal", flat)
	button.add_theme_stylebox_override("hover", flat)
	button.add_theme_stylebox_override("pressed", flat)
	button.add_theme_stylebox_override("focus", flat)
	button.pressed.connect(func() -> void: _open_sheet(rows_provider))
	return button


# --- Mode chips -------------------------------------------------------------------

func _build_mode_chips() -> void:
	var chips := HBoxContainer.new()
	chips.name = "ModeChips"
	chips.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	chips.offset_left = -430.0
	chips.offset_top = 14.0
	chips.offset_right = -20.0
	chips.offset_bottom = 42.0
	chips.alignment = BoxContainer.ALIGNMENT_END
	chips.add_theme_constant_override("separation", 6)
	chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(chips)

	# The corner speaker opens the mixer rather than toggling one channel: the
	# crew reach for sound control on day one, and "make it quiet" is not
	# always about the music. Icon-only so the corner stays quiet, with the
	# mixer popup carrying the detail.
	_audio_button = Button.new()
	_audio_button.name = "AudioToggle"
	_audio_button.focus_mode = Control.FOCUS_NONE
	_audio_button.tooltip_text = "Sound mixer"
	_audio_button.custom_minimum_size = Vector2(34.0, 28.0)
	_audio_button.add_theme_color_override("font_color", MUTED)
	var music_idle := StyleBoxFlat.new()
	music_idle.bg_color = Color(0, 0, 0, 0.35)
	music_idle.border_color = Color(0.4, 0.32, 0.26)
	music_idle.set_border_width_all(1)
	music_idle.set_corner_radius_all(3)
	_audio_button.add_theme_stylebox_override("normal", music_idle)
	var music_hover: StyleBoxFlat = music_idle.duplicate()
	music_hover.border_color = TANGERINE
	_audio_button.add_theme_stylebox_override("hover", music_hover)
	var music_on: StyleBoxFlat = music_idle.duplicate()
	music_on.border_color = GOLD
	_audio_button.add_theme_stylebox_override("pressed", music_on)
	_audio_button.add_theme_stylebox_override("focus", music_idle)
	_audio_glyph = Glyph.make("sound_off", 16.0, MUTED)
	_audio_glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_audio_glyph.set_anchors_preset(Control.PRESET_CENTER)
	_audio_glyph.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_audio_glyph.grow_vertical = Control.GROW_DIRECTION_BOTH
	_audio_button.add_child(_audio_glyph)
	_audio_button.pressed.connect(_on_audio_button)
	_refresh_audio_button()
	chips.add_child(_audio_button)

	_build_audio_popup()

	var group := ButtonGroup.new()
	group.allow_unpress = false
	for value in [InputMode.Mode.DESKTOP, InputMode.Mode.TOUCH, InputMode.Mode.VR]:
		var chip := _mode_chip(int(value), group)
		_mode_buttons[int(value)] = chip
		chips.add_child(chip)

	_mode_note = Label.new()
	_mode_note.name = "ModeNote"
	_mode_note.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_mode_note.offset_left = -440.0
	_mode_note.offset_top = 44.0
	_mode_note.offset_right = -20.0
	_mode_note.offset_bottom = 60.0
	_mode_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_mode_note.add_theme_font_size_override("font_size", 11)
	_mode_note.add_theme_color_override("font_color", MUTED)
	_mode_note.text = "input mode  -  test switch"
	_root.add_child(_mode_note)
	_mode_watch = InputMode.mode
	_refresh_mode_chips()


func _mode_chip(value: int, group: ButtonGroup) -> Button:
	var chip := Button.new()
	chip.name = "Mode_%d" % value
	chip.toggle_mode = true
	chip.button_group = group
	chip.focus_mode = Control.FOCUS_NONE
	chip.text = InputMode.label(value)
	chip.add_theme_font_size_override("font_size", 12)
	chip.add_theme_color_override("font_color", MUTED)
	chip.add_theme_color_override("font_hover_color", WHITE)
	chip.add_theme_color_override("font_pressed_color", Color(0.1, 0.06, 0.04))
	var idle := StyleBoxFlat.new()
	idle.bg_color = Color(0, 0, 0, 0.35)
	idle.border_color = Color(0.4, 0.32, 0.26)
	idle.set_border_width_all(1)
	idle.set_corner_radius_all(3)
	idle.content_margin_left = 10.0
	idle.content_margin_right = 10.0
	idle.content_margin_top = 3.0
	idle.content_margin_bottom = 3.0
	chip.add_theme_stylebox_override("normal", idle)
	var hovered: StyleBoxFlat = idle.duplicate()
	hovered.border_color = TANGERINE
	chip.add_theme_stylebox_override("hover", hovered)
	var chosen: StyleBoxFlat = idle.duplicate()
	chosen.bg_color = GOLD
	chosen.border_color = GOLD
	chip.add_theme_stylebox_override("pressed", chosen)
	chip.add_theme_stylebox_override("focus", idle)
	chip.pressed.connect(_on_mode_chip.bind(value))
	return chip


func _on_mode_chip(value: int) -> void:
	if InputMode.set_mode(value):
		_mode_note.text = "input mode  -  test switch"
	else:
		_mode_note.text = "No OpenXR runtime found - VR stays off for now."
	_refresh_mode_chips()


## The mixer popup. A small panel anchored under the corner button, carrying
## the full three-channel mixer. It closes on a click outside it, and it does
## not block the rest of the screen - the crew can hear a fader move while the
## title card stays live.
func _build_audio_popup() -> void:
	_audio_popup = PanelContainer.new()
	_audio_popup.name = "AudioPopup"
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.055, 0.04, 0.98)
	style.border_color = PAPAYA
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 18.0
	style.content_margin_right = 18.0
	style.content_margin_top = 12.0
	style.content_margin_bottom = 14.0
	_audio_popup.add_theme_stylebox_override("panel", style)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	_audio_popup.add_child(column)
	var heading := _heading("SOUND")
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	column.add_child(heading)
	column.add_child(AudioPanel.new())
	_audio_popup.visible = false
	_root.add_child(_audio_popup)
	# A full-rect catcher UNDER the panel closes the popup on the next click
	# anywhere else; it sits behind the panel in draw order, so the panel's own
	# clicks never reach it.
	var catcher := Control.new()
	catcher.name = "Catcher"
	catcher.set_anchors_preset(Control.PRESET_FULL_RECT)
	catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	catcher.visible = false
	catcher.gui_input.connect(_on_audio_catcher_input)
	_root.add_child(catcher)
	_root.move_child(catcher, _audio_popup.get_index())
	_audio_catcher = catcher


func _on_audio_catcher_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_close_audio_popup()


func _open_audio_popup() -> void:
	if _audio_popup == null:
		return
	_audio_popup.visible = true
	if _audio_catcher != null:
		_audio_catcher.visible = true
	_audio_popup.reset_size()
	# Anchor under the corner button, right-aligned to it.
	_audio_popup.position = Vector2(
		_root.size.x - _audio_popup.size.x - 20.0,
		58.0)


func _close_audio_popup() -> void:
	if _audio_popup != null:
		_audio_popup.visible = false
	if _audio_catcher != null:
		_audio_catcher.visible = false


func _on_audio_button() -> void:
	if _audio_popup != null and _audio_popup.visible:
		_close_audio_popup()
	else:
		_open_audio_popup()


func _refresh_audio_button() -> void:
	if _audio_button == null:
		return
	var silent: bool = Sfx.channel_is_muted("music") \
		and Sfx.channel_is_muted("ambience") and Sfx.channel_is_muted("sfx")
	_audio_button.tooltip_text = "Sound mixer" if not silent \
		else "Sound mixer (everything muted)"
	if _audio_glyph != null:
		_audio_glyph.icon = "sound_off" if silent else "sound_on"
		_audio_glyph.tint = MUTED if silent else GOLD


func _refresh_mode_chips() -> void:
	for value in _mode_buttons:
		var chip: Button = _mode_buttons[value]
		chip.set_pressed_no_signal(int(value) == InputMode.mode)


# --- Sheet ----------------------------------------------------------------------

func _build_sheet() -> void:
	_sheet = Control.new()
	_sheet.name = "Sheet"
	_sheet.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sheet.mouse_filter = Control.MOUSE_FILTER_STOP
	_sheet.visible = false
	_root.add_child(_sheet)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.03, 0.02, 0.015, 0.82)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(_on_sheet_dim_input)
	_sheet.add_child(dim)

	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(620.0, 0.0)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.055, 0.04, 0.99)
	style.border_color = PAPAYA
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 26.0
	style.content_margin_right = 26.0
	style.content_margin_top = 18.0
	style.content_margin_bottom = 18.0
	panel.add_theme_stylebox_override("panel", style)
	_sheet.add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)

	_sheet_title = Label.new()
	_sheet_title.name = "Title"
	_sheet_title.add_theme_font_size_override("font_size", 24)
	_sheet_title.add_theme_color_override("font_color", WHITE)
	column.add_child(_sheet_title)

	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.custom_minimum_size = Vector2(0.0, 230.0)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)

	_sheet_body = VBoxContainer.new()
	_sheet_body.name = "Body"
	_sheet_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sheet_body.add_theme_constant_override("separation", 2)
	scroll.add_child(_sheet_body)

	var close := Button.new()
	close.text = "CLOSE"
	close.custom_minimum_size = Vector2(150.0, 40.0)
	close.size_flags_horizontal = Control.SIZE_SHRINK_END
	close.add_theme_font_size_override("font_size", 14)
	close.add_theme_color_override("font_color", Color(0.1, 0.06, 0.04))
	var close_fill := StyleBoxFlat.new()
	close_fill.bg_color = GOLD
	close_fill.set_corner_radius_all(3)
	close.add_theme_stylebox_override("normal", close_fill)
	var close_hover: StyleBoxFlat = close_fill.duplicate()
	close_hover.bg_color = Color(1.0, 0.82, 0.36)
	close.add_theme_stylebox_override("hover", close_hover)
	close.add_theme_stylebox_override("focus", close_hover)
	close.pressed.connect(_close_sheet)
	column.add_child(close)


func _on_sheet_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_close_sheet()


# --- Small builders ---------------------------------------------------------------

func _kicker(text: String) -> Label:
	var label := Label.new()
	label.name = "Kicker"
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", PAPAYA)
	return label


func _title(text: String) -> Label:
	var label := Label.new()
	label.name = "Title"
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 42)
	label.add_theme_color_override("font_color", WHITE)
	return label


func _sub(text: String) -> Label:
	var label := Label.new()
	label.name = "Sub"
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", GOLD)
	return label


func _heading(text: String) -> Label:
	var label := Label.new()
	label.name = "Heading"
	label.text = text
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", GOLD)
	return label


func _micro(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", MUTED)
	return label


func _gap(height: float) -> Control:
	var spacer := Control.new()
	spacer.name = "Gap"
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.custom_minimum_size = Vector2(0.0, height)
	return spacer


func _gap_h(_weight: int) -> Control:
	var spacer := Control.new()
	spacer.name = "Spacer"
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return spacer
