class_name RotatePrompt
extends CanvasLayer

## A phone held the wrong way up, before the story starts.
##
## The telling and the ship are both laid out wide. On a phone held tall the
## words column is squeezed into a band it was never drawn for, which is where
## the type collides, so this card comes first and asks for the turn. It steps
## aside by itself the moment the device is wide again, on the same check the
## rest of the interface makes whenever the frame changes size.
##
## THE SHIP IS LANDSCAPE ONLY. There is no way past this card: a phone stays on
## it until it is wide, and it returns the moment the device is turned tall
## again. It is shown only on a touch device: a desktop window that happens to
## be portrait is not a phone, and the launch card's mode chips can force MOBILE
## when the layout is being checked on a desk.

const PAPAYA := Color(0.863, 0.369, 0.153)
const GOLD := Color(0.941, 0.722, 0.224)
const WHITE := Color(1.0, 1.0, 1.0)
const BODY := Color(0.93, 0.89, 0.85)
const GROUND := Color(0.06, 0.032, 0.022)

var _root: Control = null
var _column: VBoxContainer = null
## Watched rather than signalled: the mode layer is a plain static with no
## signals, so this card notices a change the same way the launch card and the
## station controller do - by looking at it once a frame.
var _mode_watch: int = -1


func _ready() -> void:
	layer = 140
	## Ask the OS for landscape as well as holding the card: a phone that honours
	## the request never reaches the card at all.
	if OS.has_feature("mobile"):
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_LANDSCAPE)
	_build()
	get_viewport().size_changed.connect(_refresh)
	_refresh()
	_mode_watch = InputMode.mode


func _process(_delta: float) -> void:
	if InputMode.mode != _mode_watch:
		_mode_watch = InputMode.mode
		_refresh()


## True while the card is up: the station controller asks before it treats a
## back gesture as "leave the menu".
func is_open() -> bool:
	return _root != null and _root.visible


func _refresh() -> void:
	var wanted: bool = _is_portrait() and InputMode.is_touch()
	if _root.visible != wanted:
		_root.visible = wanted
	if wanted:
		_relayout()


func _is_portrait() -> bool:
	var view: Vector2 = get_viewport().get_visible_rect().size
	return view.y > view.x


## The card owns the screen while it is up, so ENTER cannot step the telling
## along underneath it.
func _unhandled_input(event: InputEvent) -> void:
	if not is_open():
		return
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()


# --- Build ---------------------------------------------------------------------

func _build() -> void:
	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var backdrop := ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = GROUND
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(backdrop)

	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var side: int = int(_px(30))
	margin.add_theme_constant_override("margin_left", side)
	margin.add_theme_constant_override("margin_right", side)
	margin.add_theme_constant_override("margin_top", side)
	margin.add_theme_constant_override("margin_bottom", side)
	_root.add_child(margin)

	_column = VBoxContainer.new()
	_column.name = "Column"
	_column.alignment = BoxContainer.ALIGNMENT_CENTER
	_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_theme_constant_override("separation", 0)
	margin.add_child(_column)

	var kicker := Label.new()
	kicker.name = "Kicker"
	kicker.text = "ONE THING FIRST"
	kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kicker.add_theme_font_size_override("font_size", _px(14))
	kicker.add_theme_color_override("font_color", PAPAYA)
	_column.add_child(kicker)

	var title := Label.new()
	title.name = "Title"
	title.text = "TURN YOUR PHONE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size", _px(28))
	title.add_theme_color_override("font_color", WHITE)
	_column.add_child(title)

	var rule := ColorRect.new()
	rule.name = "Rule"
	rule.color = GOLD
	rule.custom_minimum_size = Vector2(_px(64.0), 2.0)
	rule.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_column.add_child(rule)

	_column.add_child(_gap(_px(18.0)))
	_column.add_child(_turn_mark())
	_column.add_child(_gap(_px(20.0)))

	var words := Label.new()
	words.name = "Words"
	words.text = "Adamant Verity is laid out wide. Turn your phone sideways to read the briefing and fly the ship the way it was drawn."
	words.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.add_theme_font_size_override("font_size", _px(17))
	words.add_theme_constant_override("line_spacing", 6)
	words.add_theme_color_override("font_color", BODY)
	_column.add_child(words)

	_column.add_child(_gap(_px(22.0)))

	var hint := Label.new()
	hint.name = "Hint"
	hint.text = "The ship will wait."
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", _px(12))
	hint.add_theme_color_override("font_color", Color(0.55, 0.48, 0.44))
	_column.add_child(hint)


## The house motif for "turn it": three parallel dashes, the same leaning ones
## the telling uses for its progress, laid on their side.
func _turn_mark() -> Control:
	var row := HBoxContainer.new()
	row.name = "Mark"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", _px(10.0))
	for i in 3:
		var dash := ColorRect.new()
		dash.name = "Dash%d" % i
		dash.color = GOLD if i == 1 else Color(0.45, 0.34, 0.26)
		dash.custom_minimum_size = Vector2(_px(30.0), 3.0)
		dash.pivot_offset = Vector2(_px(15.0), 1.5)
		dash.rotation = -0.42
		var holder := Control.new()
		holder.custom_minimum_size = Vector2(_px(30.0), _px(10.0))
		holder.add_child(dash)
		row.add_child(holder)
	return row


func _relayout() -> void:
	if _column == null:
		return
	var view: Vector2 = get_viewport().get_visible_rect().size
	## The reading is kept to a comfortable measure rather than run to the edges
	## of a narrow phone.
	var wanted: float = minf(view.x - _px(60.0), _px(520.0))
	if wanted > 40.0:
		_column.custom_minimum_size = Vector2(wanted, 0.0)


func _gap(height: float) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0.0, height)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return spacer


## One type scale for the card, from the same place every overlay reads it.
func _px(base: float) -> int:
	return int(round(base * Platform.ui_scale()))
