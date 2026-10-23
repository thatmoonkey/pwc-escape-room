class_name Interactable
extends StaticBody3D

## Base class for everything the crew member can aim at and use.
##
## Sits on collision layer 3 (value 4) so the interaction ray (mask 4) finds it,
## and keeps mask 1 so the player still bumps into it instead of walking through.
##
## A child Node3D whose name starts with "Highlight" is the aim outline; it is
## hidden until the player looks at this node.

signal interacted(by)

@export var prompt: String = "Use"
@export var active: bool = true
@export var one_shot: bool = false

var _highlight_nodes: Array[Node3D] = []


func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	add_to_group("interactable")
	for child in get_children():
		if child is Node3D and String(child.name).begins_with("Highlight"):
			_highlight_nodes.append(child)
			child.visible = false


func get_prompt() -> String:
	return prompt


func can_interact(_by: Node) -> bool:
	return active


func interact(by: Node) -> void:
	interacted.emit(by)
	if one_shot:
		active = false


func set_highlighted(value: bool) -> void:
	for node in _highlight_nodes:
		if is_instance_valid(node):
			node.visible = value


func flash() -> void:
	## Short visual acknowledgement so every input has feedback.
	var target: Node3D = _highlight_nodes[0] if not _highlight_nodes.is_empty() else null
	if target == null:
		return
	target.visible = true
	var tween := create_tween()
	tween.tween_interval(0.08)
	tween.tween_callback(func() -> void: target.visible = false)
