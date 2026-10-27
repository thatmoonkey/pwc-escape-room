class_name PauseMenu
extends CanvasLayer

## The in-run menu: the clear way back out of the ship.
##
## Three jobs, in the order a player needs them: RESUME (the common case, so it
## is the primary button), the music switch (so muting the soundtrack does not
## require leaving the run), the input mode chips (the same test switch the
## launch screen carries, usable mid-run), and MAIN MENU - the explicit door
## back to the title card, which pauses the clock and re-opens the briefing
## with the run's record already on it.
##
## Escape opens and closes this menu. While it is up the run clock is stopped -
## GameState.tick only advances while run_running, and the menu owns that flag
## for as long as it is visible - so a paused crew is not billed for thinking.
## Opening is refused while any other overlay owns the screen, exactly as the
## dev menu does: two modals must never stack.

signal main_menu_requested

const PAPAYA := Color(0.863, 0.369, 0.153)
const TANGERINE := Color(0.816, 0.251, 0.149)
const GOLD := Color(0.941, 0.722, 0.224)
const WHITE := Color(1.0, 1.0, 1.0)
const INK := Color(0.93, 0.89, 0.85)
const MUTED := Color(0.72, 0.66, 0.62)

var _root: Control = null
var _mode_buttons: Dictionary = {}

var _open: bool = false


func _ready() -> void:
	layer = 110
	_build()
	visible = false


func is_open() -> bool:
	return _open


func open() -> void:
	if _open:
		return
	_open = true
	visible = true
	InputRouter.set_ui_blocking(true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# The clock stops while the crew are in the menu, and restarts on RESUME.
	GameState.run_running = false
	_refresh_mode_chips()


func close() -> void:
	if not _open:
		return
	_open = false
	visible = false
	InputRouter.set_ui_blocking(false)
	# Only a run that has started has a clock to hand back; the flag is what
	# GameState.tick reads, so restoring it here is the whole unpause.
	GameState.run_running = GameState.run_started
	for node in get_tree().get_nodes_in_group("input_layer"):
		if node.has_method("grab_mouse"):
			node.grab_mouse()


## Back to the title card. The UI block is left in place on purpose - the
## launch screen takes ownership of it when it opens - and the clock stays
## stopped until the crew press BEGIN again.
func main_menu() -> void:
	if not _open:
		return
	_open = false
	visible = false
	GameState.run_running = false
	main_menu_requested.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if _open:
		close()
	elif not InputRouter.ui_blocking:
		# Another overlay owns the screen; do not stack two modals.
		open()
	else:
		return
	get_viewport().set_input_as_handled()


# --- Build -----------------------------------------------------------------------

func _build() -> void:
	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.04, 0.025, 0.02, 0.86)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			close())
	_root.add_child(dim)

	var card := PanelContainer.new()
	card.name = "Card"
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.custom_minimum_size = Vector2(380.0, 0.0)
	card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	card.grow_vertical = Control.GROW_DIRECTION_BOTH
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.04, 0.03, 0.98)
	style.border_color = PAPAYA
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 34.0
	style.content_margin_right = 34.0
	style.content_margin_top = 26.0
	style.content_margin_bottom = 28.0
	card.add_theme_stylebox_override("panel", style)
	_root.add_child(card)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	card.add_child(column)

	var kicker := Label.new()
	kicker.text = "ADAMANT VERITY"
	kicker.add_theme_font_size_override("font_size", 12)
	kicker.add_theme_color_override("font_color", PAPAYA)
	column.add_child(kicker)

	var title := Label.new()
	title.text = "PAUSED"
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", WHITE)
	column.add_child(title)

	column.add_child(_spacer(8))
	column.add_child(_primary_button("RESUME", close))
	column.add_child(_spacer(4))

	# The mixer, not just a music switch: music, ambience and sfx each carry
	# their own mute and fader, because "turn the music down" and "quiet the
	# sound effects" are different requests and one toggle cannot answer both.
	var audio_caption := Label.new()
	audio_caption.text = "AUDIO"
	audio_caption.add_theme_font_size_override("font_size", 11)
	audio_caption.add_theme_color_override("font_color", MUTED)
	column.add_child(audio_caption)
	var audio_panel := AudioPanel.new()
	audio_panel.name = "AudioPanel"
	column.add_child(audio_panel)

	column.add_child(_spacer(6))
	var mode_caption := Label.new()
	mode_caption.text = "INPUT MODE  -  TEST SWITCH"
	mode_caption.add_theme_font_size_override("font_size", 11)
	mode_caption.add_theme_color_override("font_color", MUTED)
	column.add_child(mode_caption)
	var chips := HBoxContainer.new()
	chips.add_theme_constant_override("separation", 6)
	var group := ButtonGroup.new()
	group.allow_unpress = false
	for value in [InputMode.Mode.DESKTOP, InputMode.Mode.TOUCH, InputMode.Mode.VR]:
		var chip := Button.new()
		chip.text = InputMode.label(int(value))
		chip.toggle_mode = true
		chip.button_group = group
		chip.focus_mode = Control.FOCUS_NONE
		chip.add_theme_font_size_override("font_size", 12)
		chip.add_theme_color_override("font_color", MUTED)
		chip.add_theme_color_override("font_hover_color", WHITE)
		chip.add_theme_color_override("font_pressed_color", Color(0.1, 0.06, 0.04))
		var idle := _ghost_style()
		chip.add_theme_stylebox_override("normal", idle)
		var hovered := _ghost_style()
		hovered.border_color = TANGERINE
		chip.add_theme_stylebox_override("hover", hovered)
		var chosen := _ghost_style()
		chosen.bg_color = GOLD
		chosen.border_color = GOLD
		chip.add_theme_stylebox_override("pressed", chosen)
		chip.add_theme_stylebox_override("focus", idle)
		chip.pressed.connect(_on_mode_chip.bind(int(value)))
		_mode_buttons[int(value)] = chip
		chips.add_child(chip)
	column.add_child(chips)

	column.add_child(_spacer(10))
	var menu_button := Button.new()
	menu_button.text = "MAIN MENU"
	menu_button.focus_mode = Control.FOCUS_NONE
	menu_button.add_theme_font_size_override("font_size", 14)
	menu_button.add_theme_color_override("font_color", PAPAYA)
	menu_button.add_theme_color_override("font_hover_color", GOLD)
	var outlined := _ghost_style()
	outlined.border_color = TANGERINE
	menu_button.add_theme_stylebox_override("normal", outlined)
	menu_button.add_theme_stylebox_override("hover", outlined)
	menu_button.add_theme_stylebox_override("pressed", outlined)
	menu_button.add_theme_stylebox_override("focus", outlined)
	menu_button.pressed.connect(main_menu)
	column.add_child(menu_button)


func _primary_button(label_text: String, handler: Callable) -> Button:
	var button := Button.new()
	button.text = label_text
	button.custom_minimum_size = Vector2(0.0, 50.0)
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size", 17)
	button.add_theme_color_override("font_color", Color(0.10, 0.06, 0.04))
	button.add_theme_color_override("font_hover_color", Color(0.10, 0.06, 0.04))
	var fill := StyleBoxFlat.new()
	fill.bg_color = GOLD
	fill.border_color = TANGERINE
	fill.set_border_width_all(2)
	fill.set_corner_radius_all(3)
	button.add_theme_stylebox_override("normal", fill)
	var hover: StyleBoxFlat = fill.duplicate()
	hover.bg_color = Color(1.0, 0.82, 0.36)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("focus", hover)
	button.pressed.connect(handler)
	return button


func _ghost_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.25)
	style.border_color = Color(0.4, 0.32, 0.26)
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	return style


func _spacer(height: float) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0.0, height)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return spacer


# --- Controls --------------------------------------------------------------------

func _on_mode_chip(value: int) -> void:
	InputMode.set_mode(int(value))
	_refresh_mode_chips()


func _refresh_mode_chips() -> void:
	for value in _mode_buttons:
		var chip: Button = _mode_buttons[value]
		chip.set_pressed_no_signal(int(value) == InputMode.mode)
