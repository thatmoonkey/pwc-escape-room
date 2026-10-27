class_name AudioPanel
extends VBoxContainer

## The audio mixer panel: one row per channel - music, ambience, sfx - each
## with its icon, its mute toggle and its fader, live.
##
## Built once and embedded wherever sound is controlled: the pause menu mid-run
## and the launch screen's corner speaker. The panel reads and writes the Sfx
## mixer directly, so every embedding stays in sync by construction - there is
## one mixer and this is its face, not a copy of its state.

const GOLD := Color(0.941, 0.722, 0.224)
const TANGERINE := Color(0.816, 0.251, 0.149)
const WHITE := Color(0.98, 0.95, 0.91)
const INK := Color(0.93, 0.89, 0.85)
const MUTED := Color(0.72, 0.66, 0.62)
const BODY := Color(0.84, 0.79, 0.74)
const SURFACE := Color(0.12, 0.075, 0.055, 0.6)

var _mutes: Dictionary = {}
var _faders: Dictionary = {}
var _percent_labels: Dictionary = {}


func _ready() -> void:
	add_to_group("audio_panel")
	add_theme_constant_override("separation", 8)
	for channel in Sfx.CHANNELS:
		add_child(_channel_row(channel))
	_refresh_all()


## One channel: icon, name, mute toggle on the left; fader and its percentage
## on the right. The row is a grid so the three columns stay aligned across
## channels - a mixer's rows line up, that is most of what makes it read as a
## mixer rather than as three unrelated controls.
func _channel_row(channel: String) -> Control:
	var row := HBoxContainer.new()
	row.name = "Row_%s" % channel
	row.add_theme_constant_override("separation", 10)

	var glyph := Glyph.make(String(Sfx.CHANNEL_ICONS[channel]), 22.0, INK)
	glyph.custom_minimum_size = Vector2(26.0, 26.0)
	glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(glyph)

	var name_label := Label.new()
	name_label.text = String(Sfx.CHANNEL_NAMES[channel])
	name_label.custom_minimum_size = Vector2(96.0, 0.0)
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", BODY)
	row.add_child(name_label)

	var mute := Button.new()
	mute.name = "Mute"
	mute.text = "MUTE"
	mute.toggle_mode = true
	mute.focus_mode = Control.FOCUS_NONE
	mute.tooltip_text = "Silence this channel"
	mute.custom_minimum_size = Vector2(64.0, 30.0)
	mute.add_theme_font_size_override("font_size", 12)
	_style_toggle(mute, "the channel plays")
	mute.toggled.connect(_on_mute_toggled.bind(channel))
	row.add_child(mute)
	_mutes[channel] = mute

	var fader := HSlider.new()
	fader.name = "Fader"
	fader.min_value = 0.0
	fader.max_value = 1.0
	fader.step = 0.05
	fader.custom_minimum_size = Vector2(150.0, 30.0)
	fader.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fader.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	fader.focus_mode = Control.FOCUS_NONE
	_style_slider(fader)
	fader.value_changed.connect(_on_fader_moved.bind(channel))
	row.add_child(fader)
	_faders[channel] = fader

	var percent := Label.new()
	percent.name = "Percent"
	percent.custom_minimum_size = Vector2(44.0, 0.0)
	percent.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	percent.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	percent.add_theme_font_size_override("font_size", 12)
	percent.add_theme_color_override("font_color", MUTED)
	row.add_child(percent)
	_percent_labels[channel] = percent

	return row


func _refresh_all() -> void:
	for channel in Sfx.CHANNELS:
		_refresh_channel(channel)


func _refresh_channel(channel: String) -> void:
	var muted: bool = Sfx.channel_is_muted(channel)
	var volume: float = Sfx.channel_volume(channel)

	var mute: Button = _mutes[channel]
	mute.set_pressed_no_signal(muted)
	mute.tooltip_text = "This channel is silent - click to let it play" if muted \
		else "Silence this channel"

	var fader: HSlider = _faders[channel]
	fader.set_value_no_signal(volume)
	# A muted fader is still grabbable - moving it implies "make it audible at
	# this level" - but it reads as asleep until it is touched.
	fader.modulate = Color(1, 1, 1, 0.45) if muted else Color(1, 1, 1, 1)

	var percent: Label = _percent_labels[channel]
	percent.text = "OFF" if muted else "%d%%" % int(round(volume * 100.0))
	percent.add_theme_color_override("font_color", TANGERINE if muted else MUTED)


func _on_mute_toggled(pressed: bool, channel: String) -> void:
	Sfx.set_channel_muted(channel, pressed)
	_refresh_channel(channel)


func _on_fader_moved(value: float, channel: String) -> void:
	Sfx.set_channel_volume(channel, value)
	# Moving a fader is an instruction to hear that channel: a fader raised on
	# a muted channel unmutes it, because a control that moves but does nothing
	# reads as broken.
	if Sfx.channel_is_muted(channel) and value > 0.0:
		Sfx.set_channel_muted(channel, false)
	_refresh_channel(channel)


# --- Styling ---------------------------------------------------------------------

func _style_toggle(button: Button, _hint: String) -> void:
	var idle := StyleBoxFlat.new()
	idle.bg_color = Color(0, 0, 0, 0.30)
	idle.border_color = Color(0.4, 0.32, 0.26)
	idle.set_border_width_all(1)
	idle.set_corner_radius_all(3)
	var chosen: StyleBoxFlat = idle.duplicate()
	chosen.bg_color = Color(0.55, 0.12, 0.06, 0.9)
	chosen.border_color = TANGERINE
	button.add_theme_stylebox_override("normal", idle)
	button.add_theme_stylebox_override("hover", idle.duplicate())
	button.add_theme_stylebox_override("pressed", chosen)
	button.add_theme_stylebox_override("hover_pressed", chosen)
	button.add_theme_stylebox_override("focus", idle)
	button.add_theme_color_override("font_color", MUTED)
	button.add_theme_color_override("font_pressed_color", Color(1.0, 0.85, 0.75))


func _style_slider(slider: HSlider) -> void:
	var grabber := StyleBoxFlat.new()
	grabber.bg_color = GOLD
	grabber.set_corner_radius_all(6)
	grabber.content_margin_left = 5.0
	grabber.content_margin_right = 5.0
	grabber.content_margin_top = 5.0
	grabber.content_margin_bottom = 5.0
	var groove := StyleBoxFlat.new()
	groove.bg_color = Color(0, 0, 0, 0.5)
	groove.border_color = Color(0.4, 0.32, 0.26)
	groove.set_border_width_all(1)
	groove.set_corner_radius_all(2)
	groove.content_margin_top = 3.0
	groove.content_margin_bottom = 3.0
	slider.add_theme_stylebox_override("grabber_area", groove.duplicate())
	var active: StyleBoxFlat = groove.duplicate()
	active.bg_color = Color(0.55, 0.35, 0.12)
	slider.add_theme_stylebox_override("grabber_area_highlight", active)
	slider.add_theme_stylebox_override("slider", groove)
	slider.add_theme_icon_override("grabber", _grabber_icon(GOLD))
	slider.add_theme_icon_override("grabber_highlight", _grabber_icon(WHITE))
	slider.add_theme_icon_override("grabber_disabled", _grabber_icon(MUTED))


func _grabber_icon(color: Color) -> ImageTexture:
	var image := Image.create(12, 12, false, Image.FORMAT_RGBA8)
	for y in range(12):
		for x in range(12):
			var dx: float = x - 5.5
			var dy: float = y - 5.5
			image.set_pixel(x, y, color if dx * dx + dy * dy <= 25.0 else Color(0, 0, 0, 0))
	return ImageTexture.create_from_image(image)
