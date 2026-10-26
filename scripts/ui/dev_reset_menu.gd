class_name DevResetMenu
extends CanvasLayer

## Developer-only test panel. It sits outside the fiction on purpose: SHIPMIND
## never mentions it and none of it is written in the ship's voice, so it stays
## obvious that this is scaffolding rather than part of the game.
##
## Two decisions worth knowing before you change it:
##
## 1. Every action RELOADS the scene rather than patching state in place. A soft
##    reset would clear GameState but leave each Puzzle's own is_solved flag (and
##    its _swept / _trusted_ai / _audited flags) still set, so a console would go
##    on reading "already under crew control" aboard a ship where nothing is
##    restored. Reloading brings the doors, the windows, the bay consoles and the
##    HUD back from one state.
## 2. It releases the UI block before reloading. InputRouter.ui_blocking is a
##    static var, so it outlives the scene swap - left set, the player would load
##    back in frozen and unable to look around.
##
## This is the only place that clears progress. The kiosk's [DEV] simulate option
## still only writes GameState, so after using that the world does not match
## until this panel has reloaded it.

@onready var root: Control = $Root
@onready var status_label: Label = $Root/Card/Margin/VBox/Status
@onready var reset_button: Button = $Root/Card/Margin/VBox/Buttons/ResetAll
@onready var restore_button: Button = $Root/Card/Margin/VBox/Buttons/RestoreAll
@onready var reload_button: Button = $Root/Card/Margin/VBox/Buttons/Reload
@onready var close_button: Button = $Root/Card/Margin/VBox/Buttons/Close

var _reloading: bool = false
var _teaser: Label = null
var _mode_buttons: Dictionary = {}


func _ready() -> void:
	add_to_group("dev_reset_menu")
	root.visible = false
	_build_teaser()
	_build_mode_row()
	reset_button.pressed.connect(_on_reset_all)
	restore_button.pressed.connect(_on_restore_all)
	reload_button.pressed.connect(_on_reload_only)
	close_button.pressed.connect(close)


func is_open() -> bool:
	return root.visible


func open() -> void:
	_refresh_status()
	_refresh_mode_buttons()
	root.visible = true
	_set_teaser(false)
	InputRouter.set_ui_blocking(true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close() -> void:
	root.visible = false
	_set_teaser(true)
	InputRouter.set_ui_blocking(false)


func _refresh_status() -> void:
	var save_state: String = "save file: present" if GameState.has_save() else "save file: none"
	status_label.text = "%d / %d systems restored\noverride log: %d entries\n%s" % [
		GameState.restored_count(),
		GameState.SYSTEMS.size(),
		GameState.override_log.size(),
		save_state,
	]


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("dev_menu"):
		if is_open():
			close()
		elif not InputRouter.ui_blocking:
			# Another overlay owns the screen; do not stack two modals.
			open()
		get_viewport().set_input_as_handled()
		return
	if not is_open():
		return
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _on_reset_all() -> void:
	GameState.clear_save()
	_reload()


## The same test switch the launch screen carries, here for flipping the input
## mode mid-run: mobile's floating sticks and the HUD's compact variant can be
## checked without leaving the ship. VR is best-effort - with no OpenXR runtime
## the mode refuses and the status line says so.
func _build_mode_row() -> void:
	var vbox := $Root/Card/Margin/VBox as VBoxContainer
	var buttons := vbox.get_node("Buttons") as VBoxContainer
	var row := HBoxContainer.new()
	row.name = "ModeRow"
	row.add_theme_constant_override("separation", 6)

	var caption := Label.new()
	caption.text = "INPUT MODE"
	caption.add_theme_font_size_override("font_size", 12)
	row.add_child(caption)

	var group := ButtonGroup.new()
	group.allow_unpress = false
	for value in [InputMode.Mode.DESKTOP, InputMode.Mode.TOUCH, InputMode.Mode.VR]:
		var chip := Button.new()
		chip.text = InputMode.label(int(value))
		chip.toggle_mode = true
		chip.button_group = group
		chip.add_theme_font_size_override("font_size", 12)
		chip.pressed.connect(_on_mode_button.bind(int(value)))
		_mode_buttons[int(value)] = chip
		row.add_child(chip)

	vbox.add_child(row)
	vbox.move_child(row, buttons.get_index())


func _on_mode_button(value: int) -> void:
	if not InputMode.set_mode(value):
		status_label.text = "No OpenXR runtime found - VR stays off."
	_refresh_mode_buttons()


func _refresh_mode_buttons() -> void:
	InputMode.ensure_detected()
	for value in _mode_buttons:
		var chip: Button = _mode_buttons[value]
		chip.set_pressed_no_signal(int(value) == InputMode.mode)


func _on_restore_all() -> void:
	for system_id in GameState.SYSTEMS:
		GameState.mark_restored(system_id)
	_reload()


func _on_reload_only() -> void:
	_reload()


func _reload() -> void:
	if _reloading:
		return
	_reloading = true
	InputRouter.set_ui_blocking(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().call_deferred("reload_current_scene")


## A small always-visible corner label. Without it the panel is undiscoverable:
## it is hidden until the key is pressed, and the only hint lives inside the
## panel you cannot see yet. Built in code so the dev scaffolding stays in one
## file, and hidden while the panel is open so it never overlaps the card.
func _build_teaser() -> void:
	_teaser = Label.new()
	_teaser.name = "Teaser"
	_teaser.anchor_left = 1.0
	_teaser.anchor_top = 1.0
	_teaser.anchor_right = 1.0
	_teaser.anchor_bottom = 1.0
	_teaser.offset_left = -360.0
	_teaser.offset_top = -34.0
	_teaser.offset_right = -16.0
	_teaser.offset_bottom = -12.0
	_teaser.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_teaser.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_teaser.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_teaser.add_theme_color_override("font_color", Color(1.0, 0.55, 0.12, 0.85))
	_teaser.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.03, 1.0))
	_teaser.add_theme_constant_override("outline_size", 4)
	_teaser.add_theme_font_size_override("font_size", 13)
	_teaser.text = "DEV TOOL   F8 or `  -  reset progress"
	add_child(_teaser)


func _set_teaser(value: bool) -> void:
	if _teaser != null and is_instance_valid(_teaser):
		_teaser.visible = value
