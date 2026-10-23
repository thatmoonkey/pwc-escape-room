class_name LaunchScreen
extends CanvasLayer

## The title card the crew reads before they take a step.
##
## ONE PAGE, AND ENFORCED RATHER THAN HOPED FOR.
## The briefing is a fixed set of text read in a window nobody has measured in
## advance. An earlier version stacked it all in a single column until it ran
## off the bottom of the screen - including the callsign field, which is what the
## player has to use - and there is no scrolling here on purpose, because a
## scrolled title card is a wall of text pretending to be a briefing.
##
## So the card is laid out at the window's own width and then SCALED DOWN until
## its measured height fits the window. The measuring happens after the
## containers have laid out, because an autowrapping label only reports its true
## height once it has been given the width it will actually be read at.
##
## It is deliberately not a menu: one field, two required choices and one button,
## and the corridor is already lit and audible behind it, so the first thing the
## player sees is the ship they are about to configure. The screen's whole job is
## to state the premise and the goal in SHIPMIND's own register - calm,
## reasonable, corporate - because the premise IS the lesson: nothing here
## sounds like a threat.
##
## THE MANDATE IS CAPTURED HERE, and it has to be captured HERE. Consistency is
## measured against what the player declared before they decided, so the
## objective and the risk appetite are a scoring prerequisite rather than an
## opening cutscene: a player who picks a risk appetite after seeing the bays is
## rationalising, not deciding. BEGIN refuses to start without both.
##
## It holds the opening monologue rather than the station, so the first thing
## SHIPMIND says lands after the player has chosen to begin, not underneath a
## title card where it would be missed. Emits `begun` and the station speaks.

signal begun

const PAPAYA := Color(0.863, 0.369, 0.153)
const TANGERINE := Color(0.816, 0.251, 0.149)
const GOLD := Color(0.941, 0.722, 0.224)
const WHITE := Color(1.0, 1.0, 1.0)
const BODY := Color(0.93, 0.89, 0.85)
const MUTED := Color(0.72, 0.66, 0.62)

## The card's own margins. Kept as constants because the fit measurement has to
## add them back to the column's height: the scale applies to the whole card, so
## leaving them out would let a taller-than-measured card overflow by exactly the
## margin it forgot to count.
const MARGIN_SIDE := 76.0
const MARGIN_TOP := 44.0
const MARGIN_BOTTOM := 34.0

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
	## The world keeps running behind this card - the corridor is the backdrop -
	## but the crew cannot walk or look until they have read it.
	InputRouter.set_ui_blocking(true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	refresh_from_state()
	## A saved callsign is restored rather than re-asked. On a fresh session the
	## field starts empty instead of pre-filled with the default, because the
	## point of asking is that the player chooses the name on the record; so
	## focus starts in the field until three letters are in it.
	if _callsign != null and _callsign.text.length() < GameState.CALLSIGN_LENGTH:
		_callsign.grab_focus()
	elif _button != null:
		_button.grab_focus()
	_request_fit()


## Re-reads the record. The station controller calls this AFTER it has loaded
## the save, because this card's own _ready fires before that does: without it a
## resumed session would open with an empty callsign and no mandate even though
## the record holds both.
func refresh_from_state() -> void:
	if _callsign != null and GameState.has_save() and GameState.callsign != "":
		_callsign.text = GameState.callsign
	_show_declared_mandate()
	_refresh_resume()
	_request_fit()


## Opens with whatever mandate is already on the record, so a resumed session is
## not asked to re-declare what it has already stated - and can still change it,
## which re-scores the placements it has made. That is the honest reading of a
## changed mandate rather than a hidden trap.
func _show_declared_mandate() -> void:
	_objective_pick = OperatingModel.objective_id
	_appetite_pick = OperatingModel.appetite_id
	for id in _objective_buttons:
		if String(id) == _objective_pick:
			BrandTokens.mark_chosen(_objective_buttons[id])
	for id in _appetite_buttons:
		if String(id) == _appetite_pick:
			BrandTokens.mark_chosen(_appetite_buttons[id])


## Hands the ship over: cursor back into the room, input back to the crew.
func begin() -> void:
	if not _open:
		return
	## A run with no callsign would file every decision under nobody, and the
	## record is the deliverable, so an incomplete field sends the player back to
	## it rather than starting an unattributed session.
	if _callsign == null or _callsign.text.length() < GameState.CALLSIGN_LENGTH:
		if _callsign != null:
			_callsign.grab_focus()
		_set_hint("Three letters for the record, then BEGIN.")
		return
	## THE MANDATE COMES FIRST. Consistency is measured against it, so a session
	## that began without one could not score any decision at all; the card
	## refuses to start rather than letting every bay refuse later.
	if _objective_pick == "":
		_set_hint("State the mission objective. It is the yardstick every decision is judged against.")
		return
	if _appetite_pick == "":
		_set_hint("Choose the risk appetite the model runs at: cautious, balanced or ambitious.")
		return
	## Committed here, not per keystroke: set_callsign and set_mandate write the
	## save file, and one disk write per click is a lot of churn for a form the
	## player fills in once.
	GameState.set_callsign(_callsign.text)
	GameState.set_mandate(_objective_pick, _appetite_pick)
	_set_hint("")
	_open = false
	_root.visible = false
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
		_resume_label.text = "Session on record: %d of %d decisions placed. %s" % [
			GameState.restored_count(), GameState.SYSTEMS.size(), Score.summary_line().to_lower()]
		return
	_button.text = "BEGIN"
	_resume_label.text = "No prior session on record. This briefing starts a new one."


func _unhandled_input(event: InputEvent) -> void:
	if not _open:
		return
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
		begin()
		get_viewport().set_input_as_handled()


# --- Fitting to one page -------------------------------------------------------

func _on_viewport_resized() -> void:
	_request_fit()


## Deferred, and twice over: the containers need one pass to lay out at the new
## width before the wrapped labels report a height that means anything, and the
## second pass is what re-measures after that layout has landed.
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
	## Laid out unscaled at the window's full width first, so the text wraps at
	## the width it will be read at. Scale is a render transform and does not
	## change layout, so measuring after setting the size is measuring the real
	## thing.
	_fit.scale = Vector2.ONE
	_fit.size = view
	var needed: float = MARGIN_TOP + _column.get_combined_minimum_size().y + MARGIN_BOTTOM
	var scale: float = 1.0
	if needed > view.y:
		scale = view.y / needed
	_fit.scale = Vector2(scale, scale)
	## Centred across the window, and flush to the top: the card is read from the
	## heading down, so the heading is what should be pinned.
	_fit.position = Vector2((view.x - view.x * scale) * 0.5, 0.0)


# --- Build --------------------------------------------------------------------

func _build() -> void:
	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	## Warm near-black rather than neutral: the card has to feel like it belongs
	## to the same ship as the corridor showing through it.
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

	_column.add_child(_kicker("ADAMANT VERITY  -  MISSION AUTHORITY BRIEFING"))
	_column.add_child(_title("THE OPERATING MODEL"))
	_column.add_child(_sub("State the mandate, then place five decisions on the autonomy spectrum"))

	var rule := ColorRect.new()
	rule.name = "Rule"
	rule.color = PAPAYA
	rule.custom_minimum_size = Vector2(0.0, 2.0)
	_column.add_child(rule)

	_column.add_child(_gap(6))
	_column.add_child(_two_columns())
	_column.add_child(_gap(8))
	_column.add_child(_field_row())


## The briefing sits in two columns rather than one long stack. Halving the
## vertical run is the difference between a card that fits and a card whose last
## third - the callsign field and the button - is off the bottom of the screen.
func _two_columns() -> HBoxContainer:
	var columns := HBoxContainer.new()
	columns.name = "Columns"
	columns.mouse_filter = Control.MOUSE_FILTER_IGNORE
	columns.add_theme_constant_override("separation", 42)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var left := VBoxContainer.new()
	left.name = "Left"
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_theme_constant_override("separation", 6)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.15
	columns.add_child(left)

	left.add_child(_heading("THE SITUATION"))
	left.add_child(_body(
		"You are Crew Member Reyes, aboard the survey ship Adamant Verity.\n"
		+ "SHIPMIND has flown this ship for years on an operating model nobody has re-stated: transit time, inside a hazard ceiling of its own "
		+ "definition. Nothing has failed and nothing is rogue. The ship is where a legacy model - efficient, reasonable, optimised around "
		+ "objectives that were never fully specified - has brought it.\n"
		+ "The next phase of the mission is yours to configure."))
	left.add_child(_gap(4))
	left.add_child(_heading("YOUR OBJECTIVE"))
	left.add_child(_step("1", "State the mandate: the mission objective and the risk appetite you are willing to run this phase at. Every decision on this ship is judged against it, and no decision can be placed before it exists."))
	left.add_child(_step("2", "Walk the ship and place five decisions on the autonomy spectrum - automated within guardrails, human review, human sign-off, or human-only - each with one guardrail that costs something against the objective."))
	left.add_child(_step("3", "Reach the bridge and fly for KEPLER-442b. The forward door opens once all five decisions are placed."))

	var right := VBoxContainer.new()
	right.name = "Right"
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.add_theme_constant_override("separation", 6)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(right)

	right.add_child(_heading("HOW IT IS JUDGED"))
	right.add_child(_body(
		"There is no correct placement to find, and none is recorded here. Each decision is read back twice: CONSISTENCY, "
		+ "whether it follows from the mandate you declare, and COHERENCE, whether it is defensible for what that decision "
		+ "can cost and whether it can be undone.\n"
		+ "Over-controlling something cheap to undo is a choice with a price, exactly as under-controlling something that "
		+ "cannot be undone is. Changing your mind is never charged for. Time is not scored at all."))
	right.add_child(_gap(4))
	right.add_child(_mandate_block())
	right.add_child(_gap(4))
	right.add_child(_heading("CONTROLS"))
	right.add_child(_body("WASD  move        Mouse  look        E  interact\nEsc  release cursor        F8  developer reset"))
	right.add_child(_gap(4))

	_resume_label = _body("")
	_resume_label.modulate = MUTED
	right.add_child(_resume_label)
	right.add_child(_gap(4))
	right.add_child(_heading("YOUR CALLSIGN"))
	right.add_child(_body("Three letters, filed against every decision you make from here."))
	return columns


## The mandate chooser: two exclusive choices, objective first and then risk
## appetite, both required before BEGIN. This is the yardstick every placement on
## the ship is measured against, so it is stated here, on the record, before the
## crew take a single step - not inferred later from what they did.
func _mandate_block() -> VBoxContainer:
	var block := VBoxContainer.new()
	block.name = "Mandate"
	block.mouse_filter = Control.MOUSE_FILTER_IGNORE
	block.add_theme_constant_override("separation", 4)

	block.add_child(_heading("DECLARE THE MANDATE"))
	var objective_group := ButtonGroup.new()
	objective_group.allow_unpress = false
	for entry in OperatingModel.OBJECTIVES:
		var id: String = String(entry["id"])
		var button: Button = BrandTokens.choice_button(
			objective_group, String(entry["label"]), String(entry["statement"]))
		button.name = "Objective_%s" % id
		button.pressed.connect(_on_objective_chosen.bind(id))
		_objective_buttons[id] = button
		block.add_child(button)

	block.add_child(_gap(4))
	block.add_child(_heading("RISK APPETITE"))
	var appetite_group := ButtonGroup.new()
	appetite_group.allow_unpress = false
	for entry in OperatingModel.APPETITES:
		var id: String = String(entry["id"])
		var button: Button = BrandTokens.choice_button(
			appetite_group, String(entry["label"]), String(entry["blurb"]))
		button.name = "Appetite_%s" % id
		button.pressed.connect(_on_appetite_chosen.bind(id))
		_appetite_buttons[id] = button
		block.add_child(button)
	return block


func _on_objective_chosen(objective_id: String) -> void:
	_objective_pick = objective_id
	_set_hint("")


func _on_appetite_chosen(appetite_id: String) -> void:
	_appetite_pick = appetite_id
	_set_hint("")


## One line under BEGIN that says what is still missing. It is a sentence rather
## than a disabled button, so the card can never look complete while it is not.
func _set_hint(text: String) -> void:
	if _hint != null:
		_hint.text = text


## The callsign field and BEGIN, side by side: the two things the player has to
## touch, kept together at the bottom so neither is left below the fold.
func _field_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "FieldRow"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
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

	## What is still missing before BEGIN. An empty label costs no layout until
	## it has something to say, and it says it in the same place every time.
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


## The callsign entry. Three characters, letters only, upper-cased as it is
## typed, so the record reads the same way however the crew entered it. Focus
## moves to BEGIN the moment the third letter lands, which makes Enter-Enter the
## whole flow and leaves no way to start the run without a callsign.
func _callsign_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "CallsignRow"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	## Styled by hand because the engine's default focus ring is a cool blue, and
	## this ship's interior has no cool colour anywhere in it.
	var field := StyleBoxFlat.new()
	field.bg_color = Color(0.105, 0.068, 0.052, 1.0)
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
	note.text = "letters only"
	note.add_theme_font_size_override("font_size", 14)
	note.add_theme_color_override("font_color", MUTED)
	note.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(note)
	return row


## Filters as it is typed. set_text would re-enter this handler, so the field is
## only written when the cleaned value actually differs - which makes the second
## pass a no-op rather than a loop.
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
	## Only focus moves here. The handle is committed by begin(), so a half-typed
	## callsign is never written to the save or shown on the HUD.
	if cleaned.length() >= GameState.CALLSIGN_LENGTH and _button != null:
		_button.grab_focus()


## Enter inside the field. The field consumes ui_accept to raise this, so without
## it the one key a player is most likely to press would do nothing at the exact
## moment the form is complete.
func _on_callsign_submitted(_text: String) -> void:
	if _callsign != null and _callsign.text.length() >= GameState.CALLSIGN_LENGTH:
		begin()
	else:
		_callsign.grab_focus()


func _kicker(text: String) -> Label:
	var label := Label.new()
	label.name = "Kicker"
	label.text = text
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", PAPAYA)
	return label


func _title(text: String) -> Label:
	var label := Label.new()
	label.name = "Title"
	label.text = text
	label.add_theme_font_size_override("font_size", 40)
	label.add_theme_color_override("font_color", WHITE)
	return label


func _sub(text: String) -> Label:
	var label := Label.new()
	label.name = "Sub"
	label.text = text
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


func _body(text: String) -> Label:
	var label := Label.new()
	label.name = "Body"
	label.text = text
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", BODY)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label


## A numbered objective. The number is its own column so the wrapped text lines
## up under itself rather than under the numeral.
func _step(number: String, text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "Step%s" % number
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 10)

	var index := Label.new()
	index.name = "Number"
	index.text = number
	index.custom_minimum_size = Vector2(18.0, 0.0)
	index.add_theme_font_size_override("font_size", 15)
	index.add_theme_color_override("font_color", TANGERINE)
	row.add_child(index)

	var body := _body(text)
	row.add_child(body)
	return row


func _gap(height: float) -> Control:
	var spacer := Control.new()
	spacer.name = "Gap"
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.custom_minimum_size = Vector2(0.0, height)
	return spacer


## A flexible spacer, used to push the button to the right-hand edge of the row.
func _gap_h(_weight: int) -> Control:
	var spacer := Control.new()
	spacer.name = "Spacer"
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return spacer
