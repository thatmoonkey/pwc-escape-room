class_name TerminalUI
extends CanvasLayer

## Renders a ScreenState as a diegetic ship terminal: a printout that types
## itself out line by line, plus option buttons.
##
## The renderer knows nothing about puzzles. It prints whatever state a Puzzle
## emits, sends option presses back through "option_chosen", and - when the
## state carries a spectrum block - draws the placement control and sends the
## chosen level, guardrail and accountable-owner ids back through
## "placement_chosen". It never reads input or platform state of its own, so
## desktop, touch and VR are all the same screen.

signal option_chosen(option_id: String)
## A spectrum commit: the level the player chose, the single guardrail they
## attached to it, and the named role that owns the outcome. All three are handed
## back together, so a placement is never half-recorded. The owner is empty for a
## human-only placement, where the operator owns it by definition.
signal placement_chosen(level_id: String, guardrail_id: String, owner_id: String)
signal opened
signal closed

@export var print_interval: float = 0.06

@onready var root: Control = $Root
@onready var dim: ColorRect = $Root/Dim
@onready var title_label: Label = $Root/Panel/VBox/Header/TitleLabel
@onready var status_label: Label = $Root/Panel/VBox/Header/StatusLabel
@onready var rule_bar: ColorRect = $Root/Panel/VBox/Rule
@onready var vbox: VBoxContainer = $Root/Panel/VBox
@onready var scroll: ScrollContainer = $Root/Panel/VBox/Columns/Readout/Scroll
@onready var print_box: VBoxContainer = $Root/Panel/VBox/Columns/Readout/Scroll/Print
@onready var options_box: VBoxContainer = $Root/Panel/VBox/Columns/Decision/Options
@onready var decision_scroll: ScrollContainer = $Root/Panel/VBox/Columns/Decision/DecisionScroll
## The placement control's host, which owns its own scroller. The decision panel
## is the half of the screen that overflows, because the four levels, three
## guardrails and three owner roles are a lot of reading; giving it a scroll of
## its own is what keeps the option buttons pinned and visible while it happens.
@onready var _spectrum_box: VBoxContainer = $Root/Panel/VBox/Columns/Decision/DecisionScroll/Spectrum
@onready var footer: Label = $Root/Panel/VBox/Footer
@onready var header: HBoxContainer = $Root/Panel/VBox/Header

## The footer is the only place the two control schemes are allowed to differ on
## screen. A phone has no ESC and no keyboard, so its way out is the CLOSE
## button rather than a key.
const FOOTER_DESKTOP := "CLICK or any key reveals the full readout   -   ESC closes"
const FOOTER_TOUCH := "TAP the readout to reveal it   -   TAP CLOSE to leave"

const TONES := {
	"shipmind": Color(0.941, 0.722, 0.224),
	"data": Color(0.9, 0.86, 0.82),
	"ok": Color(1.0, 0.88, 0.55),
	"warn": Color(0.863, 0.369, 0.153),
	"dim": Color(0.62, 0.54, 0.48),
	"rule": Color(0.42, 0.24, 0.15),
}

var _puzzle: Puzzle = null
var _pending: Array[Dictionary] = []
var _print_index: int = 0
var _timer: Timer

## What the player has picked so far, in the ids the screen was written with.
## Held here rather than on ScreenState because a ScreenState is a description
## of a screen, not the state of a control.
var _level_choice: String = ""
var _guardrail_choice: String = ""
var _owner_choice: String = ""
## Which of the block's levels demand a named owner, captured from the block when
## it is drawn. Everything above human-only does; human-only does not, because
## the operator is the accountable owner already.
var _levels_require_owner: Dictionary = {}
## The live line under the owner list, saying what the level picked right now
## requires. It is how the owner rule is read before the commit rather than
## discovered when the commit is refused.
var _owner_requirement: Label = null
var _commit: Button = null


func _ready() -> void:
	add_to_group("terminal_ui")
	_timer = Timer.new()
	_timer.one_shot = false
	_timer.timeout.connect(_print_step)
	add_child(_timer)
	dim.gui_input.connect(_on_dim_input)
	## The readout itself reveals on a tap as well as the backdrop: it is where
	## the player is looking while it prints, so it is where they will tap.
	scroll.gui_input.connect(_on_dim_input)
	_build_close_button()
	footer.text = FOOTER_TOUCH if touch_mode() else FOOTER_DESKTOP
	root.visible = false


## True on a device whose only pointer is a finger.
func touch_mode() -> bool:
	return DisplayServer.is_touchscreen_available()


## A way out of the terminal that does not depend on a keyboard.
##
## The screen used to close only on ESC, which a touchscreen does not have: on a
## phone the sole exit was an option button that happened to be labelled
## "close", and a screen is not obliged to offer one, so a console could strand
## the player with no way back. The button sits in the header, so it exists for
## every state, and it is built in code for the same reason the spectrum block
## is: the terminal draws whatever state it is handed.
func _build_close_button() -> void:
	var button := Button.new()
	button.name = "CloseButton"
	button.text = "CLOSE"
	## FOCUS_NONE: this is a pointer target, not a keyboard stop. Left in the
	## focus chain it would steal focus from the option buttons.
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(0.0, 50.0 if touch_mode() else 34.0)
	button.add_theme_font_size_override("font_size", Brand.SIZE_LABEL)
	button.add_theme_color_override("font_color", Brand.ACCENT_TINT)
	button.pressed.connect(close)
	header.add_child(button)


func is_open() -> bool:
	return root.visible


func open(puzzle: Puzzle) -> void:
	if puzzle == null or _puzzle != null:
		return
	_puzzle = puzzle
	if not puzzle.state_changed.is_connected(_render):
		puzzle.state_changed.connect(_render)
	root.visible = true
	InputRouter.set_ui_blocking(true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	puzzle.start()
	opened.emit()


func close() -> void:
	if _puzzle != null and _puzzle.state_changed.is_connected(_render):
		_puzzle.state_changed.disconnect(_render)
	_puzzle = null
	_timer.stop()
	root.visible = false
	InputRouter.set_ui_blocking(false)
	closed.emit()


func _render(state: ScreenState) -> void:
	title_label.text = state.title
	status_label.text = state.status
	status_label.modulate = state.accent
	rule_bar.color = state.accent
	_clear(print_box)
	_clear(options_box)
	_clear(_spectrum_box)
	## A placement is committed once per screen, so each new screen starts with
	## nothing picked and the commit button closed. That is what makes "revise
	## the placement" a clean second look at the decision rather than a
	## half-remembered one.
	_level_choice = ""
	_guardrail_choice = ""
	_owner_choice = ""
	_levels_require_owner.clear()
	_owner_requirement = null
	_commit = null
	_pending = state.lines.duplicate()
	_print_index = 0
	if state.has_spectrum():
		_draw_spectrum(state.spectrum)
	for entry in state.options:
		options_box.add_child(_make_option_button(entry))
	_start_print()


func _start_print() -> void:
	if _pending.is_empty():
		return
	_timer.start(print_interval)
	_print_step()


func _print_step() -> void:
	if _print_index >= _pending.size():
		_timer.stop()
		return
	var entry: Dictionary = _pending[_print_index]
	_print_index += 1
	_add_line(String(entry.get("text", "")), String(entry.get("tone", "data")))
	_snap_scroll()
	if _print_index >= _pending.size():
		_timer.stop()


func _reveal_all() -> void:
	if _print_index >= _pending.size():
		return
	_timer.stop()
	while _print_index < _pending.size():
		var entry: Dictionary = _pending[_print_index]
		_print_index += 1
		_add_line(String(entry.get("text", "")), String(entry.get("tone", "data")))
	_snap_scroll()


func _add_line(value: String, tone: String) -> void:
	if tone == "rule":
		var divider := ColorRect.new()
		divider.color = TONES["rule"]
		divider.custom_minimum_size = Vector2(0.0, 1.0)
		divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
		print_box.add_child(divider)
		return
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", Brand.SIZE_BODY)
	label.modulate = TONES.get(tone, TONES["data"])
	label.text = ("SHIPMIND:  " + value) if tone == "shipmind" else value
	print_box.add_child(label)


func _make_option_button(entry: Dictionary) -> Button:
	var hint: String = String(entry.get("hint", ""))
	var button := Button.new()
	button.text = String(entry.get("label", "...")) + ("\n" + hint if hint != "" else "")
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.focus_mode = Control.FOCUS_ALL
	## A floor only: the button grows to whatever its own two lines need, so a
	## long hint wraps rather than being cropped. The floor is raised on a
	## touchscreen because a fingertip needs about 44 px and the same sentence
	## does not get any shorter on a phone.
	var floor_height: float = 52.0 if hint == "" else 64.0
	if not touch_mode():
		floor_height = 38.0 if hint == "" else 52.0
	button.custom_minimum_size = Vector2(0.0, floor_height)
	button.add_theme_font_size_override("font_size", Brand.SIZE_LABEL)
	var tone: String = String(entry.get("tone", "normal"))
	match tone:
		"primary":
			button.modulate = Color(1.0, 0.88, 0.6)
		"danger":
			button.modulate = Color(0.98, 0.55, 0.42)
		"quiet":
			button.modulate = Color(0.76, 0.68, 0.62)
		_:
			button.modulate = Color(0.92, 0.88, 0.84)
	button.pressed.connect(func() -> void: _on_option_pressed(String(entry.get("id", ""))))
	return button


# --- The autonomy spectrum block -----------------------------------------------


## Draws the placement control: what the decision weighs, the four levels, the
## guardrails and one commit button. Two ButtonGroups, not one - a level and a
## guardrail are two different choices, and sharing a group would make picking a
## guardrail clear the level.
func _draw_spectrum(block: Dictionary) -> void:
	var level_group := ButtonGroup.new()
	level_group.allow_unpress = false
	var guardrail_group := ButtonGroup.new()
	guardrail_group.allow_unpress = false
	var owner_group := ButtonGroup.new()
	owner_group.allow_unpress = false

	_spectrum_box.add_child(_spectrum_title(String(block.get("title", "PLACE THE DECISION"))))
	var note: String = String(block.get("note", ""))
	if note != "":
		_spectrum_box.add_child(_note_label(note, Brand.NEUTRAL))
	_spectrum_box.add_child(_tag_row(block))
	var tag_note: String = String(block.get("tag_note", ""))
	if tag_note != "":
		_spectrum_box.add_child(_note_label(tag_note, Brand.NEUTRAL))
	_spectrum_box.add_child(_gap(6))

	var levels: Array = block.get("levels", [])
	for entry in levels:
		var level: Dictionary = entry
		## Which levels need an owner is the block's own statement, and the
		## default is the strict one: a level that does not say gets asked for an
		## owner rather than being let through.
		_levels_require_owner[String(level.get("id", ""))] = bool(level.get("requires_owner", true))
		var button: Button = BrandTokens.choice_button(
			level_group, String(level.get("label", "")), String(level.get("hint", "")))
		button.pressed.connect(_on_level_pressed.bind(String(level.get("id", ""))))
		_spectrum_box.add_child(button)

	var guardrail_title: String = String(block.get("guardrail_title", ""))
	if guardrail_title != "":
		_spectrum_box.add_child(_gap(6))
		_spectrum_box.add_child(_note_label(guardrail_title, Brand.ACCENT_TINT))

	var guardrails: Array = block.get("guardrails", [])
	for entry in guardrails:
		var guardrail: Dictionary = entry
		var button: Button = BrandTokens.choice_button(
			guardrail_group,
			String(guardrail.get("label", "")),
			String(guardrail.get("hint", "")),
			String(guardrail.get("cost", "")))
		button.pressed.connect(_on_guardrail_pressed.bind(String(guardrail.get("id", ""))))
		_spectrum_box.add_child(button)

	## The accountability step. It comes after the guardrail because it is the
	## last thing a placement has to answer for: who owns the outcome.
	var owner_title: String = String(block.get("owner_title", ""))
	if owner_title != "":
		_spectrum_box.add_child(_gap(6))
		_spectrum_box.add_child(_note_label(owner_title, Brand.ACCENT_TINT))
	var owner_note: String = String(block.get("owner_note", ""))
	if owner_note != "":
		_spectrum_box.add_child(_note_label(owner_note, Brand.NEUTRAL))
	_owner_requirement = _note_label("", Brand.NEUTRAL_LIGHT)
	_spectrum_box.add_child(_owner_requirement)
	var owners: Array = block.get("owners", [])
	for entry in owners:
		var owner_role: Dictionary = entry
		var owner_button: Button = BrandTokens.choice_button(
			owner_group,
			String(owner_role.get("label", "")),
			String(owner_role.get("hint", "")))
		owner_button.pressed.connect(_on_owner_pressed.bind(String(owner_role.get("id", ""))))
		_spectrum_box.add_child(owner_button)
	_refresh_owner_requirement()

	_spectrum_box.add_child(_gap(6))
	_commit = Button.new()
	_commit.name = "Commit"
	_commit.text = String(block.get("submit_label", "COMMIT THE PLACEMENT"))
	_commit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	## Taller on a touch device: this is the one button the decision cannot be
	## finished without, so it is the worst place to make a fingertip guess.
	_commit.custom_minimum_size = Vector2(0.0, 58.0 if touch_mode() else 42.0)
	_commit.add_theme_font_size_override("font_size", Brand.SIZE_DATA)
	_commit.add_theme_color_override("font_color", Brand.SURFACE)
	_commit.add_theme_color_override("font_hover_color", Brand.SURFACE)
	_commit.add_theme_color_override("font_pressed_color", Brand.SURFACE)
	_commit.add_theme_color_override("font_disabled_color", Brand.NEUTRAL)
	_commit.add_theme_stylebox_override("normal", _commit_fill(Brand.ACCENT))
	_commit.add_theme_stylebox_override("hover", _commit_fill(Brand.ACCENT_TINT))
	_commit.add_theme_stylebox_override("pressed", _commit_fill(Brand.ACCENT_TINT))
	_commit.add_theme_stylebox_override("focus", _ring())
	_commit.add_theme_stylebox_override("disabled", _commit_fill(Brand.SURFACE_RAISED))
	_commit.disabled = true
	_commit.pressed.connect(_on_commit_pressed)
	_spectrum_box.add_child(_commit)


func _on_level_pressed(level_id: String) -> void:
	_level_choice = level_id
	_refresh_owner_requirement()
	_refresh_commit()


func _on_guardrail_pressed(guardrail_id: String) -> void:
	_guardrail_choice = guardrail_id
	_refresh_commit()


func _on_owner_pressed(owner_id: String) -> void:
	_owner_choice = owner_id
	_refresh_commit()


## True when a placement at this level has to name a role that owns it.
## Everything above human-only does; the block says so per level.
func requires_owner(level_id: String) -> bool:
	if _levels_require_owner.is_empty():
		return false
	return bool(_levels_require_owner.get(level_id, true))


## The commit stays closed until the decision is complete. A placement is a
## level, a guardrail and - above human-only - a named accountable owner, so
## anything less than all of it is not something to record.
func _refresh_commit() -> void:
	if _commit == null:
		return
	if _level_choice == "" or _guardrail_choice == "":
		_commit.disabled = true
		return
	_commit.disabled = requires_owner(_level_choice) and _owner_choice == ""


## The requirement, in the words the current level calls for. It is written to be
## read before the commit: the rule is legible on the screen rather than
## discovered when the commit refuses.
func _refresh_owner_requirement() -> void:
	if _owner_requirement == null or not is_instance_valid(_owner_requirement):
		return
	if _level_choice == "":
		_owner_requirement.text = "Choose a level. Every level above human-only has to name the owner; human-only does not."
		return
	if requires_owner(_level_choice):
		_owner_requirement.text = "A NAMED OWNER IS REQUIRED at this level. Pick the role that answers for the outcome."
	else:
		_owner_requirement.text = "HUMAN-ONLY: the accountable owner is the operator at the console. No separate role is recorded."


func _on_commit_pressed() -> void:
	if _level_choice == "" or _guardrail_choice == "":
		return
	var level_id: String = _level_choice
	var guardrail_id: String = _guardrail_choice
	var owner_id: String = ""
	if requires_owner(level_id):
		owner_id = _owner_choice
		if owner_id == "":
			return
	placement_chosen.emit(level_id, guardrail_id, owner_id)
	if _puzzle != null and is_instance_valid(_puzzle):
		_puzzle.place(level_id, guardrail_id, owner_id)


func _spectrum_title(text: String) -> Label:
	var label := Label.new()
	label.name = "SpectrumTitle"
	label.text = text
	label.add_theme_font_size_override("font_size", Brand.SIZE_TITLE)
	label.add_theme_color_override("font_color", Brand.INK)
	return label


func _note_label(text: String, tint: Color) -> Label:
	var label := Label.new()
	label.name = "Note"
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", Brand.SIZE_SMALL)
	label.add_theme_color_override("font_color", tint)
	return label


func _tag_label(text: String, tint: Color) -> Label:
	var label := Label.new()
	label.name = "Tag"
	label.text = text
	label.add_theme_font_size_override("font_size", Brand.SIZE_SMALL)
	label.add_theme_color_override("font_color", tint)
	return label


## The decision's own weight, on the screen it is decided on. A tag the player
## cannot read before placing is not an input to the placement.
func _tag_row(block: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "TagRow"
	row.add_theme_constant_override("separation", 16)
	var consequence: String = String(block.get("consequence", ""))
	var reversibility: String = String(block.get("reversibility", ""))
	if consequence != "":
		row.add_child(_tag_label("CONSEQUENCE   %s" % consequence, Brand.ACCENT))
	if reversibility != "":
		row.add_child(_tag_label("REVERSIBILITY   %s" % reversibility, Brand.NEUTRAL_LIGHT))
	return row


func _commit_fill(background: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = background
	box.set_corner_radius_all(3)
	return box


func _ring() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	box.border_color = Brand.ACCENT
	box.set_border_width_all(2)
	box.set_corner_radius_all(3)
	return box


func _gap(height: float) -> Control:
	var spacer := Control.new()
	spacer.name = "Gap"
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.custom_minimum_size = Vector2(0.0, height)
	return spacer


func _on_option_pressed(option_id: String) -> void:
	if option_id == "close":
		close()
		return
	option_chosen.emit(option_id)
	if _puzzle != null and is_instance_valid(_puzzle):
		_puzzle.choose(option_id)


## Reveals the readout on a click or a tap. Both are needed: a touchscreen never
## sends an InputEventMouseButton at all, so the click-only version of this left
## a phone unable to skip the typewriter and read the screen.
func _on_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_reveal_all()
	elif event is InputEventScreenTouch and event.pressed:
		_reveal_all()


func _unhandled_input(event: InputEvent) -> void:
	if not root.visible:
		return
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		_reveal_all()
		return
	## A touch that nothing else consumed also reveals the readout, so the whole
	## screen is a skip target and not only the dimmed border. The option buttons
	## and the CLOSE button are Controls and take their own taps first, so this
	## never fires from a press that was meant for one of them.
	if event is InputEventScreenTouch and event.pressed:
		_reveal_all()


## Keeps the newest printed line in view, by moving the bar by hand.
##
## ScrollContainer has no scroll_to_bottom() in this engine build, and calling
## it crashed the terminal on the first printed line of every screen - the whole
## game died the moment a console was pressed. The bar is therefore set from its
## own maximum, and only AFTER a frame, because that maximum is not updated
## until the new line has been laid out: reading it in the same frame as the
## line is added scrolls to where the bar used to end.
##
## A screen whose content is shorter than the viewport has nothing to scroll,
## so its maximum is zero and this leaves it where it is.
func _snap_scroll() -> void:
	await get_tree().process_frame
	if is_inside_tree() and is_instance_valid(scroll):
		scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)


func _clear(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
