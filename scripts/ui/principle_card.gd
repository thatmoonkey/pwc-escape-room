class_name PrincipleCard
extends CanvasLayer

## The reflection card shown when a decision is placed on the operating model.
## Blocks input until dismissed, then hands control back to the room.
##
## It used to print one AI-safety principle per system. It now reflects the
## decision back instead: what was placed, whether it follows from the mandate
## the player declared, and whether it is defensible for what that decision can
## cost and whether it can be undone. The text comes from Score, so the card and
## the debrief can never disagree about the same placement.
##
## The class keeps its name because scenes/ui/principle_card.tscn instances it
## and the station controller holds it under that node name; renaming it would
## touch the scene layer for no behavioural gain.

signal closed

@onready var root: Control = $Root
@onready var dim: ColorRect = $Root/Dim
@onready var card: PanelContainer = $Root/Card
@onready var kicker: Label = $Root/Card/Margin/VBox/Kicker
@onready var title_label: Label = $Root/Card/Margin/VBox/Title
@onready var system_label: Label = $Root/Card/Margin/VBox/System
@onready var body_label: Label = $Root/Card/Margin/VBox/Body
@onready var hint: Label = $Root/Card/Margin/VBox/Hint

var _open: bool = false


func _ready() -> void:
	root.visible = false


func is_open() -> bool:
	return _open


func show_card(system_id: String) -> void:
	_open = true
	kicker.text = "OPERATING MODEL  -  DECISION REFLECTION"
	title_label.text = "DECISION %d / %d" % [GameState.system_index(system_id), GameState.SYSTEMS.size()]
	if GameState.has_placement(system_id):
		system_label.text = "%s  -  PLACED" % GameState.display_name(system_id)
	else:
		system_label.text = "%s  -  NOT YET PLACED" % GameState.display_name(system_id)
	body_label.text = Score.reflection_text(system_id)
	hint.text = "Click or press any key to continue"
	root.visible = true
	root.modulate = Color(1, 1, 1, 0)
	var tween := create_tween()
	tween.tween_property(root, "modulate", Color(1, 1, 1, 1), 0.25)
	InputRouter.set_ui_blocking(true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func dismiss() -> void:
	if not _open:
		return
	_open = false
	root.visible = false
	InputRouter.set_ui_blocking(false)
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not _open:
		return
	var dismissed: bool = false
	if event is InputEventMouseButton and event.pressed:
		dismissed = true
	elif event is InputEventScreenTouch and event.pressed:
		## A tap on a touchscreen, accepted explicitly rather than relying on the
		## engine emulating a mouse button from it: without this the card could
		## not be dismissed on a device with no keyboard.
		dismissed = true
	elif event is InputEventKey and event.pressed and not event.echo:
		dismissed = true
	elif event.is_action_pressed("interact"):
		dismissed = true
	if dismissed:
		dismiss()
		get_viewport().set_input_as_handled()
