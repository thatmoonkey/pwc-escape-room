class_name BrandTokens
extends RefCounted

## The shared 2D choice widget.
##
## The operating model asks the player the same question in two places: the
## mandate chooser on the boot screen and the autonomy spectrum on a decision
## console. Both are "pick exactly one of these, and read what it costs", so the
## widget is built once here and applied twice, rather than twice in two files
## drifting apart.
##
## This is the widget layer only. The values it spends live in Brand, which is
## the one place the PwC brand lands later: nothing here hardcodes a colour, a
## size or a typeface of its own.

## An exclusive choice button: one toggle inside a ButtonGroup, with a label, an
## optional hint and an optional cost line under it. The caller owns the
## pressed behaviour.
static func choice_button(group: ButtonGroup, label: String, hint: String = "", cost: String = "") -> Button:
	var button := Button.new()
	var lines: Array[String] = [label]
	if hint != "":
		lines.append(hint)
	if cost != "":
		lines.append(cost)
	button.text = "\n".join(lines)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	## Toggle plus a group is what makes the choice exclusive and makes the
	## current selection visible: the filled "pressed" state IS the selection,
	## so the widget never needs a second highlight of its own.
	button.toggle_mode = true
	button.button_group = group
	button.focus_mode = Control.FOCUS_ALL
	## One line, two lines, three lines - and the third line is a cost, so the
	## step between them is what keeps a stack of eleven choices on one screen.
	## Every line is taller on a touchscreen, because the target that is
	## comfortable under a cursor is fiddly under a thumb.
	var base: float = 30.0 + (20.0 if DisplayServer.is_touchscreen_available() else 0.0)
	button.custom_minimum_size = Vector2(0.0, base + 18.0 * float(lines.size() - 1))
	button.add_theme_font_size_override("font_size", Brand.SIZE_COMPACT)
	button.add_theme_color_override("font_color", Brand.NEUTRAL)
	button.add_theme_color_override("font_hover_color", Brand.INK)
	button.add_theme_color_override("font_pressed_color", Brand.INK)
	button.add_theme_color_override("font_focus_color", Brand.INK)
	button.add_theme_stylebox_override("normal", _fill(Brand.SURFACE, Brand.NEUTRAL))
	button.add_theme_stylebox_override("hover", _fill(Brand.SURFACE_RAISED, Brand.NEUTRAL_LIGHT))
	button.add_theme_stylebox_override("pressed", _fill(Brand.SURFACE_RAISED, Brand.ACCENT))
	## The focus ring is drawn over whatever fill is current, so it is a bare
	## orange border on nothing. The engine's default ring is cool, and this
	## layer has no cool colour in it.
	button.add_theme_stylebox_override("focus", _ring())
	return button


## An exclusive choice, already set. Used to re-read a decision that is on the
## record, so the screen opens showing what the player picked rather than
## asking them again from nothing.
##
## set_pressed and NOT set_pressed_no_signal: the no-signal form leaves the
## button group unaware of the selection, so choosing a different option later
## leaves two buttons looking chosen. This form tells the group, and it raises
## "toggled" rather than "pressed", so it never re-runs the caller's handler.
static func mark_chosen(button: Button) -> void:
	if button != null:
		button.set_pressed(true)


static func _fill(background: Color, border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = background
	box.border_color = border
	box.set_border_width_all(2)
	box.set_corner_radius_all(3)
	box.content_margin_left = 12.0
	box.content_margin_right = 12.0
	box.content_margin_top = 6.0
	box.content_margin_bottom = 6.0
	return box


static func _ring() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	box.border_color = Brand.ACCENT
	box.set_border_width_all(2)
	box.set_corner_radius_all(3)
	return box
