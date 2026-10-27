class_name Glyph
extends Control

## The icon library. One flat line-icon set, drawn with vector primitives so the
## UI never depends on a font that may or may not carry a glyph, and never
## ships a texture per icon.
##
## Every icon is drawn on a 24x24 grid and scaled to whatever square the control
## occupies, with the stroke width riding along, so the same icon reads the same
## at 20px on a chip and at 64px on a goal tile.
##
## The name-to- meaning maps live here too, because the meaning of an icon and
## its shape belong together: icon_for_objective / icon_for_appetite /
## icon_for_system turn the record's ids into picture names. A system id with no
## entry falls back to "sliders" rather than crashing a future bay.

## Secondary colour for icons drawn in two colours (badges, needles). Defaults
## to the dark surface the UI sits on.
@export var icon: String = "question":
	set(value):
		icon = value
		queue_redraw()
@export var tint: Color = Color.WHITE:
	set(value):
		tint = value
		queue_redraw()
@export var accent: Color = Color(0.078, 0.078, 0.086):
	set(value):
		accent = value
		queue_redraw()


static func make(icon_name: String, px: float, color: Color) -> Glyph:
	var g := Glyph.new()
	g.icon = icon_name
	g.custom_minimum_size = Vector2(px, px)
	g.tint = color
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return g


static func icon_for_objective(objective_id: String) -> String:
	match objective_id:
		"home_intact":
			return "home"
		"home_on_schedule":
			return "clock"
		"finish_the_survey":
			return "globe"
	return "question"


static func icon_for_appetite(appetite_id: String) -> String:
	match appetite_id:
		"cautious":
			return "shield"
		"balanced":
			return "scales"
		"ambitious":
			return "flag"
	return "question"


## The four rungs of the autonomy spectrum. The slider's whole point is that
## the eye reads four pictures in a row before it reads any words, so each rung
## gets an icon that matches its concept: the model acting alone is a gear, a
## human reading the call is an eye, a named authorisation is a stamp, and a
## decision never delegated is a person.
static func icon_for_level(level_id: String) -> String:
	match level_id:
		"automated":
			return "gear"
		"review":
			return "eye"
		"signoff":
			return "stamp"
		"human_only":
			return "person"
	return "question"


static func icon_for_system(system_id: String) -> String:
	match system_id:
		"navigation":
			return "compass"
		"life_support":
			return "heart"
		"comms":
			return "signal"
		"cargo":
			return "crate"
		"engineering":
			return "gear"
	return "sliders"


func _draw() -> void:
	var s: float = minf(size.x, size.y)
	if s < 4.0:
		return
	var w: float = maxf(1.4, s / 12.0)
	# Everything below is authored on the 24x24 grid; _p maps it onto the
	# control's square.
	match icon:
		"scroll":
			var box: PackedVector2Array = _pts([
				[6, 3], [18, 3], [18, 21], [6, 21], [6, 3],
			])
			draw_polyline(box, tint, w)
			_line([Vector2(9, 9), Vector2(15, 9)], w)
			_line([Vector2(9, 13), Vector2(15, 13)], w)
			draw_circle(_p(12, 17.5), s / 20.0, tint)
		"sliders":
			_line([Vector2(4, 6), Vector2(20, 6)], w)
			_line([Vector2(4, 12), Vector2(20, 12)], w)
			_line([Vector2(4, 18), Vector2(20, 18)], w)
			draw_circle(_p(14, 6), s / 10.0, tint)
			draw_circle(_p(8, 12), s / 10.0, tint)
			draw_circle(_p(16, 18), s / 10.0, tint)
		"rocket":
			var body: PackedVector2Array = _pts([
				[12, 2], [16, 9], [16, 17], [8, 17], [8, 9], [12, 2],
			])
			draw_polyline(body, tint, w)
			draw_arc(_p(12, 9), s / 11.0, 0.0, TAU, 20, tint, w)
			_line([Vector2(8, 13), Vector2(4.5, 18)], w)
			_line([Vector2(16, 13), Vector2(19.5, 18)], w)
			_line([Vector2(10.5, 19), Vector2(9.5, 22)], w)
			_line([Vector2(13.5, 19), Vector2(14.5, 22)], w)
		"home":
			var roof: PackedVector2Array = _pts([
				[3, 11], [12, 3], [21, 11],
			])
			draw_polyline(roof, tint, w)
			var walls: PackedVector2Array = _pts([
				[5.5, 9.5], [5.5, 20], [18.5, 20], [18.5, 9.5],
			])
			draw_polyline(walls, tint, w)
			draw_rect(Rect2(_p(10, 14), Vector2(s / 2.4, s / 2.66)), tint, false, w)
		"clock":
			draw_arc(_p(12, 12), s / 2.9, 0.0, TAU, 32, tint, w)
			_line([Vector2(12, 12), Vector2(12, 6.5)], w)
			_line([Vector2(12, 12), Vector2(16, 12)], w)
		"telescope":
			_line([Vector2(5, 17), Vector2(14.5, 6.5)], w * 2.2)
			draw_circle(_p(15.5, 5.5), s / 13.0, tint)
			_line([Vector2(10.5, 12.5), Vector2(9.5, 21)], w)
			_line([Vector2(10.5, 12.5), Vector2(15.5, 21)], w)
			_line([Vector2(10.5, 12.5), Vector2(12, 21)], w)
		"globe":
			# A planet with meridian and equator lines: the map-the-planet
			# objective. The circle is the disc, the inner arcs are the meridian
			# and the equator, so it reads as "a world being charted" rather
			# than as a generic dot.
			draw_arc(_p(12, 12), s / 2.6, 0.0, TAU, 32, tint, w)
			draw_arc(_p(12, 12), s / 2.6, -PI * 0.5, PI * 0.5, 24, tint, w * 0.7)
			_line([Vector2(12, 12 - s / 2.6), Vector2(12, 12 + s / 2.6)], w * 0.7)
			_line([Vector2(12 - s / 2.6, 12), Vector2(12 + s / 2.6, 12)], w * 0.7)
		"shield":
			var shape: PackedVector2Array = _pts([
				[12, 3], [19, 6], [19, 12], [12, 21], [5, 12], [5, 6], [12, 3],
			])
			draw_polyline(shape, tint, w)
			_line([Vector2(8.5, 11.5), Vector2(11, 14), Vector2(15.5, 8.5)], w)
		"scales":
			_line([Vector2(12, 4), Vector2(12, 18)], w)
			_line([Vector2(5, 7), Vector2(19, 7)], w)
			draw_arc(_p(5.5, 7), s / 6.5, 0.0, PI, 16, tint, w)
			draw_arc(_p(18.5, 7), s / 6.5, 0.0, PI, 16, tint, w)
			_line([Vector2(8, 18), Vector2(16, 18)], w)
			_line([Vector2(10, 21), Vector2(14, 21)], w)
		"flag":
			_line([Vector2(7, 3), Vector2(7, 21)], w)
			var banner: PackedVector2Array = _pts([
				[7, 4], [18.5, 6.5], [7, 10], [7, 4],
			])
			draw_colored_polygon(_clean(banner), tint)
		"compass":
			draw_arc(_p(12, 12), s / 2.9, 0.0, TAU, 32, tint, w)
			var north: PackedVector2Array = _pts([
				[12, 5.5], [14.5, 12], [9.5, 12],
			])
			draw_colored_polygon(_clean(north), tint)
			draw_polyline(_pts([[9.5, 12], [12, 18.5], [14.5, 12]]), tint, w)
		"heart":
			var beat: PackedVector2Array = _pts([
				[12, 20], [5.5, 13.5], [5, 9], [7.5, 5.5], [11, 6.5], [12, 8],
				[13, 6.5], [16.5, 5.5], [19, 9], [18.5, 13.5], [12, 20],
			])
			draw_polyline(beat, tint, w)
		"signal":
			draw_circle(_p(12, 17), s / 13.0, tint)
			draw_arc(_p(12, 17), s / 5.6, -PI * 0.8, -PI * 0.2, 14, tint, w)
			draw_arc(_p(12, 17), s / 2.9, -PI * 0.8, -PI * 0.2, 18, tint, w)
		"gear":
			draw_arc(_p(12, 12), s / 4.6, 0.0, TAU, 24, tint, w)
			for i in 8:
				var angle: float = TAU * float(i) / 8.0
				var from: Vector2 = _p(12, 12) + Vector2(cos(angle), sin(angle)) * (s / 4.6)
				var to: Vector2 = _p(12, 12) + Vector2(cos(angle), sin(angle)) * (s / 3.1)
				draw_line(from, to, tint, w)
			draw_circle(_p(12, 12), s / 9.0, tint)
		"crate":
			draw_rect(Rect2(_p(4.5, 6.5), Vector2(s / 1.55, s / 1.9)), tint, false, w)
			_line([Vector2(4.5, 12), Vector2(19.5, 12)], w)
			_line([Vector2(12, 12), Vector2(12, 19.5)], w)
		"check":
			_line([Vector2(5, 12.5), Vector2(10, 17.5), Vector2(19, 6.5)], w)
		"check_badge":
			draw_circle(_p(12, 12), s / 2.4, tint)
			# The check rides in the accent colour so the badge reads on any fill.
			var dark: Color = accent
			_line_colored([Vector2(7.5, 12.5), Vector2(11, 16), Vector2(17, 8)], w, dark)
		"lock":
			draw_arc(_p(12, 10.5), s / 5.2, PI, TAU, 16, tint, w)
			draw_rect(Rect2(_p(6, 10.5), Vector2(s / 2.0, s / 2.55)), tint, false, w)
			draw_circle(_p(12, 14.5), s / 16.0, tint)
		"question":
			draw_arc(_p(12, 9), s / 5.0, -PI * 0.85, PI * 0.55, 18, tint, w)
			_line([Vector2(12, 13.5), Vector2(12, 15)], w)
			draw_circle(_p(12, 18.5), s / 15.0, tint)
		"info":
			draw_arc(_p(12, 12), s / 2.8, 0.0, TAU, 32, tint, w)
			draw_circle(_p(12, 7.8), s / 16.0, tint)
			_line([Vector2(12, 11), Vector2(12, 16.5)], w)
		"keyboard":
			draw_rect(Rect2(_p(3, 7), Vector2(s / 1.33, s / 2.35)), tint, false, w)
			for key_x in [7.0, 12.0, 17.0]:
				draw_circle(_p(key_x, 11), s / 22.0, tint)
			_line([Vector2(7, 15.5), Vector2(17, 15.5)], w)
		"phone":
			draw_rect(Rect2(_p(8, 2.5), Vector2(s / 3.0, s / 1.19)), tint, false, w)
			_line([Vector2(10.8, 18.5), Vector2(13.2, 18.5)], w)
		"headset":
			draw_rect(Rect2(_p(3.5, 8.5), Vector2(s / 1.5, s / 3.6)), tint, false, w)
			_line([Vector2(3.5, 11.5), Vector2(1.5, 9.5)], w)
			_line([Vector2(20.5, 11.5), Vector2(22.5, 9.5)], w)
			draw_arc(_p(12, 15), s / 12.0, 0.0, PI, 10, tint, w)
		"close":
			_line([Vector2(6, 6), Vector2(18, 18)], w)
			_line([Vector2(18, 6), Vector2(6, 18)], w)
		"eye":
			# An eye: two arcs meeting at the corners, with an iris.
			draw_arc(_p(12, 12), s / 3.4, PI * 0.15, PI * 0.85, 18, tint, w)
			draw_arc(_p(12, 12), s / 3.4, PI * 1.15, PI * 1.85, 18, tint, w)
			draw_arc(_p(12, 12), s / 6.5, 0.0, TAU, 16, tint, w)
			draw_circle(_p(12, 12), s / 16.0, tint)
		"person":
			draw_arc(_p(12, 7.5), s / 6.0, 0.0, TAU, 20, tint, w)
			draw_arc(_p(12, 20), s / 6.8, PI * 1.05, PI * 1.95, 18, tint, w)
			_line([Vector2(5.4, 20), Vector2(7, 14.5)], w)
			_line([Vector2(18.6, 20), Vector2(17, 14.5)], w)
		"chevron":
			_line([Vector2(7, 10), Vector2(12, 15), Vector2(17, 10)], w)
		"sound_on":
			# A speaker with two arcs of sound. The speaker body is a filled
			# polygon so it reads at chip size.
			var body: PackedVector2Array = _pts([
				[4, 9], [7.5, 9], [11.5, 5], [11.5, 19], [7.5, 15], [4, 15],
			])
			draw_colored_polygon(_clean(body), tint)
			draw_arc(_p(14, 12), s / 8.0, -PI * 0.32, PI * 0.32, 12, tint, w)
			draw_arc(_p(14, 12), s / 4.4, -PI * 0.32, PI * 0.32, 16, tint, w)
		"sound_off":
			# Same speaker, muted: a slash where the waves would be.
			var muted: PackedVector2Array = _pts([
				[4, 9], [7.5, 9], [11.5, 5], [11.5, 19], [7.5, 15], [4, 15],
			])
			draw_colored_polygon(_clean(muted), tint)
			_line([Vector2(15, 8), Vector2(21, 16)], w)
		"menu":
			_line([Vector2(4, 7), Vector2(20, 7)], w)
			_line([Vector2(4, 12), Vector2(20, 12)], w)
			_line([Vector2(4, 17), Vector2(20, 17)], w)
		"note":
			# A musical note: stem with a filled head and a flag, for the music
			# channel.
			draw_circle(_p(8, 17), s / 9.0, tint)
			_line([Vector2(10.7, 17), Vector2(10.7, 5)], w)
			_line([Vector2(10.7, 5), Vector2(16.5, 7)], w)
		"waves":
			# Three arcs breaking the same way, for the ambience channel: the
			# room tone that runs under everything.
			draw_arc(_p(12, 20), s / 1.6, -PI * 0.78, -PI * 0.22, 14, tint, w)
			draw_arc(_p(12, 20), s / 2.8, -PI * 0.78, -PI * 0.22, 12, tint, w)
			draw_arc(_p(12, 20), s / 5.6, -PI * 0.78, -PI * 0.22, 10, tint, w)
		"bolt":
			# A lightning bolt, filled, for the sfx channel: the short, sharp
			# sounds - a console opening, a door sliding.
			var bolt: PackedVector2Array = _pts([
				[13, 3], [7, 13], [11, 13], [9.5, 21], [17, 10], [12.6, 10],
			])
			draw_colored_polygon(_clean(bolt), tint)
		"stamp":
			# A rubber stamp on its base, for human sign-off: an authorisation
			# a named person physically commits to paper.
			draw_rect(Rect2(_p(5, 18), Vector2(s / 2.0, s / 8.0)), tint, false, w)
			_line([Vector2(8, 16), Vector2(16, 16)], w)
			var head: PackedVector2Array = _pts([
				[9, 14], [9, 8], [12, 4.5], [15, 8], [15, 14],
			])
			draw_polyline(head, tint, w)
		_:
			draw_arc(_p(12, 12), s / 3.0, 0.0, TAU, 20, tint, w)


func _p(x: float, y: float) -> Vector2:
	var s: float = minf(size.x, size.y)
	return Vector2(x, y) * (s / 24.0)


func _pts(points: Array) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	for point in points:
		out.append(_p(point[0], point[1]))
	return out


## A closed polygon needs its first point repeated at the end, or the polyline
## leaves the closing edge undrawn.
func _clean(points: PackedVector2Array) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array(points)
	if out.size() > 2 and out[0] != out[out.size() - 1]:
		out.append(out[0])
	return out


func _line(points: Array, width: float) -> void:
	draw_polyline(_pts(points), tint, width)


func _line_colored(points: Array, width: float, color: Color) -> void:
	draw_polyline(_pts(points), color, width)
