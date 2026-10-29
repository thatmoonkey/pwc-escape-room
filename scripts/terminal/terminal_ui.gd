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
@onready var panel: PanelContainer = $Root/Panel
@onready var title_label: Label = $Root/Panel/VBox/Header/TitleLabel
@onready var status_label: Label = $Root/Panel/VBox/Header/StatusLabel
@onready var rule_bar: ColorRect = $Root/Panel/VBox/Rule
@onready var vbox: VBoxContainer = $Root/Panel/VBox
@onready var scroll: ScrollContainer = $Root/Panel/VBox/Columns/Readout/Scroll
@onready var print_box: VBoxContainer = $Root/Panel/VBox/Columns/Readout/Scroll/Print
@onready var options_box: VBoxContainer = $Root/Panel/VBox/Columns/Decision/Options
@onready var decision_scroll: ScrollContainer = $Root/Panel/VBox/Columns/Decision/DecisionScroll
@onready var _decision_box: VBoxContainer = $Root/Panel/VBox/Columns/Decision
@onready var _columns: VBoxContainer = $Root/Panel/VBox/Columns
@onready var _readout_box: VBoxContainer = $Root/Panel/VBox/Columns/Readout
@onready var readout_title: Label = $Root/Panel/VBox/Columns/Readout/ReadoutTitle
@onready var decision_title: Label = $Root/Panel/VBox/Columns/Decision/DecisionTitle
@onready var _columns_rule: ColorRect = $Root/Panel/VBox/Columns/ColumnsRule
## The placement control's host, which owns its own scroller. The decision panel
## is the lower half of the screen, because the four levels, three guardrails
## and three owner roles are a lot of reading; giving it a scroll of its own is
## what keeps the option buttons pinned and visible while it happens. On a
## screen with no placement to make the scroller is empty, so it is hidden and
## collapses to its option buttons, everything packing at the top of the panel
## with the leftover space falling in below.
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
## The readout's lines, laid out at render time and revealed one per tick by
## the typewriter. Built complete and hidden (see _make_line) so the console's
## height is the printout's final height from the first frame: nothing moves
## under the player's hand while it types.
var _line_controls: Array[Control] = []
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
## The CLOSE button, kept so the fit pass can re-scale it when the window
## changes size after it was built.
var _close_button: Button = null
## The last state handed to _render, kept so a window resize can redraw the
## screen at the new scale without the puzzle knowing anything about windows.
var _last_state: ScreenState = null

## Fit scaling. See _apply_fit: the base canvas this screen is authored for.
const BASE_HEIGHT := 648.0
## The cap on the fit factor. The canvas grows in height only: the width stays
## at the base 1152 in every portrait window, so the type can grow only as far
## as the panel's fixed width can hold. Past that the header title and the
## choice buttons overflow the panel - the width is the wall the type walks
## into. About 1.6 keeps the longest title and the longest choice line inside
## the panel while still reading one and a half steps larger.
const FIT_CAP := 1.6
## The current scale, recomputed by _apply_fit. Every size the screen spends
## goes through _fs so the whole console grows together.
var _fit: float = 1.0


## A size at the current fit. Whole pixels only: fonts are rasterized per size,
## and a half-pixel button height is not a thing anyone can see.
func _fs(size: float) -> int:
	return maxi(1, roundi(size * _fit))


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
	## Scale the screen to the window it actually gets (see _apply_fit), and
	## keep it scaled when the window changes size under it.
	get_viewport().size_changed.connect(_on_viewport_resized)
	_apply_fit.call_deferred()
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
	button.custom_minimum_size = Vector2(0.0, _fs(50.0 if touch_mode() else 34.0))
	button.add_theme_font_size_override("font_size", _fs(Brand.SIZE_LABEL))
	button.add_theme_color_override("font_color", Brand.ACCENT_TINT)
	button.pressed.connect(close)
	header.add_child(button)
	_close_button = button


## --- Fit scaling ----------------------------------------------------------------


## Scale the screen to the window it is given.
##
## The project stretches with "canvas_items" and "expand" aspect: instead of
## zooming, Godot keeps the base 1152x648 canvas on screen and grows the canvas
## itself in taller windows - a portrait window becomes a canvas of roughly
## 1152x1729 rather than a zoomed 1152x648. Every size in this screen is
## authored in pixels for that base height, so left alone the type stays small
## and the spare height pools as empty panel between the stacked readout and
## the decision. The complaint this screen got. The fit factor is the canvas
## height over the base height, and every size the screen spends goes through
## it: the panel's inset, its inner margins, the separations, the rules, and
## every font. A tall window reads like a large console instead of a stretched
## one, which is also what keeps the stacked blocks from stranding dead space
## between them.
func _apply_fit() -> void:
	_fit = clampf(root.get_viewport_rect().size.y / BASE_HEIGHT, 1.0, FIT_CAP)
	## Structure: the panel's side insets breathe with the window, and so do
	## its inner margins and every separation between the stacked blocks. The
	## panel's height is the refit's business - see _refit_panel.
	panel.offset_left = _fs(44.0)
	panel.offset_right = -_fs(44.0)
	var panel_box := panel.get_theme_stylebox("panel") as StyleBoxFlat
	if panel_box != null:
		panel_box.content_margin_left = _fs(28.0)
		panel_box.content_margin_top = _fs(20.0)
		panel_box.content_margin_right = _fs(28.0)
		panel_box.content_margin_bottom = _fs(18.0)
	vbox.add_theme_constant_override("separation", _fs(10.0))
	header.add_theme_constant_override("separation", _fs(12.0))
	_columns.add_theme_constant_override("separation", _fs(14.0))
	_readout_box.add_theme_constant_override("separation", _fs(6.0))
	print_box.add_theme_constant_override("separation", _fs(6.0))
	_decision_box.add_theme_constant_override("separation", _fs(8.0))
	_spectrum_box.add_theme_constant_override("separation", _fs(4.0))
	options_box.add_theme_constant_override("separation", _fs(6.0))
	rule_bar.custom_minimum_size = Vector2(0.0, _fs(2.0))
	_columns_rule.custom_minimum_size = Vector2(0.0, _fs(1.0))
	## Type on the standing nodes. Content drawn afterwards picks the scale up
	## at creation time, through _fs at each draw site.
	title_label.add_theme_font_size_override("font_size", _fs(Brand.SIZE_TITLE))
	status_label.add_theme_font_size_override("font_size", _fs(Brand.SIZE_DATA))
	readout_title.add_theme_font_size_override("font_size", _fs(Brand.SIZE_KICKER))
	decision_title.add_theme_font_size_override("font_size", _fs(Brand.SIZE_KICKER))
	footer.add_theme_font_size_override("font_size", _fs(Brand.SIZE_FOOTER))
	if _close_button != null:
		_close_button.add_theme_font_size_override("font_size", _fs(Brand.SIZE_LABEL))
		_close_button.custom_minimum_size = Vector2(0.0, _fs(50.0 if touch_mode() else 34.0))


## --- The panel's height ---------------------------------------------------------


## The console hugs its content.
##
## The panel used to span the full window height, and in the tall portrait
## windows this game is played in that meant the spare space pooled inside it -
## a dead band between the printout and the decision, on every screen that did
## not fill the panel. The fix is to size the sheet to what the screen actually
## prints: each scroller reports its content's own height, the panel's height
## becomes the sum of everything, and the sheet sits centred over the dim, a
## console of exactly the size of its record. Only when that sum will not fit
## the window does a scroller give height back and scroll instead - the
## decision block first, because it owns a scroll of its own for exactly this,
## then the readout down to a floor that keeps the newest lines readable.
var _refit_pending: bool = false


func _request_refit() -> void:
	if _refit_pending:
		return
	_refit_pending = true
	_refit_panel.call_deferred()


func _refit_panel() -> void:
	_refit_pending = false
	if not is_inside_tree():
		return
	## Both scrollers ask their content how tall it is. An autowrap label only
	## knows its wrapped height once it has been laid out at a real width - the
	## engine reports one bare line before that - so this pass waits out two
	## sort cycles first and reads the true printout height. Sorting is also
	## why the terminal is visible-but-transparent rather than hidden: hidden
	## containers never sort, and a readout measured at width 1 puts every
	## word on its own line.
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_inside_tree():
		return
	scroll.custom_minimum_size = Vector2(0.0, print_box.get_combined_minimum_size().y)
	decision_scroll.custom_minimum_size = Vector2(0.0, _spectrum_box.get_combined_minimum_size().y)
	var avail: float = root.size.y - _fs(24.0) - _fs(20.0)
	var over: float = panel.get_combined_minimum_size().y - avail
	if over > 0.0:
		var give: float = minf(over, maxf(0.0, decision_scroll.custom_minimum_size.y - _fs(360.0)))
		decision_scroll.custom_minimum_size.y -= give
		over -= give
		give = minf(over, maxf(0.0, scroll.custom_minimum_size.y - _fs(160.0)))
		scroll.custom_minimum_size.y -= give
	var height: float = panel.get_combined_minimum_size().y
	panel.offset_top = -height * 0.5
	panel.offset_bottom = height * 0.5
	## Measured and sized: the console is allowed on screen.
	root.modulate = Color(1.0, 1.0, 1.0, 1.0)


## A window resize redraws the screen at the new scale. The puzzle is not asked:
## it describes screens, not windows, and _render already knows how to draw the
## last state it was handed.
func _on_viewport_resized() -> void:
	_apply_fit()
	if root.visible and _last_state != null:
		_render(_last_state)


func is_open() -> bool:
	return root.visible


func open(puzzle: Puzzle) -> void:
	if puzzle == null or _puzzle != null:
		return
	_puzzle = puzzle
	if not puzzle.state_changed.is_connected(_render):
		puzzle.state_changed.connect(_render)
	## Visible from the first frame but transparent: containers only sort a
	## subtree that is in the visible tree (a hidden one keeps every stale
	## size), and the refit has to measure the printout's wrapped heights
	## before the sheet can be given its size. Transparency does the same job
	## as visibility without showing a half-measured console.
	root.visible = true
	root.modulate = Color(1.0, 1.0, 1.0, 0.0)
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
	_last_state = state
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
	_line_controls.clear()
	_print_index = 0
	if state.has_spectrum():
		decision_scroll.visible = true
		_draw_spectrum(state.spectrum)
	else:
		decision_scroll.visible = false
	for entry in state.options:
		options_box.add_child(_make_option_button(entry))
	for entry in state.lines:
		_line_controls.append(_make_line(String(entry.get("text", "")), String(entry.get("tone", "data"))))
	_start_print()
	_request_refit()


func _start_print() -> void:
	if _line_controls.is_empty():
		return
	_timer.start(print_interval)
	_print_step()


func _print_step() -> void:
	if _print_index >= _line_controls.size():
		_timer.stop()
		return
	_line_controls[_print_index].modulate.a = 1.0
	_print_index += 1
	_snap_scroll()
	if _print_index >= _line_controls.size():
		_timer.stop()


func _reveal_all() -> void:
	if _print_index >= _line_controls.size():
		return
	_timer.stop()
	while _print_index < _line_controls.size():
		_line_controls[_print_index].modulate.a = 1.0
		_print_index += 1
	_snap_scroll()


## Builds one readout line without showing it. Every line of the screen is
## laid out at render time and the typewriter only lifts them into view one
## per tick: the console's height is the printout's final height from the
## first frame, so the option buttons and the footer never shift under the
## player's hand while it types.
func _make_line(value: String, tone: String) -> Control:
	if tone == "rule":
		var divider := ColorRect.new()
		divider.color = TONES["rule"]
		divider.custom_minimum_size = Vector2(0.0, _fs(1.0))
		divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
		divider.modulate = Color(1.0, 1.0, 1.0, 0.0)
		print_box.add_child(divider)
		return divider
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", _fs(Brand.SIZE_BODY))
	var tint: Color = TONES.get(tone, TONES["data"])
	label.modulate = Color(tint.r, tint.g, tint.b, 0.0)
	label.text = ("SHIPMIND:  " + value) if tone == "shipmind" else value
	print_box.add_child(label)
	return label


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
	var floor_height: float = _fs(52.0 if hint == "" else 64.0)
	if not touch_mode():
		floor_height = _fs(38.0 if hint == "" else 52.0)
	button.custom_minimum_size = Vector2(0.0, floor_height)
	button.add_theme_font_size_override("font_size", _fs(Brand.SIZE_DATA))
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
	_spectrum_box.add_child(_gap(_fs(6.0)))

	var levels: Array = block.get("levels", [])
	for entry in levels:
		var level: Dictionary = entry
		## Which levels need an owner is the block's own statement, and the
		## default is the strict one: a level that does not say gets asked for an
		## owner rather than being let through.
		_levels_require_owner[String(level.get("id", ""))] = bool(level.get("requires_owner", true))
		var button: Button = _fit_choice_button(BrandTokens.choice_button(
			level_group, String(level.get("label", "")), String(level.get("hint", ""))))
		button.pressed.connect(_on_level_pressed.bind(String(level.get("id", ""))))
		_spectrum_box.add_child(button)

	var guardrail_title: String = String(block.get("guardrail_title", ""))
	if guardrail_title != "":
		_spectrum_box.add_child(_gap(_fs(6.0)))
		_spectrum_box.add_child(_note_label(guardrail_title, Brand.ACCENT_TINT))

	var guardrails: Array = block.get("guardrails", [])
	for entry in guardrails:
		var guardrail: Dictionary = entry
		var button: Button = _fit_choice_button(BrandTokens.choice_button(
			guardrail_group,
			String(guardrail.get("label", "")),
			String(guardrail.get("hint", "")),
			String(guardrail.get("cost", ""))))
		button.pressed.connect(_on_guardrail_pressed.bind(String(guardrail.get("id", ""))))
		_spectrum_box.add_child(button)

	## The accountability step. It comes after the guardrail because it is the
	## last thing a placement has to answer for: who owns the outcome.
	var owner_title: String = String(block.get("owner_title", ""))
	if owner_title != "":
		_spectrum_box.add_child(_gap(_fs(6.0)))
		_spectrum_box.add_child(_note_label(owner_title, Brand.ACCENT_TINT))
	var owner_note: String = String(block.get("owner_note", ""))
	if owner_note != "":
		_spectrum_box.add_child(_note_label(owner_note, Brand.NEUTRAL))
	_owner_requirement = _note_label("", Brand.NEUTRAL_LIGHT)
	_spectrum_box.add_child(_owner_requirement)
	var owners: Array = block.get("owners", [])
	for entry in owners:
		var owner_role: Dictionary = entry
		var owner_button: Button = _fit_choice_button(BrandTokens.choice_button(
			owner_group,
			String(owner_role.get("label", "")),
			String(owner_role.get("hint", ""))))
		owner_button.pressed.connect(_on_owner_pressed.bind(String(owner_role.get("id", ""))))
		_spectrum_box.add_child(owner_button)
	_refresh_owner_requirement()

	_spectrum_box.add_child(_gap(_fs(6.0)))
	_commit = Button.new()
	_commit.name = "Commit"
	_commit.text = String(block.get("submit_label", "COMMIT THE PLACEMENT"))
	_commit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	## Taller on a touch device: this is the one button the decision cannot be
	## finished without, so it is the worst place to make a fingertip guess.
	_commit.custom_minimum_size = Vector2(0.0, _fs(58.0 if touch_mode() else 42.0))
	_commit.add_theme_font_size_override("font_size", _fs(Brand.SIZE_DATA))
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


## The shared choice widget at this screen's current fit. The token builder is
## the one place the widget is shaped - it owns the heights and the type - and
## the fit is this screen's property, so the scale is re-applied over the
## builder's own sizes instead of the builder growing windows-aware for one
## consumer.
func _fit_choice_button(button: Button) -> Button:
	button.custom_minimum_size = Vector2(0.0, button.custom_minimum_size.y * _fit)
	button.add_theme_font_size_override("font_size", _fs(Brand.SIZE_COMPACT))
	return button


func _spectrum_title(text: String) -> Label:
	var label := Label.new()
	label.name = "SpectrumTitle"
	label.text = text
	label.add_theme_font_size_override("font_size", _fs(Brand.SIZE_TITLE))
	label.add_theme_color_override("font_color", Brand.INK)
	return label


func _note_label(text: String, tint: Color) -> Label:
	var label := Label.new()
	label.name = "Note"
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", _fs(Brand.SIZE_SMALL))
	label.add_theme_color_override("font_color", tint)
	return label


func _tag_label(text: String, tint: Color) -> Label:
	var label := Label.new()
	label.name = "Tag"
	label.text = text
	label.add_theme_font_size_override("font_size", _fs(Brand.SIZE_SMALL))
	label.add_theme_color_override("font_color", tint)
	return label


## The decision's own weight, on the screen it is decided on. A tag the player
## cannot read before placing is not an input to the placement.
func _tag_row(block: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "TagRow"
	row.add_theme_constant_override("separation", _fs(16.0))
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
