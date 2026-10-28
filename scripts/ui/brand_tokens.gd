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
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.size_flags_vertical = Control.SIZE_EXPAND_FILL
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.clip_text = false
	## One line, two lines, three lines - and the third line is a cost, so the
	## step between them is what keeps a stack of eleven choices on one screen.
	## Every line is taller on a touchscreen, because the target that is
	## comfortable under a cursor is fiddly under a thumb.
	var base: float = 30.0 + (26.0 if DisplayServer.is_touchscreen_available() else 0.0)
	button.custom_minimum_size = Vector2(0.0, base + 20.0 * float(lines.size() - 1))
	button.add_theme_font_size_override("font_size", Brand.SIZE_COMPACT)
	button.add_theme_color_override("font_color", Brand.NEUTRAL)
	button.add_theme_color_override("font_hover_color", Brand.INK)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_focus_color", Brand.INK)
	button.add_theme_stylebox_override("normal", _fill(Brand.SURFACE, Brand.NEUTRAL))
	button.add_theme_stylebox_override("hover", _fill(Brand.SURFACE_RAISED, Brand.NEUTRAL_LIGHT))
	## Selected is a solid orange fill with white text: the old orange border on
	## dark read as an outline, not a state, and the player had to hunt for
	## which option was actually on.
	button.add_theme_stylebox_override("pressed", _fill(Brand.ACCENT, Brand.ACCENT))
	## The focus ring is drawn over whatever fill is current, so it is a bare
	## orange border on nothing. The engine's default ring is cool, and this
	## layer has no cool colour in it.
	button.add_theme_stylebox_override("focus", _ring())
	return button


## The same exclusive choice, with an icon. The glyph sits in its own column so
## the eye can anchor each option to a picture - a list of choices reads as
## shapes first and words second, which is what stops the player re-reading the
## words every time they want to remind themselves what a choice means.
static func icon_choice_button(group: ButtonGroup, icon_name: String, label: String, hint: String = "") -> Button:
	var button := choice_button(group, label, hint)
	var glyph := Glyph.make(icon_name, 30.0, Brand.ACCENT_TINT)
	glyph.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	glyph.offset_left = 14.0
	glyph.offset_right = 44.0
	glyph.offset_top = -15.0
	glyph.offset_bottom = 15.0
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(glyph)
	# The text clears the glyph's column instead of flowing under it: the text
	# follows the current stylebox's left content margin, so every state gets
	# the same wider margin.
	for state in ["normal", "hover", "pressed", "focus"]:
		var box: StyleBoxFlat = button.get_theme_stylebox(state) as StyleBoxFlat
		if box != null:
			var adjusted: StyleBoxFlat = box.duplicate()
			adjusted.content_margin_left = 58.0
			button.add_theme_stylebox_override(state, adjusted)
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
