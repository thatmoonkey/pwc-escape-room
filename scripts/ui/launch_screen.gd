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
## what was declared before deciding; BEGIN refuses to run without a callsign
## and a mandate; and a resumed session opens with its record already shown
## rather than being asked to re-declare it.

signal begun

const PAPAYA := Color(0.863, 0.369, 0.153)
const TANGERINE := Color(0.816, 0.251, 0.149)
const GOLD := Color(0.941, 0.722, 0.224)
const WHITE := Color(1.0, 1.0, 1.0)
const BODY := Color(0.93, 0.89, 0.85)
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
var _callsign: LineEdit = null
var _hint: Label = null
var _open: bool = false

## The mandate, as chosen on this card. Held as ids until BEGIN, because a
## half-typed name or a half-chosen mandate must not reach the record: the
## mandate is what every placement is judged against, so it is committed once,
## deliberately, with the callsign.
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

var _chooser: PanelContainer = null
var _chooser_open: bool = false

var _sheet: Control = null
var _sheet_title: Label = null
var _sheet_body: VBoxContainer = null

var _mode_buttons: Dictionary = {}
var _mode_note: Label = null
var _mode_watch: int = -1
var _music_button: Button = null
var _music_glyph: Glyph = null


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
	InputRouter.set_ui_blocking(true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	refresh_from_state()
	if _callsign != null and _callsign.text.length() < GameState.CALLSIGN_LENGTH:
		_callsign.grab_focus()
	elif _button != null:
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
	if _callsign != null and GameState.has_save() and GameState.callsign != "":
		_callsign.text = GameState.callsign
	_objective_pick = OperatingModel.objective_id
	_appetite_pick = OperatingModel.appetite_id
	for id in _objective_buttons:
		if String(id) == _objective_pick:
			BrandTokens.mark_chosen(_objective_buttons[id])
	for id in _appetite_buttons:
		if String(id) == _appetite_pick:
			BrandTokens.mark_chosen(_appetite_buttons[id])
	_refresh_resume()
	_refresh_tiles()
	_request_fit()


## Hands the ship over: cursor back into the room, input back to the crew.
func begin() -> void:
	if not _open:
		return
	if _callsign == null or _callsign.text.length() < GameState.CALLSIGN_LENGTH:
		if _callsign != null:
			_callsign.grab_focus()
		_set_hint("Three letters for the record, then BEGIN.")
		return
	if _objective_pick == "":
		_open_chooser()
		_set_hint("Declare the mandate first - it is the yardstick every decision is judged against.")
		return
	if _appetite_pick == "":
		_open_chooser()
		_set_hint("Choose the risk appetite the model runs at.")
		return
	GameState.set_callsign(_callsign.text)
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
	_request_fit()


func _close_chooser() -> void:
	_chooser_open = false
	if _chooser != null:
		_chooser.visible = false
	_request_fit()


func _on_objective_chosen(objective_id: String) -> void:
	_objective_pick = objective_id
	_set_hint("")
	_refresh_tiles()
	_maybe_seal()


func _on_appetite_chosen(appetite_id: String) -> void:
	_appetite_pick = appetite_id
	_set_hint("")
	_refresh_tiles()
	_maybe_seal()


## Both halves picked: the tile completes and the chooser folds itself away,
## because a form that stays open after it is done reads as unfinished.
func _maybe_seal() -> void:
	if not _mandate_declared() or not _chooser_open:
		return
	await get_tree().create_timer(0.45).timeout
	if not is_inside_tree() or not _mandate_declared():
		return
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
			{"text": "You are Crew Member Reyes, aboard the survey ship Adamant Verity."},
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
		]
	else:
		rows = [
			{"icon": "keyboard", "lead": "WASD", "text": "move. Mouse or trackpad: look."},
			{"icon": "check", "lead": "E", "text": "interact with consoles and doors."},
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
	# space down the screen and clipped the callsign row off the bottom.
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
	_chooser = _build_chooser()
	_column.add_child(_chooser)
	_column.add_child(_gap(12))
	_column.add_child(_field_row())
	_resume_label = _micro("")
	_resume_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_column.add_child(_resume_label)
	_column.add_child(_gap(8))
	_column.add_child(_curiosity_row())

	_build_sheet()
	_build_mode_chips()


func _goal_tiles() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "Goals"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 22)

	row.add_child(_goal_tile("mandate", "scroll", "THE MANDATE",
		"Declare it before you walk."))
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


## The mandate chooser, opened from the first tile. Two exclusive picks with
## icons, one short line each - the long form of this copy lives in the
## curiosity sheets.
func _build_chooser() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "Chooser"
	panel.visible = false
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.055, 0.04, 0.98)
	style.border_color = TANGERINE
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 22.0
	style.content_margin_right = 22.0
	style.content_margin_top = 14.0
	style.content_margin_bottom = 16.0
	panel.add_theme_stylebox_override("panel", style)

	var column := VBoxContainer.new()
	column.name = "Column"
	column.add_theme_constant_override("separation", 6)
	panel.add_child(column)

	column.add_child(_heading("DECLARE THE MANDATE"))
	column.add_child(_micro("Every decision you make is judged against this."))

	var objective_group := ButtonGroup.new()
	objective_group.allow_unpress = false
	for entry in OperatingModel.OBJECTIVES:
		var id: String = String(entry["id"])
		var button := BrandTokens.icon_choice_button(
			objective_group, Glyph.icon_for_objective(id),
			String(entry["label"]), String(entry["statement"]))
		button.name = "Objective_%s" % id
		button.pressed.connect(_on_objective_chosen.bind(id))
		_objective_buttons[id] = button
		column.add_child(button)

	column.add_child(_gap(8))
	column.add_child(_heading("RISK APPETITE"))
	var appetite_group := ButtonGroup.new()
	appetite_group.allow_unpress = false
	for entry in OperatingModel.APPETITES:
		var id: String = String(entry["id"])
		var button := BrandTokens.icon_choice_button(
			appetite_group, Glyph.icon_for_appetite(id),
			String(entry["label"]), String(entry["blurb"]))
		button.name = "Appetite_%s" % id
		button.pressed.connect(_on_appetite_chosen.bind(id))
		_appetite_buttons[id] = button
		column.add_child(button)
	return panel


func _field_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "FieldRow"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)

	row.add_child(_callsign_row())
	row.add_child(_gap_h(1))

	_button = Button.new()
	_button.name = "Begin"
	_button.text = "BEGIN"
	_button.custom_minimum_size = Vector2(240.0, 50.0)
	_button.add_theme_font_size_override("font_size", 19)
	_button.add_theme_color_override("font_color", Color(0.10, 0.06, 0.04))
	_button.add_theme_color_override("font_hover_color", Color(0.10, 0.06, 0.04))
	var fill := StyleBoxFlat.new()
	fill.bg_color = GOLD
	fill.border_color = TANGERINE
	fill.set_border_width_all(2)
	fill.set_corner_radius_all(3)
	_button.add_theme_stylebox_override("normal", fill)
	var hover: StyleBoxFlat = fill.duplicate()
	hover.bg_color = Color(1.0, 0.82, 0.36)
	_button.add_theme_stylebox_override("hover", hover)
	_button.add_theme_stylebox_override("focus", hover)
	_button.pressed.connect(begin)
	row.add_child(_button)

	var start_hint := Label.new()
	start_hint.name = "StartHint"
	start_hint.text = "or press Enter"
	start_hint.add_theme_font_size_override("font_size", 14)
	start_hint.add_theme_color_override("font_color", MUTED)
	start_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(start_hint)

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


func _callsign_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "CallsignRow"
	row.add_theme_constant_override("separation", 12)

	_callsign = LineEdit.new()
	_callsign.name = "Callsign"
	_callsign.max_length = GameState.CALLSIGN_LENGTH
	_callsign.placeholder_text = "REY"
	_callsign.custom_minimum_size = Vector2(132.0, 50.0)
	_callsign.add_theme_font_size_override("font_size", 24)
	_callsign.add_theme_color_override("font_color", WHITE)
	_callsign.add_theme_color_override("caret_color", GOLD)
	_callsign.add_theme_color_override("font_placeholder_color", MUTED)
	var field := StyleBoxFlat.new()
	field.bg_color = SURFACE
	field.border_color = TANGERINE
	field.set_border_width_all(2)
	field.set_corner_radius_all(3)
	field.content_margin_left = 14.0
	field.content_margin_right = 14.0
	_callsign.add_theme_stylebox_override("normal", field)
	var focused: StyleBoxFlat = field.duplicate()
	focused.border_color = GOLD
	_callsign.add_theme_stylebox_override("focus", focused)
	_callsign.text_changed.connect(_on_callsign_typed)
	_callsign.text_submitted.connect(_on_callsign_submitted)
	row.add_child(_callsign)

	var note := Label.new()
	note.name = "Note"
	note.text = "your callsign"
	note.add_theme_font_size_override("font_size", 13)
	note.add_theme_color_override("font_color", MUTED)
	note.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(note)
	return row


func _on_callsign_typed(text: String) -> void:
	var cleaned: String = ""
	for character in text.to_upper():
		if "ABCDEFGHIJKLMNOPQRSTUVWXYZ".contains(character):
			cleaned += character
	if cleaned.length() > GameState.CALLSIGN_LENGTH:
		cleaned = cleaned.substr(0, GameState.CALLSIGN_LENGTH)
	if cleaned != text:
		_callsign.set_text(cleaned)
		_callsign.caret_column = cleaned.length()
	if cleaned.length() >= GameState.CALLSIGN_LENGTH and _button != null:
		_button.grab_focus()


func _on_callsign_submitted(_text: String) -> void:
	if _callsign != null and _callsign.text.length() >= GameState.CALLSIGN_LENGTH:
		begin()
	else:
		_callsign.grab_focus()


func _set_hint(text: String) -> void:
	if _hint != null:
		_hint.text = text


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
	chips.offset_left = -378.0
	chips.offset_top = 14.0
	chips.offset_right = -20.0
	chips.offset_bottom = 42.0
	chips.alignment = BoxContainer.ALIGNMENT_END
	chips.add_theme_constant_override("separation", 6)
	chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(chips)

	# The music switch lives beside the mode chips: a control the crew reach
	# for on day one, parked where day-one controls belong. It is icon-only so
	# the corner stays quiet, with a tooltip and the note line to name it.
	_music_button = Button.new()
	_music_button.name = "MusicToggle"
	_music_button.focus_mode = Control.FOCUS_NONE
	_music_button.tooltip_text = "Music: muted"
	_music_button.custom_minimum_size = Vector2(34.0, 28.0)
	_music_button.add_theme_color_override("font_color", MUTED)
	var music_idle := StyleBoxFlat.new()
	music_idle.bg_color = Color(0, 0, 0, 0.35)
	music_idle.border_color = Color(0.4, 0.32, 0.26)
	music_idle.set_border_width_all(1)
	music_idle.set_corner_radius_all(3)
	_music_button.add_theme_stylebox_override("normal", music_idle)
	var music_hover: StyleBoxFlat = music_idle.duplicate()
	music_hover.border_color = TANGERINE
	_music_button.add_theme_stylebox_override("hover", music_hover)
	var music_on: StyleBoxFlat = music_idle.duplicate()
	music_on.border_color = GOLD
	_music_button.add_theme_stylebox_override("pressed", music_on)
	_music_button.add_theme_stylebox_override("focus", music_idle)
	_music_glyph = Glyph.make("sound_off", 16.0, MUTED)
	_music_glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_music_glyph.set_anchors_preset(Control.PRESET_CENTER)
	_music_glyph.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_music_glyph.grow_vertical = Control.GROW_DIRECTION_BOTH
	_music_button.add_child(_music_glyph)
	_music_button.pressed.connect(_on_music_toggled)
	_refresh_music_button()
	chips.add_child(_music_button)

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


func _on_music_toggled() -> void:
	Sfx.toggle_music_muted()
	_refresh_music_button()
	if _mode_note != null:
		_mode_note.text = "music " + ("muted" if Sfx.music_muted else "on")


func _refresh_music_button() -> void:
	if _music_button == null:
		return
	_music_button.set_pressed_no_signal(not Sfx.music_muted)
	_music_button.tooltip_text = "Music: muted - click to unmute" if Sfx.music_muted \
		else "Music: on - click to mute"
	if _music_glyph != null:
		_music_glyph.icon = "sound_off" if Sfx.music_muted else "sound_on"
		_music_glyph.tint = MUTED if Sfx.music_muted else GOLD


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
