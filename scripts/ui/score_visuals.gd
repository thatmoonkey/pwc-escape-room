class_name ScoreVisuals
extends RefCounted

## THE PICTURES THE SCORES ARE DRAWN WITH.
##
## A score that is only a sentence asks the player to convert a number into a
## feeling. These builders do the conversion instead: a meter for an axis, a
## coloured pill for a rung of the autonomy spectrum, a verdict chip for a
## decision's quality, and the small text styles that hold them together.
##
## EVERY COLOUR COMES FROM THE CLIENT'S OWN CHART. The four autonomy levels
## carry the four fills of "Autonomy levels at the gate" (orange, off-white,
## peach, slate) and a decision's verdict is read on that same ramp: the vivid
## orange is the well-judged end, the slate is the end that needs defending.
## Nothing here invents a fifth colour, so a player who learns the chart on the
## first console can read every later screen at a glance.
##
## The widgets are Controls with no scene dependency: they are built in code
## like the rest of this game's 2D layer, so they work identically on desktop,
## in a mobile browser, in the Android build and inside the headset.

const ORANGE := Color(0.918, 0.369, 0.173)
const OFF_WHITE := Color(0.949, 0.949, 0.949)
const PEACH := Color(0.957, 0.737, 0.631)
const SLATE := Color(0.369, 0.404, 0.447)

## The ink that sits on top of each fill. The chart is black text on all four;
## the slate is the one fill where black loses its contrast, so it alone takes
## light text. That is a legibility correction, not a fifth colour.
const INK := Color(0.055, 0.063, 0.075)
const INK_LIGHT := Color(0.965, 0.972, 0.980)


## The colour of a decision's quality, on the chart's ramp.
static func grade_color(quality: float) -> Color:
	if quality < 0.50:
		return SLATE
	if quality < 0.75:
		return OFF_WHITE
	if quality < 0.90:
		return PEACH
	return ORANGE


## The ink for a fill produced by grade_color().
static func grade_ink(quality: float) -> Color:
	return INK_LIGHT if quality < 0.50 else INK


## One axis as a picture: its name, its number, the meter itself and the word
## the number means. The number is the largest thing in the block because it is
## the thing a player compares between decisions; the word underneath is the
## reading of it for anyone who does not want to rank percentages.
static func meter_block(title: String, value: float, colour: Color,
		word: String, compact: bool = false) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4 if compact else 6)
	var label_size: int = 18 if Platform.touch_ui() else 16 if compact else 18
	var word_size: int = 18 if Platform.touch_ui() else 16 if compact else 18

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	var name_label := Label.new()
	name_label.text = title
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", label_size)
	name_label.add_theme_color_override("font_color", Brand.NEUTRAL_LIGHT)
	head.add_child(name_label)
	var number := Label.new()
	number.text = "--" if value < 0.0 else "%d%%" % Score.percent(value)
	number.add_theme_font_size_override("font_size", 24 if compact else 30)
	number.add_theme_color_override("font_color", colour if value >= 0.0 else Brand.NEUTRAL)
	head.add_child(number)
	box.add_child(head)

	var meter := Meter.new()
	meter.custom_minimum_size = Vector2(0.0, 12.0 if compact else 16.0)
	meter.fill_color = colour
	meter.mark = 0.0 if value < 0.0 else -1.0
	meter.show_ratio(maxf(value, 0.0))
	box.add_child(meter)

	if word != "":
		var word_label := Label.new()
		word_label.text = word
		word_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		word_label.add_theme_font_size_override("font_size", word_size)
		word_label.add_theme_color_override("font_color", Brand.NEUTRAL)
		box.add_child(word_label)
	return box


## A flat coloured label: the chip language of the chart, used for a level's
## name, a verdict word and the small tags on the matrix.
static func pill(text: String, fill: Color, ink: Color, font_size: int = 13,
		pad: Vector2 = Vector2(10.0, 5.0)) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.set_corner_radius_all(2)
	style.content_margin_left = pad.x
	style.content_margin_right = pad.x
	style.content_margin_top = pad.y
	style.content_margin_bottom = pad.y
	panel.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", ink)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	panel.add_child(label)
	return panel


## A rung of the spectrum as the chart draws it: its fill, its name, and - when
## the label is wide enough to carry it - the one line of what it means.
static func level_pill(level_id: String, font_size: int = 13, with_summary: bool = false) -> PanelContainer:
	var fill: Color = OperatingModel.level_color(level_id)
	var ink: Color = INK if OperatingModel.level_dark_text(level_id) else INK_LIGHT
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.set_corner_radius_all(2)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 7.0
	style.content_margin_bottom = 7.0
	panel.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 1)
	var name_label := Label.new()
	name_label.text = OperatingModel.level_label(level_id)
	name_label.add_theme_font_size_override("font_size", font_size)
	name_label.add_theme_color_override("font_color", ink)
	box.add_child(name_label)
	if with_summary:
		var summary := Label.new()
		summary.text = OperatingModel.level_summary(level_id)
		summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		summary.add_theme_font_size_override("font_size", maxi(font_size - 2, 10))
		summary.add_theme_color_override("font_color", Color(ink.r, ink.g, ink.b, 0.82))
		box.add_child(summary)
	panel.add_child(box)
	return panel


## A quiet caption in the machine voice, for the line under a picture.
static func caption(text: String, tint: Color = Brand.NEUTRAL) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	Brand.apply_tui(label, 11)
	label.add_theme_color_override("font_color", tint)
	return label


## One score axis as a bar. Draws its own track and fill and grows into place on
## show, so a card that opens reads as a reading being taken rather than as a
## number that was always there.
class Meter:
	extends Control

	var ratio: float = 0.0:
		set(value):
			ratio = clampf(value, 0.0, 1.0)
			queue_redraw()
	var fill_color: Color = Color(0.918, 0.369, 0.173)
	var track_color: Color = Color(1.0, 1.0, 1.0, 0.13)
	## Where "full marks" begins: drawn as a faint notch, so a bar that stops
	## just short of it is visibly short of it rather than merely not full.
	var mark: float = -1.0
	var _tween: Tween = null

	func show_ratio(target: float) -> void:
		ratio = 0.0 if is_inside_tree() else target
		if not is_inside_tree():
			return
		if _tween != null:
			_tween.kill()
		_tween = create_tween()
		_tween.tween_property(self, "ratio", target, 0.65).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	func _draw() -> void:
		var height: float = size.y
		var track := _box(track_color, height)
		draw_style_box(track, Rect2(Vector2.ZERO, size))
		if ratio > 0.001:
			var fill := _box(fill_color, height)
			draw_style_box(fill, Rect2(Vector2.ZERO, Vector2(maxf(size.x * ratio, height), height)))
		if mark > 0.0 and mark < 1.0:
			var x: float = size.x * mark
			draw_line(Vector2(x, -2.0), Vector2(x, height + 2.0), Color(1.0, 1.0, 1.0, 0.42), 1.5)

	func _box(colour: Color, height: float) -> StyleBoxFlat:
		var box := StyleBoxFlat.new()
		box.bg_color = colour
		box.set_corner_radius_all(int(maxf(height * 0.5, 2.0)))
		return box
