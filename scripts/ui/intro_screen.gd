class_name IntroScreen
extends CanvasLayer

## The story's front door: a full-screen telling of the situation, played
## before the launch card.
##
## The card's "WHY YOU'RE HERE" sheet answers the question in three lines.
## This screen tells the same three lines as a narrative - one beat at a
## time, each carried by a production still in the ship's retro television
## look. The picture claims two thirds of the screen and meets the words
## through a leaning seam, dressed with parallel diagonal lines that turn
## into straight edge lines through rounded corners: the same vocabulary as
## the ship's warm-yellow console styling, drawn in gold on near-black.
##
## Clicking anywhere, the button, or ENTER steps through the beats; ESC skips
## the whole telling. When the last beat is read the screen hands back to the
## mandate card that has waited underneath it the entire time.

signal finished

const PAPAYA := Color(0.863, 0.369, 0.153)
const TANGERINE := Color(0.816, 0.251, 0.149)
const GOLD := Color(0.941, 0.722, 0.224)
const WHITE := Color(1.0, 1.0, 1.0)
const BODY := Color(0.93, 0.89, 0.85)
const MUTED := Color(0.72, 0.66, 0.62)
const GROUND := Color(0.06, 0.032, 0.022)
const PANEL := Color(0.09, 0.055, 0.04)

## The picture field claims the top of the screen and leans as it descends:
## a diagonal seam, not a vertical split. The seam leans left as it falls,
## so the words' ground widens toward the top, where the ornament lanes live.
const SEAM_TOP := 0.62
const SEAM_BOTTOM := 0.72
## The words sit clear of the seam's widest reach.
const WORDS_LEFT := 0.74

## Held the other way up the seam turns on its side: the picture claims the
## top two thirds, the words the bottom third, and the whole screen reads on
## thirds, the way a poster is meant to be read.
const WORDS_TOP_PORTRAIT := 0.62

const IMAGE_PATHS := [
	"res://assets/ui/intro/intro_crew.png",
	"res://assets/ui/intro/intro_transit.png",
	"res://assets/ui/intro/intro_bridge.png",
]

## The briefing, one beat per still - the same three lines the launch card's
## situation sheet carries.
const BEATS := [
	"You are Crew Member Reyes, aboard the survey ship Adamant Verity.",
	"The ship's AI - SHIPMIND - has flown her for years. It is fast, careful, "
		+ "and completely sure it knows best. So far, it mostly has.",
	"Now it has locked the crew out of every big decision. Your job: walk the "
		+ "ship, look at its work, and decide how much of it you hand back.",
]

var _root: Control = null
var _img_front: TextureRect = null
var _img_back: TextureRect = null
var _decor: Control = null
var _catcher: Button = null
var _panel: Control = null
var _beat_label: Label = null
var _counter: Label = null
var _dashes: Array[ColorRect] = []
var _button: Button = null

var _textures: Array[Texture2D] = []
var _beat: int = 0
var _done: bool = false
var _zoom_tween: Tween = null
var _text_tween: Tween = null


func _ready() -> void:
	layer = 130
	_load_textures()
	_build()
	get_viewport().size_changed.connect(_on_viewport_resized)
	_open()
	_relayout_layout()


## Which way is the screen held? Portrait - taller than it is wide - stacks
## the picture over the words; landscape splits them left and right, the way
## the seam was drawn first.
func _is_portrait() -> bool:
	var view: Vector2 = get_viewport().get_visible_rect().size
	return view.y > view.x


func _relayout_layout() -> void:
	if _panel == null:
		return
	if _is_portrait():
		_panel.anchor_left = 0.0
		_panel.anchor_right = 1.0
		_panel.anchor_top = WORDS_TOP_PORTRAIT
		_panel.anchor_bottom = 1.0
	else:
		_panel.anchor_left = WORDS_LEFT
		_panel.anchor_right = 1.0
		_panel.anchor_top = 0.0
		_panel.anchor_bottom = 1.0


func _process(_delta: float) -> void:
	# The cursor is the only way to step through the telling, so the open
	# screen enforces its own visibility, the same way the launch card does.
	if not _done and Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _unhandled_input(event: InputEvent) -> void:
	if _done or not _root.visible:
		return
	if event.is_action_pressed("ui_accept"):
		_advance()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		_finish()
		get_viewport().set_input_as_handled()


# --- The beats ------------------------------------------------------------------

func _advance() -> void:
	if _done:
		return
	if _beat >= BEATS.size() - 1:
		_finish()
		return
	_show_beat(_beat + 1)


func _finish() -> void:
	if _done:
		return
	_done = true
	var tween := create_tween()
	tween.tween_property(_root, "modulate:a", 0.0, 0.35)
	tween.tween_callback(_close)


func _close() -> void:
	_root.visible = false
	finished.emit()


func _show_beat(index: int, first: bool = false) -> void:
	_beat = index
	_button.text = "TO THE SHIP" if index == BEATS.size() - 1 else "CONTINUE"
	_refresh_progress(index)
	_crossfade_image(index, first)
	if first or _text_tween == null:
		_beat_label.text = String(BEATS[index])
		_beat_label.modulate = Color(1.0, 1.0, 1.0, 1.0)
	else:
		_text_tween.kill()
		_text_tween = create_tween()
		_text_tween.tween_property(_beat_label, "modulate:a", 0.0, 0.18)
		_text_tween.tween_callback(func() -> void:
			_beat_label.text = String(BEATS[index]))
		_text_tween.tween_property(_beat_label, "modulate:a", 1.0, 0.25)


func _refresh_progress(index: int) -> void:
	_counter.text = "%02d / %02d" % [index + 1, BEATS.size()]
	for i in _dashes.size():
		var dash: ColorRect = _dashes[i]
		if i < index:
			dash.color = PAPAYA
		elif i == index:
			dash.color = GOLD
		else:
			dash.color = Color(0.35, 0.26, 0.20)


func _crossfade_image(index: int, first: bool) -> void:
	var texture: Texture2D = _textures[index] if index < _textures.size() else null
	if texture == null:
		return
	var incoming := _img_back
	var outgoing := _img_front
	incoming.texture = texture
	if _zoom_tween != null:
		_zoom_tween.kill()
	incoming.pivot_offset = incoming.size * 0.5
	incoming.scale = Vector2(1.045, 1.045)
	if first:
		incoming.modulate = Color(1.0, 1.0, 1.0, 1.0)
		outgoing.visible = false
	else:
		incoming.modulate = Color(1.0, 1.0, 1.0, 0.0)
		var fade := create_tween().set_parallel()
		fade.tween_property(incoming, "modulate:a", 1.0, 0.7)
		fade.tween_property(outgoing, "modulate:a", 0.0, 0.7)
	# A slow settle toward rest keeps every still alive on screen.
	_zoom_tween = create_tween()
	_zoom_tween.tween_property(incoming, "scale", Vector2.ONE, 7.0)
	_img_front = incoming
	_img_back = outgoing


# --- Open / close ---------------------------------------------------------------

func _open() -> void:
	InputRouter.set_ui_blocking(true)
	_root.modulate = Color(1.0, 1.0, 1.0, 0.0)
	create_tween().tween_property(_root, "modulate:a", 1.0, 0.7)
	_show_beat(0, true)
	_relayout()


## Replays the telling for a crew who wants the story again from the mandate
## card. Resets the beats and plays them over from the first still.
func replay() -> void:
	_done = false
	_beat = 0
	InputRouter.set_ui_blocking(true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_root.visible = true
	_root.modulate = Color(1.0, 1.0, 1.0, 0.0)
	create_tween().tween_property(_root, "modulate:a", 1.0, 0.5)
	_show_beat(0, true)
	_relayout()


func _on_viewport_resized() -> void:
	_relayout_layout()
	_relayout()


func _relayout() -> void:
	if _decor != null:
		_decor.queue_redraw()
	if _img_front != null:
		_img_front.pivot_offset = _img_front.size * 0.5
	if _img_back != null:
		_img_back.pivot_offset = _img_back.size * 0.5


func _load_textures() -> void:
	for path in IMAGE_PATHS:
		var texture: Texture2D = load(path) as Texture2D
		if texture == null:
			push_warning("IntroScreen: missing artwork at %s - the telling runs without it." % path)
		_textures.append(texture)


# --- Build ----------------------------------------------------------------------

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

	_img_front = _image_rect("ImageFront")
	_img_back = _image_rect("ImageBack")
	_root.add_child(_img_front)
	_root.add_child(_img_back)

	_decor = Control.new()
	_decor.name = "Decor"
	_decor.set_anchors_preset(Control.PRESET_FULL_RECT)
	_decor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_decor.draw.connect(_on_decor_draw)
	_root.add_child(_decor)

	# Every click off the words steps the telling forward.
	_catcher = Button.new()
	_catcher.name = "Advance"
	_catcher.set_anchors_preset(Control.PRESET_FULL_RECT)
	_catcher.flat = true
	_catcher.focus_mode = Control.FOCUS_NONE
	_catcher.pressed.connect(_advance)
	_root.add_child(_catcher)

	_build_words()


func _image_rect(rect_name: String) -> TextureRect:
	var rect := TextureRect.new()
	rect.name = rect_name
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


func _build_words() -> void:
	_panel = Control.new()
	_panel.name = "Words"
	_panel.anchor_left = WORDS_LEFT
	_panel.anchor_right = 1.0
	_panel.anchor_top = 0.0
	_panel.anchor_bottom = 1.0
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_panel)

	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var side_margin: int = 28 if _is_portrait() else 40
	var top_margin: int = 18 if _is_portrait() else 24
	margin.add_theme_constant_override("margin_left", side_margin)
	margin.add_theme_constant_override("margin_right", side_margin)
	margin.add_theme_constant_override("margin_top", top_margin)
	margin.add_theme_constant_override("margin_bottom", top_margin)
	_panel.add_child(margin)

	var column := VBoxContainer.new()
	column.name = "Column"
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)

	var kicker := Label.new()
	kicker.name = "Kicker"
	kicker.text = "THE SITUATION"
	kicker.add_theme_font_size_override("font_size", _text_size(15))
	kicker.add_theme_color_override("font_color", PAPAYA)
	column.add_child(kicker)

	var title := Label.new()
	title.name = "Title"
	title.text = "WHY YOU'RE HERE"
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size", _text_size(30))
	title.add_theme_color_override("font_color", WHITE)
	column.add_child(title)

	var rule := ColorRect.new()
	rule.name = "Rule"
	rule.color = GOLD
	rule.custom_minimum_size = Vector2(64.0, 2.0)
	rule.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	column.add_child(rule)

	column.add_child(_gap(14))

	_beat_label = Label.new()
	_beat_label.name = "Beat"
	_beat_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_beat_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_beat_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_beat_label.custom_minimum_size = Vector2(0.0, 190.0)
	_beat_label.add_theme_font_size_override("font_size", _text_size(19))
	_beat_label.add_theme_constant_override("line_spacing", 6)
	_beat_label.add_theme_color_override("font_color", BODY)
	column.add_child(_beat_label)

	column.add_child(_gap(8))

	var progress := HBoxContainer.new()
	progress.name = "Progress"
	progress.add_theme_constant_override("separation", 10)
	column.add_child(progress)
	for i in BEATS.size():
		var dash := ColorRect.new()
		dash.name = "Dash%d" % i
		dash.custom_minimum_size = Vector2(30.0, 3.0)
		dash.pivot_offset = Vector2(15.0, 1.5)
		dash.rotation = -0.42
		progress.add_child(dash)
		_dashes.append(dash)
	_counter = Label.new()
	_counter.name = "Counter"
	_counter.add_theme_font_size_override("font_size", _text_size(13))
	_counter.add_theme_color_override("font_color", MUTED)
	_counter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	progress.add_child(_counter)

	column.add_child(_gap(18))

	var actions := HBoxContainer.new()
	actions.name = "Actions"
	actions.add_theme_constant_override("separation", 18)
	column.add_child(actions)
	_button = Button.new()
	_button.name = "Continue"
	_button.text = "CONTINUE"
	_button.custom_minimum_size = Vector2(220.0, _button_height())
	_button.add_theme_font_size_override("font_size", _text_size(19))
	_button.add_theme_color_override("font_color", Color(0.10, 0.06, 0.04))
	_button.add_theme_color_override("font_hover_color", Color(0.10, 0.06, 0.04))
	_button.add_theme_color_override("font_pressed_color", Color(0.10, 0.06, 0.04))
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
	_button.pressed.connect(_advance)
	actions.add_child(_button)

	var skip := Button.new()
	skip.name = "Skip"
	skip.text = "SKIP"
	skip.focus_mode = Control.FOCUS_NONE
	skip.custom_minimum_size = Vector2(120.0, _button_height())
	skip.add_theme_font_size_override("font_size", _text_size(15))
	skip.add_theme_color_override("font_color", MUTED)
	skip.add_theme_color_override("font_hover_color", GOLD)
	skip.add_theme_color_override("font_pressed_color", GOLD)
	var flat := StyleBoxFlat.new()
	flat.bg_color = Color(0, 0, 0, 0)
	flat.set_border_width_all(0)
	flat.content_margin_left = 6.0
	flat.content_margin_right = 6.0
	skip.add_theme_stylebox_override("normal", flat)
	skip.add_theme_stylebox_override("hover", flat)
	skip.add_theme_stylebox_override("pressed", flat)
	skip.add_theme_stylebox_override("focus", flat)
	skip.pressed.connect(_finish)
	actions.add_child(skip)

	column.add_child(_gap(10))

	var keys := Label.new()
	keys.name = "Keys"
	keys.text = "ENTER to continue  -  ESC to skip"
	keys.add_theme_font_size_override("font_size", _text_size(12))
	keys.add_theme_color_override("font_color", Color(0.55, 0.48, 0.44))
	column.add_child(keys)


func _gap(height: float) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0.0, height)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return spacer


## A touch floor on text and buttons: on a phone held at arm's length, a label
## at monitor size is a squint. Text steps up a tier on touch; buttons sit at
## the fingertip's comfortable target. Both scale back down on a desktop.
func _text_size(base: int) -> int:
	return base * 2 if DisplayServer.is_touchscreen_available() else base


func _button_height() -> float:
	return 56.0 if DisplayServer.is_touchscreen_available() else 48.0


# --- The drawn frame ------------------------------------------------------------

## The seam and its ornament are drawn, not composed from rects, so the
## diagonals stay exact at any window size.
func _on_decor_draw() -> void:
	var view: Vector2 = _decor.size
	if view.x < 2.0 or view.y < 2.0:
		return
	var seam_top := Vector2(view.x * SEAM_TOP, 0.0)
	var seam_bot := Vector2(view.x * SEAM_BOTTOM, view.y)
	var dir := (seam_bot - seam_top).normalized()
	var side := dir.orthogonal()
	if side.x < 0.0:
		side = -side

	# The words' ground: everything right of the seam.
	_decor.draw_colored_polygon(
		PackedVector2Array([seam_top, Vector2(view.x, 0.0), Vector2(view.x, view.y), seam_bot]),
		PANEL)

	# Quiet lanes hugging the seam, fading out before the ornaments take over.
	var accents := [
		{"off": 16.0, "color": GOLD, "width": 2.0},
		{"off": 34.0, "color": PAPAYA, "width": 2.0},
		{"off": 56.0, "color": Color(0.45, 0.34, 0.26), "width": 1.5},
	]
	var fade := view.y * 0.24
	for accent in accents:
		var off: float = accent["off"]
		var a: Color = accent["color"]
		var w: float = accent["width"]
		var top := seam_top + side * off + dir * (fade / dir.y)
		var bottom := seam_bot + side * off - dir * (fade / dir.y)
		_decor.draw_line(top, bottom, Color(a, 0.8), w)

	# The signature: three parallel diagonals rising with the seam, each
	# turning into a straight line along the top edge through a rounded
	# corner - and the mirrored descent that exits toward the bottom of the
	# frame. The lanes stay inside the wedge between seam and words, and both
	# groups stop short of the middle, where the briefing text lives.
	var lanes := [
		{"off": 104.0, "color": GOLD, "width": 2.5},
		{"off": 138.0, "color": PAPAYA, "width": 2.0},
		{"off": 172.0, "color": Color(0.5, 0.38, 0.3), "width": 1.5},
	]
	var rise := -dir
	for k in lanes.size():
		var lane: Dictionary = lanes[k]
		var radius := 26.0

		# Rising: the lane starts mid-frame, climbs, and bends right at the
		# top edge of the wedge.
		var base_top: Vector2 = seam_bot + side * float(lane["off"])
		var corner_top: Vector2 = base_top + rise * ((84.0 + 34.0 * k - base_top.y) / rise.y)
		var run_top := minf((0.40 * view.y - corner_top.y) / absf(rise.y),
			0.42 * view.y)
		if run_top > radius + 16.0:
			_decor.draw_polyline(
				_bent_line(corner_top, rise, Vector2.RIGHT, radius,
					run_top, view.x - corner_top.x),
				lane["color"], lane["width"])

		# Descending: the lane starts mid-frame, falls, and bends left with a
		# short tail that stops just short of the seam.
		var base_bot: Vector2 = seam_top + side * float(lane["off"])
		var corner_bot: Vector2 = base_bot + dir * ((view.y - 84.0 - 34.0 * k - base_bot.y) / dir.y)
		var run_bot := minf((corner_bot.y - 0.60 * view.y) / absf(dir.y),
			0.42 * view.y)
		if run_bot > radius + 16.0:
			var seam_x_at_corner: float = lerpf(seam_top.x, seam_bot.x,
				corner_bot.y / view.y)
			_decor.draw_polyline(
				_bent_line(corner_bot, dir, Vector2.LEFT, radius,
					run_bot, corner_bot.x - seam_x_at_corner - 26.0),
				lane["color"], lane["width"])

	# Film-gate corners on the picture side: quiet gold marks that say
	# "this is the frame the story is told in".
	var gate := Color(GOLD, 0.75)
	_decor.draw_polyline(
		_bent_line(Vector2(18.0, 18.0), Vector2.LEFT, Vector2.DOWN, 12.0, 44.0, 44.0),
		gate, 2.0)
	_decor.draw_polyline(
		_bent_line(Vector2(18.0, view.y - 18.0), Vector2.LEFT, Vector2.UP, 12.0, 44.0, 44.0),
		gate, 2.0)


## A straight run that turns a corner through a rounded fillet. The line
## travels in along d_in, rounds the corner, and leaves along d_out - the
## motif of the ship's consoles, redrawn in two dimensions.
func _bent_line(corner: Vector2, d_in: Vector2, d_out: Vector2, radius: float,
		tail_in: float, tail_out: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var turn := absf((-d_in).angle_to(d_out))
	if turn < 0.05 or turn > PI - 0.05:
		# Nearly a straight line: nothing to round.
		points.append(corner - d_in * tail_in)
		points.append(corner + d_out * tail_out)
		return points
	var reach := radius / tan(turn * 0.5)
	# The fillet's centre sits radius away from both lines, inside the turn.
	var n_in := d_in.orthogonal()
	if n_in.dot(d_out) < 0.0:
		n_in = -n_in
	var n_out := d_out.orthogonal()
	if n_out.dot(d_in) > 0.0:
		n_out = -n_out
	var along := radius * (1.0 - n_in.dot(n_out)) / n_in.dot(d_out)
	var centre := corner + n_out * radius + d_out * along
	var t_in := corner - d_in * reach
	var t_out := corner + d_out * reach
	points.append(corner - d_in * maxf(tail_in, reach + 6.0))
	points.append(t_in)
	var sweep := wrapf((t_out - centre).angle() - (t_in - centre).angle(), -PI, PI)
	for i in 9:
		var angle := (t_in - centre).angle() + sweep * (float(i) / 9.0)
		points.append(centre + Vector2(cos(angle), sin(angle)) * radius)
	points.append(t_out)
	points.append(corner + d_out * tail_out)
	return points
