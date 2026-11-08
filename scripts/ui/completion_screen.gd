class_name CompletionScreen
extends CanvasLayer

## THE END OF THE RUN, SHOWN WHEN THE SHIP HAS FLOWN.
##
## The departure cutscene hands control back to the cockpit and this takes the
## stage: the whole run as one picture. Five decisions across four autonomy
## levels is a matrix, and a matrix is the only shape that shows a run's pattern
## at a glance - which rungs this crew kept choosing, and where they broke their
## own pattern. Each decision's score sits at the end of its row, coloured on the
## client's own ramp, so the shape of the run and the cost of it are read
## together rather than in a list of sentences.
##
## Under the matrix is the one thing left to do: put the run on the board. The
## board is the live SHIPMIND uplink - the network leaderboard behind the CRT
## terminal screen, stored on the server so the whole venue can see it. The
## uplink client queues submissions on disk when the network is down, so the
## flow cannot lose a run even in a conference basement.
##
## PLATFORM NOTE. Everything here is pointer-driven - a click, a tap, a
## controller-driven pointer - and no control needs a keyboard to be dismissed.
## A headset has no keyboard, so the fields are pre-filled with what the save
## already knows and the form accepts a run without contact details there; on
## desktop and on a phone the contact is asked for properly.

signal closed

const ORANGE := Brand.ACCENT
const PEACH := ScoreVisuals.PEACH
const OFF_WHITE := ScoreVisuals.OFF_WHITE
const SLATE := ScoreVisuals.SLATE

var _open: bool = false
var _root: Control = null
var _panel: PanelContainer = null
var _content: VBoxContainer = null
## The live SHIPMIND uplink screen while it is up, hosted inside this layer.
var _board: ShipmindLeaderboard = null


func _ready() -> void:
	layer = 125
	_build_shell()
	get_viewport().size_changed.connect(_relayout)
	root_visible(false)


func is_open() -> bool:
	return _open


## The cockpit is visible behind this: the crew are back in their seats, looking
## at what their five decisions added up to.
func show_screen() -> void:
	_open = true
	root_visible(true)
	_rebuild()
	_relayout()
	InputRouter.set_ui_blocking(true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close() -> void:
	if not _open:
		return
	_open = false
	_discard_uplink()
	root_visible(false)
	InputRouter.set_ui_blocking(false)
	for node in get_tree().get_nodes_in_group("input_layer"):
		if node.has_method("grab_mouse"):
			node.grab_mouse()
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not _open:
		return
	if event.is_action_pressed("ui_cancel"):
		# The first escape closes the uplink screen if it is up, not the run.
		if _board != null:
			_close_uplink_board()
		else:
			close()
		get_viewport().set_input_as_handled()


# --- The shell -------------------------------------------------------------------


func _build_shell() -> void:
	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var backdrop := ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(Brand.SURFACE.r, Brand.SURFACE.g, Brand.SURFACE.b, 0.92)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(backdrop)

	_panel = PanelContainer.new()
	_panel.name = "Panel"
	_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	var style := StyleBoxFlat.new()
	style.bg_color = Brand.SURFACE
	style.border_color = Brand.ACCENT
	style.border_width_top = 3
	style.set_corner_radius_all(3)
	_panel.add_theme_stylebox_override("panel", style)
	_root.add_child(_panel)

	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	_panel.add_child(margin)

	_content = VBoxContainer.new()
	_content.name = "Content"
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 5)
	margin.add_child(_content)


func root_visible(value: bool) -> void:
	if _root != null:
		_root.visible = value


func _rebuild() -> void:
	_clear(_content)
	_build_results_page()


## PAGE ONE: WHAT THE RUN ADDED UP TO. Nothing to fill in, nothing to scroll to -
## one action, which is the way on.
func _build_results_page() -> void:
	_content.add_child(_title("MISSION COMPLETE"))
	_content.add_child(_summary_row())
	var mandate := Label.new()
	mandate.text = "YOUR MANDATE  %s" % OperatingModel.mandate_statement()
	mandate.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mandate.add_theme_font_size_override("font_size", _px(12))
	mandate.add_theme_color_override("font_color", Brand.NEUTRAL_LIGHT)
	_content.add_child(mandate)
	_content.add_child(_rule())
	_content.add_child(_section("YOUR FIVE DECISIONS"))
	_content.add_child(_matrix())
	_content.add_child(_gap(_px(4)))
	_content.add_child(_results_actions())


# --- The run, as a picture -----------------------------------------------------------


## The headline: the total as the biggest number on the screen, its own meter,
## and the verdict it earns - beside the two axes the total is made of.
func _summary_row() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", _px(12))

	var score_box := VBoxContainer.new()
	score_box.add_theme_constant_override("separation", _px(3))
	score_box.custom_minimum_size = Vector2(_px(130), 0.0)
	score_box.add_child(_section("RUN SCORE"))
	var total := Label.new()
	total.text = "%d / %d" % [Score.total(), Score.max_total()]
	total.add_theme_font_size_override("font_size", _px(24))
	total.add_theme_color_override("font_color", Brand.INK)
	score_box.add_child(total)
	var progress := ScoreVisuals.Meter.new()
	progress.custom_minimum_size = Vector2(0.0, _px(6))
	progress.fill_color = ORANGE
	progress.show_ratio(float(Score.total()) / maxf(float(Score.max_total()), 1.0))
	score_box.add_child(progress)
	row.add_child(score_box)

	var axes := GridContainer.new()
	axes.columns = 1 if _is_portrait() else 2
	axes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	axes.add_theme_constant_override("h_separation", 24)
	axes.add_theme_constant_override("v_separation", 10)
	var consistency := ScoreVisuals.meter_block("MATCHES YOUR MANDATE", Score.mean_consistency(),
		Brand.ACCENT, _axis_word(Score.mean_consistency()), true)
	consistency.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	axes.add_child(consistency)
	var coherence := ScoreVisuals.meter_block("FITS THE STAKES", Score.mean_coherence(),
		PEACH, _axis_word(Score.mean_coherence()), true)
	coherence.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	axes.add_child(coherence)
	row.add_child(axes)
	return row


## Five decisions down the side, the four autonomy levels across the top, and the
## decision's own score at the end of its row. The chosen rung is the filled box;
## the empty ones are the rungs this crew chose not to use, which is information
## too - a run that never leaves the first column says something.
func _matrix() -> Control:
	var grid := GridContainer.new()
	grid.name = "Decisions"
	var view: Vector2 = get_viewport().get_visible_rect().size
	grid.columns = 3 if view.x >= 1200.0 else 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 4)

	for system_id in GameState.SYSTEMS:
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(0.0, _px(44))
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var style := StyleBoxFlat.new()
		style.bg_color = Brand.SURFACE_RAISED
		style.border_color = Color(Brand.ACCENT.r, Brand.ACCENT.g, Brand.ACCENT.b, 0.45)
		style.set_border_width_all(1)
		style.set_corner_radius_all(2)
		style.content_margin_left = 8.0
		style.content_margin_right = 8.0
		style.content_margin_top = 4.0
		style.content_margin_bottom = 4.0
		card.add_theme_stylebox_override("panel", style)
		var body := HBoxContainer.new()
		body.add_theme_constant_override("separation", 5)
		card.add_child(body)
		var name_label := _cell_label(GameState.display_name(system_id), 12, Brand.NEUTRAL_LIGHT)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		body.add_child(name_label)
		var level_id := String(GameState.placement(system_id).get("level", ""))
		var level_fill: Color = OperatingModel.level_color(level_id)
		var level_ink: Color = ScoreVisuals.INK if OperatingModel.level_dark_text(level_id) else ScoreVisuals.INK_LIGHT
		var level_text := "NOT PLACED" if level_id == "" else OperatingModel.level_short(level_id)
		var level_chip := ScoreVisuals.pill(level_text, level_fill, level_ink, _px(11), Vector2(6.0, 2.0))
		level_chip.tooltip_text = OperatingModel.level_summary(level_id) if level_id != "" else "No decision placed"
		body.add_child(level_chip)
		body.add_child(_score_chip(system_id))
		grid.add_child(card)
	return grid


func _score_chip(system_id: String) -> Control:
	var quality: float = Score.decision_quality(system_id)
	if quality < 0.0:
		var none := ScoreVisuals.pill("--", Brand.SURFACE_RAISED, Brand.NEUTRAL, _px(12), Vector2(10.0, 5.0))
		none.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		return none
	var chip := ScoreVisuals.pill("%d" % Score.decision_points(system_id),
		ScoreVisuals.grade_color(quality), ScoreVisuals.grade_ink(quality),
		_px(13), Vector2(10.0, 5.0))
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chip.tooltip_text = "%s - %s" % [
		GameState.display_name(system_id), Score.grade_label(quality)]
	return chip


## The CRT screen covers this panel completely while it is up, so the root
## steps out of the way; closing the board hands the results page back
## untouched.
func _open_uplink_board() -> void:
	if _board != null:
		return
	_board = ShipmindLeaderboard.new()
	add_child(_board)
	_board.closed.connect(_close_uplink_board)
	_board.present_result(Score.total(), int(GameState.elapsed))
	_root.visible = false


func _close_uplink_board() -> void:
	_discard_uplink()
	root_visible(_open)


func _discard_uplink() -> void:
	if _board != null:
		_board.queue_free()
		_board = null


## Page one's actions. The primary is the one thing left to do with the run:
## put it on the board. The board is the SHIPMIND uplink - there is no local
## board any more.
func _results_actions() -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 14)
	row.add_child(_quiet_button("BACK TO THE SHIP", close))
	row.add_child(_primary_button("PUT IT ON THE BOARD", _open_uplink_board))
	return row


func _primary_button(label_text: String, handler: Callable) -> Button:
	var button := Button.new()
	button.name = label_text.capitalize().replace(" ", "")
	button.text = label_text
	button.custom_minimum_size = Vector2(_px(230), _px(48))
	button.add_theme_font_size_override("font_size", _px(14))
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	var fill := StyleBoxFlat.new()
	fill.bg_color = ORANGE
	fill.set_corner_radius_all(2)
	button.add_theme_stylebox_override("normal", fill)
	var hover: StyleBoxFlat = fill.duplicate()
	hover.bg_color = Brand.ACCENT_TINT
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.pressed.connect(handler)
	return button


func _quiet_button(label_text: String, handler: Callable) -> Button:
	var button := Button.new()
	button.name = label_text.capitalize().replace(" ", "")
	button.text = label_text
	button.custom_minimum_size = Vector2(0.0, _px(44))
	button.add_theme_font_size_override("font_size", _px(12))
	button.add_theme_color_override("font_color", Brand.INK)
	button.add_theme_color_override("font_hover_color", Brand.ACCENT_TINT)
	button.add_theme_stylebox_override("normal", _field_box(Color(0.0, 0.0, 0.0, 0.0), Brand.NEUTRAL))
	button.add_theme_stylebox_override("hover", _field_box(Color(0.0, 0.0, 0.0, 0.0), Brand.ACCENT_TINT))
	button.pressed.connect(handler)
	return button


func _field_box(background: Color, border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = background
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(2)
	box.content_margin_left = 10.0
	box.content_margin_right = 10.0
	return box


func _gap(height: float) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0.0, height)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return spacer


# --- Small pieces -------------------------------------------------------------------


func _kicker(text: String) -> Label:
	var label := Label.new()
	label.text = text
	Brand.apply_tui(label, _px(12))
	label.add_theme_color_override("font_color", Brand.ACCENT_TINT)
	return label


func _title(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", _px(30))
	label.add_theme_color_override("font_color", Brand.INK)
	return label


func _section(text: String) -> Label:
	var label := Label.new()
	label.text = text
	Brand.apply_tui(label, _px(11))
	label.add_theme_color_override("font_color", Brand.NEUTRAL)
	return label


func _cell_label(text: String, size: int, tint: Color, width: float = 0.0) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", _px(size))
	label.add_theme_color_override("font_color", tint)
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if width > 0.0:
		label.custom_minimum_size = Vector2(width, 0.0)
	else:
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label


func _rule() -> ColorRect:
	var rule := ColorRect.new()
	rule.color = Color(1.0, 1.0, 1.0, 0.12)
	rule.custom_minimum_size = Vector2(0.0, 1.0)
	return rule


func _axis_word(value: float) -> String:
	if value < 0.0:
		return "nothing to measure yet"
	return Score.grade_label(value).capitalize()


func _clear(container: Node) -> void:
	if container == null:
		return
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


# --- Layout -----------------------------------------------------------------------


func _relayout() -> void:
	if _panel == null:
		return
	var view: Vector2 = get_viewport().get_visible_rect().size
	var inset := Brand.safe_inset(view)
	_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_panel.size = view - Vector2(inset * 2.0, inset * 2.0)
	_panel.position = Vector2(inset, inset)
	_content.add_theme_constant_override("separation", 4 if view.y < 500.0 else 6)


func _is_portrait() -> bool:
	var view: Vector2 = get_viewport().get_visible_rect().size
	return view.y > view.x


## One type scale for the screen, stepped up where the only pointer is a thumb
## and again in a headset, where the panel is read from further away. The
## multiplier is Platform's, shared with every other overlay. The floor rule
## clamps after the multiplier so nothing ever renders below the reading floor.
func _px(base: float) -> int:
	var view: Vector2 = get_viewport().get_visible_rect().size
	if view.y < 500.0:
		return max(int(round(base * Platform.ui_scale() * 0.75)), 18)
	return max(int(round(base * Platform.ui_scale())), Brand.SIZE_SMALL)
